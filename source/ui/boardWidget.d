module ui.boardWidget;

import std.array;
import std.algorithm;
import std.conv;
import std.datetime.systime;
import std.stdio;
import std.typecons;
import core.time;

import cairo.Context;
import cairo.Matrix;
import gdk.Event;
import gdk.FrameClock;
import gtk.DrawingArea;
import gtk.Widget;
import gobject.Signals;

import game;
import player;
import utils.signals;
import ui.dicewidget;

// TODO:
// - Animation for starting new game. Flashes are bad!
// - Testing & benchmarking animations (potentially use separate thread?)
// - Use GDK frameclock for animations
// - Unstarted games
// - Split this up for god's sake

struct RGB {
    double r, g, b;
}

// Moving off the board? Moving to bar and back...
private struct PipTransition {
    uint startPoint;
    uint endPoint;
    bool undone;
    bool takesPiece;
    SysTime startTime;
}

private struct ScreenCoords {
    float x;
    float y;
}

static void setSourceRgbStruct(Context cr, RGB color) {
    cr.setSourceRgb(color.r, color.g, color.b);
}

/**
 * The layout of the board. Measurements are all relative as the board will
 * resize to fit its layout
 */
class BoardStyle {
    float boardWidth = 1200.0;          /// Width of the board.
    float boardHeight = 800.0;          /// Height of the board
    RGB boardColor = RGB(0.18, 0.204, 0.212); /// Board background colour 

    float borderWidth = 15.0;           /// Width of the border enclosing the board
    float borderFontHeight = 10.0;      /// Height of the font of the board numbers
    float barWidth = 70.0;              /// Width of bar in the centre of the board
    RGB borderColor = RGB(0.14969, 0.15141, 0.15141); /// Colour of the border

    float pointWidth = 75.0;            /// Width of each point
    float pointHeight = 300.0;          /// Height of each point
    RGB lightPointColor = RGB(0.546875, 0.390625, 0.167969); /// Colour of light points
    RGB darkPointColor = RGB(0.171875, 0.2421875, 0.3125);   /// Colour of dark points

    float pipRadius = 30.0;             /// Radius of pips
    float pipBorderWidth = 3.0;         /// Width of pip border
    RGB p1Colour = RGB(0.0, 0.0, 0.0);  /// Colour of player 1's pips
    RGB p2Colour = RGB(1.0, 1.0, 1.0);  /// Colour of player 2's pips

    double messageRadius = 15.0;
    double messagePadding = 30.0;
    double messageFontSize = 30.0;
    long animationSpeed = 750;          /// Msecs to perform animation
}

/// A corner of the board. Useful for describing where a user's home should be.
/// In the future, this will be changeable in the settings.
enum Corner {
    BL,
    BR,
    TL,
    TR
}

/**
 * Widget for rendering a backgammon game state
 */
class BackgammonBoard : DrawingArea {
    private:
    /**
     * The gameState gamestate that is being rendered
     */
    GameState _gameState;

    /**
     * The current styling. Will be modifiable in the future.
     */
    BoardStyle style;

    /**
     * Moves that are not part of the gamestate, but have been selected by the
     * user as potential moves. The board will animate these movements if
     * animation is enabled.
     */
    PipMovement[] _selectedMoves;

    /// Animation
    SysTime lastAnimation;
    SysTime frameTime;
    AnimatedDieWidget[] animatedDice;
    PipTransition[] transitionStack;

    bool showEndGame;
    SysTime endGameTransition;

    bool applyTurnAtEndOfAnimation = false;

    /// The coordinates of each point on the screen in device. Just store matrix?
    ScreenCoords[2][24] pointCoords;
    double[2] barXCoordinates;

    /// Fired when the user selects or undoes a potential move
    public Signal!() onChangePotentialMovements;
    public Signal!() onCompleteDiceAnimation;
    public Signal!() onCompleteTransitionAnimation;
    Corner p1Corner = Corner.TR;

