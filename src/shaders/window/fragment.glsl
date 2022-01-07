#version 150 core

in vec2 Texcoord;
out vec4 outColor;
uniform float opacity;

uniform sampler2D tex;

void main()
{
    vec4 color = texture(tex, Texcoord);
    outColor = vec4(color[2]/color[3], color[1]/color[3], color[0]/color[3], opacity*color[3]);
}