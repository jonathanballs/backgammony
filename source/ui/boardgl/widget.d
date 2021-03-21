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
import ui.boardgl.shaders : Shader, ShaderProgram;
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

    // GLuint shaderProgram;
    GLuint m_Mvp;

    GLuint positionIndex;
    GLuint colorIndex;

    ShaderProgram shaderProgram;
    ShaderProgram aaShaderProgram; // Antialiasing shader

    // Create resources for the display of the widget
    void realize(Widget) {
        makeCurrent();
        shaderProgram = new ShaderProgram([
            new Shader(GL_VERTEX_SHADER, import("vertex.glsl")),
            new Shader(GL_FRAGMENT_SHADER, import("fragment.glsl"))
        ]);
        aaShaderProgram = new ShaderProgram([
            new Shader(GL_VERTEX_SHADER, import("antialiasing/vertex.glsl")),
            new Shader(GL_FRAGMENT_SHADER, import("antialiasing/fragment.glsl"))
        ]);

        positionIndex = shaderProgram.getAttribLocation("position");
        colorIndex = shaderProgram.getAttribLocation("color");
        m_Mvp = shaderProgram.getUniformLocation("mvp");

        gameBoard = new GameBoard(shaderProgram);
        gameBoard.upload();

        this.enableAA();

        glUniform1i(aaShaderProgram.getUniformLocation("screenTexture"), 0);
    }

    // Destroy resources for the display of the widget
    void unrealize(Widget) {
        makeCurrent();
        shaderProgram.deleteProgram();
    }

    bool render(GLContext c, GLArea a) {
        int glareaFramebuffer;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &glareaFramebuffer);

        this.monitorFPS();

        // Draw scene to the framebuffer
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glClearColor(0.3, 0.3, 0.3, 1);
        glClear(GL_COLOR_BUFFER_BIT);

        shaderProgram.useProgram();

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

        // 2. now blit multisampled buffer(s) to normal colorbuffer of intermediate FBO. Image is stored in screenTexture
        glBindFramebuffer(GL_READ_FRAMEBUFFER, framebuffer);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, intermediateFBO);
        glBlitFramebuffer(0, 0, getAllocatedWidth(), getAllocatedHeight(),
            0, 0, getAllocatedWidth(), getAllocatedHeight(),
            GL_COLOR_BUFFER_BIT, GL_NEAREST);

        // 3. now render quad with scene's visuals as its texture image
        glBindFramebuffer(GL_FRAMEBUFFER, glareaFramebuffer);
        glClearColor(1.0f, 1.0f, 1.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glDisable(GL_DEPTH_TEST);

        // draw Screen quad
        aaShaderProgram.useProgram();

        glBindVertexArray(quadVAO);
        glEnableVertexAttribArray(aaShaderProgram.getAttribLocation("aPos"));
        glEnableVertexAttribArray(aaShaderProgram.getAttribLocation("aTexCoords"));

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, screenTexture); // use the now resolved color attachment as the quad's texture
        glDrawArrays(GL_TRIANGLES, 0, 6);

        this.queueRender();

        return true;
    }

    uint rbo;
    uint textureColorBufferMultiSampled;
    uint framebuffer;
    uint intermediateFBO;
    uint screenTexture;
    uint quadVAO;
    uint quadVBO;

    float[] quadVertices = [
        // positions   // texCoords
        -1.0f,  1.0f,  0.0f, 1.0f,
        -1.0f, -1.0f,  0.0f, 0.0f,
        1.0f, -1.0f,  1.0f, 0.0f,

        -1.0f,  1.0f,  0.0f, 1.0f,
        1.0f, -1.0f,  1.0f, 0.0f,
        1.0f,  1.0f,  1.0f, 1.0f
    ];

    // Stolen from https://learnopengl.com/Advanced-OpenGL/Anti-Aliasing Ideally
    // GTK4 will support AA out of the box at some point so I will just use that
    // once it's available: https://gitlab.gnome.org/GNOME/gtk/-/issues/2616
    void enableAA() {

        // setup screen VAO
        glGenVertexArrays(1, &quadVAO);
        glGenBuffers(1, &quadVBO);
        glBindVertexArray(quadVAO);
        glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
        glBufferData(GL_ARRAY_BUFFER, quadVertices.length * float.sizeof, quadVertices.ptr, GL_STATIC_DRAW);
        glEnableVertexAttribArray(aaShaderProgram.getAttribLocation("aPos"));
        glVertexAttribPointer(aaShaderProgram.getAttribLocation("aPos"),
            2, GL_FLOAT, GL_FALSE, 4 * float.sizeof, cast(void*)0);
        glEnableVertexAttribArray(aaShaderProgram.getAttribLocation("aPos"));
        glVertexAttribPointer(aaShaderProgram.getAttribLocation("aTexCoords"),
            2, GL_FLOAT, GL_FALSE, 4 * float.sizeof, cast(void*)(2 * float.sizeof));

        auto SCR_WIDTH = getAllocatedWidth();
        auto SCR_HEIGHT = getAllocatedHeight();
        // configure MSAA framebuffer
        // --------------------------
        glGenFramebuffers(1, &framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);

        // create a multisampled color attachment texture
        glGenTextures(1, &textureColorBufferMultiSampled);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, textureColorBufferMultiSampled);
        glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, 4, GL_RGB, SCR_WIDTH, SCR_HEIGHT, GL_TRUE);
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D_MULTISAMPLE, textureColorBufferMultiSampled, 0);

        // create a (also multisampled) renderbuffer object for depth and stencil attachments
        glGenRenderbuffers(1, &rbo);
        glBindRenderbuffer(GL_RENDERBUFFER, rbo);
        glRenderbufferStorageMultisample(GL_RENDERBUFFER, 4, GL_DEPTH24_STENCIL8, SCR_WIDTH, SCR_HEIGHT);
        glBindRenderbuffer(GL_RENDERBUFFER, 0);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo);

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            writeln("ERROR::FRAMEBUFFER:: Framebuffer is not complete!");

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        
        // configure second post-processing framebuffer
        glGenFramebuffers(1, &intermediateFBO);
        glBindFramebuffer(GL_FRAMEBUFFER, intermediateFBO);
        // create a color attachment texture
        glGenTextures(1, &screenTexture);
        glBindTexture(GL_TEXTURE_2D, screenTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, SCR_WIDTH, SCR_HEIGHT, 0, GL_RGB, GL_UNSIGNED_BYTE, null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, screenTexture, 0);	// we only need a color buffer

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            writeln("ERROR::FRAMEBUFFER:: Intermediate framebuffer is not complete!");
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
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
