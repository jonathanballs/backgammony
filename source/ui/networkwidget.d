module ui.networkwidget;

import core.time;
import std.concurrency;
import std.typecons;
import std.stdio;
import std.digest.sha;
import requests;
import bencode;

import gtk.Box;
import gtk.Button;
import gtk.Dialog;
import gdk.FrameClock;
import gtk.Label;
import gtk.Notebook;
import gtk.Spinner;
import gtk.Widget;
import gtk.Window;

import game;
import networking.messages;
import networking;
import player;
import ui.newgamedialog : HumanSelector, setMarginsExpand;
import utils.addtickcallback;
import utils.signals;

enum formPadding = 10;

class NetworkWidget : Dialog {
    Signal!(GameState) onCreateNewGame;
    Notebook tabs;

    Box lanBox;
    HumanSelector lanHuman;

    Box inetBox;
    HumanSelector inetHuman;
    Label inetErrorMessage;
    Button inetStartSearchButton;
    Box inetStartSearchBox;
    Label inetStartSearchLabel;
    Spinner inetStartSearchSpinner;
    Tid inetThreadTid;
    bool inetThreadRunning;
    bool inetThreadPreserve; // Don't delete when closing

    /**
     * Create a new Network Widget
     */
    this (Window parent) {
        super();
        this.setTransientFor(parent);
        this.setPosition(GtkWindowPosition.CENTER_ON_PARENT);
        this.setTypeHint(GdkWindowTypeHint.DIALOG);
        this.setModal(true);
        this.setSizeRequest(400, 475);
        this.setTitle("Network Game");
        this.onCreateNewGame = new Signal!(GameState);

        /**
         * Internet
         */
        inetBox = new Box(GtkOrientation.VERTICAL, formPadding);
        inetBox.setMarginsExpand(formPadding, formPadding, formPadding, formPadding, true, true);
        inetHuman = new HumanSelector("Username", "jonathan");
        inetBox.packStart(inetHuman, false, false, 0);

        inetStartSearchLabel = new Label("Find Opponent");
        inetStartSearchBox = new Box(GtkOrientation.HORIZONTAL, formPadding);
        inetStartSearchBox.packStart(inetStartSearchLabel, false, false, 0);

        inetStartSearchButton = new Button();
        inetStartSearchButton.add(inetStartSearchBox);
        inetStartSearchButton.getStyleContext().addClass("suggested-action");
        inetBox.packEnd(inetStartSearchButton, false, false, 0);
        inetStartSearchButton.addOnClicked((Button b) {
            if (!inetThreadRunning) {
                inetStartSearchSpinner = new Spinner();
                inetStartSearchBox.packStart(inetStartSearchSpinner, false, false, 0);
                inetStartSearchBox.reorderChild(inetStartSearchSpinner, 0);
                inetStartSearchSpinner.start();
                inetStartSearchSpinner.show();
                inetStartSearchLabel.setText("Matchmaking...");
                inetThreadTid = spawn((shared string playerName) {
                    auto p = PlayerMeta(playerName, playerName);
                    auto thread = new NetworkingThread(p);
                    thread.run();
                }, cast(immutable) inetHuman.getActiveSelection().id);
                inetThreadRunning = true;
            } else {
                send(inetThreadTid, NetworkThreadShutdown());
                inetThreadRunning = false;
                inetStartSearchSpinner.destroy();
                inetStartSearchLabel.setText("Find opponent");
            }
        });
        inetStartSearchBox.setHalign(GtkAlign.CENTER);

        // In case of any errors we'll put them here
        inetErrorMessage = new Label("");
        inetBox.packEnd(inetErrorMessage, false, false, 0);

        /**
         * LAN
         */
        lanBox = new Box(GtkOrientation.VERTICAL, formPadding);
        lanBox.setMarginsExpand(formPadding, formPadding, formPadding, formPadding, true, true);
        lanHuman = new HumanSelector("Username", "jonathan");
        lanBox.packStart(lanHuman, false, false, 0);

        tabs = new Notebook();
        tabs.appendPage(inetBox, new Label("Internet"));
        tabs.appendPage(lanBox, new Label("LAN"));

        this.getContentArea().add(tabs);
        this.showAll();

        this.addTickCallback(&onTick);
        this.addOnDestroy(&onDestroy);
    }

    /**
     * Handle connection events
     */
    bool onTick(Widget w, FrameClock f) {
        if (!inetThreadRunning) return true;

        receiveTimeout(0.msecs,
            (NetworkBeginGame ng) {
                Variant conn = this.inetThreadTid;
                PlayerMeta player = inetHuman.getActiveSelection();
                PlayerMeta opponent = PlayerMeta("Opponent", "oponnent", PlayerType.Network, conn);
                this.inetThreadPreserve = true;
                if (ng.clientPlayer == Player.P1) {
                    this.onCreateNewGame.emit(new GameState(player, opponent));
                } else {
                    assert(ng.clientPlayer == Player.P2);
                    this.onCreateNewGame.emit(new GameState(opponent, player));
                }
            },
            (NetworkThreadUnhandledException e) {
                import std.format : format;
                inetErrorMessage.setMarkup(format!"<span foreground='red'>%s</span>"(e.message));
            }
        );
        return true;
    }

    void onDestroy(Widget w) {
        if (inetThreadRunning && !inetThreadPreserve) {
            send(inetThreadTid, NetworkThreadShutdown());
            inetThreadRunning = false;
        }
    }

    mixin AddTickCallback;
}
