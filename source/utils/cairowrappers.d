module utils.cairowrappers;

import cairo.Context;
import cairo.Matrix;
import ui.board.layout : ScreenPoint;

/**
 * Return the transformation matrix of cairo context
 */
Matrix getMatrix(Context cr) {
    cairo_matrix_t* tm = new cairo_matrix_t;
    auto matrix = new Matrix(tm);
    cr.getMatrix(matrix);
    return matrix;
}

/**
 * Duplicate a cairo matrix
 */
Matrix duplicateMatrix(Matrix m) {
    cairo_matrix_t* tm = new cairo_matrix_t;
    *tm = *m.getMatrixStruct();
    auto matrix = new Matrix(tm);
    return matrix;
}

/**
 * Transform coordinates
 */
ScreenPoint transformCoordinates(Matrix m, ScreenPoint sc) {
    double x = sc.x;
    double y = sc.y;
    m.transformPoint(x, y);

    return ScreenPoint(x, y);
}

/**
 * Convert the distance according to the matrix transform
 */
double transformDistance(Matrix m, double d) {
    double z = 0;
    m.transformDistance(d, z);
    return d;
}