    /**
     * Create a new Backgammon Board widget.
     */
    public this() {
        super();
        this.onChangePotentialMovements = new Signal!();
        this.onCompleteDiceAnimation = new Signal!();
        this.onCompleteTransitionAnimation = new Signal!();

        setHalign(GtkAlign.FILL);
        setValign(GtkAlign.FILL);
        setHexpand(true);
        setVexpand(true);

        style = new BoardStyle;

        addOnDraw(&this.onDraw);
        addOnConfigure(&this.onConfigureEvent);
        addTickCallback(delegate bool (Widget w, FrameClock f) {
            this.queueDraw();
            return true;
        });
        this.addOnButtonPress(delegate bool (Event e, Widget w) {
            return this.handleMouseClick(e);
        });
    }

    /**
     * Create a new BackgammonBoard widget and set the gamestate
     */
    public this(GameState gs) {
        this();
        this.setGameState(gs);
    }

    /**
     * Handles GTK moust click events. This currently includes piece movement
     * as well as forward/backward buttons for undo/complete move.
     */
    bool handleMouseClick(Event e) {
        // Only accept left clicks - ignore right clicks and double click events
        if (e.button.type != GdkEventType.BUTTON_PRESS) {
            return false;
        }


        // If we aren't animating and it's a user's turn
        if (animatedDice.length && animatedDice[0].finished
                && this.getGameState().turnState == TurnState.MoveSelection
                && this.getGameState().players[getGameState().currentPlayer].type == PlayerType.User) {

            /**
            * Back and forward buttons
            */
            if (e.button.button == 8) {
                this.undoSelectedMove();
                return false;
            } else if (e.button.button == 9) {
                try {
                    getGameState().validateTurn(getSelectedMoves());
                    this.finishTurn();
                } catch (Exception e) { /* Wasn't valid, won't finsh turn */ }
                return false;
            }

            auto possibleTurns = getGameState().generatePossibleTurns();
            if (!possibleTurns.length) return false;

            if (getSelectedMoves().length == possibleTurns[0].length) return false;

            // Where have we clicked?
            uint startPos;

            // And check that player is user
            foreach (uint i, c; pointCoords) {
                if (e.button.y > min(c[0].y, c[1].y)
                        && e.button.y < max(c[0].y, c[1].y)
                        && e.button.x > c[0].x - style.pointWidth/2.5
                        && e.button.x < c[0].x + style.pointWidth/2.5) {
                    startPos = i + 1;
                    break;
                }
            }

            if (!startPos) {
                if (barXCoordinates[0] < e.button.x && e.button.x < barXCoordinates[1]) {
                    startPos = 0;
                } else {
                    return false;
                }
            }

            // TODO: Potential move might not be first avaiable dice
            uint[] moveValues = getGameState().diceValues;
            moveValues = moveValues[0] == moveValues[1]
                ? moveValues ~ moveValues
                : moveValues;
            try {
                outer: foreach (t; possibleTurns) {
                    // If it starts with the moves we've already done
                    foreach (j; 0..getSelectedMoves.length) {
                        if (getSelectedMoves[j] != t[j]) continue outer;
                    }
                    if (t[getSelectedMoves.length].startPoint == startPos) {
                        selectMove(t[getSelectedMoves.length]);
                        break;
                    }
                }

                onChangePotentialMovements.emit();
            } catch (Exception e) {
                writeln("Invalid move: ", e.message);
            }
        }
        return false;
    }

    /**
     * Return moves currently selected
     */
    public PipMovement[] getSelectedMoves() {
        return _selectedMoves.dup;
    }

