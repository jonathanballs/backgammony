// The backgammon game board
import std.algorithm : min, max;
import std.conv : to;
import std.datetime.systime : SysTime, Clock;
import std.stdio;
import std.typecons;

import gdk.Event;
import gdk.FrameClock;
import gtk.DrawingArea;
import gtk.Widget;
import gobject.Signals;
import cairo.Context;

import game;
import dicewidget;

struct RGB {
    double r, g, b;
}

static void setSourceRgbStruct(Context cr, RGB color) {
    cr.setSourceRgb(color.r, color.g, color.b);
}

// Widths and heights are relative. The board will be scaled to fit on the window.
class BoardStyle {
    float boardWidth = 1200.0;
    float boardHeight = 800.0;

    float borderWidth = 30.0;
    float barWidth = 40.0;

    float pipRadius = 60.0;

    float pointWidth = 70.0;
    float pointHeight = 300.0;
}

class BackgammonBoard : DrawingArea {
    Board board;
    GameState state;
    Player currentPlayer;

    BoardStyle style;

    this(uint desiredValue = 1) {
        super(300, 300);
        setHalign(GtkAlign.FILL);
        setValign(GtkAlign.FILL);
        setHexpand(true);
        setVexpand(true);

        style = new BoardStyle;

        addOnDraw(&this.onDraw);
        addOnConfigure(&this.onConfigureEvent);
        addTickCallback(delegate bool (Widget w, FrameClock f) {
            this.queueDraw();
            return true;
        });
        this.board = new Board();

        this.addOnButtonPress(delegate bool (Event e, Widget w) {
            writeln(e.button.x, " ", e.button.y);
            writeln("click");
            return false;
        });

        rollDice();
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

    float pointWidth() { return style.boardWidth / 12.0; }
    float pointHeight() { return style.boardHeight / 2.5; }
    float pipRadius() { return pointWidth() / 2.0; }

    Die[] dice;
    SysTime lastAnimation;

    void rollDice() {
        dice = [
            new Die(5),
            new Die(3)
        ];
        lastAnimation = Clock.currTime;
    }

    void drawDice(Context cr) {
        auto currTime = Clock.currTime();
        auto dt = currTime - lastAnimation;

        foreach (i, die; dice) {
            cr.save();

            die.update(dt.total!"usecs" / 1_000_000.0);
            cr.translate(65*i + getWidth() * 0.65, getHeight() / 2 + 25*i);
            cr.scale(getWidth() / 18, getHeight() / 18);
            die.draw(cr);

            cr.restore();
        }


        lastAnimation = currTime;
    }

    // Returns the centre bottom of the point
    ScreenCoords getPointCoords(uint pointNum) {
        // Point 1 is bottom right. Point 24 is top right
        if (pointNum <= 12) {
            return ScreenCoords(cast(uint) (cast(uint) style.boardWidth - (pointNum-0.5) * pointWidth()), 0);
        } else {
            return ScreenCoords(cast(uint) ((pointNum-12.5) * pointWidth()), cast(uint) style.boardHeight);
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
        drawBoard(cr);

        if (state == GameState.DiceRolling) {
            if (dice[0].finished) {
                state = GameState.ChoosingMove;
            }
        }

        // drawPips(cr);
        // drawDice(cr);

        return true;
    }

    void drawBoard(Context cr) {

        // Board should have ratio of 1.4;
        auto currentDimensionRatio = cast(float) getAllocatedWidth() / getAllocatedHeight();

        // Centering and scaling the board
        auto scaleFactor = min(
            getAllocatedWidth() / style.boardWidth,
            getAllocatedHeight() / style.boardHeight,
        );
        cr.translate(
            (getAllocatedWidth() - scaleFactor*style.boardWidth) / 2,
            (getAllocatedHeight() - scaleFactor*style.boardHeight) / 2
        );
        cr.scale(scaleFactor, scaleFactor);

        cr.setSourceRgb(0.18, 0.204, 0.212);
        cr.lineTo(0, 0);
        cr.lineTo(style.boardWidth, 0);
        cr.lineTo(style.boardWidth, style.boardHeight);
        cr.lineTo(0, style.boardHeight);
        cr.fill();

        drawPoints(cr);
    }

    void drawPoints(Context cr) {
        auto lightPoint = RGB(140 / 256.0, 100 / 256.0, 43 / 256.0);
        auto darkPoint = RGB(44 / 256.0, 62 / 256.0, 80 / 256.0);

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
                cr.lineTo(c.x, cast(uint) style.boardHeight-pointHeight());
                cr.lineTo(c.x + pointWidth()/2, c.y);
            }


            if (i % 2) {
                cr.setSourceRgbStruct(darkPoint);
            } else {
                cr.setSourceRgbStruct(lightPoint);
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
