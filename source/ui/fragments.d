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
     * Create a new text entry with a label
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

    string getText() { return entry.getText(); }
    void setText(string s) { entry.setText(s); }
}

/**
 * A right aligned label with a left aligned label.
 */
class LabeledLabel : Box {
    Label label;
    Label text;

    /**
     * Create a new text entry with a label
     */
    this(string label, string text) {
        super(GtkOrientation.HORIZONTAL, 0);

        this.label = new Label(label);
        this.text = new Label(text);
        this.text.setAlignment(1.0, 0.5);

        this.packStart(this.label, false, false, 0);
        this.packEnd(this.text, true, true, 0);
    }
}
