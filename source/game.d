module game;
import std.stdio;

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
    PLAYER_1,
    PLAYER_2,
}

enum TurnState {
    DiceRoll,
    MoveSelection,
}

Player opposite(Player player) {
    switch (player) {
        case Player.PLAYER_1: return Player.PLAYER_2;
        case Player.PLAYER_2: return Player.PLAYER_1;
        case Player.NONE:
            import std.stdio;
            writeln(new Exception("Warning: tried to opposite Player.NONE"));
            return Player.NONE;
        default: assert(0);
    }
}

bool isHomePoint(Player player, uint pointNumber) {
    if (player == Player.PLAYER_1 && pointNumber >= 0 && pointNumber <= 5) {
        return true;
    } else if (player == Player.PLAYER_2 && pointNumber >= 18 && pointNumber <= 23) {
        return true;
    }
    return false;
}

uint homePointToBoardPoint(Player player, uint homePoint) {
    assert(1 <= homePoint && homePoint <= 6);
    assert(player != Player.NONE);

    if (player == Player.PLAYER_1) return homePoint-1;
    else return 24 - homePoint;
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
        points[23] = Point(Player.PLAYER_1, 2);
        points[12] = Point(Player.PLAYER_1, 5);
        points[7] = Point(Player.PLAYER_1, 3);
        points[5] = Point(Player.PLAYER_1, 5);

        points[0] = Point(Player.PLAYER_2, 2);
        points[11] = Point(Player.PLAYER_2, 5);
        points[16] = Point(Player.PLAYER_2, 3);
        points[18] = Point(Player.PLAYER_2, 5);

        takenPieces[Player.PLAYER_1] = 0;
        takenPieces[Player.PLAYER_2] = 0;
        bearedOffPieces[Player.PLAYER_1] = 0;
        bearedOffPieces[Player.PLAYER_2] = 0;
    }
}

// TODO: Record game histories
struct GameState {
    Board board;

    Player currentTurn;
    TurnState turnState;

    uint[2] diceRoll;

    void rollDie() {
        import std.random;
        assert(turnState == TurnState.DiceRoll);
        turnState = TurnState.MoveSelection;

        diceRoll[0] = uniform(1, 7);
        diceRoll[1] = uniform(1, 7);
    }

    void rollDie(uint die1, uint die2) {
        assert(1 <= die1 && die1 <= 6);
        assert(1 <= die2 && die2 <= 6);
        diceRoll[0] = die1;
        diceRoll[1] = die2;

        assert(turnState == TurnState.DiceRoll);
        turnState = TurnState.MoveSelection;
    }

    void newGame() {
        this.board = Board();
        board.newGame();
        diceRoll = [0, 0];

        currentTurn = Player.PLAYER_1;
        turnState = TurnState.DiceRoll;
    }

    void validateMove(uint[2] diceValues, PipMovement[] pipMovements) {
        uint maxMovesCount = 2 * !!(diceValues[0] == diceValues[1]);
    }

    bool playerCanBearOff(Player player) {
        Point[] nonHomePoints;
        if (player == Player.PLAYER_1) {
            nonHomePoints = board.points[6..$];
        } else if (player == Player.PLAYER_2) {
            nonHomePoints = board.points[0..$-6];
        }

        foreach (point; nonHomePoints) {
            if (point.owner == player) return false;
        }

        return true;
    }

    /// A list of moves
    void performMove(PipMovement[] pipMovements) {
        assert(turnState == TurnState.MoveSelection);
        turnState = TurnState.DiceRoll;

        foreach (move; pipMovements) {
            --board.points[move.startPoint].numPieces;
            ++board.points[move.endPoint].numPieces;
        }
    }

    /// Generate a list of possible game moves based off current dice
    PipMovement[][] generatePossibleMovements() {
        uint[] moveValues = diceRoll;
        if (moveValues[0] == moveValues[1]) moveValues ~= moveValues;

        return generatePossibleMovements(moveValues);
    }

