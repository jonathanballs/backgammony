import std.getopt;
import gtk.Main;
import ui.window;

void main(string[] args) 
{

    /**
     * Parse arguments
     */
    bool uiTests = false;
    getopt(args,
        "uitests", &uiTests
    );


    Main.init(args);
    auto window = new BackgammonWindow();
    window.showAll();

    if (uiTests) {
        import ui.boardtests;
        auto boardTests = new BoardUITestWindow();
        boardTests.showAll();
    }

    Main.run();
}
