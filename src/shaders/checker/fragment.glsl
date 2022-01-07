#version 150 core

in vec2 Texcoord;
out vec4 outColor;
uniform float size;


void main()
{
    float white = 0.95;
    float grey = 0.8;
    vec2 pos = floor(Texcoord/size);

    if (mod(pos.x + pos.y, 2.0) == 0) {
        outColor = vec4(grey, grey, grey, 1.0);
    } else {
        outColor = vec4(white, white, white, 1.0);
    }
}