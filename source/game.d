module game;


import std.algorithm;
import std.array;
import std.format;
import std.math;
import std.range : enumerate, inputRangeObject;
import std.stdio;

import player;
import utils.signals;
import utils.types : EnumIndexStaticArray, OneIndexedStaticArray;

// TODO list
// - Handle users more smoothly - clean up functions etc.
// - Record board history - and validate it.
// - More compact data structures? Or leave that to the AI...

/**
 * Represents a single move in a turn e.g. a piece moving from the bar or a
 * point to another point. TODO: Basic validation. Points are 1-indexed.
 * Const.
 */
struct PipMovement {
    private PipMoveType _moveType;   /// The type of move
    private uint _startPoint;        /// Starting point
    private uint _endPoint;          /// End point

    /// The type of move
    PipMoveType moveType() { return _moveType; }
    /// Starting point (1-indexed)
    uint startPoint() { return _startPoint; }
    /// End point (1-indexed)
    uint endPoint() { return _endPoint; }

    /**
     * Create a new PipMovement
     */
    this(PipMoveType moveType, uint startPoint, uint endPoint) {
        _moveType = moveType;
        _startPoint = startPoint;
        _endPoint = endPoint;

        // Ensure that it is a legal move
        switch (moveType) {
        case PipMoveType.Movement:
            if (!startPoint || startPoint > 24 || !endPoint || endPoint > 24) {
                throw new Exception("Movement points not in board range");
            }
            if (abs(cast(int) startPoint - cast(int) endPoint) > 6) {
                throw new Exception("Movement can not be greater than 6 points");
            }
            return;
        case PipMoveType.Entering:
            if (startPoint != 0) {
                throw new Exception("startPoint for Entering must be 0");
            }
            if (!Player.P1.isHomePoint(endPoint) && !Player.P2.isHomePoint(endPoint)) {
                throw new Exception("endPoint must be in a users home");
            } // 1 - 6 or 19 - 24
            return;
        case PipMoveType.BearingOff:
            if (!Player.P1.isHomePoint(startPoint) && !Player.P2.isHomePoint(startPoint)) {
                throw new Exception("Must bear off from a home point");
            }
            if (endPoint != 0) {
                throw new Exception("endPoint for Bearing off must be 0");
            }
            return;
        default: assert(0);
        }
    }

    /**
     * The value of the dice roll
     */
    uint diceValue() {
        switch (moveType) {
        case PipMoveType.Movement:
            return abs(cast(int) endPoint - cast(int) startPoint);
        case PipMoveType.Entering:
            if (endPoint < 7) return endPoint;
            else return 25 - endPoint;
        case PipMoveType.BearingOff: // Err :/ could actually be higher.
            writeln("Warning: Getting dice value of bearing off move");
            if (endPoint < 7) return endPoint;
            else return 25 - endPoint;
        default: assert(0);
        }
    }
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
    if (player == Player.P1 && pointNumber >= 1 && pointNumber <= 6) {
        return true;
    } else if (player == Player.P2 && pointNumber >= 19 && pointNumber <= 24) {
        return true;
    }
    return false;
}

