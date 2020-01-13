module ui.newgamedialog;

import std.string;
import std.stdio;

import gtk.Box;
import gtk.Button;
import gtk.ComboBoxText;
import gtk.Dialog;
import gtk.Frame;
import gtk.Label;
import gtk.ListStore;
import gtk.Notebook;
import gtk.TreeIter;
import gtk.Widget;
import gtk.Window;

import player;
import ai.gnubg;

enum formPadding = 10;

class NewGameDialog : Dialog {
    Notebook tabs;

    /**
     * Human vs AI
     */
    Box hvaBox;
    AISelector hvaAISelector;
    Button hvaStartGame;

    /**
     * Human vs Human
     */
    Box hvhBox;
    Label hvhLabel;

    /**
     * AI vs AI
     */
    Box avaBox;
    AISelector avaAISelector1;
    AISelector avaAISelector2;
    
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
        hvaBox.setMarginBottom(formPadding);
        hvaBox.setHexpand(true);
        hvaBox.setVexpand(true);
        hvaAISelector = new AISelector(availableAIs, "Artificial Intelligence");
        hvaBox.packStart(hvaAISelector, false, false, 0);
        hvaStartGame = new Button("Start Game");
        hvaStartGame.getStyleContext().addClass("suggested-action");
        hvaBox.packEnd(hvaStartGame, false, false, 0);

        /**
         * AI vs AI
         */
        avaBox = new Box(GtkOrientation.VERTICAL, 30);
        avaBox.setMarginLeft(formPadding);
        avaBox.setMarginTop(formPadding);
        avaBox.setMarginRight(formPadding);
        avaAISelector1 = new AISelector(availableAIs, "Artificial Intelligence 1");
        avaBox.add(avaAISelector1);
        avaAISelector2 = new AISelector(availableAIs, "Artificial Intelligence 2");
        avaBox.add(avaAISelector2);

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
        try {
            const auto gnubg = execute(["gnubg", "--version"]);
            if (!gnubg.status) {
                auto lines = gnubg.output.split('\n');
                if (lines.length) {
                    ais ~= Player(lines[0], "gnubg", PlayerType.AI);
                }
            }
        } catch (Exception e) {
            // Gnu Backgammon is not installed
        }

        return ais;
    }
}

private class AISelector : Box {
    Label label;
    ComboBoxText aiSelector;
    Box aiSettings;

    Player[] availableAIs;

    this(Player[] _availableAIs, string labelString) {
        super(GtkOrientation.VERTICAL, formPadding);
        this.setMarginLeft(formPadding);
        this.setMarginRight(formPadding);
        this.setMarginTop(formPadding);
        this.setMarginBottom(formPadding);

        label = new Label(labelString);
        this.packStart(label, false, false, 0);

        availableAIs = _availableAIs;

        aiSelector = new ComboBoxText(false);
        foreach (uint i, Player ai; availableAIs) {
            aiSelector.append(ai.id, ai.name);
        }

        aiSelector.addOnChanged((ComboBoxText combo) {
            auto setting = combo.getActiveId();
            if (aiSettings) aiSettings.destroy();

            switch (setting) {
            case "gnubg":
                aiSettings = gnubgAISettings();
                break;
            default:
                break;
            }

            if (aiSettings) {
                aiSettings.showAll();
                this.packEnd(aiSettings, false, false, 0);
            }
        });

        this.packStart(aiSelector, false, false, 0);
        if (availableAIs.length) {
            aiSelector.setActive(0);
        } else {
            aiSelector.append("none", "No AIs installed...");
            aiSelector.setActive(0);
            aiSelector.setSensitive(false);
        }
    }

    private Box gnubgAISettings() {
        Box box = new Box(Orientation.VERTICAL, 0);

        auto difficultySelection = new ComboBoxText(false);
        foreach (context; gnubgDefaultEvalContexts) {
            difficultySelection.append(context.name, context.name);
        }
        difficultySelection.setActive(2); // Intermediate
        box.add(difficultySelection);

        return box;
    }
}
