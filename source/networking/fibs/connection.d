module networking.fibs.connection;

import std.socket;
import std.stdio;
import networking.connection;

/**
 * Handles connection with FIBS server
 */
class FIBSConnection : Connection {
    this(Address serverAddress, string username, string password) {
        super(serverAddress);
    }

    /*
     * Overrided writeline to send carriage return as well
     */
    override void writeline(string s = "") {
        writeln("NETSND: ", s);
        this.conn.send(s ~ "\r\n");
    }
}
