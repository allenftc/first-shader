#version 330 compatibility

out vec2 texcoord;

uniform int isEyeInWater;
uniform float frameTimeCounter;

void main() {
  gl_Position = ftransform();

  if (isEyeInWater == 1) {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  } 
  else {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  }
}