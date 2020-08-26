module ui.fibssidebar;

import std.format;
import std.path;
import gdk.FrameClock;
import gtk.Box;
import gtk.Button;
import gtk.CssProvider;
import gtk.Label;
import gtk.Separator;
import gtk.Spinner;
import gtk.Stack;
import gtk.Statusbar;
import gtk.StyleContext;
import gtk.Widget;
import gtk.Window;

import config;
import ui.chatbox;
import ui.fibsplayerlistdialog;
import ui.flagmanager;
import ui.fragments;
import utils.addtickcallback;

import networking.fibs.controller;

enum defaultPadding = 10;

/**
 * Sidebar which displays relevant FIBS information
 */
class FIBSSidebar : Box {
    FIBSController fibsController;

    Label fibsTitle;
    LabeledLabel username;
    LabeledLabel connectionStatus;

    Stack contentStack;

    // Displayed while connected
    Box connectedContentBox;
    Button playerListButton;
    Label playerListButtonLabel;
    FIBSPlayerListDialog fibsPlayerListDialog;
    ChatBox shoutBox;
    Statusbar statusBar;

    // Displayed while connecting
    Box connectingContentBox;
    Spinner connectingSpinner;

    // Displayed when connection failed
    Box connectionFailedContentBox;
    Label connectionFailedErrorMessage;

    this() {
        super(GtkOrientation.VERTICAL, 5);

        StyleContext styleContext = this.getStyleContext();      
        CssProvider cssProvider = new CssProvider();         
        cssProvider.loadFromData("box {"      
            ~ "padding: 10px;"
            ~ "border-left-width: 1px;"      
            ~ "border-left-style: solid;"      
            ~ "border-color: #1b1b1b;"      
            ~ "background-color: @theme_bg_color }");
        styleContext.addProvider(cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);    

        /**
         * FIBS meta
         */
        fibsTitle = new Label("");
        fibsTitle.setMarkup("<b>FIBS</b>");
        this.packStart(fibsTitle, false, false, 10);
        username = new LabeledLabel("User", "jonathanballs (----)");
        this.packStart(username, false, true, 0);
        connectionStatus = new LabeledLabel("Connection status", "Ready");
        this.packStart(connectionStatus, false, true, 0);

        /**
         * Connected view
         */
        connectedContentBox = new Box(GtkOrientation.VERTICAL, 5);
        playerListButton = new Button();
        playerListButtonLabel = new Label("Players (0 online)");
        playerListButton.add(playerListButtonLabel);
        playerListButton.addOnClicked((Button b) {
            Window mainWindow = new Window(cast(GtkWindow *) this.getToplevel.getStruct());
            fibsPlayerListDialog = new FIBSPlayerListDialog(
                mainWindow, fibsController);
            fibsPlayerListDialog.onWatchUser.connect((string username) {
                fibsController.requestWatch(username);
                this.fibsPlayerListDialog.close();
                this.fibsPlayerListDialog.destroy();
                this.fibsPlayerListDialog = null;
            });
            this.fibsPlayerListDialog.fillTree();
        });
        connectedContentBox.packStart(playerListButton, false, true, 0);
        new FlagManager(buildPath(Config.resourcesLocation, "flags")).load();
        connectedContentBox.packStart(new Separator(GtkOrientation.HORIZONTAL), false, true, 5);
        shoutBox = new ChatBox();
        connectedContentBox.packStart(shoutBox, true, true, 0);

        /**
         * Connecting view
         */
        connectingContentBox = new Box(GtkOrientation.VERTICAL, 0);
        connectingSpinner = new Spinner();
        connectingSpinner.start();
        connectingContentBox.packStart(connectingSpinner, true, false, 0);

        /**
         * Failed connection view
         */
        connectionFailedContentBox = new Box(GtkOrientation.VERTICAL, 0);
        connectionFailedErrorMessage = new Label("");
        connectionFailedErrorMessage.setMaxWidthChars(25);
        connectionFailedErrorMessage.setLineWrap(true);
        connectionFailedContentBox.packStart(connectionFailedErrorMessage, true, false, 0);

        /**
         * Stack to change views
         */
        contentStack = new Stack();
        contentStack.setTransitionType(GtkStackTransitionType.CROSSFADE);
        contentStack.addTitled(connectingContentBox, "connecting", "connecting");
        contentStack.addTitled(connectedContentBox, "connected", "connected");
        contentStack.addTitled(connectionFailedContentBox, "failed", "failed");
        this.packStart(contentStack, true, true, 5);

        this.setSizeRequest(250, 100);
        this.addTickCallback(&onTick);
    }

    void setController(FIBSController fibsController) {
        this.fibsController = fibsController;
        this.shoutBox.setFibsChatSource(&fibsController.shoutBox);
    }

    bool onTick(Widget w, FrameClock f) {
        // Read information from FIBS controller
        if (this.fibsController) {
            import std.conv : to;
            this.connectionStatus.text.setText(
                            fibsController.connectionStatus.status.to!string);
            switch (fibsController.connectionStatus.status) {
                case FIBSConnectionStatus.Connecting:
                    contentStack.setVisibleChild(connectingContentBox);
                    break;
                case FIBSConnectionStatus.Connected:
                    contentStack.setVisibleChild(connectedContentBox);
                    playerListButtonLabel.setText(format!"Players (%d online)"(fibsController.players.length));
                    break;
                case FIBSConnectionStatus.Failed:
                    contentStack.setVisibleChild(connectionFailedContentBox);
                    connectionFailedErrorMessage.setMarkup(
                        format!"<span foreground='red'>%s</span>"(
                            fibsController.connectionStatus.message));
                    break;
                case FIBSConnectionStatus.Crashed:
                    contentStack.setVisibleChild(connectionFailedContentBox);
                    connectionFailedErrorMessage.setMarkup(
                        format!"<span foreground='red'>%s</span>"("Network thread crashed."));
                    contentStack.setVisibleChild(connectionFailedContentBox);
                    break;
                default:
                    import std.stdio;
                    writeln("whoops, have no relevant sidebar view for ",
                        fibsController.connectionStatus.status);
                    break;
            }



        }
        return true;
    }

    mixin AddTickCallback;
}
