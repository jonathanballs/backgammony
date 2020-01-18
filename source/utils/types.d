module utils.types;

/**
 * Acts like an associative array with an Enum index but is allocated statically
 */
struct EnumIndexStaticArray(E, T) {                
    import std.traits : OriginalType;
    T[E.max+1] content;

    /**
     * Access value by reference at index
     */
    ref T opIndex(E index) {
        return content[cast(OriginalType!E) index];
    }

    ref const(T) opIndex(E index) const {
        return content[cast(OriginalType!E) index];
    }
}

struct OneIndexedStaticArray(T, uint length) {
    T[length] content;

    /**
     * Access value by reference at index
     */
    ref T opIndex(ulong index) {
        assert(index);
        return content[index - 1];
    }

    ref const(T) opIndex(ulong index) const {
        assert(index);
        return content[index - 1];
    }

    int opApply(int delegate(T) dg) {
        foreach (c; content) {
            if (dg(c)) return 1;
        }
        return 0;
    }

    uint opDollar() {
        return length + 1;
    }

    T[] opSlice(uint start, uint end) {
        assert(start || end);
        return content[start-1..end-1];
    }

    T[] opSlice() {
        return content[0..$];
    }
}

unittest {
    import std.stdio : writeln;
    writeln("Testing EnumIndexStaticArray");
    enum ExampleEnum {
        first_member,
        second_member,
    }
    EnumIndexStaticArray!(ExampleEnum, uint) a;
    assert(a.sizeof == (ExampleEnum.max+1) * uint.sizeof);

    assert(a[ExampleEnum.first_member] == 0);
    assert(a[ExampleEnum.second_member] == 0);

    a[ExampleEnum.first_member] = 3;
    assert(a[ExampleEnum.first_member] == 3);
    assert(a[ExampleEnum.second_member] == 0);

    a[ExampleEnum.first_member]++;
    assert(a[ExampleEnum.first_member] == 4);
}
