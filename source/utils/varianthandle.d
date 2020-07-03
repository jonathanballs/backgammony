/**
 * std.variant visit but for normal variants
 */
module utils.varianthandle;

import std.variant;
import std.traits;
import std.conv;

template handle(Handlers...)
if (Handlers.length > 0)
{
    auto handle(Variant)(Variant variant)
    {
        void function(Variant) defaultHandler;

        foreach (dgidx, dg; Handlers) {
            alias Params = Parameters!dg;
            if (!isSomeFunction!dg)
                assert(false, "handlers must be a function");

            if (Params.length != 1) {
                assert(false, "handlers must take a single parameter");
            }
            
            if (typeid(Params[0]) == variant.type) {
                auto v = variant.get!(Params[0]);
                return dg(v);
            }
            
            static if (is(Params[0] == Variant)) {
                defaultHandler = dg;
            }
        }

        if (defaultHandler) {
            return defaultHandler(variant);
        }

        throw new Exception("No handler for variant: ", variant.to!string);
    }
}

unittest {
    import std.stdio;
    writeln("Testing Variant handler");

    Variant v;
    v = 1;
    bool success = false;

    v.handle!(
        (int i) {
            success = true;
        }
    )();
    assert(success);

    v = "string";
    success = false;
    try {
        v.handle!(
            (int i) {
                assert(false);
            }
        )();
    } catch (Exception e) {
        success = true;
    }
    assert(success);
}
