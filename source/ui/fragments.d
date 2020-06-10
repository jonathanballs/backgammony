module ui.fragments;

import gtk.Box;
import gtk.Button;
import gtk.ComboBoxText;
import gtk.Dialog;
import gtk.Entry;
import gtk.Frame;
import gtk.Label;
import gtk.ListStore;
import gtk.Notebook;
import gtk.Widget;

enum formPadding = 10;

/**
 * A text entry with a label
 */
class LabeledEntry : Box {
    Label label;
    Entry entry;

    /**
     * Create a new Human Selector
     */
    this(string labelText, string defaultValue) {
        super(GtkOrientation.VERTICAL, 0);

        label = new Label(labelText.length ? labelText ~ ":" : "");
        entry = new Entry(defaultValue);
        Box box = new Box(GtkOrientation.HORIZONTAL, formPadding);
        box.packStart(label, false, false, 0);
        box.packStart(entry, true, true, 0);
        this.packStart(box, false, false, 0);
    }
}
