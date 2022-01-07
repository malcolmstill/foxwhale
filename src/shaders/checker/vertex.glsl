#version 150 core

in vec2 position;
in vec2 texcoord;
out vec2 Texcoord;
uniform mat4 ortho;

void main()
{
    Texcoord = position.xy + 0.000001 * texcoord;
    gl_Position = ortho * vec4(position, 0.0, 1.0);
}