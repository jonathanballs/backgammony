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
