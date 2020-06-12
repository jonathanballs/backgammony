module ui.fibssidebar;

import gtk.Box;
import gtk.Label;
import gtk.CssProvider;
import gtk.StyleContext;

class FibsSidebar : Box {
    Label fibsTitle;

    this() {
        super(GtkOrientation.VERTICAL, 10);
        fibsTitle = new Label("FIBS");
        this.packStart(fibsTitle, false, false, 10);

        StyleContext styleContext = this.getStyleContext();      
        CssProvider cssProvider = new CssProvider();         
        cssProvider.loadFromData("box {"      
            ~ "border-left-width: 1px;"      
            ~ "border-left-style: solid;"      
            ~ "border-color: #1b1b1b;"      
            ~ "background-color: @theme_bg_color }");
        styleContext.addProvider(cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);    

        this.setSizeRequest(250, 100);
    }
}
