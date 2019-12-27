module networking;

import core.thread;
import std.socket;
import std.stdio;
import std.concurrency;
import std.typecons;

import networking.upnp;
import networking.messages;

// Networking is a core part of backgammon. This module provides an implementation
// of the Secure Backgammon Protocol and provides the backbone of all networking
// (p2p, client/server etc).

alias Opponent = Tuple!(
    string, "peer_id",
    string, "address",
    ushort, "port");

class NetworkingThread : Thread {
    this() {
        this.parentTid = thisTid();
        super(&run);
    }

    private:
    TcpSocket socket;
    Tid parentTid;
    ushort portNumber;
    string peer_id;

    void bindPort(ushort portNumber) {
        socket = new TcpSocket();
        socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
        try {
            socket.bind(new InternetAddress(portNumber));
            socket.listen(1);
            this.portNumber = portNumber;
        } catch (SocketOSException e) {
            if (e.message == "Unable to bind socket: Address already in use") {
                bindPort(++portNumber);
            }
        }
    }

    void run() {
        try {
            writeln("sending status");
            send(parentTid, NetworkThreadStatus("Exposing SBP ports..."));
            // 1. Open port 42069
            bindPort(42069);

            // 2. Upnp
            serviceDiscovery();

            send(parentTid, NetworkThreadStatus("Finding p2p opponent..."));

            // 3. Connect to torrent tracker
            auto opps = findTrackerOpponents();
            writeln(opps);

            // 4. Wait for connections and matchmake
            while(true) {
                Socket client = socket.accept();
                char[1024] buffer;
                auto received = client.receive(buffer);

                writefln("The client said:\n%s", buffer[0.. received]);

                enum header =
                    "HTTP/1.0 200 OK\nContent-Type: text/html; charset=utf-8\n\n";

                string response = header ~ "Hello World!\n";
                client.send(response);

                client.shutdown(SocketShutdown.BOTH);
                client.close();
            }
        } catch (Exception e) {
            writeln(e);
        }
    }

    Opponent[] findTrackerOpponents() {
        import std.string;
        import std.random;
        import std.conv;
        import bencode;
        import std.digest.sha;
        import requests;

        string info_hash = sha1Of("backgammon").toHexString()[0..20];
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

        Opponent[] ret;

        foreach(uint i; 0.. cast(uint)peers.list.length) {
            auto opponent = Opponent(
                *(peers[i]["peer id"].str()),
                *(peers[i]["ip"].str()),
                cast(ushort) (peers[i]["port"].integer().toInt()),
            );

            writeln(opponent.peer_id, ", ", this.peer_id);
            if (opponent.peer_id != this.peer_id) {
                ret ~= opponent;
            }
        }

        return ret;
    }
}
