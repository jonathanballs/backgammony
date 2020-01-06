module networking.connection;

import core.time;
import core.thread;
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

        string responseHeader;
        try {
            this.writeline(protocolHeader);
            responseHeader = this.readline(1.seconds);
        } catch (Exception e) {
            this.close();
            throw e;
        }

        if (responseHeader != protocolHeader) {
            throw new Exception("Unexpected Response on connection: " ~ responseHeader);
        }

        writeln("Connection achieved with ", address);
    }

    this(Socket socket, bool isHost = true) {
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
    /// ARGS:
    ///   timeout: How long before throwing timeout exception. Leave for unlimited.
    string readline(Duration timeout = Duration.zero) {
        static string recBuffer;

        import std.datetime.stopwatch;
        auto timer = new StopWatch(AutoStart.yes);

        do {
            auto buffer = new ubyte[2056];
            ptrdiff_t amountRead;
            conn.blocking = false;
            amountRead = conn.receive(buffer);
            conn.blocking = true;

            if (amountRead == 0) {
                throw new Exception("Connection readline: Connection is closed");
            }

            if (amountRead == Socket.ERROR) {
                if (conn.getErrorText() == "Success") {
                    amountRead = 0;
                } else {
                    throw new Exception("Socket Error: ", conn.getErrorText());
                }
            }
            recBuffer ~= cast(string) buffer[0..amountRead];

            if (recBuffer.indexOf('\n') != -1) break;

            import core.thread;
            Thread.sleep(50.msecs);
        } while (timeout == Duration.zero || timer.peek < timeout);

        if (timeout != Duration.zero && timer.peek > timeout) {
            throw new Exception("Connection readline timeout");
        }

        auto nlIndex = recBuffer.indexOf('\n');
        if (nlIndex) {
            string ret = recBuffer[0..nlIndex];
            recBuffer = recBuffer[nlIndex+1..$];
            writeln("NETGET: ", ret);
            return ret;
        } else {
            throw new Exception("No newline is available");
        }
    }

    /// Write line to the connection.
    void writeline(string s) {
        writeln("NETSND: ", s);
        conn.send(s ~ "\n");
    }
}
