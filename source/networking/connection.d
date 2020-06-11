module networking.connection;

import core.time;
import core.thread;
import std.socket;
import std.stdio;
import std.string;
import std.typecons : tuple;

enum protocolHeader = "TBP/1.0";

class TimeoutException : Exception {
    this(string msg) { super(msg); }
}

struct ConnectionHeaders {
    string playerId;
    string userName;
}

// Wrapper around network connections. Provides helper functions and IP version
// agnosticism. Handles initial connection.
class Connection {
    protected Socket conn;
    protected Address address;
    bool isHost;
    bool _debug;

    /// Create a Connection and connects to address as a client
    this(Address address) {
        this.isHost = false;
        this.address = address;
        writeln("Attempting connection to ", address);
        this.conn = new TcpSocket(address);
    }

    /// Create a Connection as a host. Assumes socket is already active.
    this(Socket socket) {
        this.address = socket.remoteAddress;
        this.conn = socket;
        this.isHost = true;
    }

    /// Create a Connection as a client to a UnixSocket
    this(string unixAddress) {
        this.isHost = false;
        address = new UnixAddress(unixAddress);
        writeln("Attempting connection to ", address);
        conn = new Socket(AddressFamily.UNIX, SocketType.STREAM);
        conn.connect(address);
    }

    /// Close the socket
    void close() {
        conn.blocking = true;
        conn.shutdown(SocketShutdown.BOTH);
        conn.close();
    }

    string recBuffer;
    /**
     * Fills rec buffer until a new line is found
     */
    protected void fillRecBuffer(Duration timeout = Duration.zero) {
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
                version(linux) {
                    if (conn.getErrorText() == "Success") {
                        amountRead = 0;
                    } else {
                        throw new Exception("Socket Error: ", conn.getErrorText());
                    }
                }
                version(OSX) {
                    if (conn.getErrorText() == "Undefined error: 0") {
                        amountRead = 0;
                    } else {
                        throw new Exception("Socket Error: ", conn.getErrorText());
                    }
                }
            }
            recBuffer ~= cast(string) buffer[0..amountRead];

            if (recBuffer.indexOf('\n') != -1) break;

            import core.thread;
            Thread.sleep(15.msecs);
        } while (timeout == Duration.zero || timer.peek < timeout);

        if (timeout != Duration.zero && timer.peek > timeout) {
            throw new TimeoutException("Connection readline timeout");
        }
    }

    /// Read a line (newline excluded) syncronously from the current connection.
    /// ARGS:
    ///   timeout: How long before throwing timeout exception. Leave for unlimited.
    string readline(Duration timeout = Duration.zero) {

        this.fillRecBuffer(timeout);

        auto nlIndex = recBuffer.indexOf('\n');
        if (nlIndex != -1) {
            string ret = recBuffer[0..nlIndex+1].chomp();
            recBuffer = recBuffer[nlIndex+1..$];
            if (this._debug) {
                writeln("NETGET: ", ret);
            }
            return ret;
        } else {
            throw new Exception("No newline is available");
        }
    }

    /// Write line to the connection.
    void writeline(string s = "") {
        if (this._debug) {
            writeln("NETSND: ", s);
        }
        conn.send(s ~ "\n");
    }
}

/**
 * Special type of connection that performs the TBP handshake
 */
class TBPConnection : Connection {
    /// Create a Connection and connects to address as a client
    this(Address address, ConnectionHeaders headers) {
        super(address);

        try {
            this.writeline(protocolHeader);
            this.writeHeaders(headers);

            this.readline(2.seconds);
            ConnectionHeaders resp = readHeaders!ConnectionHeaders(2.seconds);
        } catch (Exception e) {
            this.close();
            throw e;
        }
    }

    /// Create a Connection as a host. Assumes socket is already active.
    this(Socket socket, ConnectionHeaders headers) {
        super(socket);

        this.readline(2.seconds);
        ConnectionHeaders resp = readHeaders!ConnectionHeaders(1.seconds);
        this.writeline(protocolHeader);
        this.writeHeaders(headers);
    }

    T readHeaders(T)(Duration timeout = Duration.zero) {
        import std.datetime.stopwatch;
        auto timer = new StopWatch(AutoStart.yes);

        T ret;

        while (true) {
            auto remainingTime = timeout == Duration.zero ? Duration.zero : timeout - timer.peek;
            auto line = readline(remainingTime);
            if (!line.length) break;
            if (line.indexOf(":") == -1) throw new Exception("Invalid header line: No colon");

            string key = line[0..line.indexOf(":")].chomp();
            string val = line[line.indexOf(":")+1..$].chomp();

            static foreach (string member; [ __traits(allMembers, T) ]) {
                if (key.toLower == member.toLower) {
                }
            }
        }

        return ret;
    }

    void writeHeaders(T)(T header, Duration timeout = Duration.zero) {
        static foreach (string member; [ __traits(allMembers, T) ]) {
            if (__traits(getMember, header, member).length) {
                this.writeline(member ~ ": " ~ __traits(getMember, header, member));
            }
        }
        this.writeline();
    }

}
