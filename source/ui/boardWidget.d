module ui.boardWidget;

// The backgammon game board
import std.algorithm : min, max;
import std.conv : to;
import std.datetime.systime : SysTime, Clock;
import std.stdio;
import std.typecons;

import cairo.Context;
import cairo.Matrix;
import gdk.Event;
import gdk.FrameClock;
import gtk.DrawingArea;
import gtk.Widget;
import gobject.Signals;

import game;
import ui.dicewidget;

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

// A corner of the board. Useful for describing where a user's home should be.
// In the future, this will be changeable in the settings.
enum Corner {
    BL,
    BR,
    TL,
    TR
}

class BackgammonBoard : DrawingArea {
    GameState gameState;

    /// The current styling. Will be modifiable in the future.
    BoardStyle style;

    /// Dice animation
    bool diceAreRolling;

    /// Create a new board widget.
    this() {
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
        gameState.newGame();

        this.addOnButtonPress(delegate bool (Event e, Widget w) {
            foreach (uint i, c; pointCoords) {
                if (e.button.y > min(c[0].y, c[1].y)
                        && e.button.y < max(c[0].y, c[1].y)
                        && e.button.x > c[0].x - pointWidth()/2
                        && e.button.x < c[0].x + pointWidth()/2) {
                    writeln("Click on point ", i);
                }
            }
            return false;
        });
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
            new Die(gameState.diceRoll[0]),
            new Die(gameState.diceRoll[1])
        ];
        lastAnimation = Clock.currTime;
        diceAreRolling = true;
    }

    void drawDice(Context cr) {
        auto currTime = Clock.currTime();
        auto dt = currTime - lastAnimation;

        foreach (i, die; dice) {
            cr.save();

            die.update(dt.total!"usecs" / 1_000_000.0);
            cr.translate(65*i + style.boardWidth * 0.65, style.boardHeight / 2 + 25*i);
            cr.scale(style.boardWidth / 24, style.boardWidth / 24);
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
        drawPips(cr);

        // Temporary: apply first available moves when dice are rolled.
        if (this.diceAreRolling) {
            if (dice[0].finished) {
                this.diceAreRolling = false;
                // Just apply the first possible move
                auto moves = this.gameState.generatePossibleMovements();
                writeln("Applying move: ", moves[0]);
                gameState.executeTurn(moves[0]);
            }
        }

        drawDice(cr);
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

    /// The coordinates of each point on the screen in device.
    ScreenCoords[2][24] pointCoords;
    void drawPoints(Context cr) {
        auto lightPoint = RGB(140 / 256.0, 100 / 256.0, 43 / 256.0);
        auto darkPoint = RGB(44 / 256.0, 62 / 256.0, 80 / 256.0);

        foreach (uint i; 1..this.gameState.board.points.length + 1) {
            auto c = getPointCoords(i);

            double pointPoint = (i <= 12)
                ? pointHeight()
                : cast(uint) style.boardHeight-pointHeight();
            

            ScreenCoords toDevice(ScreenCoords sc) {
                double x = sc.x;
                double y = sc.y;
                cr.userToDevice(x, y);
                return ScreenCoords(cast(uint) x - 25, cast(uint) y - 70);
            }

            pointCoords[i-1][0] = toDevice(c);
            pointCoords[i-1][1] = toDevice(ScreenCoords(c.x, cast(uint) pointPoint));

            // Draw the point
            cr.moveTo(c.x - pointWidth()/2, c.y);
            cr.lineTo(c.x, pointPoint);
            cr.lineTo(c.x + pointWidth()/2, c.y);

            cr.setSourceRgbStruct(i%2 ? darkPoint : lightPoint);
            cr.fill();
            cr.stroke();

            // Draw numbers
            cr.moveTo(c.x, c.y + (i <= 12 ? 20 : -10));
            cr.setSourceRgb(1.0, 1.0, 1.0);
            import std.stdio;
            cr.showText(i.to!string);
            cr.newPath();
        }
    }

    void drawPips(Context cr) {
        struct rgb { double r, g, b; }
        auto p1Colour = rgb(0.0, 0.0, 0.0);
        auto p2Colour = rgb(1.0, 1.0, 1.0);
        auto pipRadius = this.style.boardWidth / 36.0;


        foreach(pointNum, point; this.gameState.board.points) {
            auto pointX = getPointCoords(cast(uint) pointNum + 1).x;

            foreach(n; 0..point.numPieces) {
                double pointY = pipRadius + (2*n*pipRadius);
                if (pointNum >= 12) {
                    pointY = style.boardHeight - pointY;
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
