module ui.boardgl.shaders;

import glcore;
import std.format;
import std.stdio;

/**
 * An OpenGL shader
 */
class Shader {
    private:
    string source;
    bool isCompiled;

    GLenum shaderType;
    GLuint shaderObject;

    public this(GLenum shaderType, string source) {
        this.shaderType = shaderType;
        this.source = source ~ "\0";
        this.isCompiled = false;

        const shader = glCreateShader(shaderType);
        // scope (failure) glDeleteShader(shader);
        const(char)* srcPtr = source.ptr;
        glShaderSource(shader, 1, &srcPtr, null);
        glCompileShader(shader);

        int status;
        glGetShaderiv(shader, GL_COMPILE_STATUS, &status);

        if (status == GL_FALSE)
        {
            int len;
            glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &len);

            char[] buffer;
            buffer.length = len + 1;
            glGetShaderInfoLog(shader, len, null, buffer.ptr);

            const sType = shaderType == GL_VERTEX_SHADER ? "vertex" : "fragment";

            throw new Exception(format("Compilation failure in %s shader: %s", sType, buffer));
        }

        this.shaderObject = shader;
        // scope (exit) glDeleteShader(this.shaderObject);

        isCompiled = true;
    }
}

/**
 * A shader program consisting of multiple shaders
 */
class ShaderProgram {
    Shader[] shaders;
    GLuint programObject;

    this(Shader[] shaders) {
        this.programObject = glCreateProgram();

        foreach(shader; shaders) {
            glAttachShader(this.programObject, shader.shaderObject);
            // scope (exit) glDetachShader(programObject, shader.shaderObject);
        }

        glLinkProgram(this.programObject);

        int status = 0;
        glGetProgramiv(this.programObject, GL_LINK_STATUS, &status);

        if (status == GL_FALSE) {
            int len = 0;
            glGetProgramiv(this.programObject, GL_INFO_LOG_LENGTH, &len);

            char[] buffer;
            buffer.length = len + 1;
            glGetProgramInfoLog(this.programObject, len, null, buffer.ptr);

            glDeleteProgram(this.programObject);

            throw new Exception(format("Linking failure in program: %s", buffer));
        }
    }

    uint getUniformLocation(string uniformName) {
        const(char)* srcPtr = uniformName.ptr;
        return glGetUniformLocation(this.programObject, srcPtr);
    }

    uint getAttribLocation(string attribName) {
        const(char)* srcPtr = attribName.ptr;
        return glGetAttribLocation(this.programObject, srcPtr);
    }

    void deleteProgram() {
        glDeleteProgram(this.programObject);
    }

    void useProgram() {
        glUseProgram(this.programObject);
    }
}
