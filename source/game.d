module game;

struct Board {
    Point[24] points;
    Point[Player] takenPieces; // In the centre
    Point[Player] bearedOffPieces; // Taken off the side

    void newGame() {
        points[23] = Point(Player.PLAYER_1, 2);
        points[12] = Point(Player.PLAYER_1, 5);
        points[7] = Point(Player.PLAYER_1, 3);
        points[5] = Point(Player.PLAYER_1, 5);

        points[0] = Point(Player.PLAYER_2, 2);
        points[11] = Point(Player.PLAYER_2, 5);
        points[16] = Point(Player.PLAYER_2, 3);
        points[18] = Point(Player.PLAYER_2, 5);
    }
}

struct GameState {
    Board board;
    Player currentTurn;
    uint[2] diceRoll;

    uint rollDie() {
        import std.random;
        return uniform(1, 6);
    }

    void newGame() {
        this.board = Board();
        board.newGame();

        diceRoll[0] = rollDie();
        diceRoll[1] = rollDie();
        import std.stdio;
        writeln(diceRoll);
    }
}

enum PipMoveType {
    Movement,
    BearingOff,
    Entering,
}

struct PipMovement {
    PipMoveType moveType;
    uint startPoint;
    uint endPoint;
}

enum Player {
    PLAYER_1,
    PLAYER_2
}

struct Point {
    Player owner;
    uint numPieces;
}
