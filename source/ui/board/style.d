module ui.board.style;

import cairo.Context;

struct RGB {
    float r, g, b;
}

static void setSourceRgbStruct(Context cr, RGB color) {
    cr.setSourceRgb(color.r, color.g, color.b);
}

/**
 * The layout of the board. Measurements are all relative as the board will
 * resize to fit its layout
 */
class BoardStyle {
    float boardWidth = 1200.0;          /// Width of the board.
    float boardHeight = 800.0;          /// Height of the board
    RGB boardColor = RGB(0.18, 0.204, 0.212); /// Board background colour 

    float borderWidth = 15.0;           /// Width of the border enclosing the board
    float borderFontHeight = 10.0;      /// Height of the font of the board numbers
    float barWidth = 70.0;              /// Width of bar in the centre of the board
    RGB borderColor = RGB(0.14969, 0.15141, 0.15141); /// Colour of the border

    float pointWidth = 75.0;            /// Width of each point
    float pointHeight = 300.0;          /// Height of each point
    RGB lightPointColor = RGB(0.546875, 0.390625, 0.167969); /// Colour of light points
    RGB darkPointColor = RGB(0.171875, 0.2421875, 0.3125);   /// Colour of dark points

    float pipRadius = 30.0;             /// Radius of pips
    float pipBorderWidth = 3.0;         /// Width of pip border
    RGB p1Colour = RGB(0.0, 0.0, 0.0);  /// Colour of player 1's pips
    RGB p2Colour = RGB(1.0, 1.0, 1.0);  /// Colour of player 2's pips

    double messageRadius = 15.0;
    double messagePadding = 30.0;
    double messageFontSize = 30.0;
    long animationSpeed = 750;          /// Msecs to perform animation
}
