// The backgammon game board
import gtk.Widget;
import gtk.DrawingArea;
import cairo.Context;

import board;

class BackgammonBoard : DrawingArea {
    Board board;

    this() {
        super(500, 500);
        addOnDraw(&this.onDraw);
        this.board = new Board();
    }

    bool onDraw(Context cr, Widget widget) {
        drawPoints(cr);
        drawPips(cr);

        return true;
    }

    void drawPoints(Context cr) {
        struct rgb {
            double r, g, b;
        }
        auto lightPoint = rgb(140 / 256.0, 100 / 256.0, 43 / 256.0);
        auto darkPoint = rgb(44 / 256.0, 62 / 256.0, 80 / 256.0);

        foreach (i; 0..this.board.points.length) {

            // Draw the point
            if (i < 12) { // Top side
                auto startX = i * getWidth() / 12;
                auto endX = startX + getWidth()/12;
                cr.moveTo(startX, 0);
                cr.lineTo((startX+endX) / 2, this.getHeight() / 3);
                cr.lineTo(endX, 0);
            } else { // Bottom side
                auto startX = getWidth() - ((i-12) * getWidth() / 12);
                auto endX = startX - getWidth()/12;
                cr.moveTo(startX, getHeight());
                cr.lineTo((startX+endX) / 2, 2 * this.getHeight() / 3);
                cr.lineTo(endX, getHeight());
            }


            if (i % 2) {
                cr.setSourceRgb(darkPoint.r, darkPoint.g, darkPoint.b);
            } else {
                cr.setSourceRgb(lightPoint.r, lightPoint.g, lightPoint.b);
            }
            cr.fill();
            cr.stroke();
        }
    }

    private double getPointX(uint n) {
        return (getWidth() / 24.0) + (n%12)*getWidth()/12;
    }

    void drawPips(Context cr) {
        struct rgb { double r, g, b; }
        auto p1Colour = rgb(0.0, 0.0, 0.0);
        auto p2Colour = rgb(1.0, 1.0, 1.0);
        auto pipRadius = this.getWidth() / 24;

        import std.math : PI;

        foreach(pointNum, point; this.board.points) {
            auto pointX = getPointX(cast(uint) pointNum);
            if (pointNum >= 12) {
                pointX = getHeight() - pointX;
            }
            foreach(n; 0..point.numPieces) {
                double pointY = pipRadius + (2*n*pipRadius);
                if (pointNum >= 12) {
                    pointY = getHeight() - pointY;
                }

                cr.arc(pointX, pointY, pipRadius, 0, 2*PI);

                if (point.owner == Player.PLAYER_1) {
                    cr.setSourceRgb(p1Colour.r, p1Colour.g, p1Colour.b);
                } else {
                    cr.setSourceRgb(p2Colour.r, p2Colour.g, p2Colour.b);
                }

                cr.fill();
                cr.stroke();
            }
        }
    }
}
