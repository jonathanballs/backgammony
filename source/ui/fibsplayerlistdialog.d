module ui.fibsplayerlistdialog;

import gtk.Dialog;
import gtk.Window;
import gtk.TreeView;
import gtk.ListStore;
import gtk.ScrolledWindow;
import gtk.TreeModelFilter;
import gtk.TreeIter;
import gtk.TreeSelection;
import gtk.TreeViewColumn;
import gtk.TreePath;
import gtk.CellRendererText;
import gtk.Widget;
import gdk.FrameClock;
import utils.addtickcallback;

import networking.fibs.thread;

class FIBSPlayerListDialog : Dialog {
    FIBSController controller;

    TreeView treeView;    
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
        this.setTitle("Player list");

        GdkRectangle windowSize;
        w.getAllocation(windowSize);
        this.setSizeRequest(
            cast(int) (windowSize.width * 0.8),
            cast(int) (windowSize.height * 0.8));
        


        this.listStore = new ListStore([GType.STRING]);

        // Filter
        this.treeModelFilter = new TreeModelFilter(listStore, null);
        this.treeModelFilter.setVisibleFunc(&filterTree, &this.filterString, null);
        this.treeModelFilter.refilter();

        // Create the tree view
        this.treeView = new TreeView();
        treeView.setModel(treeModelFilter);
        treeView.setHeadersVisible(false);
        this.treeView.getSelection.addOnChanged((TreeSelection s) {
            auto selectedIter = this.treeView.getSelectedIter();
            if (selectedIter) {
                auto selectedPath = treeModelFilter.getPath(selectedIter);
                this.treeView.scrollToCell(selectedPath, null, false, 0, 0);
            }
        });

        auto column = new TreeViewColumn(
            "Pod Name", new CellRendererText(), "text", 0);
        treeView.appendColumn(column);
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
