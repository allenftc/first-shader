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
uniform mat4 gbufferProjection;
uniform int worldTime;
uniform float rainStrength;
uniform float frameTimeCounter;

uniform int isEyeInWater;
uniform float rainfall;
uniform vec3 skyColor;

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

vec3 raymarchSSR(vec3 viewPos, vec3 dir, out float hitMask, float waterDepth) {
  float stepSize = 0.25;
  vec3 pos = viewPos;
  hitMask = 0.0;

  for (int i = 0; i < 80; i++) {
    pos += dir * stepSize;

    vec4 clip = gbufferProjection * vec4(pos, 1.0);
    clip /= clip.w;
    vec3 screen = clip.xyz * 0.5 + 0.5;

    if (screen.x < 0.0 || screen.x > 1.0 ||
        screen.y < 0.0 || screen.y > 1.0 ||
        screen.z < 0.0 || screen.z > 1.0) {
      break;
    }

    float sceneDepth = texture(depthtex1, screen.xy).r;
    if (screen.z > sceneDepth && sceneDepth < 0.9999 && sceneDepth >= waterDepth) {
      hitMask = 1.0;
      return screen;
    }
  }

  return vec3(0.0);
}
  vec3 getViewPos(vec2 uv, float depth) {
    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0; // normalized device coordinates (NDC); [-1.0, 1.0]
    return projectAndDivide(gbufferProjectionInverse, ndcPos); // position in view space
  }
  vec3 getNormal(vec3 pos) {
	float a = 0.1;
	float h0 = 0.0, hx = 0.0, hz = 0.0;
    
    h0 += 0.025 * cos(frameTimeCounter*2.0 + pos.x*12) + 0.05*sin(frameTimeCounter*2.0 + pos.z*6.7);
    hx += 0.025 * cos(frameTimeCounter*2.0 + (pos.x+a)*20) + 0.05*sin(frameTimeCounter*2.0 + pos.z*20);
    hz += 0.025 * cos(frameTimeCounter*2.0 + pos.x*6.7) + 0.05*sin(frameTimeCounter*2.0 + (pos.z+a)*12);
    
    h0 += 0.012 * cos(frameTimeCounter*3.0 + pos.x*67 + pos.z*41);
    hx += 0.012 * cos(frameTimeCounter*3.0 + (pos.x+a)*67 + pos.z*41);
    hz += 0.012 * cos(frameTimeCounter*3.0 + pos.x*67 + (pos.z+a)*41);
    
    h0 += 0.0048 * sin(frameTimeCounter*5.0 + pos.x*12.0) * sin(frameTimeCounter*4.0 + pos.z*12.0);
    hx += 0.0048 * sin(frameTimeCounter*5.0 + (pos.x+a)*12.0) * sin(frameTimeCounter*4.0 + pos.z*12.0);
    hz += 0.0048 * sin(frameTimeCounter*5.0 + pos.x*12.0) * sin(frameTimeCounter*4.0 + (pos.z+a)*12.0);
    
    float dydx = (hx - h0) / a;
    float dydz = (hz - h0) / a;
	return normalize(vec3(-dydx, 1.0, -dydz));
}
    
void main() {
    float depthSurface = texture(depthtex0, texcoord).r;
    float depthBehind = texture(depthtex1, texcoord).r;
    
        
    
    color = texture(colortex0, texcoord);
    vec2 lightmap = texture(colortex1, texcoord).xy;

    float depth = texture(depthtex0, texcoord).r;

    vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
    vec4 viewPosH = gbufferProjectionInverse * vec4(ndcPos, 1.0);
    vec3 viewPos = viewPosH.xyz / viewPosH.w;
    vec3 pos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    vec4 waterData = texture(colortex3, texcoord);
    float reflectivity = waterData.a;
    bool hasWaterData = waterData.a > 0.5;
    bool waterInFront = hasWaterData && (depthBehind - depthSurface > 0.00001);
    vec3 waterNormal = hasWaterData ? normalize(waterData.xyz * 2.0 - 1.0) : vec3(0.0, 1.0, 0.0);

    if (depth == 1.0) {
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

    
    vec3 godRayColor = vec3(1.0, 0.9, 0.8) * lightAccum * (1-lightmap.y) * (waterInFront ? 0.2 : 1.0) * (isEyeInWater == 1 ? 0.25 : 1.0) * 1.25;
    color.rgb = 1.0 - ((1.0 - color.rgb) * (1.0 - godRayColor));
    //color = vec4(vec3(lightmap.y), 1.0);

    if (waterInFront) {
        vec3 waterPosVS = getViewPos(texcoord, depthSurface);
        vec3 V = normalize(-waterPosVS);
        vec3 waterNormalVS = normalize(mat3(gbufferModelViewInverse) * waterNormal);
        vec3 R = reflect(-V, waterNormalVS);

        float hitMask;
        vec3 hit = raymarchSSR(waterPosVS + waterNormal * 0.05, R, hitMask, depthSurface);

        vec3 reflColor = mix(skyColor * lightmap.y, texture(colortex0, hit.xy).rgb, hitMask);

        float fresnel = pow(1.0 - max(dot(waterNormalVS, V), 0.0), 1.5);

        float edgeFade = smoothstep(0.0, 0.05, texcoord.x) *
        smoothstep(0.0, 0.05, texcoord.y) *
        smoothstep(1.0, 0.95, texcoord.x) *
        smoothstep(1.0, 0.95, texcoord.y);
 
        color.rgb = mix(color.rgb, reflColor, fresnel * edgeFade * 0.5 * reflectivity);
    }
}
