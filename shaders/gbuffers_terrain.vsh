#version 330 compatibility

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;

attribute vec4 mc_Entity;

flat out int mat;

uniform float frameTimeCounter;

uniform mat4 gbufferModelViewInverse;

void main() {

	float distSq = dot(gl_Vertex.xyz, gl_Vertex.xyz);
	vec3 pos = gl_Vertex.xyz;
	if (distSq < 100) {
		vec4 worldPos4 = gbufferModelViewInverse * vec4(gl_Vertex);
		vec3 worldPos = worldPos4.xyz; // w should be ~1.0 for terrain
		

		mat = int(mc_Entity.x + 0.5);
		
		if (mat == 67) { // if this is a plant block and we're rendering the upper half, add some wind sway
			pos.x += 0.1 * sin(frameTimeCounter*2+pos.x*0.5);
			//pos.y += 0.05 * cos(frameTimeCounter+pos.y*0.5)+0.05;
			pos.z += 0.1 * sin(frameTimeCounter*2+pos.z*0.5);
		}
	}
	gl_Position = gl_ModelViewProjectionMatrix * vec4(pos, 1.0);
	//gl_Position.z += 0.01 * sin(frameTimeCounter);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	normal = gl_NormalMatrix * gl_Normal; // this gives us the normal in view space
    normal = mat3(gbufferModelViewInverse) * normal; // this converts the normal to world/player space
}