#ifndef KRKR2_ENGINE_API_INPUT_MAPPING_H_
#define KRKR2_ENGINE_API_INPUT_MAPPING_H_

#include <algorithm>
#include <cstdint>

namespace krkr2_artemis {

struct StagePoint {
  float x;
  float y;
};

// Convert a point in a zero-copy host surface to the letterboxed stage.
// A zero-sized surface denotes the pbuffer path, whose input is already in
// stage coordinates.
inline StagePoint MapWindowPointToStage(float wx, float wy,
                                        uint32_t window_w, uint32_t window_h,
                                        uint32_t stage_w, uint32_t stage_h) {
  if (window_w == 0 || window_h == 0 || stage_w == 0 || stage_h == 0) {
    return {wx, wy};
  }
  const float sw = static_cast<float>(window_w) / stage_w;
  const float sh = static_cast<float>(window_h) / stage_h;
  const float scale = std::min(sw, sh);
  const float vp_w = stage_w * scale;
  const float vp_h = stage_h * scale;
  const float vp_x = (window_w - vp_w) * 0.5f;
  const float vp_y = (window_h - vp_h) * 0.5f;
  return {(wx - vp_x) / vp_w * stage_w,
          (wy - vp_y) / vp_h * stage_h};
}

// A draggable only suppresses the click fallback after actual movement.
// Pressing and releasing without moving remains a normal button click.
inline bool IsClickRelease(bool drag_active, bool drag_moved) {
  return !drag_active || !drag_moved;
}

}  // namespace krkr2_artemis

#endif  // KRKR2_ENGINE_API_INPUT_MAPPING_H_
