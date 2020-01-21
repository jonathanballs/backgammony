module networking.messages;
import game : Player;

struct NetworkThreadShutdown {
}

struct NetworkThreadStatus {
    string message;
}

struct NetworkThreadError {
    string message;
}

struct NetworkBeginGame {
    // Information about the game. Perhaps game layout idk
    Player clientPlayer;
}

struct NetworkNewDiceRoll {
    uint dice1;
    uint dice2;
}
