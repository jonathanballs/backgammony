module game;

import std.array;
import std.format;
import std.stdio;

import utils.signals;
import utils.types : EnumIndexStaticArray;

// TODO list
// - Handle users more smoothly - clean up functions etc.
// - Record board history - and validate it.

/**
 * Represents a single move in a turn e.g. a piece moving from the bar or a
 * point to another point.
 */
struct PipMovement {
    PipMoveType moveType;   /// The type of move
    uint startPoint;        /// Starting point
    uint endPoint;          /// End point
    uint diceValue;         /// Value the dice used for this movement
}
alias Turn = PipMovement[];

/// The type of movement.
enum PipMoveType { Movement, BearingOff, Entering }

/// Current stage of a users turn, must they roll the dice, or perform their moves.
enum TurnState { DiceRoll, MoveSelection }

/// Player
enum Player { NONE, P1, P2 }

/// Get the opponent
Player opposite(Player player) {
    switch (player) {
        case Player.P1: return Player.P2;
        case Player.P2: return Player.P1;
        default: assert(0);
    }
}

/// Whether pointNumber is a home point for player
bool isHomePoint(Player player, uint pointNumber) {
    if (player == Player.P1 && pointNumber >= 0 && pointNumber <= 5) {
        return true;
    } else if (player == Player.P2 && pointNumber >= 18 && pointNumber <= 23) {
        return true;
    }
    return false;
}

/// The homePoint
uint homePointToBoardPoint(Player player, uint homePoint) {
    assert(1 <= homePoint && homePoint <= 6);
    assert(player != Player.NONE);

    return player == Player.P1 ? homePoint - 1 : 24 - homePoint;
}

/**
 * A single point on the backgammon board.
 */
struct Point {
    /// The player who owns the pieces on this point
    Player owner;

    /// Number of pieces on this point
    uint numPieces;
}

/**
 * The state of a game of backgammon. It maintains its own correctness so should
 * always be correct.
 * TODO: Ensure gamestate cant be changed from outside except through turns
 */
class GameState {

    /**
     * The 24 points that make up the backgammon board
     */
    Point[24] points;

    /**
     * Fired at the start of each turn. Calls connected functions with the player
     * who is about to begin their go.
     */
    Signal!(Player) onBeginTurn         = new Signal!(Player);

    /**
     * Fired at the end of the game. NOT IMPLEMENTED
     */
    Signal!() onEndGame                 = new Signal!();

    /**
     * Fired on a dice roll. Calls connected functions with the value of the roll.
     */
    Signal!(uint , uint) onDiceRoll     = new Signal!(uint, uint);

    EnumIndexStaticArray!(Player, uint) takenPieces;
    EnumIndexStaticArray!(Player, uint) borneOffPieces;
    private Player _currentPlayer;
    private TurnState _turnState;
    private uint[2] _diceValues;

    /**
     * Create a new gamestate. The game will be initalized to the start of P1's
     * turn.
     */
    this() {
    }

    /**
     * Reset board and begin game.
     */
    void newGame() {
        _currentPlayer = Player.P1;
        _turnState = TurnState.DiceRoll;
        _diceValues = [0, 0];
        takenPieces[Player.P1] = 0;
        takenPieces[Player.P2] = 0;
        borneOffPieces[Player.P1] = 0;
        borneOffPieces[Player.P2] = 0;

        points[23] = Point(Player.P1, 2);
        points[12] = Point(Player.P1, 5);
        points[7] = Point(Player.P1, 3);
        points[5] = Point(Player.P1, 5);
        points[0] = Point(Player.P2, 2);
        points[11] = Point(Player.P2, 5);
        points[16] = Point(Player.P2, 3);
        points[18] = Point(Player.P2, 5);

        onBeginTurn.emit(_currentPlayer);
    }

    /**
     * The player whose turn it is
     */
    Player currentPlayer() { return _currentPlayer; }

    /**
     * Whether the player must roll the dice or perform their move
     */
    TurnState turnState () { return _turnState; }

    private void turnState (TurnState t) {
        _turnState = t;
    }

    /**
     * Get the values of the dice roll.
     */
    auto diceValues() {
        return _diceValues.dup;
    }

