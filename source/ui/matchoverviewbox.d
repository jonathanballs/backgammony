module ui.matchoverviewbox;

import gtk.Box;
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

    public this() {
        super(GtkOrientation.VERTICAL, 0);
        this.add(new Label("MATCH INFORMATION"));
        this.setSizeRequest(300, 50);

        StyleContext styleContext = this.getStyleContext();      
        CssProvider cssProvider = new CssProvider();         
        cssProvider.loadFromData("box {"      
            ~ "padding: 10px;"
            ~ "border-bottom-width: 1px;"      
            ~ "border-bottom-style: solid;"      
            ~ "border-color: #1b1b1b;"      
            ~ "background-color: @theme_bg_color }");
        styleContext.addProvider(cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);    
    }

    public void setMatch(BackgammonMatch m) {
        this.match = m;
    }
}
