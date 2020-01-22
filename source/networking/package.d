module networking;

import core.time;
import std.algorithm : startsWith;
import std.socket;
import std.stdio;
import std.concurrency;
import std.format;
import std.random;
import std.conv;
import std.string;
import std.digest.sha;

import player;
import game;
import networking.messages;
import networking.connection;

private enum serverHost = "backgammon.jnthn.uk";
private enum serverPort = 420_69;

// Networking is a core part of backgammon. This module provides an implementation
// of the Secure Backgammon Protocol and provides the backbone of all networking
// (p2p, client/server etc).

// TODO list
// - Exit when window closes - Notifying opponent.
// - Basically entire game logic
// - Validate that strings are valid UTF-8
// - Reconnection.
// - Could this be cleaner with fibers?

// Handles gamestate for a dice roll
// Document and clean this up please!
class DiceRoll {
    bool goFirst;
    bool done;
    Connection conn;
    ulong mySeed;
    string oppSeed;
    string oppSeedHash;

    this(Connection conn, bool goFirst) {
        this.conn = conn;
        this.goFirst = goFirst;

        mySeed = uniform!ulong();
        
        if (goFirst) {
            conn.writeline("STARTTURN: DICEROLL");
            conn.writeline("SEEDHASH: " ~ networkHash(mySeed.to!string));
        }
    }

    void setOppSeedHash(string opHash) {
        if (opHash.length != 20) {
            throw new Exception("Invalid dice hash");
        }

        if (oppSeedHash.length) {
            throw new Exception("Already have oppSeedHash");
        }

        this.oppSeedHash = opHash;

        if (goFirst) {
            // Now send real seed
            conn.writeline("SEED: " ~ mySeed.to!string);
        } else {
            // Now send my seed hash
            conn.writeline("SEEDHASH: " ~ networkHash(mySeed.to!string));
        }
    }

    void setOppSeed(string opSeed) {
        this.oppSeed = opSeed;
        if (!goFirst) {
            conn.writeline("SEED: " ~ mySeed.to!string);
        }
        done = true;
    }

    uint[2] calculateDiceValues() {
        ulong oppSeedNum = oppSeed.to!ulong;
        ulong rSeed = mySeed ^ oppSeedNum;
        auto rng = Mt19937_64(rSeed);

        auto die1 = uniform(1, 6, rng);
        auto die2 = uniform(1, 6, rng);
        return [die1, die2];
    }

    private string networkHash(string s) {
        return sha1Of(s).toHexString().dup[0..20];
    }
}

enum NetworkState {
    AwaitingConnection,
    Reconnecting,
    Connected
}

/**
 * The network thread acts like a giant state machine
 */
class NetworkingThread {
    private:
    PlayerMeta player;
    NetworkState state;
    Connection conn; // Connection with the other computer
    bool shouldClose;
    DiceRoll newDiceRoll;

    /**
     * Store a copy of the gamestate. TODO: Need a way to hash this to compare
     * with opponents copy and client copy.
     */
    GameState gs;

    /**
    * Create a new connection. Will attempt to 
    */
    public this(PlayerMeta player) {
        this.player = player;
    }

    public void run() {
        try {
            this.state = NetworkState.AwaitingConnection;
            conn = new Connection(getAddress(serverHost, serverPort)[0]);
            conn.writeline("RequestGame " ~ player.name);
            while(true) {
                /**
                 * Receive messages from the user. E.g. dice rolls
                 */
                try {
                    receiveTimeout(25.msecs,
                        (NetworkThreadShutdown msg) {
                            shouldClose = true;
                        },
                        (NetworkThreadNewMove nm) {
                            writeln("received new move");
                            writeln(nm.toString);
                            try {
                                // gs.applyTurn(nm.moves[])
                                conn.writeline(nm.toString());
                            } catch (Exception e) {
                                writeln(e);
                                shouldClose = true;
                            }
                        }
                    );
                } catch (OwnerTerminated e) {
                    shouldClose = true;
                }

                if (shouldClose) {
                    writeln("Closing network thread");
                    conn.close();
                    return;
                }

                try {
                    auto line = conn.readline(25.msecs);
                    auto kvSplit = line.indexOf(":");
                    if (kvSplit == -1) {
                        writeln("ERROR: Received bad network command: " ~ line);
                        continue;
                    }
                    string key = line[0..line.indexOf(":")];
                    string value = line[line.indexOf(":")+1..$].strip();

                    switch (key) {
                    case "INFO":
                        writeln("Received info: " ~ line);
                        break;
                    case "MATCHED":
                        if (value.strip.toLower == "server") {
                            send(ownerTid, NetworkBeginGame(Player.P1));
                            this.newDiceRoll = new DiceRoll(this.conn, true);
                            gs = new GameState(this.player, PlayerMeta(
                                "network",
                                "network",
                                PlayerType.Network));
                        } else if (value.strip.toLower == "client") {
                            send(ownerTid, NetworkBeginGame(Player.P2));
                            this.newDiceRoll = new DiceRoll(this.conn, false);
                            gs = new GameState(this.player, PlayerMeta(
                                "network",
                                "network",
                                PlayerType.Network));
                        } else {
                            throw new Exception("Invalid MATCHED TYPE: ", line);
                        }
                        break;
                    case "SEED":
                        this.newDiceRoll.setOppSeed(value);
                        break;
                    case "SEEDHASH":
                        this.newDiceRoll.setOppSeedHash(value);
                        break;
                    default:
                        writeln("ERROR unexpected line: ", line);
                        break;
                    }

                    if (this.newDiceRoll && this.newDiceRoll.done) {
                        // We have the dice roll.
                        auto diceResult = newDiceRoll.calculateDiceValues();
                        gs.rollDice(diceResult[0], diceResult[1]);
                        send(ownerTid, NetworkNewDiceRoll(diceResult[0], diceResult[1]));
                        this.newDiceRoll = null;
                    }
                } catch (TimeoutException e) {
                }
            }
        } catch (Exception e) {
            writeln(e);
            send(ownerTid, NetworkThreadUnhandledException(e.msg, e.info.to!string));
        }
    }
}
