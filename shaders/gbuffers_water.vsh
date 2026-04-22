#version 330 compatibility

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 viewPos;

attribute vec4 mc_Entity;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
float wave(float x, float z) {
	return 0.067 * (cos(frameTimeCounter*2+x*2)+sin(frameTimeCounter*2+z*2)+0.5*cos(frameTimeCounter*3+x*8)+0.5*sin(frameTimeCounter*3+z*8));
}

void main() {
	float distSq = dot(gl_Vertex.xyz, gl_Vertex.xyz);
	vec3 pos = gl_Vertex.xyz;
	vec3 viewPos = (gl_ModelViewMatrix*gl_Vertex).xyz;
	vec3 playerFeetPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 worldPos = cameraPosition + playerFeetPos;
	int mat = int(mc_Entity.x + 0.5);
	if (distSq < 1000 && mat == 10002) {
		//pos.x += 0.1 * sin(frameTimeCounter*2+pos.x);
		pos.y += wave(worldPos.x, worldPos.z);
		//pos.z += 0.1 * sin(frameTimeCounter*2+pos.z);
		
	}
	gl_Position = gl_ModelViewProjectionMatrix * vec4(pos, 1.0);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	float a = 0.1;
	float dydx = wave(worldPos.x+a, worldPos.z) - wave(worldPos.x-a, worldPos.z);
	float dydz = wave(worldPos.x, worldPos.z+a) - wave(worldPos.x, worldPos.z-a);
	normal = normalize(vec3(-dydx, 1.0, -dydz));
	viewPos = (gl_ModelViewMatrix*gl_Vertex).xyz;
}