    /**
     * Select a move. This will not be applied to the gamestate but will be
     * layered on top of it for the user to see.
     * TODO: Move signal firing to here
     */
    public void selectMove(PipMovement move) {
        // Assert that its a valid move... Contract programming?

        // Do we need to wait for another point?
        SysTime startTime = Clock.currTime;
        if (move.startPoint) {
            const auto pointAtStart = calculatePointAtTime(move.startPoint, startTime);
            if (pointAtStart.numPieces == 0
                    || pointAtStart.owner == getGameState.currentPlayer.opposite) {
                // Find the last time that someone landed there
                auto landed = transitionStack.filter!(t => t.endPoint == move.startPoint).array;
                assert(landed.length);
                startTime = landed[$-1].startTime + style.animationSpeed.msecs;
            }
        }

        // Is this going to take a piece?
        bool takesPiece = false;
        if (move.endPoint && selectedGameState.points[move.endPoint].owner == getGameState().currentPlayer.opposite) {
            takesPiece = true;
        }

        _selectedMoves ~= move;
        transitionStack ~= PipTransition(
            move.startPoint,
            move.endPoint,
            false,
            takesPiece,
            startTime);

    }

    /// The current gamestate with selected moves applied. Transitions are
    /// Transitioning towards this
    public GameState selectedGameState() {
        if (getGameState().turnState == TurnState.MoveSelection) {
            GameState r = getGameState().dup;

            r.applyTurn(getSelectedMoves(), true);
            return r;
        } else {
            assert(getSelectedMoves().length == 0);
            return getGameState();
        }
    }

    /**
     * Finish a turn but submitting the current potential moves to the game state.
     * Maybe remove this... Don't like the idea of renderer managing gamestate
     */
    public void finishTurn() {
        applyTurnAtEndOfAnimation = true;
    }

    /**
     * Remove the most recent potential move
     */
    public void undoSelectedMove() {
        if (_selectedMoves.length > 0) {
            _selectedMoves = _selectedMoves[0..$-1];
            transitionStack = transitionStack[0..$-1]; // Might want to undo more
            onChangePotentialMovements.emit();
        }
    }

    /**
     * Get the current gameState
     */
    public GameState getGameState() {
        return _gameState;
    }

    /**
     * Set the current gamestate and start listening to its events
     * TODO: Wipe current listeners. Check current state e.g. dice, is finished
     */
    public void setGameState(GameState gameState) {
        gameState.onDiceRolled.connect((GameState gs, uint a, uint b) {
            animatedDice = [
                new AnimatedDieWidget(a, 2 * style.animationSpeed),
                new AnimatedDieWidget(b, 2 * style.animationSpeed),
            ];
            lastAnimation = Clock.currTime;
        });
        gameState.onBeginTurn.connect((GameState gs, Player p) {
            animatedDice = [];
            _selectedMoves = [];
            onChangePotentialMovements.emit();
        });
        gameState.onEndGame.connect((GameState gs, Player winner) {
            this.showEndGame = true;
            this.endGameTransition = Clock.currTime;
        });
        gameState.onStartGame.connect((GameState gs) {
            this.showEndGame = false;
        });

        this._gameState = gameState;
        this.transitionStack = [];
        this._selectedMoves = [];
        this.animatedDice = [];
        this.applyTurnAtEndOfAnimation = false;
    }

    /**
     * Returns whether the board has unfinished animations either from selection
     * or from dice roll
     */
    public bool isAnimating() {
        const bool isDiceRolling = !!animatedDice.length ? !animatedDice[0].finished : false;
        return !!transitionStack
                .filter!(t => (t.startTime + style.animationSpeed.msecs > frameTime)
                    || (t.takesPiece && t.startTime + 2*style.animationSpeed.msecs > frameTime))
                .array.length
            || isDiceRolling;
    }

    /**
     * Set the corner of the board that a player should be at
     */
    public void setPlayerCorner(Player p, Corner c) {
        if (p == Player.P1) {
            this.p1Corner = c;
        } else if (p == Player.P2) {
            switch (c) {
            case Corner.BR: p1Corner = Corner.TR; break;
            case Corner.BL: p1Corner = Corner.TL; break;
            case Corner.TR: p1Corner = Corner.BR; break;
            case Corner.TL: p1Corner = Corner.BL; break;
            default: assert(0);
            }
        }
    }

