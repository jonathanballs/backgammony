module networking;

import core.thread;
import core.time;
import std.socket;
import std.stdio;
import std.concurrency;
import std.typecons;
import std.format;
import std.random;
import std.conv;
import std.string;
import std.digest.sha;

import networking.upnp;
import networking.messages;

// Networking is a core part of backgammon. This module provides an implementation
// of the Secure Backgammon Protocol and provides the backbone of all networking
// (p2p, client/server etc).

// TODO list
// - Close listening port once connected
// - Close UpNp ports
// - Exit when window closes
// - Use against proper tracker
// - Basically entire game logic
// - Move connection logic to its own set of methods.
// - Validate that strings are valid UTF-8
// - Ensure correct version of TBP

alias Opponent = Tuple!(
    string, "peer_id",
    string, "ip",
    ushort, "port");

class NetworkingThread : Thread {
    this() {
        this.parentTid = thisTid();
        super(&run);
    }

    private:
    TcpSocket socket; // Server
    Socket conn; // Connection with the other computer

    Tid parentTid;
    ushort portNumber;
    string peer_id;

    void bindPort(ushort portNumber) {
        socket = new TcpSocket(AddressFamily.INET6);
        socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        try {
            // socket.bind(new InternetAddress(portNumber));
            socket.bind(new Internet6Address("::1", portNumber));
            import std.conv : to;
            writeln("Listening on [::1]:" ~ portNumber.to!string);
            socket.listen(1);
            this.portNumber = portNumber;
        } catch (SocketOSException e) {
            if (e.message == "Unable to bind socket: Address already in use") {
                bindPort(++portNumber);
            }
        }
    }

    /// Read a line from the network connection
    string recBuffer;
    string getNetworkLine() {
        while (recBuffer.indexOf('\n') == -1) {
            auto buffer = new ubyte[2056];
            ptrdiff_t amountRead;
            amountRead = conn.receive(buffer);
            if (amountRead == Socket.ERROR) {
                writeln("Socket Error: ", conn.getErrorText());
            }
            recBuffer ~= cast(string) buffer[0..amountRead];

            if (amountRead == 0) {
                throw new Exception("Tried to getNetworkLine but connection is closed");
            }
        }

        auto nlIndex = recBuffer.indexOf('\n');
        if (nlIndex) {
            string ret = recBuffer[0..nlIndex];
            recBuffer = recBuffer[nlIndex+1..$];
            writeln("NETGET: ", ret);
            return ret;
        } else {
            throw new Exception("Tried to getNetworkLine but connection is closed");
        }
    }

    void sendNetworkLine(string s) {
        writeln("NETSND: ", s);
        conn.send(s ~ "\n");
    }

    // Attempt to connect to an opponent as a client
    // TODO: Return a connection or null perhaps? P2P will want more details.
    bool attemptConnection(Opponent opponent) {
        // TODO: Dont connect to self I guess :D
        if (opponent.port == this.portNumber) return false;

        // Try to connect to an opponent and send TBP header
        auto address = parseAddress(opponent.ip, opponent.port);
        writeln("Attempting to connect to ", address);
        TcpSocket socket = new TcpSocket(address);
        writeln("NETSND: TBP/1.0");
        socket.send("TBP/1.0\n");

        auto buffer = new ubyte[2056];
        ptrdiff_t amountRead = socket.receive(buffer);
        if (amountRead <= 0) return false;

        writeln("NETGET: ", cast(string) buffer[0..amountRead]);

        // If we have found someone then stop listening on ours.
        if (buffer[0..amountRead] == cast(ubyte[]) "TBP/1.0\n") {
            writeln("Found client :))))))");
            this.conn = socket;
        }

        return true;
    }

