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

private enum NetworkState {
    AwaitingConnection,
    AwaitingMove,
    AwaitingDiceSeedHash,
    AwaitingDiceSeedValue,
    AwaitingDiceConfirmation,
    AwaitingUserMove,
}

/**
 * The network thread acts like a giant state machine
 */
class NetworkingThread {
    private:
    Tid parentTid;
    PlayerMeta player;
    NetworkState state;
    Connection conn; // Connection with the other computer
    bool shouldClose;

    /**
    * Create a new connection. Will attempt to 
    */
    public this(PlayerMeta player) {
        this.player = player;
        this.parentTid = thisTid();
    }

    public void run() {
        try {
            this.state = NetworkState.AwaitingConnection;
            conn = new Connection(getAddress(serverHost, serverPort)[0]);
            conn.writeline("RequestGame " ~ player.name);
            while(true) {
                /**
                 * Receive messages from the user
                 */
                receive(
                    (NetworkThreadShutdown msg) {
                        shouldClose = true;
                    }
                );

                if (shouldClose) {
                    writeln("Closing network thread");
                    conn.close();
                    return;
                }
                auto line = conn.readline(25.msecs);
                auto kvSplit = line.indexOf(":");
                if (kvSplit == -1) {
                    writeln("ERROR: Received bad network command: " ~ line);
                    continue;
                }
                if (line.startsWith("INFO: ")) {
                    writeln("Received info: " ~ line);
                }
            }
        } catch (Exception e) {
            writeln(e);
        }
    }

    string networkHash(string s) {
        return sha1Of(s).toHexString().dup[0..20];
    }

    // It is assumed that the headers have been swapped
    void beginBackgammonGame(bool isHost) {
        writeln("Beginning Game " ~ (isHost ? "as host" : "as client"));
        // The client performs the first move
        send(parentTid, NetworkBeginGame());

        // Fuck it, generate a dice roll
        performDiceRoll(isHost);
    }

    uint[] performDiceRoll(bool goFirst) {
        ulong mySeed = uniform!ulong();
        string oppSeedHash;
        string oppSeed;

        if (goFirst) {
            conn.writeline("DICEROLL");

            conn.writeline(networkHash(mySeed.to!string));
            oppSeedHash = conn.readline();
            conn.writeline(mySeed.to!string);
            oppSeed = conn.readline();
        } else {
            conn.readline(); // Reads diceroll

            oppSeedHash = conn.readline();
            conn.writeline(networkHash(mySeed.to!string));
            oppSeed = conn.readline();
            conn.writeline(mySeed.to!string);
        }

        // Validate the seeds
        if (networkHash(oppSeed) != oppSeedHash) {
            writeln("INVALID: HASH DOES NOT MATCH SEED!!!");
            throw new Exception("Invalid seed hash received in dice roll");
        }

        // Calculate dice roll
        ulong oppSeedNum = oppSeed.to!ulong;
        ulong rSeed = mySeed ^ oppSeedNum;
        auto rng = Mt19937_64(rSeed);

        auto die1 = uniform(1, 6, rng);
        auto die2 = uniform(1, 6, rng);

        send(parentTid, NetworkNewDiceRoll(die1, die2));

        writeln([die1, die2]);
        conn.readline();
        return [die1, die2];
    }
}
