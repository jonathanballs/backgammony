module ui.boardgl.gameboard;

import glcore;
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

    public:

    /// Create a new instance of the game board
    this(GLuint shaderProgram) {
        vertexAttrib = glGetAttribLocation(shaderProgram, "position");
        colorAttrib = glGetAttribLocation(shaderProgram, "color");
    }

    ~this() {
        glDeleteBuffers(1, &vao);
    }

    void upload() {
        vertexData = [
            0.0f, 0.0f, 0.0f,
            1200.0f, 0.0f, 0.0f,
            1200.0f, 800.0f, 0.0f,
        ];

        colorData = [
            1.0f, 0.0f, 0.0f,
            1.0f, 0.0f, 0.0f,
            1.0f, 0.0f, 0.0f,
        ];

        // Create a VAO to store the other buffers
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);

        // VBO that holds the vertex data. Upload data to the GPU.
        glGenBuffers(1, &vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, vertexData.length * float.sizeof,
                vertexData.ptr, GL_STATIC_DRAW);
        
        glGenBuffers(1, &colorBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
        glBufferData(GL_ARRAY_BUFFER, colorData.length * float.sizeof,
                colorData.ptr, GL_STATIC_DRAW);
    }

    void draw() {
        glBindBuffer(GL_ARRAY_BUFFER, vao);

        // Bind position and color buffers
        glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
        glEnableVertexAttribArray(vertexAttrib);
        glVertexAttribPointer(vertexAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

        glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
        glEnableVertexAttribArray(colorAttrib);
        glVertexAttribPointer(colorAttrib, 3, GL_FLOAT, GL_FALSE, 0, null);

        // Draw the triangles
        glDrawArrays(GL_TRIANGLES, 0, 3);

        glDisableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glUseProgram(0);
    }
}
