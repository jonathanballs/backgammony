module ui.window;

import std.concurrency;
import core.thread;

import gdk.FrameClock;
import gio.ThemedIcon;
import gtk.Box;
import gtk.Button;
import gtk.Container;
import gtk.HeaderBar;
import gtk.IconTheme;
import gtk.Image;
import gtk.Label;
import gtk.Main;
import gtk.MainWindow;
import gtk.Widget;

import game;
import networking;
import ui.boardWidget;
import ui.networkWidget;
import ui.newgamedialog;

class BackgammonWindow : MainWindow {
    HeaderBar header;
    Button newGameBtn;
    Button inetGameBtn;

    BackgammonBoard backgammonBoard;
    NetworkWidget networkingWidget;
    NewGameDialog newGameDialog;
    Thread netThread;

    GameState gameState;

    this() {
        super("Backgammon");

        gameState = new GameState();

        header = new HeaderBar();
        header.setTitle("Backgammon");
        header.setShowCloseButton(true);
        this.setTitlebar(header);
        gameState.onBeginTurn.connect((Player p) {
            header.setSubtitle(p == Player.P1 ? "Black to play" : "White to play");
        });

        newGameBtn = new Button("New Game");
        newGameBtn.addOnClicked((Button b) {
            // Create new game
            newGameDialog = new NewGameDialog(this);
        });
        header.packStart(newGameBtn);

        // Internet game
        inetGameBtn = new Button();
        auto icon = new ThemedIcon("network-server-symbolic");
        auto inetImg = new Image();
        inetImg.setFromGicon(icon, IconSize.BUTTON);
        inetGameBtn.add(inetImg);
        inetGameBtn.addOnClicked((Button b) {
            netThread = new NetworkingThread().start();
            networkingWidget = new NetworkWidget(this);
        });
        header.packStart(inetGameBtn);

        // // Move buttons
        auto undoMoveBtn = new Button();
        icon = new ThemedIcon("edit-undo-symbolic");
        inetImg = new Image();
        inetImg.setFromGicon(icon, IconSize.BUTTON);
        undoMoveBtn.add(inetImg);
        undoMoveBtn.addOnClicked((Button b) {
            backgammonBoard.undoPotentialMove();
        });
        undoMoveBtn.setSensitive(false);

        auto finishMoveBtn = new Button("Finish");
        finishMoveBtn.addOnClicked((Button b) {
            backgammonBoard.finishTurn();
        });
        finishMoveBtn.setSensitive(false);
        header.packEnd(finishMoveBtn);
        header.packEnd(undoMoveBtn);

        // // Game board
        backgammonBoard = new BackgammonBoard(gameState);
        backgammonBoard.onChangePotentialMovements.connect(() {
            undoMoveBtn.setSensitive(!!backgammonBoard.potentialMoves.length);

            finishMoveBtn.setSensitive(false);
            if (gameState.turnState == TurnState.MoveSelection) {
                try {
                    backgammonBoard.gameState.validateTurn(backgammonBoard.potentialMoves);
                    finishMoveBtn.setSensitive(true);
                } catch (Exception e) {
                    finishMoveBtn.setSensitive(false);
                }
            }
        });

        this.add(backgammonBoard);
        this.setDefaultSize(800, 600);

        this.addTickCallback(&handleThreadMessages);

        // For now lets just roll immediately.
        gameState.onBeginTurn.connect((Player p) {
            gameState.rollDice();
        });

        gameState.newGame();
    }

    bool handleThreadMessages(Widget w, FrameClock f) {
        import networking.messages;
        import std.stdio;

        if (netThread && netThread.isRunning) {
            receiveTimeout(5.msecs,
                (NetworkThreadStatus status) {
                    this.networkingWidget.statusMessage.setText(status.message);
                },
                (NetworkThreadError error) {
                    this.networkingWidget.statusMessage.setText(error.message);
                    this.networkingWidget.spinner.stop();
                },
                (NetworkBeginGame game) {
                    this.networkingWidget.destroy();
                },
                (NetworkNewDiceRoll diceRoll) {
                    this.backgammonBoard.gameState.rollDice(diceRoll.dice1, diceRoll.dice2);
                }
            );
        }
        return true;
    }

    override void addTickCallback(bool delegate(Widget, FrameClock) callback) {
        tickCallbackListeners ~= callback;
        static bool connected;

        if ( connected )
        {
            return;
        }

        super.addTickCallback(cast(GtkTickCallback)&tickCallback, cast(void*)this, null);
        connected = true;
    }

    extern(C) static int tickCallback(GtkWidget* widgetStruct, GdkFrameClock* frameClock, Widget _widget) {
        import std.algorithm.iteration : filter;
        import std.array : array;
        _widget.tickCallbackListeners = _widget.tickCallbackListeners.filter!((dlg) {
            return dlg(_widget, new FrameClock(frameClock));
        }).array();
        return !!_widget.tickCallbackListeners.length;
    }
}