    /**
     * =========================================================================
     * DRAWING
     * The following functions relate to drawing the board.
     * =========================================================================
     */

    void drawDice(Context cr) {
        auto currTime = Clock.currTime();
        auto dt = currTime - lastAnimation;

        if (animatedDice.length) {
            bool startFinished = animatedDice[0].finished;
            foreach (i, die; animatedDice) {
                cr.save();


                die.update(dt.total!"msecs" / 1_000.0);
                cr.translate(65*i + style.boardWidth * 0.65, style.boardHeight / 2 + 25*i);
                cr.scale(style.boardWidth / 24, style.boardWidth / 24);
                die.draw(cr);

                cr.restore();
            }
            if (startFinished != animatedDice[1].finished) {
                onCompleteDiceAnimation.emit();
            }
        }

        lastAnimation = currTime;
    }

    bool onDraw(Scoped!Context cr, Widget widget) {
        // Centering and scaling the board
        auto scaleFactor = min(
            getAllocatedWidth() / style.boardWidth,
            getAllocatedHeight() / style.boardHeight,
        );
        cr.translate(
            (getAllocatedWidth() - scaleFactor*style.boardWidth) / 2,
            (getAllocatedHeight() - scaleFactor*style.boardHeight) / 2
        );
        cr.scale(scaleFactor, scaleFactor);

        drawBoard(cr);

        frameTime = Clock.currTime(); // for animations
        if (this.getGameState() && this.getGameState._currentPlayer != Player.NONE) {
            drawPips(cr);
            drawDice(cr);
        }

        drawMessages(cr);

        if (showEndGame) {
            // End game animation takes style.animationSpeed number of msecs
            float animProgress = (Clock.currTime - endGameTransition).total!"msecs"
                / cast(float) style.animationSpeed;
            if (animProgress > 1.0) animProgress = 1.0;

            cr.setSourceRgba(0.0, 0.0, 0.0, 0.4 * animProgress);
            cr.lineTo(0, 0);
            cr.lineTo(style.boardWidth, 0);
            cr.lineTo(style.boardWidth, style.boardHeight);
            cr.lineTo(0, style.boardHeight);
            cr.fill();

            cr.setSourceRgba(1.0, 1.0, 1.0, animProgress);
            string endGameText = getGameState.players[getGameState.winner].name ~ " wins";
            cr.setFontSize(100);
            cairo_text_extents_t extents;
            cr.textExtents(endGameText, &extents);
            cr.moveTo(
                (style.boardWidth - extents.width) / 2,
                (style.boardHeight- extents.height) / 2
            );
            cr.showText(endGameText);
        }

        if (applyTurnAtEndOfAnimation && !isAnimating()) {
            applyTurnAtEndOfAnimation = false;
            auto pMoves = getSelectedMoves();
            _selectedMoves = [];
            transitionStack = [];
            getGameState().applyTurn(pMoves);
        }

        return false;
    }

