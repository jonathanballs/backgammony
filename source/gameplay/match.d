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

    // TODO: Pretty print:
    //  +13-14-15-16-17-18-------19-20-21-22-23-24-+ X: someplayer - score: 0
    //  | O           X    |   |  X              O |
    //  | O           X    |   |  X              O |
    //  | O           X    |   |  X                |
    //  | O                |   |  X                |
    //  | O                |   |  X                |
    // v|                  |BAR|                   |    3-point match
    //  | X                |   |  O                |
    //  | X                |   |  O                |
    //  | X           O    |   |  O                |
    //  | X           O    |   |  O              X |
    //  | X           O    |   |  O              X |
    //  +12-11-10--9--8--7--------6--5--4--3--2--1-+ O: myself - score: 0
    //
    //  BAR: O-0 X-0   OFF: O-0 X-0   Cube: 1  You rolled 6 2.
}
