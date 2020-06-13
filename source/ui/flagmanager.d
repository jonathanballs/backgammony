module ui.flagmanager;

import std.algorithm : endsWith;
import std.file;
import std.path;
import std.stdio;
import gdk.Pixbuf;

/**
 * Manages access to flags.
 */
class FlagManager {
    string flagDirectory;
    static Pixbuf[string] flags;

    this(string flagDirectory) {
        this.flagDirectory = flagDirectory;
    }

    void load() {
        foreach (f; flagDirectory.dirEntries(SpanMode.shallow, false)) {
            if (f.name.endsWith(".png")) {
                flags[baseName(stripExtension(f.name))] = new Pixbuf(f.name);
            }
        }
    }
}
