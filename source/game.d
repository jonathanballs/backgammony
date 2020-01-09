module game;
import std.stdio;

import signals;

// TODO list
// - GameState invariant
// - Handle users more smoothly - clean up functions etc.
// - Record board history - and validate it.

struct PipMovement {
    PipMoveType moveType;
    uint startPoint;
    uint endPoint;
    uint diceValue;
}

enum PipMoveType {
    Movement,
    BearingOff,
    Entering
}

enum Player {
    NONE,
    P1,
    P2,
}

enum TurnState {
    DiceRoll,
    MoveSelection,
}

Player opposite(Player player) {
    switch (player) {
        case Player.P1: return Player.P2;
        case Player.P2: return Player.P1;
        case Player.NONE:
            import std.stdio;
            writeln(new Exception("Warning: tried to opposite Player.NONE"));
            return Player.NONE;
        default: assert(0);
    }
}

bool isHomePoint(Player player, uint pointNumber) {
    if (player == Player.P1 && pointNumber >= 0 && pointNumber <= 5) {
        return true;
    } else if (player == Player.P2 && pointNumber >= 18 && pointNumber <= 23) {
        return true;
    }
    return false;
}

uint homePointToBoardPoint(Player player, uint homePoint) {
    assert(1 <= homePoint && homePoint <= 6);
    assert(player != Player.NONE);

    return player == Player.P1 ? homePoint - 1 : 24 - homePoint;
}

struct Point {
    Player owner;
    uint numPieces;
}

// Represents the current state of the backgammon board
// Points are from 0 to 23. P1's home is 0..5, P2's home is 18..23
struct Board {
    Point[24] points;
    uint[Player] takenPieces; // On the bar
    uint[Player] bearedOffPieces; // Born off

    void newGame() {
        points[23] = Point(Player.P1, 2);
        points[12] = Point(Player.P1, 5);
        points[7] = Point(Player.P1, 3);
        points[5] = Point(Player.P1, 5);

        points[0] = Point(Player.P2, 2);
        points[11] = Point(Player.P2, 5);
        points[16] = Point(Player.P2, 3);
        points[18] = Point(Player.P2, 5);

        takenPieces[Player.P1] = 0;
        takenPieces[Player.P2] = 0;
        bearedOffPieces[Player.P1] = 0;
        bearedOffPieces[Player.P2] = 0;
    }
}

// TODO: Record game histories
struct GameState {
    Board board;
    private Player _currentPlayer;
    private TurnState _turnState;
    uint[2] diceRoll;

    Signal!(Player) onBeginTurn = new Signal!(Player);
    Signal!(Player) onEndGame = new Signal!(Player);
    Signal!(uint , uint) onDiceRoll = new Signal!(uint, uint);

    Player currentPlayer() { return _currentPlayer; }

    TurnState turnState () { return _turnState; }
    private void turnState (TurnState t) {
        _turnState = t;
    }

    /// Generate random values for the dice roll
    void rollDie() {
        assert(turnState == TurnState.DiceRoll);

        import std.random;
        diceRoll[0] = uniform(1, 7);
        diceRoll[1] = uniform(1, 7);

        turnState = TurnState.MoveSelection;

        onDiceRoll.emit(diceRoll[0], diceRoll[1]);
    }

    /// Roll dice to the value of die1 and die2
    void rollDie(uint die1, uint die2) {
        assert(1 <= die1 && die1 <= 6);
        assert(1 <= die2 && die2 <= 6);

        diceRoll[0] = die1;
        diceRoll[1] = die2;

        assert(turnState == TurnState.DiceRoll);
        turnState = TurnState.MoveSelection;

        onDiceRoll.emit(diceRoll[0], diceRoll[1]);
    }

    /// Reset game state TODO: Just set this as initialisers
    void newGame() {
        this.board = Board();
        board.newGame();
        diceRoll = [0, 0];

        _currentPlayer = Player.P1;
        onBeginTurn.emit(_currentPlayer);
        turnState = TurnState.DiceRoll;
    }

    void validateTurn(PipMovement[] pipMovements, bool isPartialMove = false) {
        // uint maxMovesCount = 2 * !!(diceValues[0] == diceValues[1]);
    }

    bool playerCanBearOff(Player player) {
        Point[] nonHomePoints;
        if (player == Player.P1) {
            nonHomePoints = board.points[6..$];
        } else if (player == Player.P2) {
            nonHomePoints = board.points[0..$-6];
        }

        foreach (point; nonHomePoints) {
            if (point.owner == player) return false;
        }

        return true;
    }

    /// Generate a list of possible game moves based off current dice
    PipMovement[][] generatePossibleTurns() {
        uint[] moveValues = diceRoll;
        if (moveValues[0] == moveValues[1]) moveValues ~= moveValues;

        return generatePossibleTurns(moveValues);
    }

