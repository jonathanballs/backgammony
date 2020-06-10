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
        writeln("Could not read config file: " ~ Config.startupErrorMessage);
    }

    Main.init(args);
    auto window = new BackgammonWindow();
    window.showAll();

    if (uiTests) {
        import ui.board.tests;
        auto boardTests = new BoardUITestWindow(window);
        boardTests.showAll();
    }

    Main.run();
}
