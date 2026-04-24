#version 330 compatibility
#include "/lib/shadowDistort.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

 uniform sampler2D shadowtex0;
 uniform sampler2D shadowtex1;
 uniform sampler2D shadowcolor0;

 uniform float rainStrength;
 uniform float rainfall;
 uniform int worldTime;

 /*
 const int colortex0Format = RGB16;
 */

 uniform vec3 shadowLightPosition;
 uniform mat4 gbufferModelViewInverse;
 uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjection;

 

uniform vec2 texelSize;


 const vec3 blocklightColor = vec3(1, 0.25, 0.1);
 const vec3 skylightColor = vec3(0.6, 0.4, 0.3);
 const vec3 moonlightColor = vec3(0.2, 0.05, 0.3);
 const vec3 sunlightColor = vec3(1.0, 0.9, 0.8);
 const vec3 ambientColor = vec3(0.1);


in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

 vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
   vec4 homPos = projectionMatrix * vec4(position, 1.0);
   return homPos.xyz / homPos.w;
 }
  vec3 getShadow(vec3 shadowScreenPos){
   float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r); // sample the shadow map containing everything

   // A value of 1.0 means 100% of sunlight is getting through.
   if (transparentShadow == 1.0){
     // No shadow at all - easy enough!
     return vec3(1.0);
   }

   float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r); // sample the shadow map containing only opaque stuff

   if(opaqueShadow == 0.0){
     // There is a shadow cast by something fully opaque (e.g. a stone block) - we're fully in shadow.
     return vec3(0.0);
   }

   // contains the color and alpha (transparency) of the thing casting a shadow
   vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);

   // We use (1.0 - alpha) to get how much light is let through, and multiply that light by the color of the thing that's
   // casting the shadow.
   return shadowColor.rgb * (1.0 - shadowColor.a);
 }

 vec3 getSoftShadow(vec4 shadowClipPos){
  vec3 shadowAccum = vec3(0.0); // sum of all shadow samples
  const int samples = SHADOW_RANGE * SHADOW_RANGE * 4; // we are taking 2 * SHADOW_RANGE * 2 * SHADOW_RANGE samples

  for(int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++){
    for(int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++){
      vec2 offset = vec2(x, y) * SHADOW_RADIUS / float(SHADOW_RANGE);
      offset /= shadowMapResolution; // offset in the rotated direction by the specified amount. We divide by the resolution so our offset is in terms of pixels
      vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset
      offsetShadowClipPos.z -= 0.001; // apply bias
      if (any(lessThan(offsetShadowClipPos.xy, vec2(-1.0))) || any(greaterThan(offsetShadowClipPos.xy, vec2(1.0)))) {
          shadowAccum += vec3(1.0);
          continue;
      }
      offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
      vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
      vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
      shadowAccum += getShadow(shadowScreenPos); // take shadow sample
    }
  }



  return shadowAccum / float(samples); // divide sum by count, getting average shadow
}
  vec3 getViewPos(vec2 uv, float depth) {
    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0; // normalized device coordinates (NDC); [-1.0, 1.0]
    return projectAndDivide(gbufferProjectionInverse, ndcPos); // position in view space
  }
  float getAO(vec3 viewPos, vec3 viewNormal) {
    vec2 noiseUV = texcoord / (vec2(4.0) * texelSize);
    vec3 noise = texture(noisetex, noiseUV).rgb * 2.0 - 1.0;

    vec3 tangent = normalize(noise - viewNormal * dot(noise, viewNormal));
    vec3 bitangent = cross(viewNormal, tangent);
    mat3 tbn = mat3(tangent, bitangent, viewNormal);

    float occlusion = 0.0;

    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        float theta = 2.399963 * fi;
        float r = sqrt(fi + 0.5) / sqrt(16.0);
        vec3 sampleVec = tbn * vec3(cos(theta) * r, sin(theta) * r, sqrt(1.0 - r * r));
        vec3 samplePos = viewPos + sampleVec * 0.1;
        vec3 sampleNDC = projectAndDivide(gbufferProjection, samplePos);
        vec2 sampleUV = sampleNDC.xy * 0.5 + 0.5;

        float sampleDepth = texture(depthtex0, sampleUV).r;
        vec3 actualPos = getViewPos(sampleUV, sampleDepth);

        float rangeCheck = smoothstep(0.0, 1.0, 0.5 / abs(viewPos.z - actualPos.z));
        occlusion += (sampleDepth >= sampleNDC.z ? 1.0 : 0.0) * rangeCheck;
    }
    return 1.0 - occlusion / 16.0;
  }
float getDaylightMultiplier(float worldTime) {
	const float transition = 1000;
	float sunsetFade = smoothstep(12785.0 - transition, 12785.0 + transition, worldTime);
	float sunriseFade = smoothstep(23215.0 - transition, 23215.0 + transition, worldTime);
	return clamp(1 - sunsetFade + sunriseFade, 0.0, 1.0);
}
bool isNightTime(float worldTime) {
	return worldTime < 12785.0 || worldTime > 23215.0;
}

void main() {
	color = texture(colortex0, texcoord);
	vec2 lightmap = texture(colortex1, texcoord).xy;
	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize(encodedNormal * 2.0 - 1.0);
  normal.z = -normal.z;
	vec3 lightVector = normalize(shadowLightPosition);
  	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;
	

	color.rgb = pow(color.rgb, vec3(2.2));

   float depth = max(texture(depthtex0, texcoord).r, texture(depthtex1, texcoord).r);
   if (depth == 1.0) {
       return; // let's skip whats beneath us - the lighting apply logic!
   }
     vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0; // normalized device coordinates (NDC); [-1.0, 1.0]
  vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos); // position in view space
  vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz; // position relative to the feet of the player

  float depthSurface = texture(depthtex0, texcoord).r;
  float depthBehind = texture(depthtex1, texcoord).r;
  bool waterInFront = depthBehind - depthSurface > 0.00001;
  vec4 waterNormal = (texture(colortex3, texcoord) - 0.5) * 2.0;


  vec3 shadowViewPos = (shadowModelView * vec4 (feetPlayerPos, 1.0)).xyz;
vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
  if (waterInFront) {
        shadowClipPos.xz += waterNormal.xz *0.01;
  }

// note how subsequent conversion code has been moved to the getSoftShadow function


vec3 shadow = getSoftShadow(shadowClipPos);

    mat3 worldToView = mat3(transpose(gbufferModelViewInverse));
    vec3 viewNormal = normalize(worldToView * normal);

    float ao = getAO(viewPos, viewNormal);
    ao = clamp(ao, 0.0, 1.0);
    float rainMultipler = rainfall > 0 ? 1.0 - rainStrength*0.5 : 1.0;
   	vec3 blocklight = (lightmap.x-0.25) * blocklightColor;
   	vec3 skylight = (lightmap.y-0.5) * skylightColor * rainMultipler * getDaylightMultiplier(worldTime);
   	vec3 ambient = ambientColor;//*lightmap.y;
    float hello = clamp(dot(worldLightVector, normal), 0.0, 1.0);
    float bias = smoothstep(0.0, 0.1, hello);
   	vec3 sunlight = (isNightTime(worldTime) ? 4*sunlightColor : moonlightColor) * rainMultipler * hello * bias * shadow;

	
   	color.rgb *= blocklight + skylight + ambient + sunlight, 0.0, 200;
  //color = vec4(vec3(ao), 1.0);
	//color = vec4(vec3(texture(shadowtex0, texcoord)), 1.0);
  //color = vec4(waterNormal.xz, 0, 1.0);
}