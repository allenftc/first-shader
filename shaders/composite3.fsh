#version 330 compatibility
#include "/lib/exposure.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;



in vec2 texcoord;

/* RENDERTARGETS: 0,1,4 */

layout(location = 0) out vec4 refractionColor;
layout(location = 1) out vec4 bloomColor;
layout(location = 2) out vec4 exposure1;

void main() {
    float depthSurface = texture(depthtex0, texcoord).r;
    float depthBehind = texture(depthtex1, texcoord).r;

    vec2 uv = texcoord;

    float waterDepthDiff = depthBehind - depthSurface;
    if (depthSurface < depthBehind && waterDepthDiff > 0.001) {
        if (depthSurface < depthBehind) {
            vec3 waterNormal = texture(colortex3, texcoord).rgb * 2.0 - 1.0;
            
            vec2 edgeFade = smoothstep(0.0, 0.05, texcoord) * smoothstep(1.0, 0.95, texcoord);
            float fade = edgeFade.x * edgeFade.y;
            float distortStrength = clamp(waterDepthDiff * 10.0, 0.0, 1.0) * 0.02;
            vec2 distortedUV = texcoord + waterNormal.xz * distortStrength * fade;
            
            distortedUV = clamp(distortedUV, 0.001, 0.999);
            
            float distortedDepth = texture(depthtex1, distortedUV).r;
            if (distortedDepth < depthSurface + 0.001) { // small bias
                uv = texcoord;
            } 
            else {
                uv = distortedUV;
            }
        }
    }

    refractionColor = clamp(texture(colortex0, uv), 0.0, 1.0);
    
    vec3 scene = texture(colortex1, texcoord).rgb;
    
    float brightness = dot(scene, vec3(0.2, 0.7, 0.07));
    vec3 bright = brightness > 0.9 ? scene : vec3(0.0);
    
    vec3 blur = vec3(0.0);
    float size = 0.003;
    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            vec2 offset = vec2(x, y) * size;
            vec3 s = texture(colortex0, texcoord + offset).rgb;
            float b = dot(s, vec3(0.2, 0.7, 0.07));
            blur += b > 0.9 ? s : vec3(0.0);
        }
    }
    blur /= 100.0;
    
    bloomColor = vec4(blur, 1.0);

    float logLumaSum = 0.0;
    for (int x = 0; x < 8; x++) {
        for (int y = 0; y < 8; y++) {
            vec2 sampleUV = (vec2(float(x), float(y)) + 0.5) / 8.0;
            //vec3 sampleColor = pow(texture(colortex0, sampleUV).rgb, vec3(2.2));
            vec3 sampleColor = texture(colortex0, sampleUV).rgb;
            float sampleLuma = dot(sampleColor, vec3(0.2126, 0.7152, 0.0722));
            sampleLuma = clamp(sampleLuma, 0.001, EXPOSURE_METER_HIGHLIGHT_CLAMP);
            logLumaSum += log(sampleLuma);
        }
    }
    float currentLuma = exp(logLumaSum / 64.0);
    float targetExposure = clamp(EXPOSURE_KEY / currentLuma, EXPOSURE_MIN, EXPOSURE_MAX);
    
    float prevExposure = texture(colortex5, vec2(0.5)).r;
    prevExposure = clamp(prevExposure, EXPOSURE_MIN, EXPOSURE_MAX);
    if (prevExposure < 0.001 || prevExposure != prevExposure) {
        prevExposure = targetExposure;
    }

    float adaptRate = targetExposure > prevExposure ? EXPOSURE_ADAPT_UP : EXPOSURE_ADAPT_DOWN;
    float newExposure = mix(prevExposure, targetExposure, adaptRate);
    newExposure = clamp(newExposure, EXPOSURE_MIN, EXPOSURE_MAX);

    exposure1 = vec4(newExposure, 0.0, 0.0, 1.0);
}