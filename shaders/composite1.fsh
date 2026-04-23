#version 330 compatibility
#include "/lib/shadowDistort.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex1;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 shadowLightPosition;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform int worldTime;
uniform float rainStrength;

uniform int isEyeInWater;

in vec2 texcoord;
in vec2 lmcoord;


/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

#define GOD_RAY_STEPS 64

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}
vec3 distortShadowClipPos(vec3 pos);

float getShadowVisible(vec3 pos) {
    vec3 shadowViewPos = (shadowModelView * vec4(pos, 1.0)).xyz;
    vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
    vec3 preDistort = shadowClipPos.xyz / shadowClipPos.w;
    if (any(lessThan(preDistort.xy, vec2(-1.0))) || any(greaterThan(preDistort.xy, vec2(1.0)))) {
        return 0.0;
    }
    shadowClipPos.z -= 0.005;
    shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz);
    vec3 shadowNDC = shadowClipPos.xyz / shadowClipPos.w;
    vec3 shadowScreenPos = shadowNDC * 0.5 + 0.5;
    if (any(lessThan(shadowScreenPos.xy, vec2(0.0))) || any(greaterThan(shadowScreenPos.xy, vec2(1.0)))) {
        return 0.0;
    }
    return step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r);
}

bool isNightTime(float worldTime) {
	return worldTime > 12785.0 && worldTime < 23215.0;
}
    
void main() {
    float depthSurface = texture(depthtex0, texcoord).r;
    float depthBehind = texture(depthtex1, texcoord).r;
    bool waterInFront = depthBehind - depthSurface > 0.001;
    
    color = texture(colortex0, texcoord);
    vec2 lightmap = texture(colortex1, texcoord).xy;

    float depth = texture(depthtex0, texcoord).r;

    vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
    vec4 viewPosH = gbufferProjectionInverse * vec4(ndcPos, 1.0);
    vec3 viewPos = viewPosH.xyz / viewPosH.w;
    vec3 pos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    if (depth == 1.0){
        return;
    }

    if (isNightTime(worldTime) || rainStrength > 0.5) {
        return;
    }
    float stepSize = 1.0 / float(GOD_RAY_STEPS);
    float lightAccum = 0.0;
    float decay = 1.0;
    float totalSamples = 0;

    for (int i = 0; i < GOD_RAY_STEPS; i++) {
        float t = stepSize * (float(i)+0.5);
        vec3 samplePos = pos*t;
        float distFade = 1.0 - clamp(length(samplePos)/10.0, 0.0, 1.0);
        float shadowVisible = getShadowVisible(samplePos) * distFade;
        lightAccum += shadowVisible * decay;
        totalSamples += decay;

        decay *= 0.9;
    }
    float avgLight = lightAccum/max(totalSamples, 0.01);
    lightAccum *= 2*(1.0 - rainStrength) * stepSize * (1.0-avgLight*0.8);

    
    color.rgb += vec3(1.0, 0.9, 0.8) * lightAccum * (1-lightmap.y)*5 * (waterInFront ? 0.1 : 1.0) * (isEyeInWater == 1 ? 0.25 : 1.0);
    //color = vec4(vec3(lightmap.y), 1.0);
}
