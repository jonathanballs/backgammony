module networking.fibs.clipmessages;

struct CLIPWelcome {
    string message;
}

struct CLIPOwnInfo {
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

struct CLIPMOTD {
    string message;
}

struct CLIPWHO {
    string name;
    string opponent;
    string watching;
    bool ready;
    bool away;
    float rating;
    uint experience;
    uint idle;
    uint login;
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
