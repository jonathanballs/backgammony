module networking.fibs.user;

import std.datetime;
import std.conv;

struct FIBSPlayer {
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

    /**
     * Returns a string describing what the player is currently doing.
     */
    string status() {
        if (opponent != "-") {
            return "Playing against " ~ opponent;
        } else if (watching != "-") {
            return "Watching " ~ watching;
        } else if (away) {
            return "Away";
        } else if (ready) {
            return "Ready";
        } else {
            return "Online";
        }
    }

    /**
     * Returns the 2 letter country code of the player or blank if unknown. Currently
     * just checks according to the player profile protocol defined in the FIBS
     * standard. TODO: Use geo-ip.
     */
    string country() {
        if (client.length > 4) {
            if (client[0].to!byte >> 2 == 0b1111) {
                return client[1..3];
            }
        }
        return "";
    }
}
