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
    static string flagDirectory;
    static Pixbuf[string] flags;

    this() {
        if (!flagDirectory.length) {
            writeln("Warning: FlagManager initialized without flagDirectory");
        }
    }

    this(string flagDirectory) {
        this.flagDirectory = flagDirectory;
    }

    void load() {
        foreach (f; flagDirectory.dirEntries(SpanMode.shallow, false)) {
            if (f.name.endsWith(".png")) {
                Pixbuf p = new Pixbuf(f.name);
                p = p.scaleSimple(24, 24, GdkInterpType.HYPER);
                flags[baseName(stripExtension(f.name))] = p;
            }
        }
    }
}
