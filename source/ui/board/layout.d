module ui.board.layout;

import std.math;
import std.stdio;
import std.typecons;

import ui.board.style;
import game : Player;

/// A corner of the board. Useful for describing where a user's home should be.
/// In the future, this will be changeable in the settings.
enum Corner {
    BL,
    BR,
    TL,
    TR
}

/**
 * A single point on the screen
 */
struct ScreenPoint {
    float x;
    float y;

    /**
     * Return euclidean distance to another ScreenPoint
     */
    float distance(ScreenPoint p) {
        return sqrt(pow(p.x - x, 2) + pow(p.y - y, 2));
    }
}

/**
 * A circle on the screen
 */
struct ScreenCircle {
    float x;
    float y;
    float radius;

    /**
     * Returns the area of the circle
     */
    float area() {
        return PI * pow(radius, 2);
    }

    ScreenPoint center() {
        return ScreenPoint(x, y);
    }

    /**
     * Returns whether the circle contains a point
     */
    bool contains(ScreenPoint p) {
        return p.distance(center()) <= radius;
    }
}

class BoardLayout {

    BoardStyle style;
    Corner p1Corner = Corner.TR;

    this(BoardStyle style) {
        this.style = style;
    }

    /**
     * Returns a tuple containing the bottom (centre) and top of the points
     * position. By default we will be starting at top right.
     * Params:
     *      pointIndex = point number between 0 and 23
     */
    ScreenPoint[2] getPointPosition(uint pointIndex) {
        // Calculate for TR and then modify at the end
        assert (1 <= pointIndex && pointIndex <= 24);
        pointIndex--;

        ScreenPoint start;
        ScreenPoint finish;

        // y-coordinate
        if (pointIndex < 12) {
            start.y = style.borderWidth;
            finish.y = style.borderWidth + style.pointHeight;
        } else {
            start.y = style.boardHeight - style.borderWidth;
            finish.y = style.boardHeight - (style.borderWidth + style.pointHeight);
        }

        // x-coordinate
        const float halfBoardWidth = (style.boardWidth - 2*style.borderWidth - style.barWidth) / 2;
        const float pointSeparation = (halfBoardWidth + 1) / 6;
        if (pointIndex < 12) { // top
            start.x = style.boardWidth - (style.borderWidth + (pointIndex+0.5)*pointSeparation);
            if (pointIndex > 5) {
                start.x -= style.barWidth;
            }
            finish.x = start.x;
        } else { // left side
            start.x = style.borderWidth + (pointIndex-12+0.5)*pointSeparation;
            if (pointIndex > 17) {
                start.x += style.barWidth;
            }
            finish.x = start.x;
        }

        if (p1Corner == Corner.BR || p1Corner == Corner.BL) {
            // Invert the y axis
            start.y = style.boardHeight - start.y;
            finish.y = style.boardHeight - finish.y;
        }

        if (p1Corner == Corner.BL || p1Corner == Corner.TL) {
            // Invert the x axis
            start.x = style.boardWidth - start.x;
            finish.x = style.boardWidth - finish.x;
        }

        return [start, finish];
    }

    ScreenPoint getPipPosition(uint pointNum, uint pipNum) {
        assert (1 <= pointNum && pointNum <= 24);
        if (!pipNum) {
            throw new Exception("errrr");
        }
        pointNum--;
        pipNum--;
        auto pointPosition = getPointPosition(pointNum+1);
        double pointY = style.borderWidth + ((2 * pipNum + 1) * style.pipRadius);
        if (pointPosition[0].y > pointPosition[1].y) {
            pointY = style.boardHeight - pointY;
        }

        return ScreenPoint(pointPosition[0].x, pointY);
    }

    ScreenPoint getTakenPipPosition(Player player, uint pipNum) {
        assert(pipNum && pipNum <= 20);
        float pointX = style.boardWidth / 2;
        float pointY = style.boardHeight / 2 - (pipNum+1)*style.pipRadius;
        if (player == Player.P2) pointY = style.boardHeight - pointY;
        return ScreenPoint(pointX, pointY);
    }

    /**
     * Return the x-coordinate boundaries of the bar
     */
    double[2] getBarBoundaries() {
        return [
            (style.boardWidth - style.barWidth) / 2.0,
            (style.boardWidth + style.barWidth) / 2.0
        ];
    }
}