    /**
     * Draw the board onto the context. This includes the border, the bar, the
     * points on the board, the background etc (but not the pips).
     */
    void drawBoard(Context cr) {
        // Draw border
        cr.setSourceRgbStruct(style.borderColor);
        cr.lineTo(0, 0);
        cr.lineTo(style.boardWidth, 0);
        cr.lineTo(style.boardWidth, style.boardHeight);
        cr.lineTo(0, style.boardHeight);
        cr.fillPreserve();
        cr.clip();

        // Draw board background over it
        cr.setSourceRgbStruct(style.boardColor);
        cr.lineTo(style.borderWidth, style.borderWidth);
        cr.lineTo(style.boardWidth - style.borderWidth, style.borderWidth);
        cr.lineTo(style.boardWidth - style.borderWidth, style.boardHeight - style.borderWidth);
        cr.lineTo(style.borderWidth, style.boardHeight - style.borderWidth);
        cr.fill();

        // Draw the bar
        cr.setSourceRgbStruct(style.borderColor);
        cr.lineTo((style.boardWidth - style.barWidth) / 2, 0);
        cr.lineTo((style.boardWidth + style.barWidth) / 2, 0);
        cr.lineTo((style.boardWidth + style.barWidth) / 2, style.boardHeight);
        cr.lineTo((style.boardWidth - style.barWidth) / 2, style.boardHeight);
        cr.fill;
        // And save it for clicks
        double yCoord = 0.0;
        barXCoordinates[0] = (style.boardWidth - style.barWidth) / 2;
        barXCoordinates[1] = (style.boardWidth + style.barWidth) / 2;
        cr.userToDevice(barXCoordinates[0], yCoord);
        cr.userToDevice(barXCoordinates[1], yCoord);
        barXCoordinates[0]-=25;
        barXCoordinates[1]-=25;

        foreach (uint i; 0..24) {
            auto c = getPointPosition(i+1);

            // Record the point poisitoin
            ScreenCoords toDevice(ScreenCoords sc) {
                double x = sc.x;
                double y = sc.y;
                cr.userToDevice(x, y);
                // TODO: Remove these magic numbers, where do they come from?
                return ScreenCoords(x - 25, y - 70);
            }

            pointCoords[i][0] = toDevice(c[0]);
            pointCoords[i][1] = toDevice(c[1]);

            // Draw the point
            cr.moveTo(c[0].x - style.pointWidth/2, c[0].y);
            cr.lineTo(c[1].x, c[1].y);
            cr.lineTo(c[0].x + style.pointWidth/2, c[0].y);

            cr.setSourceRgbStruct(i%2 ? style.darkPointColor : style.lightPointColor);
            cr.fill();
            cr.stroke();

            // Draw numbers
            bool isTop = pointCoords[i][0].y < pointCoords[i][1].y;
            cairo_text_extents_t extents;
            cr.setFontSize(style.borderFontHeight);
            cr.textExtents((i+1).to!string, &extents);
            cr.moveTo(c[0].x - extents.width/2, c[0].y
                - (style.borderWidth - extents.height) / 2
                + (isTop ? 0 : style.borderWidth)
                );
            cr.setSourceRgb(1.0, 1.0, 1.0);
            cr.showText((i+1).to!string);
            cr.newPath();
        }
    }

    /**
     * Returns a tuple containing the bottom (centre) and top of the points
     * position. By default we will be starting at top right.
     * Params:
     *      pointIndex = point number between 0 and 23
     */
    Tuple!(ScreenCoords, ScreenCoords) getPointPosition(uint pointIndex) {
        // Calculate for TR and then modify at the end
        assert (1 <= pointIndex && pointIndex <= 24);
        pointIndex--;

        ScreenCoords start;
        ScreenCoords finish;

        // y-coordinate
        if (pointIndex < 12) {
            start.y = style.borderWidth;
            finish.y = style.borderWidth + style.pointHeight;
        } else {
            start.y = style.boardHeight - style.borderWidth;
            finish.y = style.boardHeight - (style.borderWidth + style.pointHeight);
        }

        // x-coordinate
        const float halfBoardWidth = (style.boardWidth - 2*style.borderWidth - style.barWidth) / 2;
        const float pointSeparation = (halfBoardWidth + 1) / 6;
        if (pointIndex < 12) { // top
            start.x = style.boardWidth - (style.borderWidth + (pointIndex+0.5)*pointSeparation);
            if (pointIndex > 5) {
                start.x -= style.barWidth;
            }
            finish.x = start.x;
        } else { // left side
            start.x = style.borderWidth + (pointIndex-12+0.5)*pointSeparation;
            if (pointIndex > 17) {
                start.x += style.barWidth;
            }
            finish.x = start.x;
        }

        if (p1Corner == Corner.BR || p1Corner == Corner.BL) {
            // Invert the y axis
            start.y = style.boardHeight - start.y;
            finish.y = style.boardHeight - finish.y;
        }

        if (p1Corner == Corner.BL || p1Corner == Corner.TL) {
            // Invert the x axis
            start.x = style.boardWidth - start.x;
            finish.x = style.boardWidth - finish.x;
        }

        return tuple(start, finish);
    }

