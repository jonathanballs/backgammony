module networking;

import core.thread;
import core.time;
import std.socket;
import std.stdio;
import std.concurrency;
import std.format;
import std.random;
import std.conv;
import std.string;
import std.digest.sha;

import networking.messages;
import networking.connection;

// Networking is a core part of backgammon. This module provides an implementation
// of the Secure Backgammon Protocol and provides the backbone of all networking
// (p2p, client/server etc).

// TODO list
// - Close listening port once connected
// - Close UpNp ports
// - Exit when window closes - Notifying opponent.
// - Use against proper tracker. And update list from API.
// - Basically entire game logic
// - Validate that strings are valid UTF-8
// - Ensure that not connecting to self
// - Reconnection.

// - Game process - use gamestate??
// - Agree who plays first (and thus is p1)

class NetworkingThread : Thread {
    this() {
        this.parentTid = thisTid();
        super(&run);
    }

    private:
    Tid parentTid;

    Connection conn; // Connection with the other computer
    string peer_id; // My peer id

    void run() {
        try {
            send(parentTid, NetworkThreadStatus("Matchmaking..."));
            // this.conn = new MatchMaker().getConnection();
            beginBackgammonGame(conn.isHost);
        } catch (Exception e) {
            writeln("Network Thread Exception:", e);
            send(parentTid, NetworkThreadError(
                "Network Thread Exception: " ~ cast(string) e.message));
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
