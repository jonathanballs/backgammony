module game;

class Board {
    Point[24] points;

    this(bool empty = false) {
        if (empty) return;

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

enum GameState {
    DiceRolling,
    ChoosingMove
}

enum Player {
    NONE,
    PLAYER_1,
    PLAYER_2
}

struct Point {
    Player owner;
    uint numPieces;
}
