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
 uniform int isEyeInWater;
 uniform float frameTimeCounter;

 /*
 const int colortex0Format = RGB16;
 */

 uniform vec3 shadowLightPosition;
 uniform mat4 gbufferModelViewInverse;
 uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjection;
uniform vec3 skyColor;

uniform vec3 cameraPosition;

uniform vec2 texelSize;


 const vec3 blocklightColor = vec3(1, 0.25, 0.1); 
 const vec3 skylightColor = vec3(0.6, 0.4, 0.3);
 const vec3 moonlightColor = vec3(0.2, 0.05, 0.3);
 const vec3 sunlightColor = vec3(1.0, 0.9, 0.8);
 const vec3 ambientColor = vec3(0.025);


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

float wave(float x, float z) {
	return 0.1 * (cos(frameTimeCounter*2+x*2)+sin(frameTimeCounter*2+z*2)+0.5*cos(frameTimeCounter*3+x*8)+0.5*sin(frameTimeCounter*3+z*8)) - 0.2;
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

vec3 raymarch(vec3 direction, vec3 hitPoint, inout float infinite, float dither) {
	float stepSize = 0.1;
	vec3 pathIncrement = direction * stepSize;
	vec3 currentMarchpoint = hitPoint + pathIncrement;
	vec3 oldMarchpoint;
	float depth;
	float depthDiff = 1.0;
	vec4 screenMarchPos = gbufferProjection * vec4(currentMarchpoint, 1.0);
	float marchDist = 0.0;
	screenMarchPos /= screenMarchPos.w;
	screenMarchPos.xy = screenMarchPos.xy * 0.5 + 0.5;
	float prevScreenDepth = screenMarchPos.z;
	float hitDepth = screenMarchPos.z;
	bool search = true;
	bool hidden = false;
	bool firstHidden = true;
	bool outOfEyeFlag = false;
	bool tooFar = false;
	vec4 lastScreenMarchPos;

	int hiddenSteps = 0;
	bool hiddens = false;
	
	for (int i = 0; i <100; i++) {
		if (search) {
			pathIncrement *= 0.5;
			currentMarchpoint += pathIncrement * sign(depthDiff);
		}
		else {
			oldMarchpoint = currentMarchpoint;
			marchDist += stepSize;
			currentMarchpoint = hitPoint + (direction * marchDist);
			pathIncrement = currentMarchpoint - oldMarchpoint;
		}
		lastScreenMarchPos = screenMarchPos;
		screenMarchPos = gbufferProjection * vec4(currentMarchpoint, 1.0);
		screenMarchPos /= screenMarchPos.w;
		screenMarchPos.xy = screenMarchPos.xy * 0.5 + 0.5;
		if (screenMarchPos.x < 0.0 || screenMarchPos.x > 1.0 || screenMarchPos.y < 0.0 || screenMarchPos.y > 1.0 || screenMarchPos.z < 0.0) {
			outOfEyeFlag = true;
		}

		if (screenMarchPos.z > 1.0) {
			tooFar = true;
		}

		depth = texture(depthtex1, screenMarchPos.xy).x;
		depthDiff = depth - screenMarchPos.z;

		if (depthDiff < 0.0 && abs(depth - prevScreenDepth) > abs(screenMarchPos.z - lastScreenMarchPos.z)) {
			hidden = true;
			hiddens = true;
			if (firstHidden) {
				firstHidden = false;
			}
		}
		else if (depthDiff > 0.0){
			hidden = false;
			if (!hiddens) {
				hiddenSteps++;
			}
		}
		if (search && depthDiff < 0.0 && hidden == false) {
			search = false;
		}

		prevScreenDepth = depth;
	}
	infinite = float(depth > 0.999);

	if(outOfEyeFlag) {
		infinite = 1.0;
		return screenMarchPos.xyz;
	}
	else if (tooFar) {
		infinite = 1.0;
		return screenMarchPos.xyz;
	}
	else if (hiddenSteps < 3 || depth > hitDepth) {
		return screenMarchPos.xyz;
	}
	else {
		infinite = 1.0;
		return vec3(infinite);
	}
}



vec3 getReflected(
	vec3 viewPos,
	vec3 normal,
	vec3 baseColor,
	vec3 skyReflect,
	vec3 reflected,
	float fresnel,
	float visibleSky,
	float dither,
	vec3 lightColor
) {
	float infinite = 1.0;
	vec3 hit = raymarch(reflected, viewPos, infinite, dither);
	vec4 reflColor = vec4(infinite > 0.5 ? skyReflect * visibleSky : texture(colortex3, hit.xy).rgb, 1.0);
	//vec3 reflectionColorSky = mix(skyReflect * visibleSky, reflColor.rgb, reflColor.a);
	vec3 V = normalize(-viewPos);
	vec3 L = normalize(shadowLightPosition);
	float sunSpec = pow(max(dot(reflect(-L, normal), V), 0.0), 128.0);

	return mix(baseColor, reflColor.rgb, fresnel) + sunSpec * lightColor *visibleSky;

}

float hash12(vec2 point)
{
    point = 0.0002314814814814815 * point + vec2(0.25, 0.0);
    float state = fract(dot(point * point, vec2(3571.0)));
    return fract(state * state * 7142.0);
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
   if (depth > 0.9999) {
    return;
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
  if (isEyeInWater == 1) {
      shadowClipPos.xz += getNormal(feetPlayerPos + cameraPosition).xz * 0.01;
  }
  else if (waterInFront) {
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
   	vec3 skylight = clamp((lightmap.y-0.5) * skylightColor * rainMultipler * getDaylightMultiplier(worldTime), 0.0, 1.0);
   	vec3 ambient = ambientColor;//*lightmap.y;
    float hello = clamp(dot(worldLightVector, normal), 0.0, 1.0);
    float bias = smoothstep(0.0, 0.1, hello);
   	vec3 sunlight = (isNightTime(worldTime) ? 4*sunlightColor : moonlightColor) * rainMultipler * hello * bias * shadow;

	
   	color.rgb *= blocklight + skylight + ambient + sunlight + ao * 0.5;
  //color = vec4(vec3(ao), 1.0);
	//color = vec4(vec3(texture(shadowtex0, texcoord)), 1.0);
  //color = vec4(vec3(sunlight), 1.0);


}