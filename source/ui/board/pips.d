module ui.board.pips;

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
    bool undone;
    bool takesPiece;
    SysTime startTime;
}

/**
 * The renderer mode. Defines how the renderer responds to events.
 */
// Perhaps just bool isWaiting or something
enum PipRendererMode {
    AwaitingAnimation,
    PipSelection,
    BoardEditing,
}

/**
 * Pip rendering and interaction code
 */
class PipRenderer {
    PipRendererMode mode;
    BoardStyle style;
    BoardLayout layout;
    GameState gameState;
    SysTime frameTime;

    this(BoardLayout layout, BoardStyle style) {
        this.style = style;
        this.layout = layout;
    }

    void setGameState(GameState gs) {
        clearTransitions();
        gameState = gs;
    }

    /**
     * Moves that are not part of the gamestate, but have been selected by the
     * user as potential moves. The board will animate these movements if
     * animation is enabled. The boolean is whether the selected move is 
     */
    PipTransition[] transitionStack;
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
    void drawPips(Context cr, SysTime frameTime) {
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
        uint pointNum = 0;
        foreach(point; this.selectedGameState.points) {
            const auto calculatedPoint = calculatePointAtTime(pointNum+1, frameTime);

            foreach(n; 0..calculatedPoint.numPieces) {
                auto pipPosition = layout.getPipPosition(pointNum + 1, n + 1);
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

            // If it's being borne off
            if (!transition.endPoint) {
                endPos = ScreenPoint(1.5 * style.boardWidth, 0.5*style.boardHeight);
            } else {
                auto endPoint = calculatePointAtTime(transition.endPoint,
                                    transition.startTime + style.animationSpeed.msecs);
                endPos = layout.getPipPosition(transition.endPoint, endPoint.numPieces);
            }

            float progress = (frameTime - transition.startTime).total!"msecs" / cast(float) style.animationSpeed;
            progress = progress > 1.0 ? 1.0 : progress;
            tweenPip(startPos, endPos, progress, gameState.currentPlayer);
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

        auto numPips = gameState.points[pointNum].numPieces;

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
    uint calculateTakenPiecesAtTime(Player player, SysTime time) {
        uint numPips = gameState.takenPieces[player];
        // Add points that have arrived
        if (player == gameState.currentPlayer().opposite) {
            numPips += transitionStack.filter!(t => t.takesPiece
                && t.startTime + 2*style.animationSpeed.msecs <= time).array.length;
        } else {
            numPips -= transitionStack.filter!(t => !t.startPoint && t.startTime < time).array.length;
        }
        // Minus points that have left
        return numPips;
    }

    bool isAnimating() {
        return !!transitionStack
                .filter!(t => (t.startTime + style.animationSpeed.msecs > frameTime)
                    || (t.takesPiece && t.startTime + 2*style.animationSpeed.msecs > frameTime))
                .array.length;
    }

    void selectMove(PipMovement move) {
        if (mode == PipRendererMode.PipSelection) {
            animateMove(move);
            selectedMoves ~= tuple(move, true);
        } else {
            selectedMoves ~= tuple(move, false);
        }
    }

    private void animateMove(PipMovement move) {
        SysTime startTime = Clock.currTime;

        if (move.startPoint) {
            const auto pointAtStart = calculatePointAtTime(move.startPoint, startTime);
            if (pointAtStart.numPieces == 0
                    || pointAtStart.owner == gameState.currentPlayer.opposite) {
                // Find the last time that someone landed there
                auto landed = transitionStack.filter!(t => t.endPoint == move.startPoint).array;
                assert(landed.length);
                startTime = landed[$-1].startTime + style.animationSpeed.msecs;
            }
        }

        // Is this going to take a piece?
        bool takesPiece = false;
        if (move.endPoint && selectedGameState.points[move.endPoint].owner == gameState.currentPlayer.opposite) {
            takesPiece = true;
        }

        auto pt = PipTransition(
            move.startPoint,
            move.endPoint,
            false,
            takesPiece,
            startTime);

        if (mode == PipRendererMode.PipSelection) transitionStack ~= pt;
    }

    void clearTransitions() {
        selectedMoves = [];
        transitionStack = [];
    }

    void undoTransition() {
        if (selectedMoves[$-1][1]) {
            transitionStack = transitionStack[0..$-1];
        }
        selectedMoves = selectedMoves[0..$-1];
    }

    void setMode(PipRendererMode mode) {
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
