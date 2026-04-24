#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
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
/* RENDERTARGETS: 0,4 */
layout(location = 0) out vec4 color;
layout(location = 4) out vec4 screenColor;

vec3 tonemap(vec3 color) {
    return color / (color + vec3(1.0));
}

void main() {
    vec2 uv = texcoord;
    float air = currentPlayerAir < 0.0 ? 0.0 : (1.0-currentPlayerAir);
    float xWarpAmount = (isEyeInWater == 1 ? 0.00 : 0) + 0.01 * air;
    float yWarpAmount = (isEyeInWater == 1 ? 0.00 : 0) + 0.01 * air;
    uv.x += xWarpAmount * sin(uv.x * 10.0 + frameTimeCounter * 5.0);
    uv.y += yWarpAmount * sin(uv.y * 10.0 + frameTimeCounter * 5.0) + (is_burning ? 0.005 * sin(frameTimeCounter * 20.0 + uv.y*100) : 0.0);
    color = texture(colortex0, uv);
    //color.rgb = tonemap(color.rgb*0.5);
    color.rgb = pow(color.rgb, vec3(1.0 / 2.5));
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

    float exposure = 0;
    for (int i = 0; i< 10; i++) {
        for (int j = 0; j < 10; j++) {
            exposure += texture(colortex3, texcoord + vec2(float(i-5), float(j-5)) * 0.001).r;
        }
    }
}