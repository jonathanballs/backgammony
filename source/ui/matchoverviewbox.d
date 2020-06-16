module ui.matchoverviewbox;

import gtk.Box;
import gtk.Fixed;
import gtk.Label;
import gtk.StyleContext;
import gtk.CssProvider;

import gameplay.match;
import gameplay.player;


/**
 * Display an overview of the current match - typically in the main window above
 * the board.
 */
class MatchOverviewBox : Box {
    private:
    BackgammonMatch match;

    // Scorebox
    Box scoreBox;
    Label p1Score;
    Label p2Score;
    Label scoreBoxDash;

    Box p1Info;
    Label p1Name;

    Box p2Info;
    Label p2Name;

    public this() {
        super(GtkOrientation.HORIZONTAL, 0);
        this.setSizeRequest(300, 50);

        // Styling
        StyleContext styleContext = this.getStyleContext();      
        CssProvider cssProvider = new CssProvider();         
        cssProvider.loadFromData("box {"      
            ~ "padding: 10px;"
            ~ "border-bottom-width: 1px;"      
            ~ "border-bottom-style: solid;"      
            ~ "border-color: @borders;"      
            ~ "background-color: alpha(@borders , 0.55); }");
        styleContext.addProvider(cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);    

        // Score box
        p1Score = new Label("0");
        p1Score.setWidthChars(2);
        // p1Score.setAlignment(1.0, 0.5);
        p2Score = new Label("0");
        p2Score.setWidthChars(2);
        // p2Score.setAlignment(0.0, 0.5);
        scoreBoxDash = new Label("-");
        scoreBox = new Box(GtkOrientation.HORIZONTAL, 0);
        scoreBox.packStart(p1Score, false, false, 0);
        scoreBox.packStart(scoreBoxDash, false, false, 0);
        scoreBox.packStart(p2Score, false, false, 0);
        scoreBox.setHexpand(false);

        p1Info = new Box(GtkOrientation.HORIZONTAL, 0);
        p1Name = new Label("jonathanballs");
        p1Name.setAlignment(1.0, 0.5);
        p1Info.packEnd(p1Name, true, true, 0);
        p1Info.setSizeRequest(200, 0);

        p2Info = new Box(GtkOrientation.HORIZONTAL, 0);
        p2Name = new Label("gnubg_intermediate");
        p2Info.add(p2Name);
        p2Info.setSizeRequest(200, 0);

        this.packStart(p1Info, true, true, 0);
        this.packStart(scoreBox, false, false, 0);
        this.packStart(p2Info, true, true, 0);
    }

    public void setMatch(BackgammonMatch m) {
        this.match = m;
    }
}
