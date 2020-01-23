module networking.messages;
import game : Player, PipMovement;

/**
 * Tell the network thread to shutdown immmediately
 */
struct NetworkThreadShutdown {
}

/**
 * Tell the UI thread that 
 */
struct NetworkBeginGame {
    // Information about the game. Perhaps game layout idk
    Player clientPlayer;
}

/**
 * Inform the UI thread that a new dice roll has occurred
 */
struct NetworkNewDiceRoll {
    uint dice1;
    uint dice2;
}

/**
 * Inform the UI thread that the network thread has encountered an exception.
 * This should be displayed to the user.
 */
struct NetworkThreadUnhandledException {
    string message;
    string info;
}

/**
 * Inform the UI/Network thread of a new move
 */
struct NetworkThreadNewMove {
    uint numMoves;
    PipMovement[4] moves;

    string toString() {
        import std.algorithm : map, fold;
        import formats.fibs;
        return "MOVE: " ~ moves[0..numMoves]
            .map!(m => m.toFibsString ~ " ")
            .fold!((a, b) => a ~ b);
    }
}

/**
 * Inform the network that the user would like to roll the dice
 */
struct NetworkTurnDiceRoll {
}
