module ui.fibsplayerlistdialog;

import std.stdio;
import gdk.Event;
import gdk.FrameClock;
import gdk.Pixbuf;
import gio.ThemedIcon;
import gtk.Button;
import gtk.CellRendererText;
import gtk.CellRendererPixbuf;
import gtk.Dialog;
import gtk.HeaderBar;
import gtk.Image;
import gtk.ListStore;
import gtk.Menu;
import gtk.MenuItem;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreeModel;
import gtk.TreeModelFilter;
import gtk.TreeModelSort;
import gtk.TreePath;
import gtk.TreeSelection;
import gtk.TreeView;
import gtk.TreeViewColumn;
import gtk.Widget;
import gtk.Window;
import utils.addtickcallback;

import networking.fibs.thread;

class FIBSPlayerListDialog : Dialog {
    FIBSController controller;

    HeaderBar headerBar;

    TreeView treeView;    
    TreeViewColumn[] columns;
    ListStore listStore;    
    ScrolledWindow scrolledWindow;    
    TreeModelFilter treeModelFilter;    
    TreeModelSort treeModelSort;
    TreeIter[] iters;    

    string filterString;

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
        
        headerBar = new HeaderBar();
        headerBar.setTitle("Player list");
        headerBar.setShowCloseButton(true);
        headerBar.setProperty("spacing", 100);
        this.setTitlebar(headerBar);

        Button refreshButton = new Button();
        auto icon = new ThemedIcon("view-refresh-symbolic");
        auto inetImg = new Image();
        inetImg.setFromGicon(icon, IconSize.BUTTON);
        refreshButton.add(inetImg);
        refreshButton.addOnClicked((Button b) {
            this.fillTree();
        });
        headerBar.packStart(refreshButton);

        this.listStore = new ListStore([
            GType.OBJECT, GType.STRING, GType.INT, GType.STRING]);

        // Filter
        this.treeModelFilter = new TreeModelFilter(listStore, null);
        this.treeModelFilter.setVisibleFunc(&filterTree, &this.filterString, null);
        this.treeModelFilter.refilter();

        // Sorting
        this.treeModelSort = new TreeModelSort(treeModelFilter);
        // this.treeView.getSelection.addOnChanged((TreeSelection s) {
        //     auto selectedIter = this.treeView.getSelectedIter();
        //     if (selectedIter) {
        //         auto selectedPath = treeModelFilter.getPath(selectedIter);
        //         this.treeView.scrollToCell(selectedPath, null, false, 0, 0);
        //     }
        // });

        // Create the tree view
        this.treeView = new TreeView();
        treeView.setModel(treeModelSort);
        this.treeModelSort.setSortColumnId(2, GtkSortType.DESCENDING);
        scrolledWindow = new ScrolledWindow();
        scrolledWindow.setVexpand(true);
        scrolledWindow.add(this.treeView);

        // Create columns
        columns = [
            new TreeViewColumn("", new CellRendererPixbuf(), "pixbuf", 0),
            new TreeViewColumn("Username", new CellRendererText(), "text", 1),
            new TreeViewColumn("Rating", new CellRendererText(), "text", 2),
            new TreeViewColumn("Status", new CellRendererText(), "text", 3),
        ];
        foreach (long i, c; columns) {
            treeView.appendColumn(c);
            if (i > 0) {
                c.setSortColumnId(cast(int) i);
                treeModelSort.setSortFunc(cast(int) i, &sortColumnFunc, cast(void*) i, null);
            }
        }

        /**
         * Display button press
         */
        treeView.addOnButtonPress((Event e, Widget w) {
            if (e.button.button != GDK_BUTTON_SECONDARY) {
                return false;
            }

            // Selection
            TreePath path;
            TreeViewColumn col;
            int cellx, celly;
            if (!treeView.getPathAtPos(cast(int) e.button.x, cast(int) e.button.y, path, col, cellx, celly)) {
                return false;
            }
            auto selection = treeView.getSelection();
            selection.selectPath(path);

            TreeIter iter = new TreeIter();
            if (!treeView.getModel().getIter(iter, path)) {
                return false;
            }

            string username = treeView.getModel().getValue(iter, 1).getString();

            Menu menu = new Menu();

            MenuItem profile = new MenuItem("Profile");
            MenuItem watch = new MenuItem("Watch " ~ username);
            MenuItem invite = new MenuItem("Invite " ~ username);

            menu.append(profile);
            menu.append(watch);
            menu.append(invite);

            menu.showAll();

            menu.popupAtPointer(null);

            return true;
        });

        this.getContentArea().add(scrolledWindow);
        this.showAll();
    }

    /**
     * Clear tree and fill with player data
     */
    void fillTree() {
        import ui.flagmanager;
        auto flagManager = new FlagManager();

        // Create the list store
        listStore.clear();
        foreach(player; controller.players) {
            this.iters ~= listStore.createIter();
            auto c = player.country();
            if (c in flagManager.flags) {
                listStore.setValue(iters[$-1], 0, flagManager.flags[c]);
            } else {
                listStore.setValue(iters[$-1], 0, flagManager.flags["_unknown"]);
            }
            listStore.setValue(iters[$-1], 1, player.name);
            listStore.setValue(iters[$-1], 2, cast(int) player.rating);
            listStore.setValue(iters[$-1], 3, player.status);
        }
    }

    /**
     * Function for filtering the list
     */
    public static extern(C) int filterTree(GtkTreeModel* m, GtkTreeIter* i, void* data) {
        return true;
        // TreeModel model = new TreeModel(m);
        // TreeIter  iter  = new TreeIter(i);
        // string name = model.getValue(iter, 0).getString();
        // import std.algorithm : canFind;
        // return name.canFind(*cast(string*) data);
    }

    /**
     * Function for sorting the list
     */
    public static extern(C) int sortColumnFunc(GtkTreeModel* m, GtkTreeIter* a, GtkTreeIter* b, void* data) {
        TreeModel model = new TreeModel(m);
        TreeIter  itera  = new TreeIter(a);
        TreeIter  iterb  = new TreeIter(b);
        import gobject.Value;

        Value av = model.getValue(itera, cast(int) data);
        Value bv = model.getValue(iterb, cast(int) data);

        if (av.gType == GType.STRING) {
            string as = av.getString();
            string bs = bv.getString();
            if (as == bs) return 0;
            return (as < bs) ? -1 : 1;
        } else if (av.gType == GType.INT) {
            int ai = av.getInt();
            int bi = bv.getInt();
            if (ai == bi) return 0;
            return (ai < bi) ? -1 : 1;
        }
        return 0;
    }
}
