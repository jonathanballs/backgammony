/**
 * Code for rendering the backgammon board (minus pips, dice etc.)
 */
module ui.boardgl.gameboard;

import glcore;

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

    // Create a new instance of the game board
    public this() {
    }

    void uploadBuffers() {
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
}
