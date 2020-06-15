module gameplay.match;

import gameplay.gamestate;
import gameplay.player;

/**
 * A match between two players. Could be multiple games.
 */
struct BackgammonMatch {
    PlayerMeta player1;
    PlayerMeta player2;

    // The length of the match in points
    int length;

    // The scores of the players
    int[Player] score;
}
