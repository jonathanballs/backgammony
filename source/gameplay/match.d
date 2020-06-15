module gameplay.match;

import gameplay.gamestate;
import gameplay.player;

/**
 * A match between two players. Could be multiple games.
 */
struct BackgammonMatch {
    PlayerMeta player1;
    PlayerMeta player2;
    int p1score;
    int p2score;
    int length;
    GameState currentGame;
}
