module ui.board.boardwidget;

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
import ui.board.dice;
import ui.board.layout;
public import ui.board.layout : Corner;
import ui.board.pips;
import ui.board.style;

// TODO:
// - Testing & benchmarking animations (potentially use separate thread?)
// - Use GDK frameclock for animations

/**
 * Widget for rendering a backgammon game state
 */
class BackgammonBoardWidget : DrawingArea {
    private:
    /**
     * The gameState gamestate that is being rendered
     */
    GameState _gameState;

    /**
     * The current styling. Will be modifiable in the future.
     */
    BoardStyle style;
    BoardLayout layout;
    PipRenderer pipRenderer;

    /// Animation
    SysTime lastAnimation;
    SysTime frameTime;
    AnimatedDie[] animatedDice;

    PipMovement[] _selectedMoves;

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
        layout = new BoardLayout(style);
        pipRenderer = new PipRenderer(layout, style);

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
     * Create a new BackgammonBoardWidget widget and set the gamestate
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


        // If we aren't animating the dice and it's a user's turn
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

            auto possibleTurns = getGameState().generatePossibleTurns().filter!((t) {
                foreach (j; 0..getSelectedMoves.length) {
                    if (getSelectedMoves[j] != t[j]) return false;
                }
                return true;
            }).array;

            if (!possibleTurns.length) return false;

            if (getSelectedMoves().length == possibleTurns[0].length) return false;

            // TODO: Put bearing off ahead of normal movement
            possibleTurns = possibleTurns.sort!((a, b) {
                return a[getSelectedMoves.length].diceValue > b[getSelectedMoves.length].diceValue;
            }).array;

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

            uint[] moveValues = getGameState().diceValues;
            moveValues = moveValues[0] == moveValues[1]
                ? moveValues ~ moveValues
                : moveValues;

            try {
                foreach (t; possibleTurns) {
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
                new AnimatedDie(a, 2 * style.animationSpeed),
                new AnimatedDie(b, 2 * style.animationSpeed),
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
        this.pipRenderer.setGameState(gameState);
        this._startDisplayMessage = SysTime.init;
        this._selectedMoves = [];
        this.animatedDice = [];
        this.applyTurnAtEndOfAnimation = false;
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


        // Do we need to wait for animations?
        // if (animatedDice.length && !animatedDice[0].finished) {
        //     startTime = animatedDice[0].startTime + 2*style.animationSpeed.msecs
        //         + getSelectedMoves.length.msecs; // Just to offset after eachother
        // }

        _selectedMoves ~= move;
        pipRenderer.animateMove(move);
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
        if (!_selectedMoves.length) {
            this.displayMessage("No movement available", () {});
        }

        applyTurnAtEndOfAnimation = true;
    }

    /**
     * Remove the most recent potential move
     */
    public void undoSelectedMove() {
        if (_selectedMoves.length > 0) {
            _selectedMoves = _selectedMoves[0..$-1];
            pipRenderer.undoTransition();
            onChangePotentialMovements.emit();
        }
    }
    /**
     * Returns whether the board has unfinished animations either from selection
     * or from dice roll
     */
    public bool isAnimating() {
        const bool isDiceRolling = !!animatedDice.length ? !animatedDice[0].finished : false;
        return pipRenderer.isAnimating()
            || isDiceRolling
            || Clock.currTime - _startDisplayMessage < 2 * style.animationSpeed.msecs;
    }

    /**
     * Set the corner of the board that a player should be at
     */
    public void setPlayerCorner(Player p, Corner c) {
        if (p == Player.P1) {
            this.layout.p1Corner = c;
        } else if (p == Player.P2) {
            switch (c) {
            case Corner.BR: layout.p1Corner = Corner.TR; break;
            case Corner.BL: layout.p1Corner = Corner.TL; break;
            case Corner.TR: layout.p1Corner = Corner.BR; break;
            case Corner.TL: layout.p1Corner = Corner.BL; break;
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

    // Could more of this code simply be inside the dicewidget module?
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
            pipRenderer.drawPips(cr, frameTime);
            drawDice(cr);
        }

        drawMessages(cr);

        // TODO: should be it's own method
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
            pipRenderer.clearTransitions();
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
            auto c = layout.getPointPosition(i+1);

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
}
