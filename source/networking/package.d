module networking;

import core.thread;
import std.socket;
import std.stdio;
import std.concurrency;

import networking.upnp;
import networking.messages;

// Networking is a core part of backgammon. This module provides an implementation
// of the Secure Backgammon Protocol and provides the backbone of all networking
// (p2p, client/server etc).

class NetworkingThread : Thread {
    this() {
        this.parentTid = thisTid();
        super(&run);
    }

    private:
    TcpSocket socket;
    Tid parentTid;

    void run() {
        try {
            writeln("sending status");
            send(parentTid, NetworkThreadStatus("Exposing SBP ports..."));
            // 1. Open port 42069
            socket = new TcpSocket();
            socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
            socket.bind(new InternetAddress(42069));
            socket.listen(1);

            // 2. Upnp
            serviceDiscovery();

            send(parentTid, NetworkThreadStatus("Finding opponent..."));

            // 3. Connect to torrent tracker

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
}
