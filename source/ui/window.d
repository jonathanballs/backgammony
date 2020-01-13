module ui.window;

import std.concurrency;
import std.stdio;
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
import utils.addtickcallback;

/**
 * The MainWindow of the backgammon game. Also acts as a high level controller
 * for receiving button presses, network events etc.
 */
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

        header = new HeaderBar();
        header.setTitle("Backgammon");
        header.setShowCloseButton(true);
        this.setTitlebar(header);

        newGameBtn = new Button("New Game");
        newGameBtn.addOnClicked((Button b) {
            // Create new game
            newGameDialog = new NewGameDialog(this);
            newGameDialog.onCreateNewGame.connect((GameState gs) {
                setGameState(gs);
                gs.newGame();
                auto t = newGameDialog;
                t.destroy();
                newGameDialog = null;
            });
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
        backgammonBoard = new BackgammonBoard();
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

        // auto gs = new GameState();
        // setGameState(gs);
        // gs.newGame();
    }

    final void setGameState(GameState gs) {
        backgammonBoard.setGameState(gs);
        this.gameState = gs;

        // Link up gamestate to various things
        // How are dice rolls handled?
        gs.onBeginTurn.connect((GameState _gs, Player p) {
            header.setSubtitle(p == Player.P1 ? "Black to play" : "White to play");
            _gs.rollDice();
        });
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

    mixin AddTickCallback;
}
