module networking.fibs.connection;

import std.socket;
import networking.connection;

/**
 * Handles connection with FIBS server
 */
class FIBSConnection : Connection {
    this(Address serverAddress, string username, string password) {
        super(serverAddress);
    }
}
