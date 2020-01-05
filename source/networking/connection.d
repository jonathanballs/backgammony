module networking.connection;

import std.socket;
import std.stdio;
import std.string;

enum protocolHeader = "TBP/1.0";

// Wrapper around network connections. Provides helper functions and IP version
// agnosticism.
class Connection {
    private Socket conn;
    private Address address;
    bool isHost;

    /// Create a Connection and connects to address as a client
    this(Address address) {
        writeln("Attempting connection to ", address);
        this.address = address;
        this.isHost = false;
        this.conn = new TcpSocket(address);

        this.writeline(protocolHeader);
        auto response = this.readline();

        if (response != protocolHeader)
            throw new Exception("Unexpected Response on connection: " ~ response);

        writeln("Connection achieved with ", address);
    }

    this (Socket socket, bool isHost = true) {
        this.address = socket.remoteAddress;
        this.conn = socket;

        auto header = this.readline();
        if (header != "TBP/1.0")
            throw new Exception("Unexpected header on received connection: " ~ header);

        this.writeline(protocolHeader);
        this.isHost = isHost;
    }

    /// Close the socket
    void close() {
        conn.shutdown(SocketShutdown.BOTH);
        conn.close();
    }

    /// Read a line (newline excluded) syncronously from the current connection.
    string readline() {
        static string recBuffer;
        while (recBuffer.indexOf('\n') == -1) {
            auto buffer = new ubyte[2056];
            ptrdiff_t amountRead;
            amountRead = conn.receive(buffer);

            if (amountRead == 0) {
                throw new Exception("Tried to getNetworkLine but connection is closed");
            }

            if (amountRead == Socket.ERROR) {
                writeln("Socket Error: ", conn.getErrorText());
            }

            recBuffer ~= cast(string) buffer[0..amountRead];
        }

        auto nlIndex = recBuffer.indexOf('\n');
        if (nlIndex) {
            string ret = recBuffer[0..nlIndex];
            recBuffer = recBuffer[nlIndex+1..$];
            writeln("NETGET: ", ret);
            return ret;
        } else {
            throw new Exception("Tried to getNetworkLine but connection is closed");
        }
    }

    void writeline(string s) {
        writeln("NETSND: ", s);
        conn.send(s ~ "\n");
    }
}
