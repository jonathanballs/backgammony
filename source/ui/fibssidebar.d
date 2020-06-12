module ui.fibssidebar;

import gtk.Box;
import gtk.Button;
import gtk.CssProvider;
import gtk.Label;
import gtk.Separator;
import gtk.StyleContext;
import gtk.Statusbar;
import ui.fragments;
import ui.chatbox;

import networking.fibs.thread;

enum defaultPadding = 10;

class FIBSSidebar : Box {
    FIBSController fibsController;

    Label fibsTitle;
    LabeledLabel username;
    LabeledLabel connectionStatus;

    Button playerListButton;
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

        playerListButton = new Button("Players (27 online)");
        this.packStart(playerListButton, false, true, 0);

        this.packStart(new Separator(GtkOrientation.HORIZONTAL), false, true, 5);

        shoutBox = new ChatBox();
        this.packStart(shoutBox, true, true, 0);

        this.setSizeRequest(250, 100);
    }

    void setController(FIBSController fibsController) {
        this.fibsController = fibsController;
    }
}
