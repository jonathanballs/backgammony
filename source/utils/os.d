module utils.os;
import std.conv : to;

/**
  * Functions for interacting with the OS
  */

/**
  * Get the local user name. Useful as  a default for player name
  */
string getLocalUserName() {
    import std.process : environment;
    version(Posix) {
        import core.sys.posix.unistd : geteuid, uid_t;
        import core.sys.posix.pwd : getpwuid, passwd;

        uid_t uid = geteuid();
        passwd* pw = getpwuid(uid);
        if (!pw) return "Human";

        return to!string(pw.pw_name);
    }
    version(Windows) {
        return environment.get("%USERNAME%", "Human");
    }
}
