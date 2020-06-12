module ui.fibsplayerlistdialog;

import gtk.Dialog;
import gtk.Window;
import networking.fibs.thread;

class FIBSPlayerListDialog : Dialog {
    FIBSController controller;

    this(Window w, FIBSController controller) {
        super();
        this.controller = controller;

        this.setTransientFor(w);
        this.setPosition(GtkWindowPosition.CENTER_ON_PARENT);
        this.setTypeHint(GdkWindowTypeHint.DIALOG);
        this.setModal(true);

        GdkRectangle windowSize;
        w.getAllocation(windowSize);

        this.setSizeRequest(
            cast(int) (windowSize.width * 0.8),
            cast(int) (windowSize.height * 0.8));
        this.setTitle("Player list");

        this.showAll();
    }
}
