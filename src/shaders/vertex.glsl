#version 150 core

in vec2 position;
in vec2 texcoord;
out vec2 Texcoord;
uniform mat4 ortho;
uniform mat4 origin;
uniform mat4 originInverse;
uniform mat4 translate;
uniform mat4 scale;

void main()
{
    Texcoord = texcoord;
    gl_Position = ortho * translate * originInverse * scale * origin * vec4(position, 0.0, 1.0);
    // gl_Position = ortho * vec4(position, 0.0, 1.0);
}