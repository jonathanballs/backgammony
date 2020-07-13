module gameplay.match;

import gameplay.gamestate;
import gameplay.player;

/**
 * A match between two players.
 */
class BackgammonMatch {
    PlayerMeta player1;
    PlayerMeta player2;
    int p1score;
    int p2score;
    int length;
    GameState gs;

    /**
     * Create a new 1-point match between two human players.
     */
    this() {
        player1 = PlayerMeta("Player 1", "p1", PlayerType.User);
        player2 = PlayerMeta("Player 2", "p2", PlayerType.User);
        length = 1;
        gs = new GameState();
    }

    /**
     * Create a new match between two players of a certain length (default 1).
     * Params:
     *      p1 = PlayerMeta of player 1
     *      p2 = PlayerMeta of player 2
     *      length = The length of the game. Default is a 1 point match.
     */
    this(PlayerMeta p1, PlayerMeta p2, int length = 1) {
        this.player1 = p1;
        this.player2 = p2;
        this.length = length;
        gs = new GameState();
    }

    /**
     * Return the PlayerMeta of the player who's turn it is or an empty PlayerMeta
     * if it's nobody's turn.
     */
    PlayerMeta currentTurn() {
        switch (gs._currentPlayer) {
            case Player.P1:
                return player1;
            case Player.P2:
                return player2;
            default:
                return PlayerMeta();
        }
    }

    /**
     * Return the PlayerMeta of the player who's turn it is or an empty PlayerMeta
     * if it's nobody's turn.
     */
    PlayerMeta oppositeTurn() {
        switch (gs._currentPlayer) {
            case Player.P1:
                return player2;
            case Player.P2:
                return player1;
            default:
                return PlayerMeta();
        }
    }

    /**
     * Pretty print the current match state to the console.
     */
    void prettyPrint() {
        import std.stdio : writeln;
        import std.format : format;
        import std.string;
        import std.conv;

        string[] board = [
            format!"     +13-14-15-16-17-18-------19-20-21-22-23-24-+ X: %s - score: %d"(player2.name, p2score),
                   "     |                  |   |                   |",
                   "     |                  |   |                   |",
                   "     |                  |   |                   |",
                   "     |                  |   |                   |",
                   "     |                  |   |                   |",
            format!"    v|                  |BAR|                   |    %d-point match"(this.length),
                   "     |                  |   |                   |",
                   "     |                  |   |                   |",
                   "     |                  |   |                   |",
                   "     |                  |   |                   |",
                   "     |                  |   |                   |",
            format!"     +12-11-10--9--8--7--------6--5--4--3--2--1-+ O: %s - score: %d"(player1.name, p1score),
                   "",
            format!"     BAR: O-%d X-%d   OFF: O-%d X-%d   Cube: %d  %s rolled %d %d"(
                gs.takenPieces[Player.P1], gs.takenPieces[Player.P2],
                gs.borneOffPieces[Player.P1], gs.borneOffPieces[Player.P2],
                1, // TODO: Cube value
                gs.currentPlayer == Player.P2 ? player2.name : player1.name,
                gs.diceValues[0], gs.diceValues[1])
                ];

        // Fill in the piece values
        foreach (int p; 1..25) {
            string key = format!"%d-"(p);
            if (key.length < 3) key = '-' ~ key;

            int pointRow = p >= 13 ? 0 : 12;
            int pointCol = cast(int) board[pointRow].indexOf(key) + 1;
            int movDir = p >= 13 ? +1 : -1;

            Point point = gs.points[p];
            foreach (i; 1..point.numPieces + 1) {
                auto l = board[pointRow + movDir*i].dup;
                l[pointCol] = point.owner == Player.P1 ? 'O' : 'X';
                board[pointRow + movDir*i] = l.to!string;
            }
        }

        foreach (l; board) writeln(l);
    }

    /**
     * Is this a network game?
     */
    bool isNetworkGame() {
        return player1.type == PlayerType.Network
            || player2.type == PlayerType.Network
            || player1.type == PlayerType.FIBS
            || player2.type == PlayerType.FIBS;
    }
}
