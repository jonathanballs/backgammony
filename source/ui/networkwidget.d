module ui.networkwidget;

import std.parallelism;
import std.typecons;
import std.stdio;
import std.digest.sha;
import requests;
import bencode;

import gtk.Box;
import gtk.Dialog;
import gdk.FrameClock;
import gtk.Label;
import gtk.Notebook;
import gtk.Spinner;
import gtk.Widget;
import gtk.Window;

import utils.addtickcallback;
import ui.newgamedialog : HumanSelector, setMarginsExpand;

enum formPadding = 10;

class NetworkWidget : Dialog {

    // Signal!(GameState) onCreateNewGame;
    Notebook tabs;

    Box lanBox;
    HumanSelector lanHuman;

    Box inetBox;
    HumanSelector inetHuman;

    this (Window parent) {
        super();
        this.setTransientFor(parent);
        this.setPosition(GtkWindowPosition.CENTER_ON_PARENT);
        this.setTypeHint(GdkWindowTypeHint.DIALOG);
        this.setModal(true);
        this.setSizeRequest(400, 475);
        this.setTitle("Network Game");


        /**
         * LAN
         */
        
        lanBox = new Box(GtkOrientation.VERTICAL, formPadding);
        lanBox.setMarginsExpand(formPadding, formPadding, formPadding, formPadding, true, true);
        lanHuman = new HumanSelector("Username", "jonathan");
        lanBox.packStart(lanHuman, false, false, 0);

        /**
         * Internet
         */
        inetBox = new Box(GtkOrientation.VERTICAL, formPadding);
        inetBox.setMarginsExpand(formPadding, formPadding, formPadding, formPadding, true, true);
        inetHuman = new HumanSelector("Username", "jonathan");
        inetBox.packStart(inetHuman, false, false, 0);

        tabs = new Notebook();
        tabs.appendPage(lanBox, new Label("LAN"));
        tabs.appendPage(inetBox, new Label("Internet"));

        this.getContentArea().add(tabs);

        this.showAll();
    }

    mixin AddTickCallback;
}
