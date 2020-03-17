module utils.signals;
import std.stdio;

/**
 * Signals and used for communication between objects. The user can create a
 * signal on one of their objects which can be subscribed to by other parts of
 * the application. This is modelled after QT signals.
 */
template Signal(T...) {

    // Type of a slot
    alias slot_t = void delegate(T);

    class Signal {
        private slot_t[] slots;

        /**
         * Call each of the signal handlers in turn in the order that they were
         * added.
         */
        void emit(T...)(T t) {
            foreach (f; this.slots) {
                f(t);
            }
        }

        /**
         * Connect a new callback to a signal
         */
        void connect(slot_t slot) {
            slots ~= slot;
        }

        /**
         * Disconnect a callback from a signal
         */
        void disconnect(slot_t slot) {
            slot_t[] newSlots = [];
            foreach (s; slots) {
                if (s != slot) newSlots ~= s;
            }
            slots = newSlots;
        }

        /**
         * Clear all callbacks
         */
        void clear() {
            slots = [];
        }
    }
}

unittest {
    writeln("Testing Signals");

    /**
     * Test that signal can be called
     */
    bool called;
    void handler(int i, string s) { called = true; }
    auto s = new Signal!(int, string);
    s.connect(&handler);
    assert(s.slots.length == 1);
    s.emit(0x3, "string");
    assert(called);
    
    /**
     * Test clearing
     */
    s.clear();
    assert(s.slots.length == 0);

    /**
     * Test removing
     */
    s.connect(&handler);
    assert(s.slots.length == 1);
    s.disconnect(&handler);
    assert(s.slots.length == 0);
}
