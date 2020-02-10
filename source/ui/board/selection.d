module ui.board.selection;

import std.datetime;

// Moving off the board? Moving to bar and back...
struct PipTransition {
    uint startPoint;
    uint endPoint;
    bool undone;
    bool takesPiece;
    SysTime startTime;
}


/**
 * Functionality for the user selecting moves
 * 1. find methods that may be related. Right now the code is very tangled up so
 *    time will need to be spent unwinding it.
 * 2. Move it over
 */
public template TurnSelection() {
    /**
     * Moves that are not part of the gamestate, but have been selected by the
     * user as potential moves. The board will animate these movements if
     * animation is enabled.
     */
    PipMovement[] _selectedMoves;
    PipTransition[] transitionStack;

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

        SysTime startTime = Clock.currTime;

        // Do we need to wait for animations?
        if (animatedDice.length && !animatedDice[0].finished) {
            startTime = animatedDice[0].startTime + 2*style.animationSpeed.msecs
                + getSelectedMoves.length.msecs; // Just to offset after eachother
        }

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
            transitionStack = transitionStack[0..$-1]; // Might want to undo more
            onChangePotentialMovements.emit();
        }
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
            auto endPos = layout.getTakenPipPosition(getGameState().currentPlayer.opposite,
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
                startPos = layout.getTakenPipPosition(getGameState().currentPlayer, startingPip);
            } else {
                auto startPoint = calculatePointAtTime(transition.startPoint, transition.startTime);
                startPos = layout.getPipPosition(transition.startPoint, startPoint.numPieces);
            }

            // If it's being borne off
            if (!transition.endPoint) {
                endPos = ScreenCoords(1.5 * style.boardWidth, 0.5*style.boardHeight);
            } else {
                auto endPoint = calculatePointAtTime(transition.endPoint,
                                    transition.startTime + style.animationSpeed.msecs);
                endPos = layout.getPipPosition(transition.endPoint, endPoint.numPieces);
            }

            float progress = (frameTime - transition.startTime).total!"msecs" / cast(float) style.animationSpeed;
            progress = progress > 1.0 ? 1.0 : progress;
            tweenPip(startPos, endPos, progress, getGameState.currentPlayer);
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
}
