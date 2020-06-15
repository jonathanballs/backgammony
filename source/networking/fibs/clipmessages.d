module networking.fibs.clipmessages;
import std.conv : to;
import std.format;
import std.datetime;

/// This is the very first line you'll see after a successful standard login in
/// client mode.
/// Example:
///     1 myself 1041253132 192.168.1.308
struct CLIPWelcome {
    this(string s) {
        uint lastLoginUnix;
        s.formattedRead!"1 %s %d %s"(name, lastLoginUnix, lastHost);
        lastLogin = SysTime.fromUnixTime(lastLoginUnix);
    }
    string name;
    SysTime lastLogin;
    string lastHost;
}

/// Example:
///     2 jonathanballs 1 1 0 0 0 0 1 1 0 0 1 0 1 1500.00 0 0 0 1 0 UTC
struct CLIPOwnInfo {
    this(string s) {
        s.formattedRead!"2 %s %d %d %d %d %d %d %d %d %d %d %d %d %d %f %d %d %d %d %d %s"
            (name, allowpip, autoboard, autodouble, automove, away, bell, crawford,
            _double, experience, greedy, moreboards, moves, notify, rating, ratings,
            ready, redoubles, report, silent, timezone);
    }

    string name;
    bool allowpip;
    bool autoboard;
    bool autodouble;
    bool automove;
    bool away;
    bool bell;
    bool crawford;
    bool _double;
    uint experience;
    bool greedy;
    bool moreboards;
    bool moves;
    bool notify;
    float rating;
    bool ratings;
    bool ready;
    int redoubles;
    bool report;
    bool silent;
    string timezone;
}

/// This is usually displayed after the CLIP Own Info line during login, and
/// whenever the motd command is used.
struct CLIPMOTD {
    this(string[] s) {
        foreach (l; s[1..$-1]) {
            message ~= l ~ "\n";
        }
    }

    string message;
}

/// Information about a user
/// Example:
///     5 mgnu_advanced someplayer - 1 0 1912.15 827 8 1040515752 192.168.143.5 3DFiBs -
struct CLIPWho {
    this(string s) {
        uint lastLoginUnix;
        s.formattedRead!"5 %s %s %s %d %d %f %d %d %d %s %s %s"(
            name, opponent, watching, ready, away, rating, experience, idle,
            lastLoginUnix, hostname, client, email
        );
        login = SysTime.fromUnixTime(lastLoginUnix);
    }

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
}

/// Example:
///     7 someplayer someplayer logs in.
struct CLIPLogin {
    this(string s) {
        string message;
        s.formattedRead!"7 %s %s"(name, message);
    }
    string name;
}

/// Example:
///     8 someplayer someplayer drops connection.
struct CLIPLogout {
    this(string s) {
        string message;
        s.formattedRead!"8 %s %s"(name, message);
    }
    string name;
}

/// Example:
///     9 someplayer 1041253132 I'll log in at 10pm if you want to finish that game.
struct CLIPMessage {
    this(string s) {
        uint timeUnix;
        s.formattedRead!"9 %s %d %s"(from, timeUnix, message);
        time = SysTime.fromUnixTime(timeUnix);
    }

    string from;
    SysTime time;
    string message;
}

/// Example:
///     10 someplayer
struct CLIPMessageDelivered {
    this(string s) {
        s.formattedRead!"10 %s"(name);
    }
    string name;
}

/// Example:
///     11 someplayer
struct CLIPMessageSaved {
    this(string s) {
        s.formattedRead!"11 %s"(name);
    }
    string name;
}

/// Example:
///     12 someplayer Do you want to play a game?
struct CLIPSays {
    this(string s) {
        s.formattedRead!"12 %s %s"(name, message);
    }
    string name;
    string message;
}

/// Example:
///     13 someplayer Anybody for a 5 point match?
struct CLIPShouts {
    this(string s) {
        s.formattedRead!"13 %s %s"(name, message);
    }
    string name;
    string message;
}

/// Example:
///     14 someplayer I think he is using loaded dice  :-)
struct CLIPWhispers {
    this(string s) {
        s.formattedRead!"14 %s %s"(name, message);
    }
    string name;
    string message;
}

/// Example:
///     15 someplayer G'Day and good luck from Hobart, Australia.
struct CLIPKibitz {
    this(string s) {
        s.formattedRead!"15 %s %s"(name, message);
    }
    string name;
    string message;
}

/// Example:
///     16 someplayer What's this "G'Day" stuff you hick?  :-)
struct CLIPYouSay {
    this(string s) {
        s.formattedRead!"16 %s %s"(name, message);
    }
    string name;
    string message;
}

/// Example:
///     17 Watch out for someplayer.  He's a Tasmanian.
struct CLIPYouShout {
    this(string s) {
        string name;
        s.formattedRead!"17 %s %s"(name, message);
    }
    string message;
}

/// Example:
///     18 Hello and hope you enjoy watching this game.
struct CLIPYouWhisper {
    this(string s) {
        string name;
        s.formattedRead!"18 %s %s"(name, message);
    }
    string message;
}

/// Example:
///     19 Are you sure those dice aren't loaded?
struct CLIPYouKibitz {
    this(string s) {
        string name;
        s.formattedRead!"19 %s %s"(name, message);
    }
    string message;
}

struct FIBSRequestDisconnect {
}

/**
 * Request that a command be sent over the connection
 */
struct FIBSRequestCommand {
    string command;
}
