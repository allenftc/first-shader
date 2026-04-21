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
 uniform float worldTime;

 /*
 const int colortex0Format = RGB16;
 */

 uniform vec3 shadowLightPosition;
 uniform mat4 gbufferModelViewInverse;
 uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

 const vec3 blocklightColor = vec3(1, 0.25, 0.1);
 const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
 const vec3 sunlightColor = vec3(1.0);
 const vec3 ambientColor = vec3(0);


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

void main() {
	color = texture(colortex0, texcoord);
	vec2 lightmap = texture(colortex1, texcoord).xy;
	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize(encodedNormal - 0.5) * 2.0;
	vec3 lightVector = normalize(shadowLightPosition);
  	vec3 worldLightVector = mat3(gbufferModelViewInverse) * lightVector;
	

	color = texture(colortex0, texcoord);
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
  shadowClipPos.z -= 0.01;
  shadowClipPos.xyz = distortShadowClipPos(shadowClipPos.xyz);
  vec3 shadowNdcPos = shadowClipPos.xyz / shadowClipPos.w;
  vec3 shadowScreenPos = shadowNdcPos * 0.5 + 0.5;

   vec3 shadow = getShadow(shadowScreenPos);

   	vec3 blocklight = lightmap.x * blocklightColor;
   	vec3 skylight = lightmap.y * skylightColor * (1.0 - rainStrength*0.1) * (worldTime/24000.0);
   	vec3 ambient = ambientColor;
   	vec3 sunlight = sunlightColor * (1-rainStrength) * clamp(dot(worldLightVector, normal), 0.0, 1.0) * shadow;

	
   	color.rgb *= blocklight + skylight + ambient + sunlight;
	//color.rgb = skylight;
}