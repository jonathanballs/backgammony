module ui.boardgl.shaders;

import glcore;
import std.format;

immutable FragShaderCode = import("fragment.glsl");
immutable VertShaderCode = import("vertex.glsl");

uint compileShader(int type, string source) {
    const shader = glCreateShader(type);
    scope (failure)
        glDeleteShader(shader);
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

        const sType = type == GL_VERTEX_SHADER ? "vertex" : "fragment";

        throw new Exception(format("Compilation failure in %s shader: %s",
                sType, buffer));
    }

    return shader;
}

void initShaders(uint* program_out, uint* mvp_location_out,
        uint* position_location_out, uint* color_location_out) {
    const vertex = compileShader(GL_VERTEX_SHADER, VertShaderCode ~ "\0");
    scope (exit) glDeleteShader(vertex);

    const fragment = compileShader(GL_FRAGMENT_SHADER, FragShaderCode ~ "\0");
    scope (exit) glDeleteShader(fragment);

    const program = glCreateProgram();

    glAttachShader(program, vertex);
    scope (exit) glDetachShader(program, vertex);

    glAttachShader(program, fragment);
    scope (exit) glDetachShader(program, fragment);

    glLinkProgram(program);

    int status = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &status);

    if (status == GL_FALSE) {
        int len = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &len);

        char[] buffer;
        buffer.length = len + 1;
        glGetProgramInfoLog(program, len, null, buffer.ptr);

        glDeleteProgram(program);

        throw new Exception(format("Linking failure in program: %s",
                buffer));
    }

    *program_out = program;

    *mvp_location_out = glGetUniformLocation(program, "mvp");
    *position_location_out = glGetAttribLocation(program, "position");
    *color_location_out = glGetAttribLocation(program, "color");
}