#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
 uniform vec3 fogColor;
 uniform float far;
 uniform int worldTime;

in vec2 texcoord;

const int FOG_DENSITY = 5;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}
float getDaylightMultiplier(float worldTime) {
	const float transition = 1500;
	float sunsetFade = smoothstep(12785.0 - transition, 12785.0 + transition, worldTime);
	float sunriseFade = smoothstep(23215.0 - transition, 23215.0 + transition, worldTime);
	return clamp(1 - sunsetFade + sunriseFade, 0.0, 1.0);
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
  color = texture(colortex0, texcoord);

  float depth = texture(depthtex0, texcoord).r;
  if (depth == 1.0){
    return;
  }

  vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
  vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);

   float dist = length(viewPos) / far;
 float fogFactor = exp(-FOG_DENSITY * (1.0 - dist));


    color.rgb = mix(color.rgb, pow(vec3(0.7,0.6,0.6) * getDaylightMultiplier(worldTime), vec3(2.2)), clamp(fogFactor, 0.0, 1.0));
}