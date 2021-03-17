module ui.boardgl.widget;

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

import ui.boardgl.gameboard;

class BoardGLWidget : GLArea {

    this() {
        setAutoRender(true);

        addEvents(GdkEventMask.BUTTON_PRESS_MASK);
        addEvents(GdkEventMask.SCROLL_MASK);

        addOnRender(&render);
        addOnRealize(&realize);
        addOnUnrealize(&unrealize);

        showAll();

        this.style = new BoardStyle();
    }

    private:

    // FPS monitoring
    SysTime lastFrameStartRender;
    float smoothedFPS;

    GameBoard gameBoard;
    BoardStyle style;

    GLuint shaderProgram;
    GLuint m_Mvp;

    GLuint positionIndex;
    GLuint colorIndex;

    // Create resources for the display of the widget
    void realize(Widget) {
        makeCurrent();
        initShaders(&shaderProgram, &m_Mvp, &positionIndex, &colorIndex);

        gameBoard = new GameBoard(shaderProgram);
        gameBoard.upload();
    }

    // Destroy resources for the display of the widget
    void unrealize(Widget) {
        makeCurrent();
        glDeleteProgram(shaderProgram);
    }

    bool render(GLContext c, GLArea a) {
        this.monitorFPS();

        makeCurrent();
        glClearColor(0.3, 0.3, 0.3, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(shaderProgram);


        // Update translation matrix
        const float aspectRatio = cast(float) getAllocatedWidth() / getAllocatedHeight();
        const float desiredAspectRatio = cast(float) this.style.boardWidth / this.style.boardHeight;

        auto mvp = mat4.identity
            .scale(2.0 / style.boardWidth, 2.0 / style.boardHeight, 1.0)
            .translate(-1.0, -1.0, 0.0);

        if (aspectRatio > desiredAspectRatio) {
            mvp = mvp.scale(desiredAspectRatio / aspectRatio, 1.0, 1.0);
        } else {
            mvp = mvp.scale(1.0, aspectRatio / desiredAspectRatio, 1.0);
        }
        glUniformMatrix4fv(m_Mvp, 1, GL_TRUE, mvp.value_ptr);

        gameBoard.draw();

        // glDisableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glUseProgram(0);

        glFlush();

        this.queueRender();

        return true;
    }

    void monitorFPS() {
        auto currTime = Clock.currTime();
        if (this.lastFrameStartRender != SysTime.init) {
            auto diff = currTime - this.lastFrameStartRender;
            auto fps = 1.seconds / diff;
            // writeln(fps);
        }
        this.lastFrameStartRender = currTime;
    }
}