    PipMovement[][] generatePossibleTurns(uint[] moveValues) {
        import std.algorithm : remove, reverse, uniq;
        import std.range : enumerate, inputRangeObject;
        import std.array;
        // First find all possible movements of any length and then prune to
        // only the longest ones.
        assert (currentPlayer != Player.NONE);
        PipMovement[][] ret;

        if (moveValues.length == 0) return [];

        // Check if player needs to enter the board
        if (playerCanBearOff(currentPlayer)) {
            if (board.takenPieces[currentPlayer]) {
                foreach (i, moveValue; moveValues.uniq().enumerate()) {
                    auto boardPointNumber = homePointToBoardPoint(currentPlayer.opposite, moveValue);
                    auto point = board.points[boardPointNumber];
                    if (point.owner != currentPlayer.opposite || point.numPieces == 1) {
                        // Player can enter on this area
                        foreach (move; generatePossibleTurns(moveValues.dup.remove(i))) {
                            ret ~= [[PipMovement(PipMoveType.Entering, boardPointNumber, 0, moveValue)] ~ move];
                        }
                    }
                }
            }

            return ret;
        }

        // Check if player can move
        foreach (i, moveValue; moveValues.uniq().enumerate()) {
            foreach (uint pointIndex, point; board.points) {
                if (point.owner == currentPlayer) {
                    PipMovement potentialMovement = PipMovement(
                        PipMoveType.Movement,
                        pointIndex,
                        Player.P1 ? pointIndex-moveValue : pointIndex+moveValue,
                        moveValue);
                    if (isValidPotentialMovement(potentialMovement)) {
                        GameState potentialGS = this;
                        potentialGS.applyMovement(potentialMovement);
                        auto nextMoves = potentialGS.generatePossibleTurns(moveValues.dup.remove(i));

                        if (nextMoves) {
                            foreach (m; nextMoves) ret ~= [[potentialMovement] ~ m];
                        } else {
                            ret ~= [potentialMovement];
                        }
                    }
                }
            }
        }

        // TODO: Only the longest ones.
        return ret;
    }

    void applyMovement(PipMovement pipMovement) {
        assert(isValidPotentialMovement(pipMovement));


        if (pipMovement.moveType == PipMoveType.Movement) {
            if (!--board.points[pipMovement.startPoint].numPieces) {
                board.points[pipMovement.startPoint].owner = Player.NONE;
            }

            if (board.points[pipMovement.endPoint].owner == currentPlayer.opposite()) {
                board.takenPieces[currentPlayer.opposite()]++;
                board.points[pipMovement.endPoint].owner = Player.NONE;
                board.points[pipMovement.endPoint].numPieces = 0;
            }

            board.points[pipMovement.endPoint].numPieces++;
            board.points[pipMovement.endPoint].owner = currentPlayer;
        }
    }

    void applyTurn(PipMovement[] turn) {
        assert(turnState == TurnState.MoveSelection);
        turnState = TurnState.DiceRoll;
        foreach (move; turn) {
            applyMovement(move);
        }

        _currentPlayer = currentPlayer.opposite();
        _turnState = TurnState.DiceRoll;
        onBeginTurn.emit(_currentPlayer);
    }

    /// Need to validate with a dice roll as well
    void validateMovement(PipMovement pipMovement) {
        if (currentPlayer == Player.NONE)
            throw new Exception("Warning: tried to validate while currentPlayer is NONE");

        // Firstly, if the player has taken peaces he must place them back in
        // the game.
        if (board.takenPieces[currentPlayer]) {
            if (pipMovement.moveType != PipMoveType.Entering) {
                throw new Exception("Player must enter all their pieces before playing");
            }

            if (!currentPlayer.opposite().isHomePoint(pipMovement.endPoint)) {
                throw new Exception("Player must enter piece into opposing player's home board");
            }

            if (board.points[pipMovement.endPoint].owner == currentPlayer.opposite()
                    && board.points[pipMovement.endPoint].numPieces >= 2) {
                throw new Exception("You may not enter onto a blocked point");
            }

            // It's a valid entering move
            return;
        } else if (pipMovement.moveType == PipMoveType.Entering) {
            throw new Exception("Player can not enter if they do not have pieces on the bar");
        }

        // Secondly check if they can perform the move that they want
        if (pipMovement.moveType == PipMoveType.Movement) {
            // Ensure that movement is within the board boundaries. Uints cant be
            // below zero.
            if (pipMovement.startPoint > 23 || pipMovement.endPoint > 23) {
                throw new Exception("Player movement must start and end inside the board");
            }

            if (currentPlayer == Player.P1
                    && pipMovement.endPoint > pipMovement.startPoint) {
                throw new Exception("Player 1 must move towards their home board");
            } else if (currentPlayer == Player.P2
                    && pipMovement.endPoint < pipMovement.startPoint) {
                throw new Exception("Player 2 must move towards their home board");
            }

            // Ensure that they have pieces to move
            if (board.points[pipMovement.startPoint].owner != currentPlayer) {
                throw new Exception("Player cannot move pieces from a point they do not own");
            }

            // Ensure that the the endPoint is not blocked
            if (board.points[pipMovement.endPoint].owner == currentPlayer.opposite()
                    && board.points[pipMovement.endPoint].numPieces >= 2) {
                throw new Exception("Player cannot move pieces to a blocked point");
            }

            return;
        }

        // Lastly check if the player can bear off.
        if (pipMovement.moveType == PipMoveType.BearingOff) {
            // Check that the player can bear off
            if (!playerCanBearOff(currentPlayer)) {
                throw new Exception("Player has points outside of their home board");
            }

            // Check that they have points
            if (board.points[pipMovement.startPoint].owner != currentPlayer) {
                throw new Exception("Player can not bear off from a point they do not own");
            }

            return;
        }

        assert(false);
    }

    bool isValidPotentialMovement(PipMovement pipMovement) {
        try {
            validateMovement(pipMovement);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
