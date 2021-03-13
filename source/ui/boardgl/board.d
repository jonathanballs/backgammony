module ui.boardgl.board;

import std.string;
import std.datetime;
import std.stdio;

import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
import gdk.GLContext;
import gtk.DrawingArea;
import gtk.GLArea;
import gtk.Widget;

import glcore;
import ui.boardgl.shaders : initShaders;
import ui.boardgl.style : BoardStyle;
import gl3n.linalg;

class BoardGL : GLArea {

    // FPS monitoring
    SysTime lastFrameStartRender;
    float smoothedFPS;

public:
    this() {
        setAutoRender(true);

        addEvents(GdkEventMask.BUTTON_PRESS_MASK);
        addEvents(GdkEventMask.SCROLL_MASK);

        addOnRender(&render);
        addOnRealize(&realize);
        addOnUnrealize(&unrealize);

        showAll();
    }

    GLuint m_Vao;
    GLuint m_Program;
    GLuint m_Mvp;

    GLuint position_index;
    GLuint positionBuffer;
    GLuint color_index;
    GLuint colorBuffer;

    // Create resources for the display of the widget
    void realize(Widget) {
        makeCurrent();
        initShaders(&m_Program, &m_Mvp, &position_index, &color_index);
        initBuffers(position_index, color_index);
    }

    // Destroy resources for the display of the widget
    void unrealize(Widget) {
        makeCurrent();
        glDeleteBuffers(1, &m_Vao);
        glDeleteProgram(m_Program);
    }

    bool render(GLContext c, GLArea a) {
        auto currTime = Clock.currTime();
        if (this.lastFrameStartRender != SysTime.init) {
            auto diff = currTime - this.lastFrameStartRender;
            auto fps = 1.seconds / diff;
            // writeln(fps);
        }
        this.lastFrameStartRender = currTime;
        makeCurrent();

        glClearColor(0.3, 0.3, 0.3, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        drawTriangle();

        glFlush();

        this.queueRender();

        return true;
    }

    void drawTriangle() {
        immutable mvp = mat4.identity;

        // Use shaders
        glUseProgram(m_Program);

        // Update the "mvp" matrix we use in the shader
        glUniformMatrix4fv(m_Mvp, 1, GL_FALSE, mvp.value_ptr);

        glBindBuffer(GL_ARRAY_BUFFER, m_Vao);

        // Set triangle colour
        // GLint uniColor = glGetUniformLocation(m_Program, "color");
        // writeln(uniColor);
        // glUniform3f(uniColor, 1.0f, 0.0f, 0.0f);
        // float[3] color = [1.0, 0.0, 0.0];
        glBindBuffer(GL_ARRAY_BUFFER, positionBuffer);
        glEnableVertexAttribArray(position_index);
        glVertexAttribPointer(position_index, 4, GL_FLOAT, GL_FALSE, 0, null);

        glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
        glEnableVertexAttribArray(color_index);
        glVertexAttribPointer(color_index, 3, GL_FLOAT, GL_FALSE, 0, null);

        // draw the three vertices as a triangle
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glDisableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glUseProgram(0);
    }

    void initBuffers(uint position_index, uint color_index) {
        // Vertex data of the triangle.
        static immutable GLfloat[] vertex_data = [
            0.0f, 0.5f, 0.0f, 1.0f,
            0.5f, -0.366f, 0.0f, 1.0f,
            -0.5f, -0.366f, 0.0f, 1.0f,

            0.1f, 0.5f, 0.0f, 1.0f,
            0.5f, -0.366f, 0.0f, 1.0f,
            -0.5f, -0.366f, 0.0f, 1.0f,
        ];

        static immutable GLfloat[] color_data = [
            1.0f, 0.0f, 0.0f,
            1.0f, 0.0f, 0.0f,
            1.0f, 0.0f, 0.0f,
            0.0f, 1.0f, 0.0f,
            0.0f, 1.0f, 0.0f,
            0.0f, 1.0f, 0.0f,
        ];

        // Create a VAO to store the other buffers
        glGenVertexArrays(1, &m_Vao);
        glBindVertexArray(m_Vao);

        // VBO that holds the vertex data. Upload data to the GPU.
        glGenBuffers(1, &positionBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, positionBuffer);
        glBufferData(GL_ARRAY_BUFFER, vertex_data.length * float.sizeof,
                vertex_data.ptr, GL_STATIC_DRAW);
        
        glGenBuffers(1, &colorBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, colorBuffer);
        glBufferData(GL_ARRAY_BUFFER, color_data.length * float.sizeof,
                color_data.ptr, GL_STATIC_DRAW);
    }
}