    ScreenCoords getPipPosition(uint pointNum, uint pipNum) {
        assert (1 <= pointNum && pointNum <= 24);
        // assert (pipNum);
        if (!pipNum) {
            writeln(getGameState.currentPlayer());
            writeln(pointNum, " ", getGameState.points[pointNum]);
            writeln(transitionStack);
            writeln("frameTime: ", frameTime);
            throw new Exception("errrr");
        }
        pointNum--;
        pipNum--;
        auto pointPosition = getPointPosition(pointNum+1);
        double pointY = style.borderWidth + ((2 * pipNum + 1) * style.pipRadius);
        if (pointPosition[0].y > pointPosition[1].y) {
            pointY = style.boardHeight - pointY;
        }

        return ScreenCoords(pointPosition[0].x, pointY);
    }

    ScreenCoords getTakenPipPosition(Player player, uint pipNum) {
        assert(pipNum && pipNum <= 20);
        float pointX = style.boardWidth / 2;
        float pointY = style.boardHeight / 2 - (pipNum+1)*style.pipRadius;
        if (player == Player.P2) pointY = style.boardHeight - pointY;
        return ScreenCoords(pointX, pointY);
    }

    PipTransition[] getCurrentTransitions() {
        return transitionStack
            .filter!(t => t.startTime + style.animationSpeed.msecs > frameTime)
            .filter!(t => t.startTime < frameTime)
            .array;
    }

    /**
     * Calculates what a point will look like at a certain point in time
     */
    Point calculatePointAtTime(uint pointNum, SysTime time) {
        assert(1 <= pointNum && pointNum <= 24);

        auto numPips = getGameState().points[pointNum].numPieces;

        // Add the ones that arrived
        numPips += transitionStack
            .filter!(t => t.endPoint == pointNum)
            .filter!(t => t.startTime + style.animationSpeed.msecs <= time)
            .array.length;

        // Minus the ones that left
        numPips -= transitionStack
            .filter!(t => t.startPoint == pointNum)
            .filter!(t => t.startTime < time)
            .array.length;
        
        if (transitionStack.filter!(t => t.endPoint == pointNum)
                .filter!(t => t.startTime + style.animationSpeed.msecs <= time).array.length) {

            if (getGameState().points[pointNum].owner == getGameState().currentPlayer.opposite) {
                return Point(getGameState().currentPlayer, --numPips);
            } else  {
                return Point(getGameState().currentPlayer, numPips);
            }
        }
        
        // Should change this to an assert tbqh
        if (numPips > 100) {
            writeln(getGameState.currentPlayer);
            writeln(pointNum, " ", getGameState.points[pointNum]);
            writeln(time);
            writeln(transitionStack);
            writeln(getSelectedMoves);
            assert(0);
        }

        return Point(getGameState.points[pointNum].owner, numPips);
    }

    /**
     * Calculates what's been taken
     */
    uint calculateTakenPiecesAtTime(Player player, SysTime time) {
        uint numPips = getGameState().takenPieces[player];
        // Add points that have arrived
        if (player == getGameState().currentPlayer().opposite) {
            numPips += transitionStack.filter!(t => t.takesPiece
                && t.startTime + 2*style.animationSpeed.msecs <= time).array.length;
        } else {
            numPips -= transitionStack.filter!(t => !t.startPoint && t.startTime < time).array.length;
        }
        // Minus points that have left
        return numPips;
    }

