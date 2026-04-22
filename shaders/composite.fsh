#version 330 compatibility
#include "/lib/shadowDistort.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;

 uniform sampler2D shadowtex0;
 uniform sampler2D shadowtex1;
 uniform sampler2D shadowcolor0;

 uniform float rainStrength;
 uniform int worldTime;

 /*
 const int colortex0Format = RGB16;
 */

 uniform vec3 shadowLightPosition;
 uniform mat4 gbufferModelViewInverse;
 uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

 const vec3 blocklightColor = vec3(1, 0.25, 0.1);
 const vec3 skylightColor = vec3(1, 0.8, 0.6);
 const vec3 moonlightColor = vec3(0.1, 0.05, 0.2);
 const vec3 sunlightColor = vec3(1.0, 0.9, 0.8);
 const vec3 ambientColor = vec3(0.1, 0.05, 0.1);


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
      offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
      vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
      vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
      shadowAccum += getShadow(shadowScreenPos); // take shadow sample
    }
  }

  return shadowAccum / float(samples); // divide sum by count, getting average shadow
}
float getDaylightMultiplier(float worldTime) {
	const float transition = 1500;
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
	vec3 normal = normalize(encodedNormal - 0.5) * 2.0;
	vec3 lightVector = normalize(shadowLightPosition);
  	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;
	

	color.rgb = pow(color.rgb, vec3(2.2));

   float depth = texture(depthtex0, texcoord).r;
   if (depth == 1.0) {
       return; // let's skip whats beneath us - the lighting apply logic!
   }
     vec3 ndcPos = vec3(texcoord.xy, depth) * 2.0 - 1.0; // normalized device coordinates (NDC); [-1.0, 1.0]
  vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos); // position in view space
  vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz; // position relative to the feet of the player
  vec3 shadowViewPos = (shadowModelView * vec4 (feetPlayerPos, 1.0)).xyz;
vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

// note how subsequent conversion code has been moved to the getSoftShadow function

vec3 shadow = getSoftShadow(shadowClipPos);

   	vec3 blocklight = (lightmap.x-0.25) * blocklightColor;
   	vec3 skylight = (lightmap.y) * skylightColor * (1.0 - rainStrength*0.1) * getDaylightMultiplier(worldTime);
   	vec3 ambient = ambientColor;//*lightmap.y;
   	vec3 sunlight = (isNightTime(worldTime) ? 2*sunlightColor : moonlightColor) * (1-rainStrength) * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow;

	
   	color.rgb *= clamp(blocklight + skylight + ambient + sunlight, 0.0, 2.50);
	
	//color = vec4(shadow/2.0, 1.0);
}