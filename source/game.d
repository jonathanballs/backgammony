module game;

struct PipMovement {
    PipMoveType moveType;
    uint startPoint;
    uint endPoint;
}

enum PipMoveType {
    Movement,
    BearingOff,
    Entering
}

enum Player {
    NONE,
    PLAYER_1,
    PLAYER_2
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
    uint[Player] takenPieces; // In the centre
    uint[Player] bearedOffPieces; // Taken off the side

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
    uint[2] diceRoll;

    uint rollDie() {
        import std.random;
        return uniform(1, 6);
    }

    void newGame() {
        this.board = Board();
        board.newGame();

        currentTurn = Player.PLAYER_1;
        diceRoll[0] = rollDie();
        diceRoll[1] = rollDie();
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
        foreach (move; pipMovements) {
            --board.points[move.startPoint].numPieces;
            ++board.points[move.endPoint].numPieces;
        }
    }

    /// Generate a list of possible game moves based off current dice
    PipMovement[] generatePossibleMovements() {
        uint[] moveValues = diceRoll;
        if (moveValues[0] == moveValues[1]) moveValues ~= moveValues;

        return generatePossibleMovements(moveValues);
    }

    PipMovement[] generatePossibleMovements(uint[] moveValues) {
        import std.algorithm.iteration : uniq;
        import std.range : enumerate;
        import std.algorithm : remove;
        // First find all possible movements of any length and then prune to
        // only the longest ones.
        PipMovement[] ret;

        if (moveValues.length == 0) return [];

        // Check if player needs to enter the board
        if (playerCanBearOff(currentTurn)) {
            if (board.takenPieces[currentTurn]) {
                foreach (i, moveValue; moveValues.uniq().enumerate()) {
                    auto point = board.points[homePointToBoardPoint(currentTurn.opposite, moveValue)];
                    if (point.owner != currentTurn.opposite || point.numPieces == 1) {
                        // Player can enter on this area
                        ret ~= generatePossibleMovements(moveValues.dup.remove(i));
                    }
                }
            }

            return ret;
        }

        return ret;
    }

    /// Need to validate with a dice roll as well
    void validateMovement(PipMovement pipMovement) {
        if (currentTurn == Player.NONE)
            throw new Exception("Warning: tried to validate while currentPlayer is NONE");

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
