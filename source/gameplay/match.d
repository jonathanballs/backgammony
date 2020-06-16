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
    GameState currentGame;
}
