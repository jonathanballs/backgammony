module networking.fibs.thread;

import std.stdio;
import std.socket;
import core.time;
import networking.fibs.connection;

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
        try {
            conn = new FIBSConnection(serverAddress, username, password);
            conn.writeline("login backgammony-1.0.0 1008 " ~ username ~ " " ~ password);
            while(true) {
                try {
                    auto line = conn.readline(25.msecs);
                    // writeln(line);
                } catch (Exception e) {
                }
            }
        } catch (Exception e) {
            writeln(e);
        }
    }
}
