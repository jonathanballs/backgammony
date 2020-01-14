module networking.matchmaking;

import std.concurrency;
import std.conv;
import std.digest.sha;
import std.format;
import std.random;
import std.socket;
import std.stdio;
import std.typecons;

import networking.connection;
import networking.upnp;
import networking.messages;

alias Opponent = Tuple!(
    string, "peer_id",
    string, "ip",
    ushort, "port");


// P2P matchmaking. Logic for connecting to trackers, other clients and accepting
// incoming connections.
enum listeningPort = 42069;

class MatchMaker {
    Tid parentTid;
    string peer_id;
    TcpSocket socket; // Server
    ushort portNumber;

    this() {
    }

    // Return a socket with a connection to another player.
    Connection getConnection() {
        // 1. Open port 42069
        bindPort(42069);
        writeln("Listening on ", socket.localAddress);

        auto opps = this.findTrackerOpponents();

        // 4. Attempt to connect to other players
        writeln(format!"Attempting to connect to %d other players"(opps.length));
        writeln("======================================================================");
        foreach (o; opps) {
            try {
                // Attempt connection, return socket if connection is successful.
                Address addr = parseAddress(o.ip, o.port);
                return new TBPConnection(addr, ConnectionHeaders(peer_id, peer_id));
            } catch (Exception e) {
                writeln("Failed to connect: ", e.message);
                writeln("======================================================================");
            }
        }

        // 4. Wait for connections and matchmake
        writeln("Waiting for connections");
        writeln("======================================================================");
        while(true) {
            try {
                auto c = socket.accept();
                writeln("Incoming connection from ", c.remoteAddress);
                return new TBPConnection(c, ConnectionHeaders(peer_id, peer_id));
            } catch (Exception e) {
                writeln("Failed to accept incoming connection: ", e.message);
                writeln("======================================================================");
            }
        }
    }

    private:

    // Attach to tracker and find a list of opponents. Returns 
    Opponent[] findTrackerOpponents() {
        import requests;
        import bencode;

        try {
            // Generate a random peer_id
            string hex = "abcdefghijklmnopqrstuvyxyz1234567890";
            foreach (i; 0..20)
                peer_id ~= hex[uniform(0, hex.length)];

            // Announce presence to torrent tracker
            auto peers = getContent("http://localhost:8000/announce", [
                "info_hash": cast(string) sha1Of("backgammon").toHexString().dup[0..20],
                "peer_id": peer_id,
                "port": portNumber.to!string,
                "uploaded": "0",
                "downloaded": "0",
                "left": "0",
                "numwanted": "0",
                "event": "started",
                "compact": "0",
            ]).data().bencodeParse()["peers"];
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
        } catch (Exception e) {
            writeln("Error connecting to tracker: ", e.message);
            // send(parentTid, NetworkThreadError(cast(string) e.message));
            return [];
        }
    }

    void bindPort(ushort portNumber) {
        socket = new TcpSocket(AddressFamily.INET6);
        socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        try {
            // socket.bind(new InternetAddress(portNumber));
            socket.bind(new Internet6Address("::1", portNumber));
            socket.listen(1);
            this.portNumber = portNumber;
        } catch (SocketOSException e) {
            writeln(e.message);
            if (e.message == "Unable to bind socket: Address already in use") {
                bindPort(++portNumber);
            }
        }
    }
}
