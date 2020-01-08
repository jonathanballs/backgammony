import gtk.Main;
import window;

void main(string[] args) 
{
    Main.init(args);

    auto window = new BackgammonWindow();
    window.showAll();

    Main.run();
}
