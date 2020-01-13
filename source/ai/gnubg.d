module ai.gnubg;

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
