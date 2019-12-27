module networkWidget;

import std.parallelism;
import std.typecons;
import std.stdio;
import std.digest.sha;
import requests;
import bencode;

import gdk.FrameClock;
import gtk.Dialog;
import gtk.Label;
import gtk.Spinner;
import gtk.Widget;
import gtk.Window;

class NetworkWidget : Dialog {
    Spinner spinner;
    Label statusMessage;

    Task!(getContent, string, string[string])* announceTask;

    this (Window parent) {
        super();
        /**
         * Set position
         */
        this.setTransientFor(parent);
        this.setPosition(GtkWindowPosition.CENTER_ON_PARENT);
        this.setTypeHint(GdkWindowTypeHint.DIALOG);
        this.setModal(true);
        this.setSizeRequest(400, 175);
        this.setTitle("Network Game");

        /**
         * Add spinner and status message
         */
        this.spinner = new Spinner();
        spinner.start();
        spinner.setMarginTop(15);
        spinner.setMarginBottom(15);
        this.getContentArea().add(spinner);
        statusMessage = new Label("Loading network...");
        this.getContentArea().add(statusMessage);

        this.showAll();
    }

    override void addTickCallback(bool delegate(Widget, FrameClock) callback)
    {
        tickCallbackListeners ~= callback;
        static bool connected;

        if ( connected )
        {
            return;
        }

        super.addTickCallback(cast(GtkTickCallback)&tickCallback, cast(void*)this, null);
        connected = true;
    }

    extern(C) static int tickCallback(GtkWidget* widgetStruct, GdkFrameClock* frameClock, Widget _widget)
    {
        import std.algorithm.iteration : filter;
        import std.array : array;
        _widget.tickCallbackListeners = _widget.tickCallbackListeners.filter!((dlg) {
            return dlg(_widget, new FrameClock(frameClock));
        }).array();
        return !!_widget.tickCallbackListeners.length;
    }
}