    /**
     * Generate random values for the dice roll
     */
    void rollDice() {
        assert(currentPlayer != Player.NONE);
        assert(turnState == TurnState.DiceRoll);

        import std.random : uniform;
        _diceValues[0] = uniform(1, 7);
        _diceValues[1] = uniform(1, 7);

        turnState = TurnState.MoveSelection;

        onDiceRoll.emit(diceValues[0], diceValues[1]);
    }

    /**
     * Set the current dice roll.
     * Params:
     *     die1 = The first dice value. Must be between values of 1 and 6
     *     die2 = The second dice value. Must be between values of 1 and 6
     */
    void rollDice(uint die1, uint die2) {
        assert(1 <= die1 && die1 <= 6);
        assert(1 <= die2 && die2 <= 6);

        _diceValues[0] = die1;
        _diceValues[1] = die2;

        assert(turnState == TurnState.DiceRoll);
        turnState = TurnState.MoveSelection;

        onDiceRoll.emit(diceValues[0], diceValues[1]);
    }

    /// Generate a list of possible game moves based off current dice
    PipMovement[][] generatePossibleTurns() {
        uint[] moveValues = diceValues;
        if (moveValues[0] == moveValues[1]) moveValues ~= moveValues;

        return generatePossibleTurns(moveValues);
    }

    private PipMovement[][] generatePossibleTurns(uint[] moveValues) {
        import std.algorithm : remove, reverse, uniq;
        import std.range : enumerate, inputRangeObject;
        // First find all possible movements of any length and then prune to
        // only the longest ones.
        PipMovement[][] ret;

        if (moveValues.length == 0) return [];

        // Check if player needs to enter the board
        // if (canBearOff(currentPlayer)) {
        //     if (takenPieces[currentPlayer]) {
        //         foreach (i, moveValue; moveValues.uniq().enumerate()) {
        //             auto boardPointNumber = homePointToBoardPoint(currentPlayer.opposite, moveValue);
        //             auto point = points[boardPointNumber];
        //             if (point.owner != currentPlayer.opposite || point.numPieces == 1) {
        //                 // Player can enter on this area
        //                 foreach (move; generatePossibleTurns(moveValues.dup.remove(i))) {
        //                     ret ~= [[PipMovement(PipMoveType.Entering, boardPointNumber, 0, moveValue)] ~ move];
        //                 }
        //             }
        //         }
        //     }

        //     return ret;
        // }

        // Check if player can move
        foreach (i, moveValue; moveValues.uniq().enumerate()) {
            foreach (uint pointIndex, point; points) {
                if (point.owner == currentPlayer) {
                    PipMovement potentialMovement = PipMovement(
                        PipMoveType.Movement,
                        pointIndex,
                        Player.P1 ? pointIndex-moveValue : pointIndex+moveValue,
                        moveValue);
                    if (isValidPotentialMovement(potentialMovement)) {
                        GameState potentialGS = this.dup;
                        potentialGS.applyMovement(potentialMovement);
                        auto nextMoves = potentialGS.generatePossibleTurns(moveValues.dup.remove(i));

                        if (nextMoves) {
                            foreach (m; nextMoves) {
                                auto moveList = [[potentialMovement] ~ m.dup];
                                ret ~= moveList;
                            }
                        } else {
                            ret ~= [potentialMovement];
                        }
                    }
                }
            }
        }

        uint longestTurn = 0;
        import std.algorithm : filter;
        foreach (t; ret) {
            longestTurn = t.length > longestTurn ? cast(uint) t.length : longestTurn;
        }
        return ret.filter!(t => t.length == longestTurn).array;
    }

    /**
     * Apply a movement to the board
     */
    private void applyMovement(PipMovement pipMovement) {
        assert(isValidPotentialMovement(pipMovement));


        if (pipMovement.moveType == PipMoveType.Movement) {
            if (!--points[pipMovement.startPoint].numPieces) {
                points[pipMovement.startPoint].owner = Player.NONE;
            }

            if (points[pipMovement.endPoint].owner == currentPlayer.opposite()) {
                writeln( takenPieces[currentPlayer.opposite()]++ );
                points[pipMovement.endPoint].owner = Player.NONE;
                points[pipMovement.endPoint].numPieces = 0;
            }

            points[pipMovement.endPoint].numPieces++;
            points[pipMovement.endPoint].owner = currentPlayer;
        }
    }

