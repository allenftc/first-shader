#version 330 compatibility

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
void main() {
	float distSq = dot(gl_Vertex.xyz, gl_Vertex.xyz);
	vec3 pos = gl_Vertex.xyz;
	if (distSq < 10000) {
		
		vec3 worldPos = cameraPosition + pos; // w should be ~1.0 for terrain
		//pos.x += 0.1 * sin(frameTimeCounter*2+pos.x);
		pos.y += 0.05 * (cos(frameTimeCounter*2+worldPos.x*2)+sin(frameTimeCounter*2+worldPos.z*2));
		//pos.z += 0.1 * sin(frameTimeCounter*2+pos.z);
		
	}
	gl_Position = gl_ModelViewProjectionMatrix * vec4(pos, 1.0);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
}