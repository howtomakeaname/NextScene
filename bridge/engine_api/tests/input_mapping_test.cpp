#include "input_mapping.h"

#include <cmath>
#include <cstdlib>
#include <iostream>

namespace {

void ExpectNear(float actual, float expected, const char* message) {
  if (std::fabs(actual - expected) > 0.001f) {
    std::cerr << message << ": expected " << expected << ", got " << actual
              << '\n';
    std::exit(1);
  }
}

void ExpectTrue(bool value, const char* message) {
  if (!value) {
    std::cerr << message << '\n';
    std::exit(1);
  }
}

}  // namespace

int main() {
  using krkr2_artemis::IsClickRelease;
  using krkr2_artemis::MapWindowPointToStage;

  const auto pbuffer = MapWindowPointToStage(120.0f, 130.0f, 0, 0, 1280, 720);
  ExpectNear(pbuffer.x, 120.0f, "pbuffer keeps stage x");
  ExpectNear(pbuffer.y, 130.0f, "pbuffer keeps stage y");

  // iPhone-sized IOSurface: 2622x1206 physical pixels contain a 1280x720
  // stage at scale 1.675 with a 239-pixel horizontal letterbox.
  const auto iosurface =
      MapWindowPointToStage(440.0f, 217.75f, 2622, 1206, 1280, 720);
  ExpectNear(iosurface.x, 120.0f, "IOSurface maps x into the stage");
  ExpectNear(iosurface.y, 130.0f, "IOSurface maps y into the stage");

  const auto native =
      MapWindowPointToStage(192.0f, 108.0f, 1920, 1080, 1280, 720);
  ExpectNear(native.x, 128.0f, "native window scales x");
  ExpectNear(native.y, 72.0f, "native window scales y");

  ExpectTrue(IsClickRelease(false, false), "no drag is a click");
  ExpectTrue(IsClickRelease(true, false), "an unmoved draggable is a click");
  ExpectTrue(!IsClickRelease(true, true), "a moved drag is not a click");

  std::cout << "input mapping regressions passed\n";
  return 0;
}
