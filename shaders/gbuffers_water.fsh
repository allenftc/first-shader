#version 330 compatibility

uniform sampler2D lightmap;
uniform sampler2D gtexture;
uniform sampler2D depthtex1;
uniform sampler2D colortex3;
uniform vec3 shadowLightPosition;
uniform vec3 skyColor;
uniform vec3 sunPosition;

uniform float alphaTestRef = 0.1;

uniform mat4 gbufferModelViewInverse;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
uniform vec3 playerLookVector;
uniform mat4 gbufferProjection;

flat in int materialID;


/* RENDERTARGETS: 0,3 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 waterNormal;



void main() {
	vec3 lightDir = 0.01 * shadowLightPosition;
	vec3 viewDir = normalize(-playerLookVector);
	
	color = texture(gtexture, texcoord) * glcolor;
	color *= texture(lightmap, lmcoord);

	if (materialID == 10003) {
		color.a = 1.0;
	}

	
	if (color.a < alphaTestRef) {
		discard;
	}
	float reflectivity = materialID == 10002 ? 1 : 0.15;
	vec3 worldNormal = normalize((gbufferModelViewInverse * vec4(normal, 0.0)).xyz);
	waterNormal = vec4(worldNormal * 0.5 + 0.5, reflectivity);
	
}