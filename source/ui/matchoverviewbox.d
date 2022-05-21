module ui.matchoverviewbox;

import std.conv : to;
import gdk.FrameClock;
import gtk.Box;
import gtk.CssProvider;
import gtk.Fixed;
import gtk.Label;
import gtk.StyleContext;
import gtk.Widget;
import gtk.Stack;

import gameplay.match;
import gameplay.player;
import utils.addtickcallback;


/**
 * Display an overview of the current match - typically in the main window above
 * the board.
 */
class MatchOverviewBox : Box {
    private:
    BackgammonMatch match;

    Stack displayStack;

    // No match running
    Box noMatchBox;
    Label noMatchLabel;

    // Match info
    Box matchRunningBox;
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
        this.addTickCallback(&onTick);

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
        p1Name = new Label("");
        p1Name.setAlignment(1.0, 0.5);
        p1Info.packEnd(p1Name, true, true, 0);
        p1Info.setSizeRequest(200, 0);

        p2Info = new Box(GtkOrientation.HORIZONTAL, 0);
        p2Name = new Label("");
        p2Info.add(p2Name);
        p2Info.setSizeRequest(200, 0);

        matchRunningBox = new Box(GtkOrientation.HORIZONTAL, 0);
        matchRunningBox.packStart(p1Info, true, true, 0);
        matchRunningBox.packStart(scoreBox, false, false, 0);
        matchRunningBox.packStart(p2Info, true, true, 0);

        noMatchBox = new Box(GtkOrientation.HORIZONTAL, 0);
        noMatchLabel = new Label("No game in progress");
        noMatchLabel.getStyleContext().addClass("dim-label");
        noMatchBox.packStart(noMatchLabel, true, false, 0);

        displayStack = new Stack();
        displayStack.addNamed(matchRunningBox, "matchRunning");
        displayStack.addNamed(noMatchBox, "noMatchRunning");

        this.packStart(displayStack, true, true, 0);
    }

    public void setMatch(BackgammonMatch m) {
        this.match = m;
        displayStack.setTransitionType(GtkStackTransitionType.CROSSFADE);
        displayStack.setVisibleChild(matchRunningBox);
    }

    public bool onTick(Widget w, FrameClock f) {
        if (match) {
            //displayStack.setVisibleChild(matchRunningBox);
            //p1Name.setText(match.player1.name);
            //p2Name.setText(match.player2.name);
            //p1Score.setText(match.p1score.to!string);
            //p2Score.setText(match.p1score.to!string);
        } else {
            displayStack.setVisibleChild(noMatchBox);
        }
        return true;
    }

    public mixin AddTickCallback;
}
