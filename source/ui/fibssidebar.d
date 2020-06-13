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
import ui.fragments;
import ui.chatbox;
import ui.fibsplayerlistdialog;
import ui.flagmanager;
import utils.addtickcallback;
import config;

import networking.fibs.thread;

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
        connectionStatus = new LabeledLabel("Status", "Ready");
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

        contentStack = new Stack();
        contentStack.setTransitionType(GtkStackTransitionType.CROSSFADE);
        contentStack.addTitled(connectingContentBox, "connecting", "connecting");
        contentStack.addTitled(connectedContentBox, "connected", "connected");
        this.packStart(contentStack, true, true, 5);

        this.setSizeRequest(250, 100);
        this.addTickCallback(&onTick);
    }

    void setController(FIBSController fibsController) {
        this.fibsController = fibsController;
    }

    bool onTick(Widget w, FrameClock f) {
        // Read information from FIBS controller
        if (this.fibsController) {
            switch (fibsController.connectionStatus.status) {
                case FIBSConnectionStatus.Connecting:
                    contentStack.setVisibleChild(connectingContentBox);
                    break;
                case FIBSConnectionStatus.Connected:
                    contentStack.setVisibleChild(connectedContentBox);
                    import std.conv : to;
                    this.connectionStatus.text.setText(
                                    fibsController.connectionStatus.status.to!string);
                    playerListButtonLabel.setText(format!"Players (%d online)"(fibsController.players.length));
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
