module networking.fibs.thread;

import std.concurrency;
import std.conv;
import std.datetime;
import std.socket;
import std.stdio;
import std.typecons;
import core.thread;
import core.time;
import std.array : split;
import networking.fibs.connection;
import networking.fibs.messages;
import networking.fibs.clipmessages;

enum FIBSConnectionStatus {
    Disconnected, Connecting, Connected, FailedConnection, Crashed
}

struct FIBSPlayer {
    string name;
    string opponent;
    string watching;
    bool ready;
    bool away;
    float rating;
    uint experience;
    uint idle;
    SysTime login;
    string hostname;
    string client;
    string email;

    string status() {
        if (opponent != "-") {
            return "Playing against " ~ opponent;
        } else if (watching != "-") {
            return "Watching " ~ watching;
        } else if (away) {
            return "Away";
        } else if (ready) {
            return "Ready";
        } else {
            return "Online";
        }
    }

    /**
     * The 2 letter country code of the player or blank if unknown. Currently
     * just checks according to the player profile protocol defined in the FIBS
     * standard. TODO: Use geo-ip.
     */
    string country() {
        if (client.length > 4) {
            if (client[0].to!byte >> 2 == 0b1111) {
                return client[1..3];
            }
        }
        return "";
    }
}

/**
 * Communication with the FIBS thread.
 */
class FIBSController {
    private:
    Tid networkingThread;

    FIBSConnectionStatus fibsConnectionStatus;
    string fibsConnectionStatusMessage;

    string serverAddress;
    string username;
    string password;

    public FIBSPlayer[] players;

    public this(string serverAddress, string username, string password) {
        this.serverAddress = serverAddress;
        this.username = username;
        this.password = password;
        this.fibsConnectionStatus = FIBSConnectionStatus.Connecting;

        networkingThread = spawn((shared string serverAddress,
                            shared string username, shared string password) {
            new FIBSNetworkingThread(
                getAddress(serverAddress.split(':')[0], 4321)[0],
                username, password).run();
        }, cast(immutable) serverAddress,
            cast(immutable) username,
            cast(immutable) password);
    }

    /**
     * Get the current connection status of the FIBS thread
     */
    public Tuple!(FIBSConnectionStatus, "status", string, "message") connectionStatus() {
        receiveTimeout(0.msecs,
            (FIBSConnectionSuccess _) {
                this.fibsConnectionStatus = FIBSConnectionStatus.Connected;
                // Successful connection. Close window and reveal sidebar
            },
            (FIBSConnectionFailure e) {
                this.fibsConnectionStatus = FIBSConnectionStatus.Connected;
                this.fibsConnectionStatusMessage = e.message;
            }
        );

        return tuple!("status", "message")(fibsConnectionStatus, "");
    }

    /**
     * Receive new CLIP messages and update data structures.
     */
    public void processMessages() {
                // Receive events for up to 50ms
        auto startTime = MonoTime.currTime;
        import std.variant;
        while((MonoTime.currTime - startTime) < 50.msecs && receiveTimeout(-1.msecs,
            (CLIPWho w) {
                FIBSPlayer p = FIBSPlayer(w.name, w.opponent, w.watching,
                    w.ready, w.away, w.rating, w.experience, w.idle, w.login,
                    w.hostname, w.client, w.email);
                players ~= p;
            }
        )) {}
    }

    void disconnect() {}
}

private class FIBSNetworkingThread {
    FIBSConnection conn;
    Address serverAddress;
    string username;
    string password;

    public this(Address serverAddress, string username, string password) {
        this.serverAddress = serverAddress;
        this.username = username;
        this.password = password;
    }

    public void run() {
        FIBSConnection conn;
        try {
            conn = new FIBSConnection(serverAddress, username, password);
        } catch (Exception e) {
            // Send connection failure information and exit thread
            send(ownerTid, FIBSConnectionFailure(e.msg, e.info.to!string));
            return;
        }

        send(ownerTid, FIBSConnectionSuccess());

        while(true) {
            try {
                send(ownerTid, conn.readMessage(25.msecs));
            } catch (Exception e) {
            }
        }
    }
}
