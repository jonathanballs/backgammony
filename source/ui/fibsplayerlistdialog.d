module ui.fibsplayerlistdialog;

import std.stdio;
import gdk.FrameClock;
import gio.ThemedIcon;
import gtk.Button;
import gtk.CellRendererText;
import gtk.Dialog;
import gtk.HeaderBar;
import gtk.Image;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.TreeIter;
import gtk.TreeModelFilter;
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
            GType.STRING, GType.STRING, GType.INT,
            GType.STRING, GType.STRING]);

        // Filter
        this.treeModelFilter = new TreeModelFilter(listStore, null);
        this.treeModelFilter.setVisibleFunc(&filterTree, &this.filterString, null);
        this.treeModelFilter.refilter();

        // Create the tree view
        this.treeView = new TreeView();
        treeView.setModel(treeModelFilter);
        this.treeView.getSelection.addOnChanged((TreeSelection s) {
            auto selectedIter = this.treeView.getSelectedIter();
            if (selectedIter) {
                auto selectedPath = treeModelFilter.getPath(selectedIter);
                this.treeView.scrollToCell(selectedPath, null, false, 0, 0);
            }
        });

        columns = [
            new TreeViewColumn("Username", new CellRendererText(), "text", 0),
            new TreeViewColumn("Status", new CellRendererText(), "text", 1),
            new TreeViewColumn("Rating", new CellRendererText(), "text", 2),
            new TreeViewColumn("Experience", new CellRendererText(), "text", 3),
            new TreeViewColumn("Idle", new CellRendererText(), "text", 4)
        ];

        foreach (c; columns) {
            treeView.appendColumn(c);
        }

        scrolledWindow = new ScrolledWindow();
        scrolledWindow.setVexpand(true);
        scrolledWindow.add(this.treeView);

        // Selection
        auto selection = treeView.getSelection();
        selection.selectPath(new TreePath(true));

        this.getContentArea().add(scrolledWindow);
        this.showAll();
    }

    /**
     * Update tree
     */
    void fillTree() {
        // Create the list store
        listStore.clear();
        foreach(player; controller.players) {
            this.iters ~= listStore.createIter();
            listStore.setValue(iters[$-1], 0, player.name);
            listStore.setValue(iters[$-1], 1, player.status);
            listStore.setValue(iters[$-1], 2, cast(int) player.rating);
            listStore.setValue(iters[$-1], 3, player.experience);
            listStore.setValue(iters[$-1], 4, player.idle);
        }
    }

    public static extern(C) int filterTree(GtkTreeModel* m, GtkTreeIter* i, void* data) {
        return true;
        // TreeModel model = new TreeModel(m);
        // TreeIter  iter  = new TreeIter(i);
        // string name = model.getValue(iter, 0).getString();
        // import std.algorithm : canFind;
        // return name.canFind(*cast(string*) data);
    }
}
