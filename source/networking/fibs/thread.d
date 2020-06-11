module networking.fibs.thread;

import std.concurrency;
import std.conv;
import std.socket;
import std.stdio;
import core.thread;
import core.time;
import networking.fibs.connection;
import networking.fibs.messages;

class FIBSNetworkingThread {
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