    /**
     * Apply a turn for the current user. Must be valid turn or 
     * Params:
     *     turn = The turn to apply
     *     partialTurn = Whether this is a partial (incomplete) turn.
     */
    void applyTurn(Turn turn, bool partialTurn = false) {
        assert(turnState == TurnState.MoveSelection,
            "Tried to applyTurn() before dice are rolled");

        if (!partialTurn) {
            validateTurn(turn);
        }

        foreach (move; turn) {
            applyMovement(move);
        }

        if (!partialTurn) {
            _currentPlayer = currentPlayer.opposite();
            _turnState = TurnState.DiceRoll;
            _diceValues = [0, 0];
            onBeginTurn.emit(_currentPlayer);
        }
    }

    /// Need to validate with a dice roll as well
    void validateMovement(PipMovement pipMovement) {
        if (currentPlayer == Player.NONE)
            throw new Exception("Warning: tried to validate while currentPlayer is NONE");

        // Firstly, if the player has taken peaces he must place them back in
        // the game.
        if (takenPieces[currentPlayer]) {
            if (pipMovement.moveType != PipMoveType.Entering) {
                throw new Exception("Player must enter all their pieces before playing");
            }

            if (!currentPlayer.opposite().isHomePoint(pipMovement.endPoint)) {
                throw new Exception("Player must enter piece into opposing player's home board");
            }

            if (points[pipMovement.endPoint].owner == currentPlayer.opposite()
                    && points[pipMovement.endPoint].numPieces >= 2) {
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
            if (points[pipMovement.startPoint].owner != currentPlayer) {
                throw new Exception("Player cannot move pieces from a point they do not own");
            }

            // Ensure that the the endPoint is not blocked
            if (points[pipMovement.endPoint].owner == currentPlayer.opposite()
                    && points[pipMovement.endPoint].numPieces >= 2) {
                throw new Exception("Player cannot move pieces to a blocked point");
            }

            return;
        }

        // Lastly check if the player can bear off.
        if (pipMovement.moveType == PipMoveType.BearingOff) {
            // Check that the player can bear off
            if (!canBearOff(currentPlayer)) {
                throw new Exception("Player has points outside of their home board");
            }

            // Check that they have points
            if (points[pipMovement.startPoint].owner != currentPlayer) {
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

    void validateTurn(PipMovement[] turn) {
        auto possibleTurns = generatePossibleTurns();

        if (!possibleTurns.length) {
            if (turn.length) {
                throw new Exception(format!"The longest turn is %d moves but you tried to validate a turn of %d moves"(0, turn.length));
            } else {
                return; // No move is possible
            }
        }

        if (turn.length != possibleTurns[0].length) {
            throw new Exception(format!"The longest turn is %d moves but you tried to validate a turn of %d moves"(possibleTurns[0].length, turn.length));
        }

        import std.algorithm : equal;
        foreach (possibleTurn; possibleTurns) {
            if (possibleTurn.equal(turn)) {
                return;
            }
        }
        throw new Exception("Your turn is not a valid one.");
    }

    bool canBearOff(Player player) {
        Point[] nonHomePoints;
        if (player == Player.P1) {
            nonHomePoints = points[6..$];
        } else if (player == Player.P2) {
            nonHomePoints = points[0..$-6];
        }

        foreach (point; nonHomePoints) {
            if (point.owner == player) return false;
        }

        return true;
    }

    /**
     * Duplicate the current gamestate. Does not copy signals. Use for exploring
     * alternative game scenarios or saving the game at a certain point.
     */
    GameState dup() {
        GameState d = new GameState;
        d._currentPlayer = _currentPlayer;
        d._diceValues = _diceValues;
        d._turnState = _turnState;
        d.borneOffPieces = borneOffPieces;
        d.takenPieces = takenPieces;
        d.points = points;

        return d;
    }

    invariant {
        // Ensure that every player has 15 points
        // foreach (Player p; [Player.P1, Player.P2]) {
        //     uint numPieces = takenPieces[p] + borneOffPieces[p];
        //     foreach (point; points) {
        //         if (point.owner == p) {
        //             assert(point.numPieces > 0);
        //             numPieces += point.numPieces;
        //         }
        //     }
        //     assert(numPieces == 15);
        // }
        // assert (_currentPlayer == Player.P1 || _currentPlayer == Player.P2);
    }
}