    /**
     * Draw gamestate pips onto the context
     */
    void drawPips(Context cr) {
        // General function for drawing a pip at a certain point
        void drawPip(float pointX, float pointY, RGB color) {
            import std.math : PI;
            cr.arc(pointX, pointY, style.pipRadius - style.pipBorderWidth/2, 0, 2*PI);

            // Centre
            cr.setSourceRgbStruct(color);
            cr.fillPreserve();

            // Outline
            cr.setLineWidth(style.pipBorderWidth);
            cr.setSourceRgb(0.5, 0.5, 0.5);
            cr.stroke();
        }

        /**
         * Draw pip in between two positions
         */
        void tweenPip(ScreenCoords startPos, ScreenCoords endPos, float progress, Player player) {
            // Functions found here https://gist.github.com/gre/1650294
            // in/out quadratic easing
            float easingFunc(float t) {
                return t<.5 ? 2*t*t : -1+(4-2*t)*t;
            }

            // Tween between positions
            auto currPosition = ScreenCoords(
                startPos.x + easingFunc(progress)*(endPos.x - startPos.x),
                startPos.y + easingFunc(progress)*(endPos.y - startPos.y)
            );

            drawPip(currPosition.x, currPosition.y, player == Player.P1
                    ? style.p1Colour
                    : style.p2Colour);
        }

        // Draw pips on each point
        uint pointNum = 0;
        foreach(point; this.selectedGameState.points) {
            const auto calculatedPoint = calculatePointAtTime(pointNum+1, frameTime);

            foreach(n; 0..calculatedPoint.numPieces) {
                auto pipPosition = getPipPosition(pointNum + 1, n + 1);
                drawPip(cast(uint) pipPosition.x, cast(uint) pipPosition.y,
                    calculatedPoint.owner == Player.P1 ? style.p1Colour : style.p2Colour);
            }
            pointNum++;
        }

        // Player 1 at the top. Pips start in the middle and work their way out
        foreach (player; [Player.P1, Player.P2]) {
            foreach (uint i; 0..calculateTakenPiecesAtTime(player, frameTime)) {
                auto point = getTakenPipPosition(player, i+1);
                drawPip(point.x, point.y, player == Player.P1 ? style.p1Colour : style.p2Colour);
            }
        }

        // Draw pieces being taken
        foreach (takenTransition; transitionStack
                .filter!(t => t.takesPiece)
                .filter!(t => t.startTime + 2*style.animationSpeed.msecs > frameTime)
                .filter!(t => t.startTime + style.animationSpeed.msecs < frameTime)
                .array) {
            auto startPos = getPipPosition(takenTransition.endPoint, 1);
            auto endPos = getTakenPipPosition(getGameState().currentPlayer.opposite,
                calculateTakenPiecesAtTime(getGameState().currentPlayer.opposite,
                takenTransition.startTime + 2*style.animationSpeed.msecs));
            float progress = (frameTime -
                (takenTransition.startTime +style.animationSpeed.msecs)
                ).total!"msecs" / cast(float) style.animationSpeed;
            tweenPip(startPos, endPos, progress, getGameState().currentPlayer.opposite);
        }

        // Draw pip movement animations
        foreach (transition; getCurrentTransitions()) {
            ScreenCoords startPos;
            ScreenCoords endPos;

            // If it's coming from the bar
            if (!transition.startPoint) {
                auto startingPip = calculateTakenPiecesAtTime(
                    getGameState().currentPlayer, transition.startTime
                );
                startPos = getTakenPipPosition(getGameState().currentPlayer, startingPip);
            } else {
                auto startPoint = calculatePointAtTime(transition.startPoint, transition.startTime);
                startPos = getPipPosition(transition.startPoint, startPoint.numPieces);
            }

            // If it's being borne off
            if (!transition.endPoint) {
                endPos = ScreenCoords(1.5 * style.boardWidth, 0.5*style.boardHeight);
            } else {
                auto endPoint = calculatePointAtTime(transition.endPoint,
                                    transition.startTime + style.animationSpeed.msecs);
                endPos = getPipPosition(transition.endPoint, endPoint.numPieces);
            }

            float progress = (frameTime - transition.startTime).total!"msecs" / cast(float) style.animationSpeed;
            progress = progress > 1.0 ? 1.0 : progress;
            tweenPip(startPos, endPos, progress, getGameState.currentPlayer);
        }

    }

