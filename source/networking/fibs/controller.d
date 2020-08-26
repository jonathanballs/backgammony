module networking.fibs.controller;

import core.thread;
import core.time;
import std.array : split;
import std.concurrency;
import std.conv;
import std.datetime;
import std.format;
import std.socket;
import std.stdio;
import std.typecons;
import std.variant;
import url;

import gameplay.match;
import networking.fibs.connection;
import networking.fibs.clipmessages;
import utils.signals;
import utils.varianthandle;
public import networking.fibs.user;


/**
 * Wrapper and controller for communication with FIBS server. All FIBS
 * networking is managed here.
 */
class FIBSController {
    /// When the current match is changed
    public Signal!(BackgammonMatch) onUpdateMatchState;

    private:
    FIBSConnection conn;

    /// The current match being watched/played
    BackgammonMatch currentMatch;

    // Meta status info to be displayed to the user
    FIBSConnectionStatus fibsConnectionStatus;
    string fibsConnectionStatusMessage;

    // Auth details
    string serverAddress;
    string username;
    string password;

    /// The shoutbox
    public FIBSMessage[] shoutBox;

    /** Map usernames to fibs players **/
    public FIBSPlayer[string] players;

    /**
     * Create a new FIBS Controller. This will automatically create a connection
     * and attempt to login with the given username and password. Connection
     * status can be monitored through FIBSController.connectionStatus().
     */
    public this(string serverAddress, string username, string password) {
        this.serverAddress = serverAddress;
        this.username = username;
        this.password = password;
        this.fibsConnectionStatus = FIBSConnectionStatus.Connecting;
        this.onUpdateMatchState = new Signal!(BackgammonMatch);

        auto addr = getAddress(parseURL(serverAddress).host, parseURL(serverAddress).port)[0];
        conn = new FIBSConnection(addr, username, password);
    }

    /**
     * Get the current connection status of the FIBS thread.
     */
    public Tuple!(FIBSConnectionStatus, "status", string, "message") connectionStatus() {
        this.processMessages();
        return tuple!("status", "message")(fibsConnectionStatus, fibsConnectionStatusMessage);
    }

    /**
     * Receive new CLIP messages and update data structures.
     */
    public void processMessages() {
        const auto startTime = MonoTime.currTime;

        while(MonoTime.currTime < startTime + 5.msecs) {
            Variant m;
            try {
                m = conn.readMessage(Duration.zero);
            } catch (Exception e) {
                break;
            }

            m.handle!(
            (CLIPWelcome w) {
                this.fibsConnectionStatus = FIBSConnectionStatus.Connected;
            },
            (CLIPWho w) {
                FIBSPlayer p = FIBSPlayer(w.name, w.opponent, w.watching,
                    w.ready, w.away, w.rating, w.experience, w.idle, w.login,
                    w.hostname, w.client, w.email);
                players[w.name] = p;
            },
            (CLIPLogout l) {
                // TODO: Move to offline list? This data could still be useful
                players.remove(l.name);
            },
            (CLIPShouts s) {
                shoutBox ~= FIBSMessage(Clock.currTime, s.name, s.message);
            },
            (CLIPMatchState ms) {
                if (this.currentMatch) {
                    if (!this.currentMatch.gs.equals(ms.match.gs)) {
                        writeln(ms);
                        writeln("Received match state update which doesn't correspond to local state");
                        writeln("============================ OLD =========================");
                        this.currentMatch.prettyPrint();
                        writeln("============================ RECEIVED =========================");
                        ms.match.prettyPrint();
                        this.currentMatch = ms.match;
                        this.onUpdateMatchState.emit(ms.match);
                    }
                } else {
                    this.currentMatch = ms.match;
                    this.onUpdateMatchState.emit(ms.match);
                }
            },
            (CLIPMatchMovement mv) {
                if (this.currentMatch) {
                    try {
                        this.currentMatch.gs.applyTurn(mv.moves);
                    } catch (Exception e) {
                        writeln(e);
                        writeln(mv);
                        this.currentMatch.prettyPrint();
                    }
                }
            },
            (CLIPMatchRoll mr) {
                if (this.currentMatch) {
                    this.currentMatch.gs.rollDice(mr.die1, mr.die2);
                }
            },
            (Variant v) {
                writeln(v, " (UNHANDLED)");
            }
            )();
        }
    }

    /**
     * Request to watch a particular user.
     */
    public void requestWatch(string username) {
        conn.writeline("watch " ~ username);
        conn.writeline("board");
    }

    /**
     * Request disconnection
     */
    public void disconnect() {
        conn.writeline("adios");
        conn.close();
    }
}

/// A private or shoutbox message
/// TODO: Make this FIBS non specific
struct FIBSMessage {
    SysTime timestamp;
    string from;
    string message;
}

/// Status of connection with FIBS server
/// TODO: Put this in the connection module!
enum FIBSConnectionStatus {
    Disconnected, Connecting, Connected, Failed, Crashed
}
