module window;

import gdk.FrameClock;
import gio.ThemedIcon;
import gtk.Box;
import gtk.Button;
import gtk.Container;
import gtk.HeaderBar;
import gtk.IconTheme;
import gtk.Image;
import gtk.Label;
import gtk.Main;
import gtk.MainWindow;
import gtk.Widget;

import boardWidget;
import networking;
import upnp;

class BackgammonWindow : MainWindow {
    HeaderBar header;
    Button newGameBtn;
    Button inetGameBtn;

    BackgammonBoard backgammonBoard;
    NetworkingThread netThread;

    this() {
        super("Backgammon");

        header = new HeaderBar();
        header.setTitle("Backgammon");
        header.setSubtitle("White to play");
        header.setShowCloseButton(true);
        this.setTitlebar(header);

        newGameBtn = new Button("New Game");
        header.packStart(newGameBtn);

        // Internet game
        auto inetGameBtn = new Button();
        auto icon = new ThemedIcon("network-server-symbolic");
        auto inetImg = new Image();
        inetImg.setFromGicon(icon, IconSize.BUTTON);
        inetGameBtn.add(inetImg);
        inetGameBtn.addOnClicked((Button b) {
            import networkWidget;
            auto w = new NetworkWidget(this);
            netThread = new NetworkingThread();
            netThread.start();
        });
        header.packStart(inetGameBtn);

        // Game board
        auto backgammonBoard = new BackgammonBoard();
        auto box   = new Box(GtkOrientation.HORIZONTAL, 0);
        box.setHalign(GtkAlign.FILL);
        box.setValign(GtkAlign.FILL);
        box.setHexpand(true);
        box.setVexpand(true);
        // box.add(board);

        this.add(backgammonBoard);
        this.setDefaultSize(800, 600);
    }

    override void addTickCallback(bool delegate(Widget, FrameClock) callback)
    {
        tickCallbackListeners ~= callback;
        static bool connected;

        if ( connected )
        {
            return;
        }

        super.addTickCallback(cast(GtkTickCallback)&tickCallback, cast(void*)this, null);
        connected = true;
    }

    extern(C) static int tickCallback(GtkWidget* widgetStruct, GdkFrameClock* frameClock, Widget _widget)
    {
        import std.algorithm.iteration : filter;
        import std.array : array;
        _widget.tickCallbackListeners = _widget.tickCallbackListeners.filter!((dlg) {
            return dlg(_widget, new FrameClock(frameClock));
        }).array();
        return !!_widget.tickCallbackListeners.length;
    }
}
