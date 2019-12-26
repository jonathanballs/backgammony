module networking;

import core.thread;
import upnp;

// Networking is a core part of backgammon. This module provides an implementation
// of the Secure Backgammon Protocol and provides the backbone of all networking
// (p2p, client/server etc).

class NetworkingThread : Thread {
    this() {
        super(&run);
    }

    private:
    void run() {
        // 1. Open port

        // 2. Upnp
        serviceDiscovery();

        // 3. Connect to torrent tracker

        // 4. Matchmaking
    }
}