    /**
     * Logic for resizing self
     */
    bool onConfigureEvent(Event e, Widget w) {
        auto short_edge = min(getAllocatedHeight(), getAllocatedWidth());
        auto border_width = cast(uint) style.pointWidth / 2;
        short_edge -= 2 * border_width;
        setSizeRequest(short_edge, short_edge);
        return true;
    }

    string _displayMessage;
    SysTime _startDisplayMessage;
    bool _displayMessageCallbackCalled = true;
    void delegate() _displayMessageCallback;

    /**
     * Display a message to the user in a friendly way
     */
    public void displayMessage(string s, void delegate() dlg) {
        import std.uni : toUpper;
        _displayMessage = s.toUpper;
        _startDisplayMessage = Clock.currTime + 250.msecs;
        _displayMessageCallbackCalled = false;
        _displayMessageCallback = dlg;
    }

    /**
     * Draw a message on the screen
     */
    void drawMessages(Context cr) {
        // Fade in/out time is 0.25 anim. Display is 1.5 anim
        double animProgress = cast(double) (Clock.currTime - _startDisplayMessage).total!"msecs"
                                                    / (2*style.animationSpeed);
        if (animProgress > 1.0) {
            if (!_displayMessageCallbackCalled) _displayMessageCallback();
            _displayMessageCallbackCalled = true;
            return;
        }
        double alpha; // Transparency of message
        if (animProgress < 0.125) {
            alpha = (animProgress / 0.125) * 0.5;
        } else if (animProgress > 0.875) {
            alpha = ((1.0 - animProgress) / 0.125) * 0.5;
        } else {
            alpha = 0.5;
        }

        // Find size of displayed message
        cr.setFontSize(style.messageFontSize);
        cr.selectFontFace("Calibri",
            cairo_font_slant_t.NORMAL,
            cairo_font_weight_t.BOLD);
        cairo_text_extents_t extents;
        cr.textExtents(_displayMessage, &extents);

        // Draw the rounded rectangle
        double x = (style.boardWidth - extents.width) / 2.0 - style.messageRadius - style.messagePadding/2;
        double y = (style.boardHeight - extents.height) / 2.0 - style.messageRadius - style.messagePadding/2;
        double width = extents.width + 2*style.messageRadius + style.messagePadding;
        double height = extents.height + 2*style.messageRadius + style.messagePadding;
        double radius = style.messageRadius;
        double degrees = 0.01745329251;

        cr.newSubPath();
        cr.arc(x + width - radius, y + radius, radius, -90 * degrees, 0 * degrees);
        cr.arc(x + width - radius, y + height - radius, radius, 0 * degrees, 90 * degrees);
        cr.arc(x + radius, y + height - radius, radius, 90 * degrees, 180 * degrees);
        cr.arc(x + radius, y + radius, radius, 180 * degrees, 270 * degrees);
        cr.closePath();

        cr.setSourceRgba(0.0, 0.0, 0.0, alpha);
        cr.fill();

        // Draw the message
        cr.moveTo((style.boardWidth - extents.width) / 2.0,
                    (style.boardHeight + extents.height) / 2.0),
        cr.setSourceRgba(1.0, 1.0, 1.0, alpha);
        cr.showText(_displayMessage);
        cr.fill();
    }

    unittest {
        /**
        * Test point calculation
        */
        // auto gs = new GameState();
        // auto b = new BackgammonBoard(gs);
        // gs.rollDice(3, 3);
        // b.selectMove(PipMovement(PipMoveType.Movement, 13, 10));
        // should be animating now
        // assert(b.calculatePointAtTime(10, Clock.currTime).numPieces == 4);
    }
}
