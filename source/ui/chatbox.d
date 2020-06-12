module ui.chatbox;

import gtk.Box;
import gtk.Entry;
import gtk.TextBuffer;
import gtk.TextTagTable;
import gtk.TextView;

class ChatBox : Box {
    TextTagTable textTagTable;
    TextBuffer textBuffer;
    TextView textView;
    Entry messageEntry;

    this() {
        super(GtkOrientation.VERTICAL, 5);

        textTagTable = new TextTagTable();
        textBuffer = new TextBuffer(textTagTable);
        textView = new TextView(textBuffer);
        textView.setEditable(false);
        this.packStart(textView, true, true, 0);

        messageEntry = new Entry();
        this.packStart(messageEntry, false, false, 0);
    }
}
