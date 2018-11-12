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

import boardWidget;

void main(string[] args) 
{
    Main.init(args);

    auto window = new MainWindow("Window Demo");
    window.setDefaultSize(800, 600);

    // Header
    auto header = new HeaderBar();
    header.setTitle("Backgammon");
    header.setSubtitle("White to play");
    header.setShowCloseButton(true);
    window.setTitlebar(header);

    // New game
    auto newGameBtn = new Button("New Game");
    header.packStart(newGameBtn);

    // Internet game
    auto inetGameBtn = new Button();
    auto icon = new ThemedIcon("network-server-symbolic");
    auto inetImg = new Image();
    inetImg.setFromGicon(icon, IconSize.BUTTON);
    inetGameBtn.add(inetImg);
    header.packStart(inetGameBtn);

    // Game board
    // 
    auto board = new BackgammonBoard();
    auto label = new Label("hello world");
    auto box   = new Box(GtkOrientation.HORIZONTAL, 0);
    box.setHalign(GtkAlign.CENTER);
    box.setValign(GtkAlign.CENTER);
    box.add(board);


    window.add(box);

    window.showAll();
    Main.run();
}

