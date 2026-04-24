#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform vec3 sunPosition;

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;
uniform vec3 playerLookVector;


/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 waterNormal;

void main() {
	vec3 lightDir = 0.01 * shadowLightPosition;
	vec3 viewDir = normalize(-playerLookVector);
	float specular = pow(max(dot(reflect(-lightDir, normal), viewDir), 1.0), 1024.0);
	color = texture(gtexture, texcoord) * glcolor;
	color *= texture(lightmap, lmcoord);
	//color = vec4(vec3(specular), 0.0);
	waterNormal = vec4(normal * 0.5 + 0.5, 1.0);
	if (color.a < alphaTestRef) {
		discard;
	}
}