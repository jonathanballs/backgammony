module ui.boardgl.style;

import glcore;

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
}

// void glClearColor(RGBA color) {
//     glClearColor(color.r, color.g, color.b, color.a);
// }
