module networking.messages;

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
}

struct NetworkNewDiceRoll {
    uint dice1;
    uint dice2;
}
