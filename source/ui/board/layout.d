module ui.board.layout;

import std.typecons;

import ui.board.style;
import game : Player;

struct ScreenCoords {
    float x;
    float y;
}

mixin template BoardLayout() {
    /**
     * Returns a tuple containing the bottom (centre) and top of the points
     * position. By default we will be starting at top right.
     * Params:
     *      pointIndex = point number between 0 and 23
     */
    Tuple!(ScreenCoords, ScreenCoords) getPointPosition(uint pointIndex) {
        // Calculate for TR and then modify at the end
        assert (1 <= pointIndex && pointIndex <= 24);
        pointIndex--;

        ScreenCoords start;
        ScreenCoords finish;

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

        return tuple(start, finish);
    }

    ScreenCoords getPipPosition(uint pointNum, uint pipNum) {
        assert (1 <= pointNum && pointNum <= 24);
        // assert (pipNum);
        if (!pipNum) {
            writeln(getGameState.currentPlayer());
            writeln(pointNum, " ", getGameState.points[pointNum]);
            writeln(transitionStack);
            writeln("frameTime: ", frameTime);
            throw new Exception("errrr");
        }
        pointNum--;
        pipNum--;
        auto pointPosition = getPointPosition(pointNum+1);
        double pointY = style.borderWidth + ((2 * pipNum + 1) * style.pipRadius);
        if (pointPosition[0].y > pointPosition[1].y) {
            pointY = style.boardHeight - pointY;
        }

        return ScreenCoords(pointPosition[0].x, pointY);
    }

    ScreenCoords getTakenPipPosition(Player player, uint pipNum) {
        assert(pipNum && pipNum <= 20);
        float pointX = style.boardWidth / 2;
        float pointY = style.boardHeight / 2 - (pipNum+1)*style.pipRadius;
        if (player == Player.P2) pointY = style.boardHeight - pointY;
        return ScreenCoords(pointX, pointY);
    }
}