module ui.boardgl.gameboard;

import glcore;
import gl3n.linalg;

import ui.boardgl.style;


/**
 * Code for rendering the backgammon board (minus pips, dice etc.)
 */
class GameBoard {
    private:

    bool buffersUploaded;

    GLfloat[] vertexData;
    GLfloat[] colorData;

    GLint vertexAttrib;
    GLuint vertexBuffer;
    GLint colorAttrib;
    GLuint colorBuffer;

    GLuint vao;

    BoardStyle style;

    public:

    /// Create a new instance of the game board
    this(GLuint shaderProgram) {
        vertexAttrib = glGetAttribLocation(shaderProgram, "position");
        colorAttrib = glGetAttribLocation(shaderProgram, "color");
        style = new BoardStyle();
    }

    ~this() {
        glDeleteBuffers(1, &vao);
    }

    void upload() {
        // Main board
        prepareRectangle(0, 0, style.boardWidth, style.boardHeight, style.borderColor);

        // Home board and outer board
        prepareRectangle(
            2*style.borderWidth + style.pipHolderWidth,
            style.borderWidth,
            style.boardWidth / 2 - 2*style.borderWidth - style.barWidth/2 - style.pipHolderWidth,
            style.boardHeight - style.borderWidth*2,
            style.boardColor
            );
        prepareRectangle(
            style.boardWidth / 2 + style.barWidth/2,
            style.borderWidth,
            style.boardWidth / 2 - 2*style.borderWidth - style.barWidth/2 - style.pipHolderWidth,
            style.boardHeight - style.borderWidth*2,
            style.boardColor
            );

        // Pip holders
        prepareRectangle( // BL
            style.borderWidth,
            style.borderWidth,
            style.pipHolderWidth,
            style.boardHeight/2 - style.barWidth/2 - style.borderWidth,
            style.boardColor
        );
        prepareRectangle( // TL
            style.borderWidth,
            style.boardHeight / 2 + style.barWidth/2,
            style.pipHolderWidth,
            style.boardHeight/2 - style.barWidth/2 - style.borderWidth,
            style.boardColor
        );
        prepareRectangle( // TR
            style.boardWidth - style.borderWidth - style.pipHolderWidth,
            style.boardHeight / 2 + style.barWidth/2,
            style.pipHolderWidth,
            style.boardHeight/2 - style.barWidth/2 - style.borderWidth,
            style.boardColor
        );
        prepareRectangle( // BR
            style.boardWidth - style.borderWidth - style.pipHolderWidth,
            style.borderWidth,
            style.pipHolderWidth,
            style.boardHeight/2 - style.barWidth/2 - style.borderWidth,
            style.boardColor
        );

        // Create VAO
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);

        // Create buffers to hold vertices and color data
        glGenBuffers(1, &vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, vertexData.length * float.sizeof,
                vertexData.ptr, GL_STATIC_DRAW);
        glEnableVertexAttribArray(vertexAttrib);
        glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

        glGenBuffers(1, &colorBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
        glBufferData(GL_ARRAY_BUFFER, colorData.length * float.sizeof,
                colorData.ptr, GL_STATIC_DRAW);
        glEnableVertexAttribArray(colorAttrib);
        glVertexAttribPointer(colorAttrib, 4, GL_FLOAT, GL_FALSE, 0, null);

        glBindVertexArray(0);
    }

    void draw() {
        glBindVertexArray(vao);
        glEnableVertexAttribArray(vertexBuffer);
        glEnableVertexAttribArray(colorBuffer);

        // Draw the triangles
        glDrawArrays(GL_TRIANGLES, 0, cast(int) vertexData.length / 3);

        glBindVertexArray(0);
    }

    private void prepareTriangle(vec3 p1, vec3 p2, vec3 p3, RGBA color) {
        vertexData ~= [
            p1.x, p1.y, p1.z,
            p2.x, p2.y, p2.z,
            p3.x, p3.y, p3.z
        ];

        colorData ~= [
            color.r, color.g, color.b, color.a,
            color.r, color.g, color.b, color.a,
            color.r, color.g, color.b, color.a
        ];
    }

    private void prepareRectangle(float x, float y, float width, float height, RGBA color) {
        vec3 bl = vec3(x, y, 0.0);
        vec3 br = vec3(x+width, y, 0.0);
        vec3 tl = vec3(x, y+height, 0.0);
        vec3 tr = vec3(x+width, y+height, 0.0);

        prepareTriangle(bl, br, tr, color);
        prepareTriangle(bl, tl, tr, color);
    }
}
