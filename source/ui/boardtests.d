module ui.boardtests;

import std.stdio;
import std.typecons;
import gtk.Window;
import gtk.Button;
import gtk.Box;

import ui.window;
import ui.boardWidget;
import game;
import player;

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
        auto gs = new GameState();
        w.setGameState(gs);
        gs.newGame();
        gs.points[19] = Point(Player.P2, 2);
        gs.points[20] = Point(Player.P2, 2);
        gs.points[21] = Point(Player.P2, 2);
        gs.points[22] = Point(Player.P2, 2);
        gs.points[23] = Point(Player.P2, 2);
        gs.points[24] = Point(Player.P2, 2);

        gs.points[1] = Point(Player.P1, 2);
        gs.points[2] = Point(Player.P1, 2);
        gs.points[3] = Point(Player.P1, 2);
        gs.points[4] = Point(Player.P1, 2);
        gs.points[5] = Point(Player.P1, 2);
        gs.points[6] = Point(Player.P1, 2);

        gs.takenPieces[Player.P1] = 1;
        gs.takenPieces[Player.P2] = 1;
    }

    @uitest static void noMovesMessageAI(BackgammonWindow w) {
        import std.variant : Variant;
        import ai.gnubg;
        Variant aiConfig = gnubgDefaultEvalContexts[0];

        auto gs = new GameState(
            PlayerMeta("Player 1", "gnubg", PlayerType.AI, aiConfig),
            PlayerMeta("Player 2", "gnubg", PlayerType.AI, aiConfig)
        );
        w.setGameState(gs);
        gs.newGame();
        gs.points[19] = Point(Player.P2, 2);
        gs.points[20] = Point(Player.P2, 2);
        gs.points[21] = Point(Player.P2, 2);
        gs.points[22] = Point(Player.P2, 2);
        gs.points[23] = Point(Player.P2, 2);
        gs.points[24] = Point(Player.P2, 2);

        gs.points[1] = Point(Player.P1, 2);
        gs.points[2] = Point(Player.P1, 2);
        gs.points[3] = Point(Player.P1, 2);
        gs.points[4] = Point(Player.P1, 2);
        gs.points[5] = Point(Player.P1, 2);
        gs.points[6] = Point(Player.P1, 2);

        gs.takenPieces[Player.P1] = 1;
        gs.takenPieces[Player.P2] = 1;
    }
}
