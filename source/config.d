module config;

import std.file;
import std.path;
import std.stdio;
import std.json;

/**
 * Application configuration
 */
class Config {
    static bool couldReadAtStartup;
    static string startupErrorMessage;

    static string fibsServer = "fibs.com:4321";
    static string fibsUsername;
    static string fibsPassword;

    static void write() {
    }

    static void read() {
        // TODO: Location by environment variable or command line arg
        try {
            string fileLocation = expandTilde("~/.config/backgammony/backgammony.json");
            string fileContents = readText(fileLocation);
            auto fileJson = parseJSON(fileContents);

            if (const(JSONValue)* fibsConf = "fibs" in fileJson) {
                if (fibsConf.type() == JSONType.object) {
                    if ("server" in fibsConf.object) {
                        this.fibsServer = fibsConf.object["server"].str;
                    }

                    if ("username" in fibsConf.object) {
                        this.fibsUsername = fibsConf.object["username"].str;
                    }

                    if ("password" in fibsConf.object) {
                        this.fibsPassword = fibsConf.object["password"].str;
                    }
                }
            }
            couldReadAtStartup = true;
            startupErrorMessage = "";
        } catch (Exception e) {
            couldReadAtStartup = false;
            startupErrorMessage = cast(string) e.message;
        }

    }
}
