module ui.boardgl.style;

import glcore;
import gl3n.linalg;

import std.conv : to;

/**
 * A struct holding RGBA color data
 */
struct RGBA {
    float r, g, b, a;
}

/**
 * The layout of the board. Measurements are all relative as the board will
 * resize to fit its layout
 */
class BoardStyle {
    float boardWidth = 1200.0;          /// Width of the board.
    float boardHeight = 800.0;          /// Height of the board
    RGBA boardColor = RGBA(0.18, 0.204, 0.212, 1.0); /// Board background colour 

    float borderWidth = 15.0;           /// Width of the border enclosing the board
    float borderFontHeight = 10.0;      /// Height of the font of the board numbers
    float barWidth = 70.0;              /// Width of bar in the centre of the board
    float pipHolderWidth = 60.0;
    RGBA borderColor = RGBA(0.14969, 0.15141, 0.15141, 1.0); /// Colour of the border

    float pointWidth = 75.0;            /// Width of each point
    float pointHeight = 300.0;          /// Height of each point
    RGBA lightPointColor = RGBA(0.546875, 0.390625, 0.167969, 1.0); /// Colour of light points
    RGBA darkPointColor = RGBA(0.171875, 0.2421875, 0.3125, 1.0);   /// Colour of dark points

    float pipRadius = 30.0;             /// Radius of pips
    float pipBorderWidth = 3.0;         /// Width of pip border
    RGBA p1Colour = RGBA(0.0, 0.0, 0.0, 1.0);  /// Colour of player 1's pips
    RGBA p2Colour = RGBA(1.0, 1.0, 1.0, 1.0);  /// Colour of player 2's pips

    double messageRadius = 15.0;
    double messagePadding = 30.0;
    double messageFontSize = 30.0;
    long animationSpeed = 750;          /// Msecs to perform animation

    /**
     * Return the position of a point on the board. The array returned 
     */
    vec2[2] pointPosition(int position) {
        if (position < 1 || position > 24) {
            throw new Exception("Tried to get position of point number " ~ position.to!string);
        }

        vec2 base = vec2(0.0, 0.0);

        float halfBoardWidth = this.boardWidth / 2 - 2*this.borderWidth - this.barWidth/2 - this.pipHolderWidth;

        if (position <= 12) {
            base.x = this.boardWidth - 2*this.borderWidth - this.pipHolderWidth - position*halfBoardWidth/6 + halfBoardWidth/12;
            base.y = this.borderWidth;
            if (position > 6) {
                base.x -= this.barWidth;
            }
            vec2 tip = vec2(base.x, base.y + this.pointHeight);

            return [base, tip];
        } else {
            position -= 12;
            base.x = 2*this.borderWidth + this.pipHolderWidth + position*halfBoardWidth/6 - halfBoardWidth/12;
            base.y = this.boardHeight - this.borderWidth;
            if (position > 6) {
                base.x += this.barWidth;
            }
            vec2 tip = vec2(base.x, base.y - this.pointHeight);

            return [base, tip];
        }
    }
}

