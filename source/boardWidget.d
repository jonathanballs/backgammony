// The backgammon game board
import std.algorithm : min;
import std.conv : to;
import std.datetime.systime : SysTime, Clock;
import std.stdio;
import std.typecons;

import gdk.Event;
import gdk.FrameClock;
import gtk.DrawingArea;
import gtk.Widget;
import cairo.Context;

import board;
import dicewidget;

class BackgammonBoard : DrawingArea {
    Board board;

    this(uint desiredValue = 1) {
        super(300, 300);
        setHalign(GtkAlign.FILL);
        setValign(GtkAlign.FILL);
        setHexpand(true);
        setVexpand(true);

        addOnDraw(&this.onDraw);
        addOnConfigure(&this.onConfigureEvent);
        addTickCallback(delegate bool (Widget w, FrameClock f) {
            this.queueDraw();
            return true;
        });
        this.board = new Board();
    }

    private struct ScreenCoords {
        uint x;
        uint y;
    }

    bool onConfigureEvent(Event e, Widget w) {
        auto short_edge = min(getAllocatedHeight(), getAllocatedWidth());
        auto border_width = cast(uint) pointWidth() / 2;
        short_edge -= 2 * border_width;
        setSizeRequest(short_edge, short_edge);
        return true;
    }

    float pointWidth() { return getWidth() / 12.0; }
    float pointHeight() { return getHeight() / 3.0; }
    float pipRadius() { return pointWidth() / 2.0; }

    Die die;
    SysTime lastAnimation;
    void drawDiceRoll(Context cr) {
        if (!die) {
            writeln("creating new dice");
            die = new Die();
            lastAnimation = Clock.currTime();
        }

        auto currTime = Clock.currTime();
        auto dt = currTime - lastAnimation;
        die.update(dt.total!"usecs" / 1_000_000.0);
        
        cr.save();
        cr.translate(getWidth() * 0.65, getHeight() / 2);
        cr.scale(getWidth() / 18, getHeight() / 18);
        die.draw(cr);
        cr.restore();

        lastAnimation = currTime;
    }

    // Returns the centre bottom of the point
    ScreenCoords getPointCoords(uint pointNum) {
        // Point 1 is bottom right. Point 24 is top right
        if (pointNum <= 12) {
            return ScreenCoords(cast(uint) (getWidth() - (pointNum-0.5) * pointWidth()), 0);
        } else {
            return ScreenCoords(cast(uint) ((pointNum-12.5) * pointWidth()), getHeight());
        }
    }

    ScreenCoords getPipCoords(uint pointNum, uint pipNum) {
        auto coords = getPointCoords(pointNum);
        if (pointNum <= 12) {
            coords.y -= cast(uint) ((2*pipNum + 1) * pipRadius());
        } else {
            coords.y += cast(uint) ((2*pipNum + 1) * pipRadius());
        }
        return coords;
    }

    bool onDraw(Context cr, Widget widget) {

        // Center the board in the container
        int boardWidth, boardHeight;
        getSizeRequest(boardWidth, boardHeight);
        cr.translate(
            (getAllocatedWidth() - boardWidth) / 2,
            (getAllocatedHeight() - boardHeight) / 2);

        cr.setSourceRgb(0.18, 0.204, 0.212);
        cr.lineTo(0, 0);
        cr.lineTo(getWidth(), 0);
        cr.lineTo(getWidth(), getHeight());
        cr.lineTo(0, getHeight());
        cr.fill();
        drawPoints(cr);
        drawPips(cr);
        drawDiceRoll(cr);

        return true;
    }

    void drawPoints(Context cr) {
        struct rgb {
            double r, g, b;
        }
        auto lightPoint = rgb(140 / 256.0, 100 / 256.0, 43 / 256.0);
        auto darkPoint = rgb(44 / 256.0, 62 / 256.0, 80 / 256.0);

        foreach (uint i; 1..this.board.points.length + 1) {
            import std.stdio;
            auto c = getPointCoords(i);

            // Draw the point
            if (i <= 12) { // Top side
                cr.moveTo(c.x - pointWidth()/2, c.y);
                cr.lineTo(c.x, pointHeight());
                cr.lineTo(c.x + pointWidth()/2, c.y);
            } else { // Bottom side
                cr.moveTo(c.x - pointWidth()/2, c.y);
                cr.lineTo(c.x, getHeight()-pointHeight());
                cr.lineTo(c.x + pointWidth()/2, c.y);
            }


            if (i % 2) {
                cr.setSourceRgb(darkPoint.r, darkPoint.g, darkPoint.b);
            } else {
                cr.setSourceRgb(lightPoint.r, lightPoint.g, lightPoint.b);
            }
            cr.fill();
            cr.stroke();

            // Draw numbers
            cr.moveTo(c.x, c.y + (i <= 12 ? 20 : -10));
            cr.setSourceRgb(1.0, 1.0, 1.0);
            cr.showText(to!string(i));
            cr.newPath();
        }
    }

    void drawPips(Context cr) {
        struct rgb { double r, g, b; }
        auto p1Colour = rgb(0.0, 0.0, 0.0);
        auto p2Colour = rgb(1.0, 1.0, 1.0);
        auto pipRadius = this.getWidth() / 24.0;


        foreach(pointNum, point; this.board.points) {
            auto pointX = getPointCoords(cast(uint) pointNum + 1).x;
            if (pointNum >= 12) {
                pointX = getHeight() - pointX;
            }
            foreach(n; 0..point.numPieces) {
                double pointY = pipRadius + (2*n*pipRadius);
                if (pointNum >= 12) {
                    pointY = getHeight() - pointY;
                }

                import std.math : PI;
                cr.arc(pointX, pointY, pipRadius, 0, 2*PI);

                if (point.owner == Player.PLAYER_1) {
                    cr.setSourceRgb(p1Colour.r, p1Colour.g, p1Colour.b);
                } else {
                    cr.setSourceRgb(p2Colour.r, p2Colour.g, p2Colour.b);
                }

                cr.fillPreserve();

                cr.setLineWidth(3.0);
                cr.setSourceRgb(0.5, 0.5, 0.5);
                cr.stroke();
            }
        }
    }
}
