const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;
vec3 distortShadowClipPos(vec3 shadowClipPos) {
  shadowClipPos.xy /= 0.8*abs(shadowClipPos.xy) + 0.2;

  return shadowClipPos;
}