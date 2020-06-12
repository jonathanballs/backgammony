module ui.networkgamedialog;

import core.time;
import std.concurrency;
import std.typecons;
import std.stdio;
import std.digest.sha;
import std.socket;
import requests;

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
import networking.fibs.thread;
import player;
import ui.newgamedialog : HumanSelector, setMarginsExpand;
import ui.fragments;
import utils.addtickcallback;
import utils.os;
import utils.signals;

// TODO:
//  - Move TBP form and functionality to separate class

enum formPadding = 10;

class NetworkGameDialog : Dialog {
    /// Emitted when a new TBP game is started
    Signal!(GameState) onCreateNewGame;

    /// Emitted when a connection to a FIBS server is made successfully
    Signal!() onFibsConnection;

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

    FIBSLoginForm fibsLoginForm;

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
        this.onFibsConnection = new Signal!();

        /**
         * Internet
         */
        inetBox = new Box(GtkOrientation.VERTICAL, formPadding);
        inetBox.setMarginsExpand(formPadding, formPadding, formPadding, formPadding, true, true);
        inetHuman = new HumanSelector("Username", getLocalUserName());
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
        lanHuman = new HumanSelector("Username", getLocalUserName());
        lanBox.packStart(lanHuman, false, false, 0);

        /**
         * Fibs
         */
        fibsLoginForm = new FIBSLoginForm();
        fibsLoginForm.onSuccessfulConnection.connect(() {
            this.onFibsConnection.emit();
        });

        tabs = new Notebook();
        tabs.appendPage(inetBox, new Label("Internet"));
        tabs.appendPage(lanBox, new Label("LAN"));
        tabs.appendPage(fibsLoginForm, new Label("FIBS"));

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

/**
 * Login form for a FIBS server
 */
class FIBSLoginForm : Box {
    Signal!() onSuccessfulConnection;

    /// Connection Settings
    Box fibsBox;
    LabeledEntry serverEntry;
    LabeledEntry usernameEntry;
    LabeledEntry passwordEntry;

    /// Fibs connect button
    Label connectionErrorMessage;
    Button connectButton;
    Box connectButtonBox;
    Label connectButtonLabel;
    Spinner connectButtonSpinner;
    bool isConnecting;

    /// Connection thread
    FIBSController fibsController;

    this() {
        super(GtkOrientation.VERTICAL, formPadding);

        this.onSuccessfulConnection = new Signal!();

        this.setMarginsExpand(formPadding, formPadding, formPadding, formPadding, true, true);

        /// Connection Info form
        import config;
        auto label = new Label("Connection Info");
        this.packStart(label, false, false, 0);
        label.setMarginTop(formPadding);
        serverEntry = new LabeledEntry("Server", Config.fibsServer);
        serverEntry.label.setWidthChars(8);
        serverEntry.label.setXalign(0.0);
        usernameEntry = new LabeledEntry("Username", Config.fibsUsername);
        usernameEntry.label.setWidthChars(8);
        usernameEntry.label.setXalign(0.0);
        passwordEntry = new LabeledEntry("Password", Config.fibsPassword);
        passwordEntry.label.setWidthChars(8);
        passwordEntry.label.setXalign(0.0);
        passwordEntry.entry.setVisibility(false);
        this.add(serverEntry);
        this.add(usernameEntry);
        this.add(passwordEntry);

        /// Connection button
        connectButtonLabel = new Label("Connect");
        connectButtonBox = new Box(GtkOrientation.HORIZONTAL, formPadding);
        connectButtonBox.packStart(connectButtonLabel, false, false, 0);
        connectButtonBox.setHalign(GtkAlign.CENTER);

        connectButton = new Button();
        connectButton.add(connectButtonBox);
        connectButton.getStyleContext().addClass("suggested-action");
        this.packEnd(connectButton, false, false, 0);
        connectButton.addOnClicked((Button b) {
            if (!isConnecting) {
                // Reset error message
                connectionErrorMessage.setMarkup("");

                connectButtonSpinner = new Spinner();
                connectButtonBox.packStart(connectButtonSpinner, false, false, 0);
                connectButtonBox.reorderChild(connectButtonSpinner, 0);
                connectButtonSpinner.start();
                connectButtonSpinner.show();
                connectButtonLabel.setText("Connecting...");
                import std.array : split;
                fibsController = new FIBSController(
                    serverEntry.getText(),
                    usernameEntry.getText(),
                    passwordEntry.getText());
                isConnecting = true;
            } else {
                // TODO: Kill thread
                // send(inetThreadTid, NetworkThreadShutdown());
                isConnecting = false;
                connectButtonSpinner.destroy();
                connectButtonLabel.setText("Connect");
            }
        });

        // In case of any errors we'll put them here
        connectionErrorMessage = new Label("");
        this.packEnd(connectionErrorMessage, false, false, 0);

        this.addTickCallback(&onTick);
    }

    /**
     * Handle connection events
     */
    bool onTick(Widget w, FrameClock f) {
        import networking.fibs.messages;

        if (this.fibsController) {
            const auto connStatus = fibsController.connectionStatus();

            switch (connStatus.status) {
                case FIBSConnectionStatus.Connected:
                    this.onSuccessfulConnection.emit();
                    break;
                case FIBSConnectionStatus.FailedConnection:
                case FIBSConnectionStatus.Crashed:
                    import std.format : format;
                    connectionErrorMessage.setMarkup(format!"<span foreground='red'>%s</span>"(connStatus.message));
                    connectButton.clicked();
                    break;
                default:
                    break;
            }

        }
        return true;
    }

    void onDestroy(Widget w) {
        // if (inetThreadRunning && !inetThreadPreserve) {
        //     send(inetThreadTid, NetworkThreadShutdown());
        //     inetThreadRunning = false;
        // }
    }

    mixin AddTickCallback;
}
