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

    private static char[] blankFlagBytes;
    private static Pixbuf blankFlag;

    /**
     * Create an instance of the flag manager. Assume that it has already been
     * initialised.
     */
    this() {
        if (!flagDirectory.length) {
            writeln("Warning: FlagManager initialized without flagDirectory");
        }
    }

    /**
     * Create an instance of the flag manager and set the directory that holds the flags.
     */
    this(string flagDirectory) {
        this.flagDirectory = flagDirectory;

        blankFlagBytes.length = 24 * 24;
        foreach (ref c; blankFlagBytes) c = 0;
        blankFlag = new Pixbuf(blankFlagBytes, GdkColorspace.RGB, true, 8, 24, 24, 24, null, null);
    }

    /**
     * Load flags into memory from flagDirectory.
     */
    void load() {
        try {
            foreach (f; flagDirectory.dirEntries(SpanMode.shallow, false)) {
                if (f.name.endsWith(".png")) {
                    Pixbuf p = new Pixbuf(f.name);
                    p = p.scaleSimple(24, 24, GdkInterpType.HYPER);
                    flags[baseName(stripExtension(f.name))] = p;
                }
            }
        } catch (Exception e) {
            writeln("Could not load flags: " ~ e.message);
        }
    }

    /**
     * Return pixbuf flag when no suitable flag is found in flag cache.
     */
    Pixbuf getUnknownFlag() {
        if ("_unknown" in flags) {
            return flags["_unknown"];
        } else {
            // Likely caused by a previous failure to successfully load flags.
            return blankFlag;
        }
    }
}
