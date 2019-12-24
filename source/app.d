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
import upnp;

import window;

void main(string[] args) 
{
    serviceDiscovery();
    Main.init(args);

    auto window = new BackgammonWindow();
    window.showAll();

    Main.run();
}