    PipMovement[][] generatePossibleMovements(uint[] moveValues) {
        import std.algorithm : remove, reverse, uniq;
        import std.range : enumerate, inputRangeObject;
        import std.array;
        // First find all possible movements of any length and then prune to
        // only the longest ones.
        assert (currentTurn != Player.NONE);
        PipMovement[][] ret;

        if (moveValues.length == 0) return [];

        // Check if player needs to enter the board
        if (playerCanBearOff(currentTurn)) {
            if (board.takenPieces[currentTurn]) {
                foreach (i, moveValue; moveValues.uniq().enumerate()) {
                    auto boardPointNumber = homePointToBoardPoint(currentTurn.opposite, moveValue);
                    auto point = board.points[boardPointNumber];
                    if (point.owner != currentTurn.opposite || point.numPieces == 1) {
                        // Player can enter on this area
                        foreach (move; generatePossibleMovements(moveValues.dup.remove(i))) {
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
                if (point.owner == currentTurn) {
                    PipMovement potentialMovement = PipMovement(
                        PipMoveType.Movement,
                        pointIndex,
                        Player.PLAYER_1 ? pointIndex-moveValue : pointIndex+moveValue,
                        moveValue);
                    if (isValidMovement(potentialMovement)) {
                        GameState potentialGS = this;
                        potentialGS.applyMove(potentialMovement);
                        auto nextMoves = potentialGS.generatePossibleMovements(moveValues.dup.remove(i));

                        if (nextMoves) {
                            foreach (m; nextMoves) ret ~= [[potentialMovement] ~ m];
                        } else {
                            ret ~= [potentialMovement];
                        }
                    }
                }
            }
        }

        return ret;
    }

    void applyMove(PipMovement pipMovement) {
        assert(isValidMovement(pipMovement));

        if (pipMovement.moveType == PipMoveType.Movement) {
            if (!--board.points[pipMovement.startPoint].numPieces) {
                board.points[pipMovement.startPoint].owner = Player.NONE;
            }

            if (board.points[pipMovement.endPoint].owner == currentTurn.opposite()) {
                board.takenPieces[currentTurn.opposite()]++;
                board.points[pipMovement.endPoint].owner = Player.NONE;
                board.points[pipMovement.endPoint].numPieces = 0;
            }

            board.points[pipMovement.endPoint].numPieces++;
            board.points[pipMovement.endPoint].owner = currentTurn;
        }
    }

    void executeTurn(PipMovement[] turn) {
        foreach (move; turn) {
            applyMove(move);
        }

        currentTurn = currentTurn.opposite();
    }

    /// Need to validate with a dice roll as well
    void validateMovement(PipMovement pipMovement) {
        if (currentTurn == Player.NONE)
            throw new Exception("Warning: tried to validate while currentTurn is NONE");

        // Firstly, if the player has taken peaces he must place them back in
        // the game.
        if (board.takenPieces[currentTurn]) {
            if (pipMovement.moveType != PipMoveType.Entering) {
                throw new Exception("Player must enter all their pieces before playing");
            }

            if (!currentTurn.opposite().isHomePoint(pipMovement.endPoint)) {
                throw new Exception("Player must enter piece into opposing player's home board");
            }

            if (board.points[pipMovement.endPoint].owner == currentTurn.opposite()
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

            if (currentTurn == Player.PLAYER_1
                    && pipMovement.endPoint > pipMovement.startPoint) {
                throw new Exception("Player 1 must move towards their home board");
            } else if (currentTurn == Player.PLAYER_2
                    && pipMovement.endPoint < pipMovement.startPoint) {
                throw new Exception("Player 2 must move towards their home board");
            }

            // Ensure that they have pieces to move
            if (board.points[pipMovement.startPoint].owner != currentTurn) {
                throw new Exception("Player cannot move pieces from a point they do not own");
            }

            // Ensure that the the endPoint is not blocked
            if (board.points[pipMovement.endPoint].owner == currentTurn.opposite()
                    && board.points[pipMovement.endPoint].numPieces >= 2) {
                throw new Exception("Player cannot move pieces to a blocked point");
            }

            return;
        }

        // Lastly check if the player can bear off.
        if (pipMovement.moveType == PipMoveType.BearingOff) {
            // Check that the player can bear off
            if (!playerCanBearOff(currentTurn)) {
                throw new Exception("Player has points outside of their home board");
            }

            // Check that they have points
            if (board.points[pipMovement.startPoint].owner != currentTurn) {
                throw new Exception("Player can not bear off from a point they do not own");
            }

            return;
        }

        assert(false);
    }

    bool isValidMovement(PipMovement pipMovement) {
        try {
            validateMovement(pipMovement);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
