module utils.addtickcallback;

/**
 * The default addTickCallack methods are broken. This is a fix.
 */
mixin template AddTickCallback() {
    override void addTickCallback(bool delegate(Widget, FrameClock) callback) {
        tickCallbackListeners ~= callback;
        static bool connected;

        if ( connected )
        {
            return;
        }

        super.addTickCallback(cast(GtkTickCallback)&tickCallback, cast(void*)this, null);
        connected = true;
    }

    extern(C) static int tickCallback(GtkWidget* widgetStruct, GdkFrameClock* frameClock, Widget _widget) {
        import std.algorithm.iteration : filter;
        import std.array : array;
        _widget.tickCallbackListeners = _widget.tickCallbackListeners.filter!((dlg) {
            return dlg(_widget, new FrameClock(frameClock));
        }).array();
        return !!_widget.tickCallbackListeners.length;
    }
}