/// The homePoint
uint homePointToBoardPoint(Player player, uint homePoint) {
    assert(1 <= homePoint && homePoint <= 6);
    assert(player != Player.NONE);

    return player == Player.P1 ? homePoint : 25 - homePoint;
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
    EnumIndexStaticArray!(Player, PlayerMeta) players;
    /**
     * The 24 points that make up the backgammon board
     */
    OneIndexedStaticArray!(Point, 24) points;
    EnumIndexStaticArray!(Player, uint) takenPieces;
    EnumIndexStaticArray!(Player, uint) borneOffPieces;
    Player _currentPlayer;
    private TurnState _turnState;
    private uint[2] _diceValues;
    Player winner = Player.NONE;

    /**
     * Fired at the start of each turn. Calls connected functions with the player
     * who is about to begin their go.
     */
    Signal!(GameState, Player) onBeginTurn;

    /**
     * Fired at the start of a game
     */
    Signal!(GameState) onStartGame;

    /**
     * Fired at the end of the game.
     */
    Signal!(GameState, Player) onEndGame;

    /**
     * Fired on a dice roll. Calls connected functions with the value of the roll.
     */
    Signal!(GameState, uint , uint) onDiceRoll;

    /**
     * Create a new gamestate. The game will be initalized to the start of P1's
     * turn.
     */
    this() {
        onBeginTurn = new Signal!(GameState, Player);
        onDiceRoll = new Signal!(GameState, uint, uint);
        onEndGame = new Signal!(GameState, Player);
        onStartGame = new Signal!(GameState);
    }

    /**
     * Create a new gamestate with players
     */
    this(PlayerMeta p1, PlayerMeta p2) {
        this();

        players[Player.P1] = p1;
        players[Player.P2] = p2;
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

        points[24] = Point(Player.P1, 2);
        points[13] = Point(Player.P1, 5);
        points[8] = Point(Player.P1, 3);
        points[6] = Point(Player.P1, 5);
        points[1] = Point(Player.P2, 2);
        points[12] = Point(Player.P2, 5);
        points[17] = Point(Player.P2, 3);
        points[19] = Point(Player.P2, 5);

        onStartGame.emit(this);
        onBeginTurn.emit(this, _currentPlayer);
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

        onDiceRoll.emit(this, diceValues[0], diceValues[1]);
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

        onDiceRoll.emit(this, diceValues[0], diceValues[1]);
    }

    /// Generate a list of possible game moves based off current dice
    PipMovement[][] generatePossibleTurns() {
        assert(turnState == TurnState.MoveSelection);
        uint[] moveValues = diceValues;
        if (moveValues[0] == moveValues[1]) moveValues ~= moveValues;

        return generatePossibleTurns(moveValues);
    }

    /// This could definitely be better written
    private PipMovement[][] generatePossibleTurns(uint[] moveValues) {
        if (moveValues.length == 0) return [];
        // First find all possible movements of any length and then prune to
        // only the longest ones.
        PipMovement[][] ret;


        /**
         * Enter the board
         */
        if (takenPieces[currentPlayer]) {
            foreach (i, moveValue; moveValues) {
                auto selectedMovement = PipMovement( PipMoveType.Entering, 0,
                    homePointToBoardPoint(currentPlayer.opposite, moveValue));

                if (isValidPotentialMovement(selectedMovement)) {
                    GameState potentialGS = this.dup;
                    potentialGS.applyMovement(selectedMovement);
                    auto nextMoves = potentialGS.generatePossibleTurns(moveValues.dup.remove(i));

                    if (nextMoves) {
                        foreach (m; nextMoves) {
                            auto moveList = [[selectedMovement] ~ m.dup];
                            ret ~= moveList;
                        }
                    } else {
                        ret ~= [selectedMovement];
                    }
                }
            }
        }

        /**
         * Bearing off
         */
        if (canBearOff(currentPlayer)) {
            foreach (i, moveValue; moveValues.uniq().enumerate()) {
                try {
                    PipMovement[] possibleBearoffs;

                    auto noHigherPips = [1,2,3,4,5,6][moveValue..$].map!((mv) {
                        auto p = points[homePointToBoardPoint(currentPlayer, mv)];
                        return p.owner != currentPlayer;

                    }).fold!((a, b) => a && b)(true);

                    foreach_reverse (homePoint; 1..moveValue+1) {
                        auto point = points[homePointToBoardPoint(currentPlayer, homePoint)];
                        if (point.owner == currentPlayer) {
                            possibleBearoffs ~= PipMovement(PipMoveType.BearingOff,
                                homePointToBoardPoint(currentPlayer, homePoint), 0);
                            break;
                        }
                        if (!noHigherPips) break;
                    }

                    foreach (selectedMovement; possibleBearoffs) {
                        if (isValidPotentialMovement(selectedMovement)) {
                            GameState potentialGS = this.dup;
                            potentialGS.applyMovement(selectedMovement);
                            auto nextMoves = potentialGS.generatePossibleTurns(moveValues.dup.remove(i));

                            if (nextMoves) {
                                foreach (m; nextMoves) {
                                    auto moveList = [[selectedMovement] ~ m.dup];
                                    ret ~= moveList;
                                }
                            } else {
                                ret ~= [selectedMovement];
                            }
                        }
                    }
                } catch (Exception e) {
                    // Ignore
                }
            }
        }

        // Check if player can move
        foreach (i, moveValue; moveValues.uniq().enumerate()) {
            foreach (pointIndex, point; points[]) {
                pointIndex = pointIndex+1;

                if (point.owner == currentPlayer) {
                    try {
                        PipMovement selectedMovement = PipMovement(
                            PipMoveType.Movement,
                            cast(uint) pointIndex,
                            _currentPlayer == Player.P1 ? cast(uint) pointIndex-moveValue : cast(uint) pointIndex+moveValue);
                        if (isValidPotentialMovement(selectedMovement)) {
                            GameState potentialGS = this.dup;
                            potentialGS.applyMovement(selectedMovement);
                            auto nextMoves = potentialGS.generatePossibleTurns(moveValues.dup.remove(i));

                            if (nextMoves) {
                                foreach (m; nextMoves) {
                                    auto moveList = [[selectedMovement] ~ m.dup];
                                    ret ~= moveList;
                                }
                            } else {
                                ret ~= [selectedMovement];
                            }
                        }
                    } catch (Exception e) {
                        // Ignore
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
                assert(points[pipMovement.endPoint].numPieces == 1);
                takenPieces[currentPlayer.opposite()]++;
                points[pipMovement.endPoint].owner = Player.NONE;
                points[pipMovement.endPoint].numPieces = 0;
            }

            points[pipMovement.endPoint].numPieces++;
            points[pipMovement.endPoint].owner = currentPlayer;
        } else if (pipMovement.moveType == PipMoveType.Entering) {
            takenPieces[currentPlayer]--;

            if (points[pipMovement.endPoint].owner == currentPlayer.opposite) {
                assert(points[pipMovement.endPoint].numPieces == 1);
                takenPieces[currentPlayer.opposite]++;
                points[pipMovement.endPoint].owner = Player.NONE;
                points[pipMovement.endPoint].numPieces = 0;
            }

            points[pipMovement.endPoint].owner = currentPlayer;
            points[pipMovement.endPoint].numPieces++;
        } else if (pipMovement.moveType == PipMoveType.BearingOff) {
            if (!--points[pipMovement.startPoint].numPieces) {
                points[pipMovement.startPoint].owner = Player.NONE;
            }
            borneOffPieces[currentPlayer]++;
        }
    }

    /**
     * Apply a turn for the current user. Must be valid turn or 
     * Params:
     *     turn = The turn to apply
     *     partialTurn = Whether this is a partial (incomplete) turn.
     */
    GameState applyTurn(Turn turn, bool partialTurn = false) {
        assert(turnState == TurnState.MoveSelection,
            "Tried to applyTurn() before dice are rolled");
        assert(winner == Player.NONE, "Tried to applyTurn to finished game");

        if (!partialTurn) {
            validateTurn(turn);
        }

        foreach (move; turn) {
            applyMovement(move);
        }

        winner = calculateWinner();
        if (winner != Player.NONE) {
            onEndGame.emit(this, winner);
        } else if (!partialTurn) {
            _currentPlayer = currentPlayer.opposite();
            _turnState = TurnState.DiceRoll;
            _diceValues = [0, 0];
            onBeginTurn.emit(this, _currentPlayer);
        }

        return this;
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
            // below zero. This should be checked in the PipMovement constructor.
            if (!pipMovement.startPoint || !pipMovement.endPoint
                    || pipMovement.startPoint > 24 || pipMovement.endPoint > 24) {
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
            nonHomePoints = points[7..$];
        } else if (player == Player.P2) {
            nonHomePoints = points[1..$-6];
        }

        foreach (point; nonHomePoints) {
            if (point.owner == player) return false;
        }

        return true;
    }

    /**
    * Calculate the winner of the game.
    */
    Player calculateWinner() {
        outer: foreach (player; [Player.P1, Player.P2]) {
            foreach (pointIndex; 1..25) {
                if (points[pointIndex].owner == player) continue outer;
            }
            if (takenPieces[player]) continue outer;

            return player;
        }

        return Player.NONE;
    }

    /**
     * Is this a network game?
     */
    bool isNetworkGame() {
        return players[Player.P1].type == PlayerType.Network
            || players[Player.P2].type == PlayerType.Network;
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
        d.players = players;

        return d;
    }

    /**
     * Test value equality
     */
    bool equals(GameState rhs) {
        return this._currentPlayer == rhs._currentPlayer
            && this._diceValues == rhs._diceValues
            && this._turnState == rhs._turnState
            && this.borneOffPieces == rhs.borneOffPieces
            && this.takenPieces == rhs.takenPieces
            && this.points == rhs.points;
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


unittest {
    writeln("Testing GameState");
    GameState gs = new GameState();
    gs.newGame();
    gs.takenPieces[Player.P1] = 1;
    assert(gs.dup.takenPieces[Player.P1] == 1);

    /**
     * Test potential move generation
     */
    gs.newGame();
    gs.points[24].numPieces--;
    gs.takenPieces[Player.P1]++;
    gs.rollDice(1, 6);
    auto possibleTurns = gs.generatePossibleTurns();
    assert(possibleTurns.length);
    foreach (turn; possibleTurns) {
        assert(turn[0] == PipMovement(PipMoveType.Entering, 0, 24));
        gs.dup.applyTurn(turn);
    }

    /**
     * Test opEquals
     */
    assert(gs.equals(gs.dup));

    /**
     * Test bearing off. Player 1 has 1 piece to take off
     */
    gs = new GameState();
    gs.points[1] = Point(Player.P1, 1);
    gs.points[24] = Point(Player.P2, 1);
    gs._currentPlayer = Player.P1;
    gs.rollDice(3, 6);
    assert(gs.generatePossibleTurns[0].length == 1);
    assert(gs.generatePossibleTurns[0][0] == PipMovement(PipMoveType.BearingOff, 1, 0));
}
