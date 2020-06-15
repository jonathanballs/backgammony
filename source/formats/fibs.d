module formats.fibs;

import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.math;
import std.stdio;
import std.string;
import gameplay.gamestate;
import gameplay.match;

/**
 * Contains functions and methods for handling FIBS encoded games and moves
 * Reference: http://www.fibs.com/fibs_interface.html#game_play
 * P1 = O (positive on board), P2 = X (negative on board)
 */

/**
 * Convert a GameState to FIBS string.
 * Fibs boards are for sending to a client so must be from a perspective. Leave
 * perspective blank to default to the currentPlayer variable of the gamestate.
 */
string toFibsString(GameState gs, Player perspective = Player.NONE) {
    BackgammonMatch m;
    m.currentGame = gs;
    m.player1.name = "You";
    m.player2.name = "Opponent";
    m.length = 1;

    return m.toFibsString(perspective);
}

/**
 * Converts a backgammon match into a FIBS string
 */
string toFibsString(BackgammonMatch m, Player perspective = Player.NONE) {
    auto gs = m.currentGame;

    perspective = perspective == Player.NONE ? gs.currentPlayer : perspective;
    perspective = perspective == Player.NONE ? Player.P1 : perspective;

    return format!"board:%s:%s:%d:%d:%d:%d:%s:%d:%d:%s:%s:%s:%s:%d:%d:%s:%s:%s:%s:%s"(
        perspective == Player.P1 ? m.player1.name : m.player2.name,
        perspective == Player.P1 ? m.player2.name : m.player1.name,
        m.length, // Match length
        m.p1score,
        m.p2score,
        gs.takenPieces[Player.P1], // P1 bar
        gs.points.array
            .map!(p => (p.owner == Player.P2 ? "-" : "") ~ p.numPieces.to!string ~ ":")
            .reduce!((a,b) => a ~ b)[0..$-1], // Board
        gs.takenPieces[Player.P2], // P2 bar
        gs.currentPlayer == Player.P1 ? 1 : -1, // Who's turn
        format!"%d:%d:%d:%d"(gs.diceValues[0], gs.diceValues[1], gs.diceValues[0], gs.diceValues[1]), // Dice
        "1", // Doubling cube
        "0:0", // May double
        "0", // Was doubled
        perspective == Player.P1 ? 1 : -1, // Color
        perspective == Player.P1 ? -1 : 1, // Direction (P1 moves downwards)
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
PipMovement parseFibsMovement(string fibsString){
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

BackgammonMatch parseFibsMatch(string s) {
    BackgammonMatch m;
    m.currentGame = new GameState();

    string[] sSplit = s.split(':');
    bool p1isX = sSplit[41] == "-1"; // Is player 1 X
    bool p1moveDown = sSplit[42] == "-1"; // Does player 1 move down the board

    m.player1.name = sSplit[1];
    m.player2.name = sSplit[2];
    m.length = sSplit[3].to!int;
    m.p1score = sSplit[4].to!int;
    m.p2score = sSplit[5].to!int;
    m.currentGame.takenPieces[Player.P1] = sSplit[6].to!int;
    m.currentGame.takenPieces[Player.P2] = sSplit[31].to!int;

    // Board
    string[] boardState = p1moveDown ? sSplit[7..31] : sSplit[7..31].reverse;
    foreach (long i, p; boardState) {
        int pVal = p.to!int;
        if (pVal == 0) {
            continue;
        } else if (pVal < 0) {  // Negative is X
            m.currentGame.points[i + 1] = Point(p1isX ? Player.P1 : Player.P2, abs(pVal));
        } else {                // Positive is O
            m.currentGame.points[i + 1] = Point(p1isX ? Player.P2 : Player.P1, abs(pVal));
        }
    }

    // -1 is X's turn
    m.currentGame._currentPlayer = sSplit[32] == "-1" ? Player.P1 : Player.P2;
    if (!p1isX) m.currentGame._currentPlayer = m.currentGame.currentPlayer.opposite;
    if (sSplit[32] == "0") m.currentGame._currentPlayer = Player.NONE;

    // 33,34,35,36 are dice rolls...
    return m;
}

unittest {
    import std.stdio : writeln;
    writeln("Testing FIBS formatting");
    auto gs = new GameState();
    gs.newGame();
    assert(gs.toFibsString == gs.toFibsString.parseFibsMatch.toFibsString);

    const auto testMovements = [
        "move 5 7": PipMovement(PipMoveType.Movement, 5, 7),
        "move bar 3": PipMovement(PipMoveType.Entering, 0, 3),
        "move 22 off": PipMovement(PipMoveType.BearingOff, 22, 0),
    ];

    foreach(ms; testMovements.byKey()) {
        // writeln(ms.parseFibsMovement);
        assert(ms.parseFibsMovement == testMovements[ms]);
        assert(ms.parseFibsMovement.toFibsString == ms);
    }
}