    void run() {
        try {
            send(parentTid, NetworkThreadStatus("Exposing SBP ports..."));
            // 1. Open port 42069
            bindPort(42069);

            // 2. Upnp
            // serviceDiscovery();

            send(parentTid, NetworkThreadStatus("Matchmaking..."));
            // 3. Connect to torrent tracker

            Opponent[] opps;
            try {
                opps = findTrackerOpponents();
            } catch (Exception e) {
                // TODO: Can this be caught higher up?
                send(parentTid, NetworkThreadError(
                    "Failed to connect to matchmaking tracker: " ~ cast(string) e.message));
            }

            // 4. Attempt to connect to other players
            writeln(format!"Attempting to connect to %d other players"(opps.length));
            foreach (o; opps) {
                try {
                    // Attempt connection, return socket if ready to play...
                    if (attemptConnection(o)) {
                        writeln("Connected to ", o.ip, ":", o.port);
                        beginBackgammonGame(false);
                        break;
                    }
                } catch (Exception e) {
                    writeln("Failed to connect: ", e.message);
                }
            }

            // 4. Wait for connections and matchmake
            writeln("Unable to connect... So waiting for connections");
            while(true) {
                Socket client = socket.accept();
                char[1024] buffer;
                auto received = client.receive(buffer);

                string response = "TBP/1.0\n";
                client.blocking = true;
                client.send(response);

                this.conn = client;
                beginBackgammonGame(true);

                client.shutdown(SocketShutdown.BOTH);
                client.close();
            }
        } catch (Exception e) {
            writeln(e);
            send(parentTid, NetworkThreadError(
                "Network Thread Exception: " ~ cast(string) e.message));
        }
    }

    Opponent[] findTrackerOpponents() {
        import std.string;
        import std.random;
        import std.conv;
        import bencode;
        import requests;

        string info_hash = sha1Of("backgammon").toHexString().dup[0..20];
        // Generate a random peer_id
        auto rnd = Random(unpredictableSeed);
        peer_id = "";
        string hex = "abcdefghijklmnopqrstuvyxyz1234567890";
        foreach (i; 0..20) {
            peer_id ~= hex[uniform(0, hex.length)];
        }

        auto response = getContent("http://localhost:8000/announce", [
            "info_hash": info_hash,
            "peer_id": peer_id,
            "port": portNumber.to!string,
            "uploaded": "0",
            "downloaded": "0",
            "left": "0",
            "numwanted": "0",
            "event": "started",
            "compact": "0",
        ]).data();

        auto debencoded = bencodeParse(response);
        auto peers = debencoded["peers"];

        if (!peers) return [];

        Opponent[] ret;

        foreach(uint i; 0.. cast(uint)peers.list.length) {
            auto opponent = Opponent(
                *(peers[i]["peer id"].str()),
                *(peers[i]["ip"].str()),
                cast(ushort) (peers[i]["port"].integer().toInt()),
            );

            if (opponent.peer_id != this.peer_id) {
                ret ~= opponent;
            }
        }

        return ret;
    }

    string networkHash(string s) {
        return sha1Of(s).toHexString().dup[0..20];
    }

    // It is assumed that the headers have been swapped
    void beginBackgammonGame(bool isHost) {
        // The client performs the first move
        send(parentTid, NetworkBeginGame());

        // Fuck it, generate a dice roll
        performDiceRoll(isHost);
    }

    uint[] performDiceRoll(bool goFirst) {
        ulong mySeed = uniform!ulong();
        string oppSeedHash;
        string oppSeed;

        writeln("mySeed: ", mySeed);
        if (goFirst) {
            sendNetworkLine("DICEROLL");

            sendNetworkLine(networkHash(mySeed.to!string));
            oppSeedHash = getNetworkLine();
            sendNetworkLine(mySeed.to!string);
            oppSeed = getNetworkLine();
        } else {
            getNetworkLine();

            oppSeedHash = getNetworkLine();
            sendNetworkLine(networkHash(mySeed.to!string));
            oppSeed = getNetworkLine();
            sendNetworkLine(mySeed.to!string);
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
        getNetworkLine();
        getNetworkLine();
        getNetworkLine();
        return [die1, die2];
    }
}
