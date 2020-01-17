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
// - Organise this - perhaps the worst organised module rn
// - Respect which corner / side of board P1 is
// - Testing & benchmarking animations (separate thread)
// - Animation easing, curving
// - Use GDK frameclock for animations

struct RGB {
    double r, g, b;
}

// Start Pip, End Pip?
private struct PipTransition {
    uint startPoint;
    uint endPoint;
    bool undone;
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

    long animationSpeed = 1000;         /// Msecs to perform animation
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

    /// The current styling. Will be modifiable in the future.
    BoardStyle style;

    /// Animation
    SysTime lastAnimation;
    SysTime frameTime;
    AnimatedDieWidget[] animatedDice;
    PipTransition[] transitionStack;

    /// The coordinates of each point on the screen in device. Just store matrix?
    ScreenCoords[2][24] pointCoords;

    /// Fired when the user selects or undoes a potential move
    public Signal!() onChangePotentialMovements;

    /**
     * Moves that are not part of the gamestate, but have been selected by the
     * user as potential moves. The board will animate these movements if
     * Animation is enabled
     */
    PipMovement[] _selectedMoves;

    /**
     * Create a new Backgammon Board widget.
     */
    public this() {
        super();
        this.onChangePotentialMovements = new Signal!();

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
            return this.handleButtonPress(e);
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
     * Handles GTK button press events. This currently only includes piece
     * movement.
     */
    bool handleButtonPress(Event e) {
        // Only accept left clicks - ignore right clicks and double click events
        if (e.button.type != GdkEventType.BUTTON_PRESS) {
            return false;
        }

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
            } catch (Exception e) {
                // Wasn't valid, won't fish turn
            }
            return false;
        }

