import gtk.Main;
import ui.window;

void main(string[] args) 
{
    Main.init(args);

    auto window = new BackgammonWindow();
    window.showAll();

    Main.run();
}
