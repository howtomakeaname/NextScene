/**
 * @file artemis_runtime.h
 * @brief Artemis Engine backend for the engine_api C bridge.
 *
 * KrKr2-Next exposes one C API (engine_api.h) to the Flutter host. The
 * KiriKiri2 runtime implements it directly in engine_api.cpp; this class
 * implements the same lifecycle for Artemis games (`.pfs` pack chains) on
 * top of the pinned artemis-compat runtime in cpp/artemis/upstream, so the Dart side
 * needs no engine-specific code path: engine_open_game_async() detects the
 * pack, and tick / frame readback / input / pause flow through unchanged.
 *
 * Rendering reuses krkr::EGLContextManager (the same headless EGL pbuffer
 * the krkr2 core draws into) so the existing RawImage readback and the
 * OHNativeWindow attach path both keep working.
 *
 * Threading: Open() runs on the startup worker thread, everything else on
 * the engine owner thread (the Dart UI isolate). The EGL context is made
 * current on whichever thread is executing and released before Open()
 * returns, mirroring the krkr2 startup path.
 */
#ifndef KRKR2_ENGINE_API_ARTEMIS_RUNTIME_H_
#define KRKR2_ENGINE_API_ARTEMIS_RUNTIME_H_

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>

#include "engine_api.h"

namespace krkr2_artemis {

/**
 * Returns true when `path` is an Artemis game: either a `.pfs` pack file
 * (patch volumes `.pfs.000` … are chained automatically) or a directory
 * holding one. On success `*out_pack_path` receives the pack to open.
 */
bool LooksLikeArtemisGame(const std::string& path, std::string* out_pack_path);

class ArtemisRuntime {
 public:
  using LogFn = std::function<void(const std::string& line)>;

  explicit ArtemisRuntime(LogFn log);
  ~ArtemisRuntime();

  ArtemisRuntime(const ArtemisRuntime&) = delete;
  ArtemisRuntime& operator=(const ArtemisRuntime&) = delete;

  /** Open the pack chain, read system.ini, bring up EGL + GL and run the
   *  boot chain (system/first.iet). Blocking; intended for the startup
   *  worker. `*error` is set on failure. */
  bool Open(const std::string& game_path, std::string* error);

  enum class TickStatus { kOk, kExitRequested, kError };

  /** Run one engine frame: drain input, step the framework and script
   *  runner, composite, and either present to the native window or read
   *  the frame back. */
  TickStatus Tick(std::string* error);

  /** Queue one host input event; drained by the next Tick(). */
  void QueueInput(const engine_input_event_t& event);

  void Pause();
  void Resume();
  void MarkFrameDirty();

  /** Release Lua/GL/audio state. Safe to call twice. Destroys the EGL
   *  context only when this runtime created it. */
  void Close();

  bool IsOpen() const;
  uint32_t StageWidth() const;
  uint32_t StageHeight() const;

  /** True when the last Tick() produced new pixels (readback path) or
   *  presented a frame (native window path). Cleared by the call. */
  bool ConsumeFrameDirty();

  /** Latest read-back frame (RGBA8888, top-down, stride = width*4). Empty
   *  until the first readback. */
  const std::vector<uint8_t>& FrameRgba() const;

  /** OHNativeWindow / ANativeWindow render target (zero-copy present). */
  bool AttachNativeWindow(void* window, uint32_t width, uint32_t height);
  void DetachNativeWindow();
  bool HasNativeWindow() const;
  void UpdateNativeWindowSize(uint32_t width, uint32_t height);

  /** Human readable GL renderer string ("Artemis compat | <GL_RENDERER>"). */
  std::string RendererInfo();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace krkr2_artemis

#endif  // KRKR2_ENGINE_API_ARTEMIS_RUNTIME_H_
