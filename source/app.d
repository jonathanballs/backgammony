import std.getopt;
import std.stdio;
import gtk.Main;
import ui.window;
import config;

void main(string[] args) 
{

    /**
     * Parse arguments
     */
    bool uiTests = false;
    getopt(args,
        "uitests", &uiTests
    );

    // Read config file
    Config.read();
    if (!Config.couldReadAtStartup) {
        writeln("Could not load config file: " ~ Config.startupErrorMessage);
    }

    Main.init(args);
    auto window = new BackgammonWindow();

    // Connect to fibs or start a ai game
    if (Config.fibsAutoConnect) {
        import networking.fibs.controller;
        window.setFibsController(new FIBSController(
            Config.fibsServer, Config.fibsUsername, Config.fibsPassword));
    } else {
        // By default, let's start a game between the player and the AI with
        // the player going first (assuming that gnubg exists)
        import std.file : exists;
        import ai.gnubg;
        import std.variant;
        import gameplay.gamestate;
        import gameplay.player;
        import gameplay.match;
        import gtk.Widget;
        try {
            if (exists("/usr/bin/gnubg") || exists("/app/bin/gnubg")) {
                Variant aiConfig = gnubgDefaultEvalContexts[4];
                auto match = new BackgammonMatch(
                    PlayerMeta("Player", "gnubg", PlayerType.User),
                    PlayerMeta("AI", "gnubg", PlayerType.AI, aiConfig)
                );

                window.setBackgammonMatch(match);

                // Start game 50msecs after first draw
                import cairo.Context : Context;
                import gobject.Signals : Signals;
                gulong sigId;
                sigId = window.backgammonBoard.addOnDraw((Scoped!Context c, Widget w) {
                    Signals.handlerDisconnect(window.backgammonBoard, sigId);

                    // Timeout
                    import glib.Timeout : Timeout;
                    Timeout t;
                    // Wait 100msecs and start a game
                    t = new Timeout(100, () {
                        match.gs.newGame();
                        t.stop();
                        return false;
                    }, false);

                    return false;
                });
            } else {
                writeln("GNUBG not installed. Not starting game");
            }
        } catch (Exception e) {
            writeln(e);
        }
    }

    window.showAll();

    if (uiTests) {
        import ui.board.tests;
        auto boardTests = new BoardUITestWindow(window);
        boardTests.showAll();
    }

    Main.run();
}
