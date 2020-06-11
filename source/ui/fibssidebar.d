module ui.fibssidebar;

import gtk.Box;
import gtk.Label;
import gtk.CssProvider;
import gtk.StyleContext;

class FibsSidebar : Box {
    this() {
        super(GtkOrientation.VERTICAL, 0);
        this.add(new Label("FIBS!!!!"));

        StyleContext styleContext = this.getStyleContext();      
        CssProvider cssProvider = new CssProvider();         
        cssProvider.loadFromData("box {"      
            ~ "border-left-width: 2px;"      
            ~ "border-left-style: solid;"      
            ~ "border-color: #000000;"      
            ~ "background-color: @theme_bg_color }");      
        styleContext.addProvider(cssProvider, STYLE_PROVIDER_PRIORITY_APPLICATION);    

        this.setSizeRequest(250, 100);
    }
}
