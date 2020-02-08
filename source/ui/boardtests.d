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
    this() {
        super("UI Tests");
        auto box = new Box(GtkOrientation.VERTICAL, 0);
        import std.traits : getSymbolsByUDA;
        static foreach (s; getSymbolsByUDA!(UITests, uitest)) {
            {
                auto b = new Button(s.stringof[0..$-2]);
                b.addOnClicked((Button) {
                    s();
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

    @uitest static void newGame() {
        writeln("new gameeee");
    }

    @uitest static void rollDice() {
        writeln("rolling diicee");
    }

    @uitest static void noMovesMessage() {
    }
}