        if (animatedDice.length && animatedDice[0].finished
                && this.getGameState().turnState == TurnState.MoveSelection
                && this.getGameState().players[getGameState().currentPlayer].type == PlayerType.User) {
            auto possibleTurns = getGameState().generatePossibleTurns();
            if (!possibleTurns.length) return false;

            if (getSelectedMoves().length == possibleTurns[0].length) return false;

            // And check that player is user
            foreach (uint i, c; pointCoords) {
                if (e.button.y > min(c[0].y, c[1].y)
                        && e.button.y < max(c[0].y, c[1].y)
                        && e.button.x > c[0].x - style.pointWidth/2.5
                        && e.button.x < c[0].x + style.pointWidth/2.5) {

                    // TODO: Potential move might not be first avaiable dice
                    uint[] moveValues = getGameState().diceValues;
                    moveValues = moveValues[0] == moveValues[1]
                        ? moveValues ~ moveValues
                        : moveValues;
                    try {
                        uint startPoint = i+1;
                        uint endPoint = getGameState().currentPlayer == Player.P1 
                                ? i+1 - moveValues[this.getSelectedMoves().length]
                                : i+1 + moveValues[this.getSelectedMoves().length];

                        auto selectedMove = PipMovement(PipMoveType.Movement,
                            startPoint, endPoint);
                        selectedGameState.validateMovement(selectedMove);

                        _selectedMoves ~= selectedMove;
                        transitionStack ~= PipTransition(startPoint, endPoint, false, Clock.currTime);

                        onChangePotentialMovements.emit();
                    } catch (Exception e) {
                        writeln("Invalid move: ", e.message);
                    }

                    break;
                }
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
     * Submit a move to the board.
     */
    public void selectMove(PipMovement move) {
        _selectedMoves ~= move;
        transitionStack ~= PipTransition(
            move.startPoint,
            move.endPoint,
            false,
            Clock.currTime);
    }

    /**
     * Remove the most recent potential move
     */
    public void undoSelectedMove() {
        if (_selectedMoves.length > 0) {
            _selectedMoves = _selectedMoves[0..$-1];
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
     * TODO: Wipe current listeners
     */
    public void setGameState(GameState gameState) {
        gameState.onDiceRoll.connect((GameState gs, uint a, uint b) {
            animatedDice = [
                new AnimatedDieWidget(a, false),
                new AnimatedDieWidget(b, false)
            ];
            lastAnimation = Clock.currTime;
        });
        gameState.onBeginTurn.connect((GameState gs, Player p) {
            _selectedMoves = [];
            onChangePotentialMovements.emit();
        });

        this._gameState = gameState;
    }

    /**
     * Returns whether the board has unfinished animations either from selection
     * or from dice roll
     */
    public bool isAnimating() {
        return !!transitionStack
                .filter!(t => t.startTime + style.animationSpeed.msecs > frameTime)
                .array.length
            && (!animatedDice.length || animatedDice[0].finished);
    }

    /// The current gamestate with selected moves applied. Transitions are
    /// Transitioning towards this
    public GameState selectedGameState() {
        if (getGameState().turnState == TurnState.DiceRoll) {
            assert(getSelectedMoves().length == 0);
            return getGameState();
        }

        GameState r = getGameState().dup;

        r.applyTurn(getSelectedMoves(), true);
        return r;
    }

    /**
     * Finish a turn but submitting the current potential moves to the game state.
     * Maybe remove this... Don't like the idea of renderer managing gamestate
     */
    public void finishTurn() {
        auto pMoves = getSelectedMoves();
        _selectedMoves = [];
        getGameState().applyTurn(pMoves);
    }

    void drawDice(Context cr) {
        auto currTime = Clock.currTime();
        auto dt = currTime - lastAnimation;

        foreach (i, die; animatedDice) {
            cr.save();

            die.update(dt.total!"usecs" / 1_000_000.0);
            cr.translate(65*i + style.boardWidth * 0.65, style.boardHeight / 2 + 25*i);
            cr.scale(style.boardWidth / 24, style.boardWidth / 24);
            die.draw(cr);

            cr.restore();
        }


        lastAnimation = currTime;
    }

    bool onDraw(Context cr, Widget widget) {
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
        if (this.getGameState()) {
            drawPips(cr);
            drawDice(cr);
        }

        return true;
    }

    void drawBoard(Context cr) {
        // Draw border
        cr.setSourceRgbStruct(style.borderColor);
        cr.lineTo(0, 0);
        cr.lineTo(style.boardWidth, 0);
        cr.lineTo(style.boardWidth, style.boardHeight);
        cr.lineTo(0, style.boardHeight);
        cr.fill();

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

        drawPoints(cr);
    }

    /// Returns a tuple containing the bottom (centre) and top of the points position.
    /// By default we will be starting at top right.
    /// Params:
    ///     pointIndex = point number between 0 and 23
    Tuple!(ScreenCoords, ScreenCoords) getPointPosition(uint pointIndex) {
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

        return tuple(start, finish);
    }

    ScreenCoords getPipPosition(uint pointNum, uint pipNum) {
        assert (1 <= pointNum && pointNum <= 24);
        assert (pipNum);
        pointNum--;
        pipNum--;
        auto pointPosition = getPointPosition(pointNum+1)[0];
        double pointY = style.borderWidth + ((2 * pipNum + 1) * style.pipRadius);
        if (pointNum >= 12) {
            pointY = style.boardHeight - pointY;
        }

        return ScreenCoords(pointPosition.x, pointY);
    }

    void drawPoints(Context cr) {
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
            cr.moveTo(c[0].x, c[0].y + (i < 12 ? 20 : -10));
            cr.setSourceRgb(1.0, 1.0, 1.0);
            cr.showText(i.to!string);
            cr.newPath();
        }
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

        auto numPips = selectedGameState().points[pointNum].numPieces;

        // Minus the ones that haven't arrived
        numPips -= transitionStack
            .filter!(t => t.endPoint == pointNum)
            .filter!(t => t.startTime + style.animationSpeed.msecs > time)
            .array.length;

        // Add the ones that hadn't left yet
        numPips += transitionStack
            .filter!(t => t.startPoint == pointNum)
            .filter!(t => t.startTime >= time)
            .array.length;
        
        // What if the point contains a taken point?
        if (getGameState().points[pointNum].owner 
                == getGameState().currentPlayer.opposite
            && numPips == 0
            && selectedGameState().points[pointNum].owner
                != getGameState().currentPlayer.opposite()) {
            // This is a taken piece but has it been landed on
            if (transitionStack.filter!(t => t.startTime+style.animationSpeed.msecs > frameTime
                && t.endPoint == pointNum).array.length) {
                return Point(selectedGameState.points[pointNum].owner.opposite, 1);
            }
        }
        
        if (numPips > 100) numPips = 0;

        return Point(selectedGameState.points[pointNum].owner, numPips);
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

        // Draw pips for the taken pieces.
        float pointX = style.boardWidth / 2;
        // Player 1 at the top. Pips start in the middle and work their way out
        foreach (player; [Player.P1, Player.P2]) {
            foreach (uint i; 0..selectedGameState.takenPieces[player]) {
                float pointY = style.boardHeight/2 - (i+2)*style.pipRadius;
                if (player == Player.P2) pointY = style.boardHeight - pointY;
                drawPip(pointX, pointY, player == Player.P1 ? style.p1Colour : style.p2Colour);
            }
        }

        // Draw pip animations
        foreach (transition; getCurrentTransitions()) {
            if (!transition.startPoint || !transition.endPoint) continue; // Ignore non movements
            auto startPoint = calculatePointAtTime(transition.startPoint, transition.startTime);
            auto startPos = getPipPosition(transition.startPoint, startPoint.numPieces);
            auto endPoint = calculatePointAtTime(transition.endPoint,
                                transition.startTime + style.animationSpeed.msecs);
            auto endPos = getPipPosition(transition.endPoint, endPoint.numPieces);

            float progress = (frameTime - transition.startTime).total!"msecs" / cast(float) style.animationSpeed;
            progress = progress > 1.0 ? 1.0 : progress;

            // Tween between positions
            auto currPosition = ScreenCoords(
                startPos.x + progress*(endPos.x - startPos.x),
                startPos.y + progress*(endPos.y - startPos.y)
            );

            drawPip(currPosition.x, currPosition.y,
                selectedGameState.points[transition.endPoint].owner == Player.P1
                    ? style.p1Colour
                    : style.p2Colour);
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

    unittest {
        /**
        * Test point calculation
        */
        auto gs = new GameState();
        auto b = new BackgammonBoard(gs);
        gs.rollDice(3, 3);
        b.selectMove(PipMovement(PipMoveType.Movement, 13, 10));
        // should be animating now
        assert(b.calculatePointAtTime(10, Clock.currTime).numPieces == 4);
    }
}
