module ui.board.pips;

/**
 * Pip rendering for BackgammonBoardWidget. The functions and classes in this
 * file provide functionality for animating and drawing the pips.
 * TODO:
 *  - Is there any reason for no gamestate to be set?
 */

import std.algorithm;
import std.array;
import std.datetime;
import std.stdio;
import std.typecons;
import cairo.Context;
import game;

import ui.board.style;
import ui.board.layout;


/**
 * A single pip transition animation
 */
private struct PipTransition {
    uint startPoint;
    uint endPoint;
    bool takesPiece;
    SysTime startTime;
}

/**
 * The renderer mode. Defines how the renderer responds to animation requests.
 */
enum PipRendererMode {
    AwaitingAnimation,          // Animation is queued
    PipSelection,               // Animations are happening
    BoardEditing,               // Not used yet - when the board is being edited
}

/**
 * Pip rendering and interaction code
 */
class PipRenderer {
    private:
    PipRendererMode mode;
    BoardStyle style;
    BoardLayout layout;
    GameState gameState;
    SysTime frameTime;

    public bool isDragging;
    public uint dragPointIndex;
    public ScreenPoint dragOffset;
    public SysTime dragStartTime;

    /**
     * Create a new PipRenderer
     */
    public this(BoardLayout layout, BoardStyle style) {
        this.style = style;
        this.layout = layout;
    }

    /**
     * Set the gamestate.
     */
    public void setGameState(GameState gs) {
        clearTransitions();
        isDragging = false;
        gameState = gs;
    }

    /**
     * Moves that are not part of the gamestate, but have been selected by the
     * user as potential moves. The board will animate these movements if
     * animation is enabled. The boolean is whether the selected move has been
     * added to the animation stack.
     */
    PipTransition[] transitionStack;
    PipTransition[] undoTransitionStack;
    Tuple!(PipMovement, bool)[] selectedMoves;

    /// The current gamestate with selected moves applied. Transitions are
    /// Transitioning towards this
    public GameState selectedGameState() {
        if (gameState.turnState == TurnState.MoveSelection) {
            return gameState.dup.applyTurn(selectedMoves
                    .filter!(m => m[1])
                    .map!(m => m[0]).array,
                true);
        } else {
            return gameState;
        }
    }


