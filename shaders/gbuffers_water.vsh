#version 330 compatibility

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 viewPos;

flat out int materialID;

attribute vec4 mc_Entity;

uniform float frameTimeCounter;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelViewInverse;
float wave(float x, float z) {
	return 0.1 * (cos(frameTimeCounter*2+x*2)+sin(frameTimeCounter*2+z*2)+0.1*cos(frameTimeCounter*3+x*8)+0.1*sin(frameTimeCounter*3+z*8)) - 0.2;
}

vec3 getNormal(vec3 pos) {
	float a = 0.1;
	float h0 = 0.0, hx = 0.0, hz = 0.0;
    
    // octave 1 - large slow waves
    h0 += 0.05 * cos(frameTimeCounter*2.0 + pos.x*2.0) + 0.05*sin(frameTimeCounter*2.0 + pos.z*2.0);
    hx += 0.05 * cos(frameTimeCounter*2.0 + (pos.x+a)*2.0) + 0.05*sin(frameTimeCounter*2.0 + pos.z*2.0);
    hz += 0.05 * cos(frameTimeCounter*2.0 + pos.x*2.0) + 0.05*sin(frameTimeCounter*2.0 + (pos.z+a)*2.0);
    
    // octave 2 - medium waves at diagonal
    h0 += 0.02 * cos(frameTimeCounter*3.0 + pos.x*5.0 + pos.z*3.0);
    hx += 0.02 * cos(frameTimeCounter*3.0 + (pos.x+a)*5.0 + pos.z*3.0);
    hz += 0.02 * cos(frameTimeCounter*3.0 + pos.x*5.0 + (pos.z+a)*3.0);
    
    // octave 3 - small fast ripples
    h0 += 0.008 * sin(frameTimeCounter*5.0 + pos.x*12.0) * sin(frameTimeCounter*4.0 + pos.z*12.0);
    hx += 0.008 * sin(frameTimeCounter*5.0 + (pos.x+a)*12.0) * sin(frameTimeCounter*4.0 + pos.z*12.0);
    hz += 0.008 * sin(frameTimeCounter*5.0 + pos.x*12.0) * sin(frameTimeCounter*4.0 + (pos.z+a)*12.0);
    
    float dydx = (hx - h0) / a;
    float dydz = (hz - h0) / a;
	return normalize(vec3(-dydx, 1.0, -dydz));
}

void main() {
	float distSq = dot(gl_Vertex.xyz, gl_Vertex.xyz);
	vec3 pos = gl_Vertex.xyz;
	vec3 viewPos = (gl_ModelViewMatrix*gl_Vertex).xyz;
	vec3 playerFeetPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 worldPos = cameraPosition + playerFeetPos;
	int mat = int(mc_Entity.x + 0.5);
	materialID = mat;
	if (distSq < 1000 && mat == 10002) {
		//pos.x += 0.1 * sin(frameTimeCounter*2+pos.x);
		pos.y += wave(worldPos.x, worldPos.z);
		//pos.z += 0.1 * sin(frameTimeCounter*2+pos.z);
		normal = getNormal(worldPos);
		
	}
	else {
		normal = vec3(0,1,0);
	}
	gl_Position = gl_ModelViewProjectionMatrix * vec4(pos, 1.0);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	glcolor = gl_Color;
	
	viewPos = (gl_ModelViewMatrix*gl_Vertex).xyz;
}