#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;


in vec2 texcoord;

/* RENDERTARGETS: 0,1 */

layout(location = 0) out vec4 refractionColor;
layout(location = 1) out vec4 bloomColor;

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
}