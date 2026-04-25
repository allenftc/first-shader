#version 330 compatibility
#include "/lib/exposure.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform int isEyeInWater;
uniform float constantMood;
uniform float currentPlayerAir;
uniform float maxPlayerAir;
uniform float currentPlayerHealth;
uniform float maxPlayerHealth;
uniform float currentPlayerHunger;
uniform float maxPlayerHunger;
uniform bool is_burning;
uniform bool is_hurt;
uniform float frameTimeCounter;

in vec2 texcoord;
/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 exposureOld;

vec3 tonemap(vec3 color) {
    return color / (color + vec3(1.0));
}

void main() {
    vec2 uv = texcoord;
    float air = currentPlayerAir < 0.0 ? 0.0 : (1.0-currentPlayerAir);
    float xWarpAmount = (isEyeInWater == 1 ? 0.01 : 0) + 0.01 * air;
    float yWarpAmount = (isEyeInWater == 1 ? 0.01 : 0) + 0.01 * air;
    uv.x += xWarpAmount * sin(uv.x * 10.0 + frameTimeCounter * 5.0);
    uv.y += yWarpAmount * sin(uv.y * 10.0 + frameTimeCounter * 5.0) + (is_burning ? 0.005 * sin(frameTimeCounter * 20.0 + uv.y*100) : 0.0);
    color = texture(colortex0, uv);
    
    
    if (isEyeInWater == 1) {
        color.rgb = mix(color.rgb, vec3(0.0, 0.0, 1)*air, 0.5);
    }
    if (is_burning) {
        color.rgb = mix(color.rgb, vec3(0.5, 0.25, 0.0), 0.5);
    }
    if (is_hurt) {
        color.rgb = mix(color.rgb, vec3(0.25, 0.0, 0.0), 0.5);
    }
    vec3 bloom = texture(colortex1, texcoord).rgb;
    color.rgb += bloom * 0.5;

    float exposure = texture(colortex4, vec2(0.5)).r;
    if (exposure != exposure) {
        exposure = 1.0;
    }
    exposure = clamp(exposure, EXPOSURE_MIN, EXPOSURE_MAX);
    //color.rgb *= exposure;
    //color.rgb = tonemap(color.rgb);
    color.rgb = pow(color.rgb, vec3(1.0 / 2.5));

    exposureOld = vec4(exposure, 0.0, 0.0, 1.0);

    //color.rgb = texture(colortex4, vec2(0.5)).rgb;

}