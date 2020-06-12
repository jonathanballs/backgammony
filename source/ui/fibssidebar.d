module ui.fibssidebar;

import std.format;
import gdk.FrameClock;
import gtk.Box;
import gtk.Button;
import gtk.CssProvider;
import gtk.Label;
import gtk.Separator;
import gtk.StyleContext;
import gtk.Statusbar;
import gtk.Widget;
import gtk.Window;
import ui.fragments;
import ui.chatbox;
import ui.fibsplayerlistdialog;
import utils.addtickcallback;

import networking.fibs.thread;

enum defaultPadding = 10;

class FIBSSidebar : Box {
    FIBSController fibsController;

    Label fibsTitle;
    LabeledLabel username;
    LabeledLabel connectionStatus;

    Button playerListButton;
    Label playerListButtonLabel;
    FIBSPlayerListDialog fibsPlayerListDialog;
    ChatBox shoutBox;
    Statusbar statusBar;

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

        fibsTitle = new Label("");
        fibsTitle.setMarkup("<b>FIBS</b>");
        this.packStart(fibsTitle, false, false, 10);

        username = new LabeledLabel("Username", "jonathanballs");
        this.packStart(username, false, true, 0);

        connectionStatus = new LabeledLabel("Status", "Ready");
        this.packStart(connectionStatus, false, true, 0);

        playerListButton = new Button();
        playerListButtonLabel = new Label("Players (0 online)");
        playerListButton.add(playerListButtonLabel);
        playerListButton.addOnClicked((Button b) {
            Window mainWindow = new Window(cast(GtkWindow *) this.getToplevel.getStruct());
            fibsPlayerListDialog = new FIBSPlayerListDialog(
                mainWindow, fibsController);
        });
        this.packStart(playerListButton, false, true, 0);

        this.packStart(new Separator(GtkOrientation.HORIZONTAL), false, true, 5);

        shoutBox = new ChatBox();
        this.packStart(shoutBox, true, true, 0);

        this.setSizeRequest(250, 100);
        this.addTickCallback(&onTick);
    }

    void setController(FIBSController fibsController) {
        this.fibsController = fibsController;
    }

    bool onTick(Widget w, FrameClock f) {
        // Read information from FIBS controller
        if (this.fibsController) {
            import std.conv : to;
            this.connectionStatus.text.setText(
                            fibsController.connectionStatus.status.to!string);
            playerListButtonLabel.setText(format!"Players (%d online)"(fibsController.players.length));

            if (this.fibsPlayerListDialog && this.fibsController.players.length) {
                this.fibsPlayerListDialog.fillTree();
            }
        }
        return true;
    }

    mixin AddTickCallback;
}
