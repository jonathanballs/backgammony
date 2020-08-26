module ui.chatbox;

import gdk.FrameClock;
import gtk.Box;
import gtk.Entry;
import gtk.TextBuffer;
import gtk.TextTagTable;
import gtk.TextView;
import gtk.Widget;

import utils.addtickcallback;
import networking.fibs.controller : FIBSMessage;

class ChatBox : Box {
    TextTagTable textTagTable;
    TextBuffer textBuffer;
    TextView textView;
    Entry messageEntry;

    ulong numMessagesInView;
    FIBSMessage[]* messageSource;

    this() {
        super(GtkOrientation.VERTICAL, 5);

        textTagTable = new TextTagTable();
        textBuffer = new TextBuffer(textTagTable);
        textView = new TextView(textBuffer);
        textView.setEditable(false);
        textView.setWrapMode(GtkWrapMode.WORD);
        this.packStart(textView, true, true, 0);

        messageEntry = new Entry();
        this.packStart(messageEntry, false, false, 0);

        this.addTickCallback(&tickCallback);
    }


    void setFibsChatSource(FIBSMessage[]* messages) {
        this.messageSource = messages;
        this.numMessagesInView = 0;
    }

    bool tickCallback(Widget w, FrameClock f) {
        if (messageSource && numMessagesInView < messageSource.length) {
            foreach (m; (*messageSource)[numMessagesInView..messageSource.length]) {
                this.textView.appendText(m.from ~ ": " ~ m.message ~ "\n");
            }
            numMessagesInView = messageSource.length;
        }
        return true;
    }

    public mixin AddTickCallback;
}
