module networking.fibs.thread;

import std.concurrency;
import std.conv;
import std.socket;
import std.stdio;
import std.typecons;
import core.thread;
import core.time;
import std.array : split;
import networking.fibs.connection;
import networking.fibs.messages;

enum FIBSConnectionStatus {
    Disconnected, Connecting, Connected, FailedConnection, Crashed
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

    public this(string serverAddress, string username, string password) {
        this.serverAddress = serverAddress;
        this.username = username;
        this.password = password;

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
    void processMessages() {
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
                auto line = conn.readMessage(25.msecs);
                writeln(line);
            } catch (Exception e) {
            }
        }
    }
}
