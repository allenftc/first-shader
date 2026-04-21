// defines the total radius in which we sample (in pixels)
#define SHADOW_RADIUS 1
// controls how many samples we take for every pixel we sample
#define SHADOW_RANGE 4

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

const int shadowMapResolution = 2048;
vec3 distortShadowClipPos(vec3 shadowClipPos) {
  shadowClipPos.xy /= 0.8*abs(shadowClipPos.xy) + 0.2;

  return shadowClipPos;
}

