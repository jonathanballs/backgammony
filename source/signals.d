module signals;
import std.stdio;

template Signal(T...) {

    // Type of a slot
    alias slot_t = void delegate(T);

    class Signal {
        private slot_t[] slots;

        void emit(T...)(T t) {
            foreach(f; this.slots) {
                f(t);
            }
        }

        void connect(slot_t slot) {
            slots ~= slot;
        }
    }
}

unittest {
    writeln("Testing Signals...");

    bool called;
    void handler(int i, string s) { called = true; }
    auto s = new Signal!(int, string);
    s.connect(&handler);
    s.emit(0x3, "string");
    assert(called);
}
