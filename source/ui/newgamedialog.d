module ui.newgamedialog;

import std.string;
import std.stdio;

import gtk.Box;
import gtk.ComboBoxText;
import gtk.Dialog;
import gtk.Label;
import gtk.ListStore;
import gtk.Notebook;
import gtk.TreeIter;
import gtk.Widget;
import gtk.Window;

import player;

enum formPadding = 15;

class NewGameDialog : Dialog {
    Notebook tabs;

    /**
     * Human vs AI
     */
    Box hvaBox;
    Label hvaLabel;
    ComboBoxText hvaAISelector;

    /**
     * Human vs Human
     */
    Box hvhBox;
    Label hvhLabel;

    /**
     * AI vs AI
     */
    Box avaBox;
    Label avaLabel;
    
    Player[] availableAIs;

    this (Window parent) {
        super();
        /**
         * Set position
         */
        this.setTransientFor(parent);
        this.setPosition(GtkWindowPosition.CENTER_ON_PARENT);
        this.setTypeHint(GdkWindowTypeHint.DIALOG);
        this.setModal(true);
        this.setSizeRequest(400, 475);
        this.setTitle("New Game");

        availableAIs = getAvailableAIs();

        /**
         * Human vs AI
         */
        hvaBox = new Box(GtkOrientation.VERTICAL, 30);
        hvaBox.setMarginLeft(formPadding);
        hvaBox.setMarginTop(formPadding);
        hvaBox.setMarginRight(formPadding);

        hvaAISelector = new ComboBoxText(false);
        foreach (uint i, Player ai; availableAIs) {
            hvaAISelector.append(ai.id, ai.name);
        }
        hvaAISelector.setActive(0);
        hvaBox.packStart(hvaAISelector, false, false, 0);

        /**
         * AI vs AI
         */
        avaBox = new Box(GtkOrientation.VERTICAL, 30);
        avaBox.add(new Label("TODO: AI vs AI"));
        avaBox.setHalign(GtkAlign.FILL);
        avaBox.setValign(GtkAlign.FILL);
        avaBox.setHexpand(true);
        avaBox.setVexpand(true);

        /**
         * Human vs Human
         */
        hvhBox = new Box(GtkOrientation.VERTICAL, 30);
        hvhBox.add(new Label("TODO: Human vs Human"));
        hvhBox.setHalign(GtkAlign.FILL);
        hvhBox.setValign(GtkAlign.FILL);
        hvhBox.setHexpand(true);
        hvhBox.setVexpand(true);

        tabs = new Notebook();
        tabs.appendPage(hvaBox, new Label("Human vs AI"));
        tabs.appendPage(hvhBox, new Label("Human vs Human"));
        tabs.appendPage(avaBox, new Label("AI vs AI"));

        this.getContentArea().add(tabs);

        this.showAll();
    }

    Player[] getAvailableAIs() {
        Player[] ais = [
            // Player("Default", "local", PlayerType.AI),
        ];

        // Gnu Backgammon
        import std.process : execute;
        const auto gnubg = execute(["gnubg", "--version"]);
        if (!gnubg.status) {
            auto lines = gnubg.output.split('\n');
            if (lines.length) {
                writeln("Version: ", lines[0]);
                ais ~= Player(lines[0], "gnubg", PlayerType.AI);
            }
        }

        return ais;
    }
}
