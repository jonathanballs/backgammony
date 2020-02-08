module ui.boardtests;

import std.stdio;
import std.typecons;
import gtk.Window;
import gtk.Button;
import gtk.Box;

import ui.window;
import ui.boardWidget;
import game;

// UDA for uitests
private enum uitest;

/**
 * UI Tests. Creates a 
 */
class BoardUITestWindow : Window {
    /**
     * Create a new UI Tests window
     */
    this(BackgammonWindow w) {
        super("UI Tests");
        auto box = new Box(GtkOrientation.VERTICAL, 0);
        import std.traits : getSymbolsByUDA;
        static foreach (s; getSymbolsByUDA!(UITests, uitest)) {
            {
                auto b = new Button((&s).stringof[2..$]);
                b.addOnClicked((Button) {
                    s(w);
                });
                box.add(b);
            }
        }

        this.add(box);
    }
}

/**
 * The actual tests that get run
 */
private class UITests {
    this() {}

    @uitest static void newGame(BackgammonWindow w) {
        auto gs = new GameState();
        w.setGameState(gs);
        gs.newGame();
    }

    @uitest static void rollDice(BackgammonWindow w) {
        writeln("rolling diicee");
    }

    @uitest static void noMovesMessage(BackgammonWindow w) {
    }
}
