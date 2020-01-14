module ai.gnubg;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.format;
import std.process;
import std.stdio;
import std.string;

import formats.fibs;
import game;

/**
 * Manages interfacing with GnuBackgammon
 */

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

/**
 * Request an evaluation from gnubg
 */
GnubgEvalResult evaluatePosition(GameState gs, GnubgEvalContext context) {
    assert(gs.turnState == TurnState.MoveSelection);
    string gnubgCommand = format!"eval FIBSBOARD %s PLIES 0 CUBEFUL\n"(gs.toFibsString());

    // Create commands
    string tmpFileName = "/tmp/gnubg-" ~ Clock.currTime().toISOString() ~ "";
    auto f = File(tmpFileName, "w");
    f.write(gnubgCommand);
    f.close();

    // Run 
    auto p = execute(["gnubg", "--tty", "-c", tmpFileName]);

    // Filter output to 0-ply static line
    string[] r = p.output.split('\n').filter!(s => s.indexOf("static: ") > -1).array;
    if (!r.length) throw new Exception("Failed to get results from gnubg");
    float[] results = r[0].split().array[1..$].map!(n => n.chomp.to!float).array;
    if (results.length < 6) throw new Exception("Failed to get results from gnubg");

    return GnubgEvalResult(results[0], results[1], results[2], results[3], results[4]);
}

unittest {
    writeln("Testing gnubg...");
    auto gs = new GameState();
    gs.newGame();
    gs.rollDice(3, 3);
    auto eval = evaluatePosition(gs, gnubgDefaultEvalContexts[2]);
    writeln(eval);
}
