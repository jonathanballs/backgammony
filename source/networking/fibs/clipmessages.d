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

struct CLIPLogin {
    string name;
}

struct CLIPLogout {
    struct name;
}

struct CLIPMessage {
    string from;
    uint time;
    string message;
}

struct CLIPMessageDelivered {
    string name;
}

struct CLIPMessageSaved {
    string name;
}

struct CLIPSays {
    string name;
    string message;
}

struct CLIPShouts {
    string name;
    string message;
}

struct CLIPKibitz {
    string name;
    string message;
}

struct CLIPYouSay {
    string name;
    string message;
}

struct CLIPYouWhisper {
    string message;
}

struct CLIPYouKibitz {
    string message;
}