    /**
     * Draw gamestate pips onto the context
     */
    public void drawPips(Context cr, SysTime frameTime) {
        this.frameTime = frameTime;

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
        void tweenPip(ScreenPoint startPos, ScreenPoint endPos, float progress, Player player) {
            // Functions found here https://gist.github.com/gre/1650294
            // in/out quadratic easing
            float easingFunc(float t) {
                return t<.5 ? 2*t*t : -1+(4-2*t)*t;
            }

            // Tween between positions
            auto currPosition = ScreenPoint(
                startPos.x + easingFunc(progress)*(endPos.x - startPos.x),
                startPos.y + easingFunc(progress)*(endPos.y - startPos.y)
            );

            drawPip(currPosition.x, currPosition.y, player == Player.P1
                    ? style.p1Colour
                    : style.p2Colour);
        }

        // Draw pips on each point
        uint pointNum = 1;
        foreach(point; this.selectedGameState.points) {
            const auto calculatedPoint = calculatePointAtTime(pointNum, frameTime);

            foreach(n; 0..calculatedPoint.numPieces) {
                auto pipPosition = layout.getPipPosition(pointNum, n + 1);
                drawPip(cast(uint) pipPosition.x, cast(uint) pipPosition.y,
                    calculatedPoint.owner == Player.P1 ? style.p1Colour : style.p2Colour);
            }
            pointNum++;
        }

        // Player 1 at the top. Pips start in the middle and work their way out
        foreach (player; [Player.P1, Player.P2]) {
            foreach (uint i; 0..calculateTakenPiecesAtTime(player, frameTime)) {
                auto point = layout.getTakenPipPosition(player, i+1);
                drawPip(point.x, point.y, player == Player.P1 ? style.p1Colour : style.p2Colour);
            }
        }

        // Draw pieces being taken
        foreach (takenTransition; transitionStack
                .filter!(t => t.takesPiece)
                .filter!(t => t.startTime + 2*style.animationSpeed.msecs > frameTime)
                .filter!(t => t.startTime + style.animationSpeed.msecs < frameTime)
                .array) {
            auto startPos = layout.getPipPosition(takenTransition.endPoint, 1);
            auto endPos = layout.getTakenPipPosition(gameState.currentPlayer.opposite,
                calculateTakenPiecesAtTime(gameState.currentPlayer.opposite,
                takenTransition.startTime + 2*style.animationSpeed.msecs));
            float progress = (frameTime -
                (takenTransition.startTime +style.animationSpeed.msecs)
                ).total!"msecs" / cast(float) style.animationSpeed;
            tweenPip(startPos, endPos, progress, gameState.currentPlayer.opposite);
        }

        // Draw pip movement animations
        foreach (transition; getCurrentTransitions()) {
            ScreenPoint startPos;
            ScreenPoint endPos;

            // If it's coming from the bar
            if (!transition.startPoint) {
                auto startingPip = calculateTakenPiecesAtTime(
                    gameState.currentPlayer, transition.startTime
                );
                startPos = layout.getTakenPipPosition(gameState.currentPlayer, startingPip);
            } else {
                auto startPoint = calculatePointAtTime(transition.startPoint, transition.startTime);
                startPos = layout.getPipPosition(transition.startPoint, startPoint.numPieces);
            }

            if (transition.endPoint) {
                auto endPoint = calculatePointAtTime(transition.endPoint,
                                    transition.startTime + style.animationSpeed.msecs);
                try {
                    endPos = layout.getPipPosition(transition.endPoint, endPoint.numPieces);
                } catch (Exception e) {
                    writeln(transitionStack);
                    writeln(selectedMoves);
                }
            } else {
                // If it's being borne off
                endPos = ScreenPoint(1.5 * style.boardWidth, 0.5*style.boardHeight);
            }

            float progress = (frameTime - transition.startTime).total!"msecs" / cast(float) style.animationSpeed;
            progress = progress > 1.0 ? 1.0 : progress;
            tweenPip(startPos, endPos, progress, gameState.currentPlayer);
        }

        // Draw pip undo animations
        auto currentUndoTransitions = undoTransitionStack
            .filter!(t => t.startTime + style.animationSpeed.msecs > frameTime)
            .filter!(t => t.startTime < frameTime)
            .array;

        foreach (transition; currentUndoTransitions) {
            ScreenPoint startPos;
            ScreenPoint endPos;

            // If it's coming from the bar
            if (!transition.startPoint) {
                auto startingPip = calculateTakenPiecesAtTime(
                    gameState.currentPlayer, transition.startTime
                );
                startPos = layout.getTakenPipPosition(gameState.currentPlayer, startingPip + 1);
            } else {
                auto startPoint = calculatePointAtTime(transition.startPoint, transition.startTime);
                startPos = layout.getPipPosition(transition.startPoint, startPoint.numPieces + 1);
            }

            if (transition.endPoint) {
                auto endPoint = calculatePointAtTime(transition.endPoint,
                                    transition.startTime + style.animationSpeed.msecs);
                try {
                    endPos = layout.getPipPosition(transition.endPoint, endPoint.numPieces);
                } catch (Exception e) {
                    writeln(transitionStack);
                    writeln(selectedMoves);
                }
            } else {
                // If it's being borne off
                endPos = ScreenPoint(1.5 * style.boardWidth, 0.5*style.boardHeight);
            }

            float progress = (frameTime - transition.startTime).total!"msecs" / cast(float) style.animationSpeed;
            progress = progress > 1.0 ? 1.0 : progress;
            tweenPip(startPos, endPos, progress, gameState.currentPlayer);
        }

        // Draw the dragged pip
        if (isDragging) {
            ScreenPoint pipStartPos;
            if (dragPointIndex) {
                auto pipStartPoint = calculatePointAtTime(dragPointIndex, dragStartTime);
                pipStartPos = layout.getPipPosition(dragPointIndex, pipStartPoint.numPieces);
            } else {
                auto pipStartPoint = calculateTakenPiecesAtTime(
                    gameState.currentPlayer, dragStartTime);
                pipStartPos = layout.getTakenPipPosition(gameState.currentPlayer, pipStartPoint);
            }

            auto currentPos = pipStartPos + dragOffset;
            drawPip(currentPos.x, currentPos.y,
                gameState._currentPlayer == Player.P1 ? style.p1Colour : style.p2Colour);
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
    public Point calculatePointAtTime(uint pointNum, SysTime time) {
        assert(1 <= pointNum && pointNum <= 24);

        auto numPips = gameState.points[pointNum].numPieces;

        // Add the ones that arrived
        numPips += transitionStack
            .filter!(t => t.endPoint == pointNum)
            .filter!(t => t.startTime + style.animationSpeed.msecs <= time)
            .array.length;

        // Minus the ones that left yet
        numPips -= transitionStack
            .filter!(t => t.startPoint == pointNum)
            .filter!(t => t.startTime < time)
            .array.length;

        // Minus those that haven't yet returned
        numPips -= undoTransitionStack
            .filter!(t => t.endPoint == pointNum)
            .filter!(t => t.startTime + style.animationSpeed.msecs > time)
            .array.length;

        if (isDragging && dragPointIndex == pointNum && numPips && time > dragStartTime) {
            numPips--;
        }

        if (transitionStack.filter!(t => t.endPoint == pointNum)
                .filter!(t => t.startTime + style.animationSpeed.msecs <= time).array.length) {

            if (gameState.points[pointNum].owner == gameState.currentPlayer.opposite) {
                return Point(gameState.currentPlayer, --numPips);
            } else  {
                return Point(gameState.currentPlayer, numPips);
            }
        }
        
        // Should change this to an assert tbqh
        if (numPips > 100) {
            writeln(gameState.currentPlayer);
            writeln(pointNum, " ", gameState.points[pointNum]);
            writeln(time);
            writeln(transitionStack);
            assert(0);
        }

        return Point(gameState.points[pointNum].owner, numPips);
    }

    /**
     * Calculates what's been taken
     */
    public uint calculateTakenPiecesAtTime(Player player, SysTime time) {
        uint numPips = gameState.takenPieces[player];
        // Add points that have arrived
        if (player == gameState.currentPlayer().opposite) {
            numPips += transitionStack.filter!(t => t.takesPiece
                && t.startTime + 2*style.animationSpeed.msecs <= time).array.length;
        } else {
            numPips -= transitionStack.filter!(t => !t.startPoint && t.startTime < time).array.length;
        }

        if (isDragging && !dragPointIndex && numPips && time > dragStartTime) {
            numPips--;
        }
        // Minus points that have left
        return numPips;
    }

    public bool isAnimating() {
        return !!transitionStack
                .filter!(t => (t.startTime + style.animationSpeed.msecs > frameTime)
                    || (t.takesPiece && t.startTime + 2*style.animationSpeed.msecs > frameTime))
                .array.length;
    }

    public void selectMove(PipMovement move, bool animate = true) {
        if (mode == PipRendererMode.PipSelection) {
            animateMove(move, animate);
            selectedMoves ~= tuple(move, true);
        } else {
            selectedMoves ~= tuple(move, false);
        }
    }

    void animateMove(PipMovement move, bool animate = true) {
        SysTime startTime = Clock.currTime;

        // Do we need to delay this move
        if (move.startPoint) {
            const auto pointAtStart = calculatePointAtTime(move.startPoint, startTime);
            if (pointAtStart.numPieces == 0
                    || pointAtStart.owner == gameState.currentPlayer.opposite) {
                // Find the last time that someone landed there
                if (animate) {
                    auto landed = transitionStack.filter!(t => t.endPoint == move.startPoint).array;
                    assert(landed.length); // This is failing sometimes bc of drag and drops
                    startTime = landed[$-1].startTime + style.animationSpeed.msecs
                        + transitionStack.length.msecs; // Staggered to fix uitests.doublePipMove()
                }
            }
        }

        if (!animate) startTime = Clock.currTime - style.animationSpeed.msecs;

        // Is this going to take a piece?
        bool takesPiece = false;
        if (move.endPoint && selectedGameState.points[move.endPoint].owner == gameState.currentPlayer.opposite) {
            takesPiece = true;
        }

        auto pt = PipTransition(
            move.startPoint,
            move.endPoint,
            takesPiece,
            startTime);

        if (mode == PipRendererMode.PipSelection) transitionStack ~= pt;
    }

    public void clearTransitions() {
        selectedMoves = [];
        transitionStack = [];
        undoTransitionStack = [];
        isDragging = false;
        dragPointIndex = 0;
        dragOffset = ScreenPoint();
    }

    public void undoTransition() {
        if (selectedMoves[$-1][1]) {
            auto lastTransition = transitionStack[$-1];
            if (lastTransition.startTime < Clock.currTime - style.animationSpeed.msecs) {
                // What if double undoing? Need to delay...
                undoTransitionStack ~= PipTransition(
                    lastTransition.endPoint, lastTransition.startPoint,
                    lastTransition.takesPiece, Clock.currTime
                );
            } else {
                undoTransitionStack ~= PipTransition(
                    lastTransition.endPoint, lastTransition.startPoint,
                    lastTransition.takesPiece,
                    (Clock.currTime - (style.animationSpeed.msecs - (Clock.currTime - lastTransition.startTime)))
                );
            }

            transitionStack = transitionStack[0..$-1];
        }
        selectedMoves = selectedMoves[0..$-1];
    }

    public void startDrag(uint pointIndex) {
        dragStartTime = Clock.currTime;
        dragPointIndex = pointIndex;
        dragOffset = ScreenPoint(0.0, 0.0);
        isDragging = true;
    }

    public void releaseDrag() {
        isDragging = false;
    }

    public void setMode(PipRendererMode mode) {
        auto prevMode = this.mode;
        this.mode = mode;

        if (prevMode == PipRendererMode.AwaitingAnimation
                && mode == PipRendererMode.PipSelection) {
            foreach (ref m; selectedMoves) {
                animateMove(m[0]);
                m[1] = true;
            }
        }
    }
}

unittest {
    writeln("Testing PipRenderer");
    auto style = new BoardStyle();
    auto gs = new GameState().newGame();
    auto pr = new PipRenderer(new BoardLayout(style), style);
    pr.setGameState(gs);

    /**
     * Test animation timing. Move from 6=>5=>3 then get taken by P2 from point 1
     */
    gs.rollDice(1, 2);
    assert(pr.mode == PipRendererMode.AwaitingAnimation);

    /**
     * Move piece 6 => 5
     */
    pr.selectMove(PipMovement(PipMoveType.Movement, 6, 5));
    assert(pr.selectedMoves.length == 1);
    assert(pr.transitionStack.length == 0);
    assert(pr.calculatePointAtTime(6, Clock.currTime).numPieces == 5);
    // Enable the pip seletion and start the animations
    pr.setMode(PipRendererMode.PipSelection);
    assert(pr.transitionStack.length == 1);
    // Check that piece has left point 6
    assert(pr.calculatePointAtTime(6, Clock.currTime).numPieces == 4);
    assert(pr.calculatePointAtTime(6, pr.transitionStack[0].startTime).numPieces == 5);
    // And doesn't arrive at point 5 until animationSpeed.msecs later
    assert(pr.calculatePointAtTime(5, Clock.currTime).numPieces == 0);
    assert(pr.calculatePointAtTime(5, pr.transitionStack[0].startTime
                                    + (style.animationSpeed - 1).msecs).numPieces == 0);
    assert(pr.calculatePointAtTime(5, pr.transitionStack[0].startTime
                                    + style.animationSpeed.msecs).numPieces == 1);

    /**
     * Move the piece 5 => 3
     */
    pr.selectMove(PipMovement(PipMoveType.Movement, 5, 3));
    assert(pr.calculatePointAtTime(5, pr.transitionStack[0].startTime
                                    + style.animationSpeed.msecs).numPieces == 1);
    assert(pr.calculatePointAtTime(5, pr.transitionStack[0].startTime
                                    + (5 + style.animationSpeed).msecs).numPieces == 0);
    assert(pr.calculatePointAtTime(3, pr.transitionStack[0].startTime
                                    + 2*style.animationSpeed.msecs + 5.msecs).numPieces == 1);
}
