#version 330 compatibility

uniform sampler2D gtexture;

uniform float alphaTestRef = 0.1;

in vec2 texcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = vec4(texture(gtexture, texcoord).rgb, 0.25) * glcolor;
	if (color.a < alphaTestRef) {
		discard;
	}
}