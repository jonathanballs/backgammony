module formats.fibs;

import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.math;
import std.regex;
import std.stdio;
import std.string;
import gameplay.gamestate;
import gameplay.match;
import gameplay.player;

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
    BackgammonMatch m = new BackgammonMatch();
    m.gs = gs;
    m.player1.name = "You";
    m.player2.name = "Opponent";
    m.length = 1;

    return m.toFibsString(perspective);
}

/**
 * Converts a backgammon match into a FIBS string
 */
string toFibsString(BackgammonMatch m, Player perspective = Player.NONE) {
    auto gs = m.gs;

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
        -gs.takenPieces[Player.P2], // P2 bar
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
PipMovement parseFibsMovementCommand(string fibsString){
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

/**
 * Parse a FIBS style movement e.g. "3-5" or "bar-22" or "2-off"
 */
PipMovement parseFibsMovement(string fibsString) {
    string movementRegex = "([0-9]+|bar)-([0-9]|off)+";
    if (!fibsString.match(movementRegex)) {
        throw new Exception("Invalid fibs move: " ~ fibsString);
    }

    PipMoveType moveType = PipMoveType.Movement;
    uint startPoint = 0;
    uint endPoint = 0;

    auto fibsStringSplit = fibsString.split('-');

    // From
    if (fibsStringSplit[0] == "bar") {
        moveType = PipMoveType.Entering;
    } else {
        startPoint = fibsStringSplit[0].to!uint;
    }

    // To
    if (fibsStringSplit[1] == "off") {
        if (moveType == PipMoveType.Entering) // Can't go from bar to home
            throw new Exception("Couldn't parse '" ~ fibsString ~ "'");
        moveType = PipMoveType.BearingOff;
    } else {
        endPoint = fibsStringSplit[1].to!uint;
    }

    return PipMovement(moveType, startPoint, endPoint);
}

BackgammonMatch parseFibsMatch(string s) {
    BackgammonMatch m = new BackgammonMatch();
    m.gs = new GameState();

    string[] sSplit = s.split(':');
    bool p1isX = sSplit[41] == "-1"; // Is player 1 X
    bool p1moveDown = sSplit[42] == "-1"; // Does player 1 move down the board

    auto p1 = PlayerMeta(sSplit[1], sSplit[1], PlayerType.FIBS);
    auto p2 = PlayerMeta(sSplit[2], sSplit[2], PlayerType.FIBS);
    if (p1moveDown) {
        m.player1 = p1;
        m.player2 = p2;
    } else {
        m.player1 = p2;
        m.player2 = p1;
        p1isX = !p1isX;
    }

    m.length = sSplit[3].to!int;
    m.p1score = sSplit[4].to!int;
    m.p2score = sSplit[5].to!int;

    if (p1moveDown) {
        m.gs.borneOffPieces[Player.P1] = abs(sSplit[45].to!int);
        m.gs.borneOffPieces[Player.P2] = abs(sSplit[46].to!int);
        m.gs.takenPieces[Player.P1] = abs(sSplit[47].to!int);
        m.gs.takenPieces[Player.P2] = abs(sSplit[48].to!int);
    } else {
        m.gs.borneOffPieces[Player.P1] = abs(sSplit[46].to!int);
        m.gs.borneOffPieces[Player.P2] = abs(sSplit[45].to!int);
        m.gs.takenPieces[Player.P1] = abs(sSplit[48].to!int);
        m.gs.takenPieces[Player.P2] = abs(sSplit[47].to!int);
    }

    // Board
    // string[] boardState = p1moveDown ? sSplit[7..31] : sSplit[7..31].reverse;
    string[] boardState = sSplit[7..31];
    foreach (long i, p; boardState) {
        int pVal = p.to!int;
        if (pVal == 0) {
            continue;
        } else if (pVal < 0) {  // Negative is X
            m.gs.points[i + 1] = Point(p1isX ? Player.P1 : Player.P2, abs(pVal));
        } else {                // Positive is O
            m.gs.points[i + 1] = Point(p1isX ? Player.P2 : Player.P1, abs(pVal));
        }
    }

    // Current turn. -1 is X's turn
    m.gs._currentPlayer = sSplit[32] == "-1" ? Player.P1 : Player.P2;
    if (!p1isX) m.gs._currentPlayer = m.gs.currentPlayer.opposite;
    if (sSplit[32] == "0") m.gs._currentPlayer = Player.NONE;

    // 33,34,35,36 are dice rolls...
    uint die1 = sSplit[33].to!int;
    uint die2 = sSplit[34].to!int;
    uint die3 = sSplit[35].to!int;
    uint die4 = sSplit[36].to!int;

    if (die1 && die2) {
        m.gs.turnState = TurnState.DiceRoll;
        m.gs.rollDice(die1, die2);
    } else if (die3 && die4) {
        m.gs.turnState = TurnState.DiceRoll;
        m.gs.rollDice(die3, die4);
    } else {
        m.gs.turnState = TurnState.DiceRoll;
    }

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
        // writeln(ms.parseFibsMovementCommand);
        assert(ms.parseFibsMovementCommand == testMovements[ms]);
        assert(ms.parseFibsMovementCommand.toFibsString == ms);
        assert("3-6".parseFibsMovement() == PipMovement(PipMoveType.Movement, 3, 6));
    }

    string testString = "board:GammonBot_XVII:Pirlanta:5:4:2:-1:0:0:2:0:-2:6:0:3:0:0:0:-4"
         ~ ":2:0:0:0:-2:-2:-4:2:0:0:0:0:0:-1:0:0:0:0:1:1:1:0:1:-1:0:25:0:0:0:1:2:3:0:0";
    BackgammonMatch m = testString.parseFibsMatch();
    assert(m.player1.name == "GammonBot_XVII");
    assert(m.player2.name == "Pirlanta");
    assert(m.length == 5);
    assert(m.p1score == 4);
    assert(m.p2score == 2);
    assert(m.gs.takenPieces[Player.P1] == 0);
    assert(m.gs.takenPieces[Player.P2] == 1);
}
