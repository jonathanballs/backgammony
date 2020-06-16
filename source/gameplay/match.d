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
     * Create a new match
     */
    this() {
        player1 = PlayerMeta("Player 1", "p1", PlayerType.User);
        player2 = PlayerMeta("Player 2", "p2", PlayerType.User);
        length = 1;
        gs = new GameState();
    }
}
