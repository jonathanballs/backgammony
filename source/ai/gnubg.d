/**
 * Manages interfacing with GnuBackgammon
 */
module ai.gnubg;

import core.thread;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.format;
import std.process;
import std.stdio;
import std.string;

import formats.fibs;
import game;

/**
 * Gnubg Evaluation settings
 */
struct GnubgEvalContext {
    string name;     /// The name of this context
    bool cubeful;    /// Evaluate with cube
    uint nPlies;     /// Number of positions ahead to evaluate
    bool usePrune;   /// Prune away candidates in deep search - makes eval slightly faster
    bool deterministic; /// Standard deviation
    float noise;     /// Amount of noise to add to evaluation
}

/**
 * Response of a gnubg position evaluation
 */
struct GnubgEvalResult {
    float chanceWin;            /// Chance of winning
    float chanceWinGammon;      /// Chance of winning by gammon
    float chanceWinBackGammon;  /// Chance of winning by backgammon
    float chanceLoseGammon;     /// Chance of losing by gammon
    float chanceLoseBackGammon; /// Chance of losing by backgammon
}

/**
 * Default contexts lifted from gnubg source code.
 * https://cvs.savannah.gnu.org/viewvc/gnubg/gnubg/eval.c?revision=1.485&view=markup#l316
 */
GnubgEvalContext[] gnubgDefaultEvalContexts = [
    { "Beginner",       true, 0, false, true, 0.060f },
    { "Casual",         true, 0, false, true, 0.050f },
    { "Intermediate",   true, 0, false, true, 0.040f },
    { "Advanced",       true, 0, false, true, 0.014f },
    { "Expert",         true, 0, false, true, 0.0f },
    { "World Class",    true, 2, true,  true, 0.0f },
    { "Supremo",        true, 2, true,  true, 0.0f },
    { "Gandmaster",     true, 3, true,  true, 0.0f },
    { "4-ply",          true, 4, true,  true, 0.0f },
];

PipMovement[] gnubgGetTurn(GameState gs, GnubgEvalContext context) {
    import std.socket;
    import networking.connection;

    /**
     * Generate moves and possible gamestates. This can become slow with large
     * numbers of possible turns. Largely due to the applyTurn()s
     */
    Turn[] pMovements;
    GameState[] pGameStates;

    outer: foreach (t; gs.generatePossibleTurns()) {
        auto d = gs.dup().applyTurn(t);
        foreach (f; pGameStates) {
            if (d.equals(f)) continue outer;
        }
        pMovements ~= t;
        pGameStates ~= d;
    }

    /**
     * Run gnubg
     */
    string tmpFileName = "/tmp/gnubg-" ~ Clock.currTime().toISOString();
    string tmpSock = tmpFileName ~ ".sock";
    auto f = File(tmpFileName, "w");
    f.write(format!"external %s\n"(tmpSock));
    f.close();

    auto process = pipeProcess(["gnubg", "--tty", "-c", tmpFileName]);
    Thread.sleep(1.seconds);

    auto c = new Connection(tmpSock);

    GnubgEvalResult[] pResults = [];
    foreach (pos; pGameStates) {
        string gnubgCommand = format!"EVALUATION FIBSBOARD %s PLIES %d %s %s NOISE %d"(
            pos.toFibsString(),
            context.nPlies,
            context.usePrune ? "PRUNE" : "",
            "CUBELESS", // No support for cube currently
            cast(int) (context.noise * 10000),
            );
        c.writeline(gnubgCommand);
        float[] r = c.readline().split().map!(n => n.to!float).array;
        if (r.length < 5) throw new Exception("couldnt parse output");
        pResults ~= GnubgEvalResult(r[0], r[1], r[2], r[3], r[4]);
    }

    import core.sys.posix.signal : SIGKILL;
    kill(process.pid, SIGKILL);
    assert(wait(process.pid) == -SIGKILL);
    remove(tmpFileName);

    // Find best
    float bestProb = 0.0;
    PipMovement[] bestTurn;
    foreach (index, GnubgEvalResult result; pResults) {
        if (result.chanceWin >= bestProb) {
            bestProb = result.chanceWin;
            bestTurn = pMovements[index];
        }
    }

    return bestTurn;
}

unittest {
    writeln("Testing gnubg...");
    auto gs = new GameState();
    gs.newGame();
    gs.rollDice(3, 3);
    // gnubgGetTurn(gs, gnubgDefaultEvalContexts[2]);

    // Testing a long move
    // gs.newGame();
    // gs.rollDice(2, 2);
    // gs.points[5] = Point(Player.P1, 2);
    // gs.points[4] = Point(Player.P1, 2);
    // gs.points[3] = Point(Player.P1, 2);
    // gs.points[2] = Point(Player.P1, 2);
    // gnubgGetTurn(gs, gnubgDefaultEvalContexts[2]);
}
