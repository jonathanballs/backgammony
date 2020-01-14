module formats.fibs;

import std.format;
import std.conv;
import std.algorithm;
import std.array;
import std.string;
import std.stdio;
import game;

/**
 * Contains functions and methods for handling FIBS encoded games and moves
 * Reference: http://www.fibs.com/fibs_interface.html#game_play
 * P1 = 0 (positive), P2 = X (negative)
 */

/**
 * Convert a GameState to FIBS string.
 * Fibs boards are for sending to a client so must be from a perspective. Leave
 * perspective blank to default to the currentPlayer variable of the gamestate.
 */
string toFibsString(GameState gs, Player perspective = Player.NONE) {
    perspective = perspective == Player.NONE ? gs.currentPlayer : perspective;

    return format!"board:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s:%s"(
        "You:Opponent", // Player names
        "1", // Match length
        "0:0", // Current Match Score
        gs.takenPieces[Player.P1].to!string, // P1 bar
        gs.points.array
            .map!(p => (p.owner == Player.P2 ? "-" : "") ~ p.numPieces.to!string ~ ":")
            .reduce!((a,b) => a ~ b)[0..$-1], // Board
        gs.takenPieces[Player.P2].to!string, // P2 bar
        gs.currentPlayer == Player.P1 ? "1" : "-1", // Who's turn turn
        format!"%d:%d:%d:%d"(gs.diceValues[0], gs.diceValues[1], gs.diceValues[0], gs.diceValues[1]), // Dice
        "1", // Doubling cube
        "0:0", // May double
        "0", // Was doubled
        perspective == Player.P1 ? "1" : "-1", // Color
        perspective == Player.P1 ? "-1" : "1", // Direction (P1 moves downwards)
        perspective == Player.P1 ? "0:25" : "25:0", // Home and bar
        format!"%d:%d"(gs.borneOffPieces[perspective], gs.borneOffPieces[perspective.opposite()]), // On Home
        format!"%d:%d"(gs.takenPieces[perspective], gs.takenPieces[perspective.opposite()]), // On Bar
        "0:0", // Forced Move
        "0"  // Redoubles
    );
}

/**
 * Convert a PipMovement to FIBS string.
 */
string toFibsString(PipMovement pipMovement) {
    switch (pipMovement.moveType) {
    case PipMoveType.Movement:
        return format!"move %d %d"(pipMovement.startPoint, pipMovement.endPoint);
    case PipMoveType.BearingOff:
        return format!"move %d off"(pipMovement.startPoint);
    case PipMoveType.Entering:
        return format!"move bar %d"(pipMovement.endPoint);
    default: assert(0);
    }
}

/**
 * Parse a FIBS movement. Tries to be lenient in what it accepts. Will throw
 * Exception if it can't parse
 */
PipMovement parseFibsString(string fibsString){
    PipMoveType moveType = PipMoveType.Movement;
    uint startPoint = 0;
    uint endPoint = 0;

    string[] fibsStringSplit = fibsString.toLower().split(" "); // Case insensitive
    if (fibsStringSplit.length != 3 || fibsStringSplit[0] != "move") {
        throw new Exception("Couldn't parse '" ~ fibsString ~ "'");
    }

    // From
    if (fibsStringSplit[1] == "bar") {
        moveType = PipMoveType.Entering;
    } else {
        startPoint = fibsStringSplit[1].to!uint;
    }

    // To
    if (fibsStringSplit[2] == "off") {
        if (moveType == PipMoveType.Entering) // Can't go from bar to home
            throw new Exception("Couldn't parse '" ~ fibsString ~ "'");
        moveType = PipMoveType.BearingOff;
    } else {
        endPoint = fibsStringSplit[2].to!uint;
    }

    return PipMovement(moveType, startPoint, endPoint);
}

unittest {
    import std.stdio : writeln;
    writeln("Testing FIBS formatting");
    auto gs = new GameState();
    gs.newGame();
    gs.toFibsString;

    const auto testMovements = [
        "move 5 7": PipMovement(PipMoveType.Movement, 5, 7)
    ];

    foreach(ms; testMovements.byKey()) {
        // writeln(ms.parseFibsString);
        assert(ms.parseFibsString == testMovements[ms]);
        assert(ms.parseFibsString.toFibsString == ms);
    }
}
