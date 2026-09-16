# artemis-compat (vendored)

Upstream: https://github.com/Weiss-UltimateSavior/artemis-compat
Pinned source commit: `2c44929ca854ec5dbab6f0727fb21179c62b4b4a`
(2026-09-14, compatibility fixes through the pre-host-dialog series)
License: GPL-3.0 (`LICENSE`), third-party components per `THIRD_PARTY_NOTICES.md`
(Lua 5.1.5 — MIT; stb_vorbis — public domain / MIT).

Only `src/` (minus `cli/` and `jni/`) and `third_party/` are vendored; the
standalone `lua.c` / `luac.c` interpreters are removed.

The source tree matches upstream through the pinned commit. Later upstream
host-dialog and ownership/assembly refactors are intentionally deferred: they
change the host callback contract, audio ownership and engine construction, so
the HarmonyOS bridge and OHAudio backend need to migrate with them.

## Local patches (keep this list current when re-syncing)

- `src/log/logger.{h,cpp}` — added `artc::SetLogSink()` so the KrKr2-Next
  bridge can mirror engine output into its startup-log queue / engine log
  file; added an OpenHarmony `hilog` output path (tag `Artemis`, domain
  `0x0207`).
- `src/render/compositor.cpp` — the GLES2 compositor is gated on
  `ARTC_HAS_GLES` (auto-defined on Android, set by `cpp/artemis/CMakeLists.txt`
  on OpenHarmony) instead of `__ANDROID__` only.
- `src/audio/audio.cpp` is not compiled on OpenHarmony; the OHAudio backend
  lives in `cpp/artemis/ohos/audio_ohos.cpp` (same `artc::Audio` interface).
- `src/script/lua_engine.cpp` — `e:random()` returns a non-negative integer
  (C `rand()` semantics) instead of a `[0,1)` float; the adv framework uses
  `e:random() % n + 1` (sysvo.lua / config.lua / image.lua), which needs an
  integer to index tables (START on the title screen aborted otherwise).
- `src/script/lua_engine.{h,cpp}` — new `e:loadPngComments(path)` (PNG tEXt /
  iTXt keyword→text table; the framework's `getfgfilepos` reads the
  `comment` = "pos,x,y,…" anchor of face-part sprites, which were otherwise
  drawn at 0,0 and invisible) and a no-op `e:unbindSurface`.
- `src/render/compositor.{h,cpp}` — `EffectiveRect` now composes a proper
  layer transform down the id chain (offset relative to the parent + scale
  about the layer's own anchor; `xscale`/`yscale` parsed as percent, effective
  size returned to Draw/HitLayer) instead of the upstream absolute/inherit
  heuristic that subtracted the anchor. Fixes BGs dragged to -640,-360 by the
  anchored `1.0` root, face parts on positioned character containers, choice
  buttons under positioned parents, and keeps the pull-out toolbar hidden at
  `left=1240` as the real engine does. `Layers()` accessor added for tests.
- `src/script/lua_engine.cpp` — bridge `lua_pcall`s (calllua / lyevent /
  e:tag / DoString) run under a `debug.traceback` handler so framework
  errors log their Lua call chain.
- `src/script/lua_engine.cpp` — `ClickAt` dispatches to the frontmost layer
  that *owns* a click lyevent (id-chain walk) instead of whatever decorative
  child is drawn on top (choice text over its button image);
  `Compositor::HitLayers` added for that.
- `src/script/asb_parser.cpp` — `AsbRunner::Return` reloads the caller's
  script on a cross-file frame (`[call file=system/first.iet …]` from
  script.asb) instead of halting.
- `src/render/compositor.{h,cpp}` — real `[lytween]` tweens (alpha / left /
  top / xscale / yscale / zoom / w / h, delay + easing curves, `lytweendel`
  cancels a subtree) and `[trans]` crossfades (the retained composited scene is
  captured and faded out over the new state; `rule=`
  images drive a thresholded wipe with `vague` softness). `Update(now)` /
  `PendingAnimationMs()` let the host advance animations and make `[wt]` /
  `wait scenario` hold the script for their duration.
- Host-side (bridge/engine_api/artemis_runtime.cpp): `[stop]` halts without
  popping the call frame (`[return]` pops); `[stop exskip]` is a no-op. The
  upstream "stop pops a frame" heuristic let `*main` run past a pending
  choice (`script.asb *select [stop]`), which is what produced the
  `message.lua:535` / `select.lua:500` errors.
- `src/audio/audio.{h,cpp}` + `ohos/audio_ohos.cpp` — `Audio::IsPlaying(key)`.
  `src/script/lua_engine.cpp` — `[wait se=N]` releases when voice N ends,
  `setonsoundfinish`/`delonsoundfinish` fire their Lua callback once the
  voice ends (polled per frame), and a bare `[wait]` (time=0, input=0 — the
  framework's eqwait/trans_flag) waits for the running transition/tween
  instead of blocking until a tap.

- `src/audio/audio_channels.*` — shared logical BGM/SE/voice channels with
  timed gain/pan ramps, overlap for crossfades, and completed-track retirement.
- `src/audio/vorbis_stream.*` — shared block decoder with `_a` intro / `_b`
  continuation support (also for non-looping playback). Android OpenSL ES and
  the HarmonyOS OHAudio backend consume stereo blocks instead of whole-file PCM.
- `src/script/lua_engine.*` — wait input permissions no longer create an
  unconditional wait; mandatory waits survive taps; event filters, wait reasons,
  and dotted callbacks retain balanced Lua stacks. Layer events preserve the
  interrupted runner cursor and wait across script jumps/calls/returns.
- `src/script/asb_parser.*` — common reentrant instruction execution, event
  return frames, and script-stack file enumeration. The host calls `ExecuteLine`
  instead of holding script references across Lua callbacks. App resume shifts
  both active wait deadlines and waits suspended below a menu event.
- `src/render/compositor.*` — retained scene framebuffer for transition
  captures, consistent 0–255 alpha, zero/mirrored scale; em-based text with
  typographic metrics, reserved ruby line spacing, alignment, outline, explicit newlines, and font selection
  per message layer. Text rectangle origins compose with layer translations;
  empty text clears old pixels. `rt` appends a line break.
- Regression fixtures under `../tests` are synthetic scripts/audio and an
  original rectangle-glyph font; no commercial game content is included.
- HarmonyOS-only `../ohos/audio_ohos.cpp` — retire finished voices after the
  submitted frames have been presented; mute and release renderers on a worker
  so OHAudio's blocking Stop does not stall rendering. Log submitted frames and
  renderer underflows when retiring a voice.
- `src/render/compositor.*` — reloading a layer surface adopts the new natural
  dimensions and resets crop UVs, retaining the layer transform. This fixes PNG
  face-expression changes with different bounding boxes; it is not E-mote.
  Tween sets retain sequential segments per property; loop/yoyo counts and
  infinite animation waits no longer lose segments or overflow the wait timer.
- `src/script/input_state.h`, `src/script/lua_engine.*` — key overrides implement
  push/down/down-edge/up-edge/decide bits and -1 restoration. Input is dispatched
  after the frame callback so scripts can suppress a key in that frame. Confirm
  and movie-cancel roles respect overrides. Auto-read waits for text and selected
  voice channels, then the configured reading interval; click/stop can end it.
- `src/render/compositor.*`, `src/render/line_break.h`, `src/script/lua_engine.*`
  — retained pages per message layer, glyph atlases and batched draws, per-glyph
  in-tween timing, click-to-complete before advancing, and ruby ranges/tags.
  Ruby reserves its measured width and wraps with its base. Basic horizontal
  CJK prohibit/hung rules keep brackets and punctuation on suitable lines.
  Mixed style runs, vertical text, full shaping and full ruby semantics remain
  incomplete; do not remove that distinction during an upstream sync.
- `src/audio/pcm_stream.h`, `src/audio/audio.*`, `../ohos/audio_ohos.cpp` — shared
  PCM source interface and playback clocks for movie sound. Platform backends
  supply the presentation position; the common player uses it for frame timing.
- `src/render/video_decoder.*`, `src/render/video_player.*`,
  `src/script/lua_engine.*` — FFmpeg demux/decode from immutable compressed bytes,
  RGBA video and resampled stereo PCM, full-screen/layer playback and loops,
  wait reasons and cancel roles. A shorter sound track does not freeze the video
  at its last audio timestamp. Decoder failures log the failing operation.
- `src/pack/pack_manager.*` — after searching the patch/PFS chain, resolve loose
  files below the directory containing the archive, including `movie/*.mp4`.
  Relative paths are normalized; absolute and parent traversal paths are rejected.
- `src/script/expression.*`, `src/script/lua_engine.*` — evaluate `$` expressions
  and references before tag dispatch, with 32-bit integer operations, logical
  short-circuit, comparisons, strings and variable lookup. Preserve embedded NUL
  bytes in variable values. This fixes the game's video condition checks.
- Outside the vendor tree, `vcpkg/ports/ffmpeg/0002-aarch64-swscale-output-height.patch`
  fixes FFmpeg 3.3.9 NEON conversion wrappers returning zero after writing valid
  rows. The fix belongs to FFmpeg and applies to ARM64, without disabling NEON.
  `../tests/video_decoder_regressions.cpp` and GLES tests use generated movies;
  no commercial movie is committed.

- `src/render/compositor.*` — anchored rotation and independent reverse flags
  compose through the full layer ancestry, including nonuniform scales. Images
  and glyph batches transform their corners; inverse hit tests reject empty
  regions of a rotated bounding box. Uniform zoom respects explicit axis scales.
  Rotation is also a tween property, retaining sequence/loop/yoyo behavior.
- `src/script/lua_engine.cpp`, `src/render/compositor.*` — dragging maps stage
  displacement back into the parent coordinate space before applying local drag
  bounds, and updates both axes. Singular transforms ignore pointer movement.

- `src/script/pluto_codec.*` — native Pluto value graphs (32/64-bit string
  lengths, cycles, shared tables, binary strings and permanent references), with
  legacy Lua-source-bank reading retained. VM closures, threads, userdata and
  special persistence are explicitly unsupported.
- `src/script/native_save.*`, `src/script/save_storage.*`, `lua_engine.*`,
  `asb_parser.*` — validated BOWS/1003 zlib and indexed object directories;
  native variable/layer journals restore through the game's `onLoad` callback.
  Discard stale runner call frames before restoration. `save file=...` now writes
  an independent ARCV compatibility checkpoint after `onSave`; checksums and
  atomic file replacement prevent partial bank/slot writes. ARCV is NOT native
  BOWS export; original-engine round-trip and complete VM snapshots are pending.
- `lua_engine.cpp`, `src/script/save_metadata.*` — `var system=date` writes
  local year/month/day/hour/minute/second for save captions. Recover empty dates
  in early compatibility slot metadata from the matching ARCV file's mtime;
  retain existing dates and leave absent/non-ARCV files alone.
- `src/render/layer_shader.*`, `compositor.*`, `lua_engine.*` — load game-authored
  mobile GLSL via `lyshader`; compose parent/child effect groups and intermediate
  framebuffers with straight/premultiplied alpha conversion. Bind native
  foreground/background/mask/user textures, float/int/bool vectors, matrices
  and arrays independently per layer. Includes negative/gray/multiply and
  add/screen blending. HLSL and full intermediate-mode caching semantics remain
  unsupported; shader source retention allows reload after GL resource loss.
- `src/pack/psb.*`, `src/render/emote_model.*` — platform-neutral, bounded plain
  PSB v2–v4/MDF resource decoding, RL/raw RGBA/CI8 images, original sprite origins,
  variable/timeline metadata and offline keyframe sampling. Public model data
  exposed duplicate tracks and numeric-string values, both retained/accepted.
  This is an E-mote data foundation; the bounded scene renderer added below
  does not turn it into a complete SDK/player.

- `src/script/native_save.*`, `lua_engine.cpp` — decode BOWG/1003 global banks
  and read-line sets. Import native globals only when compatibility `system.dat`
  is absent, validating every Pluto graph before application. Existing banks
  remain authoritative; never merge older native metadata over current progress.
  Native files stay read-only. Read-line sets are not yet applied to skip state.
- `src/render/layer_shader.*`, `compositor.*`, `lua_engine.cpp` — intermediate
  group masks use red times alpha, with transparent coverage outside the image;
  clipping and masks sample inverse-transformed group-local coordinates. Resolve
  native path aliases and reload mask textures after GL resource loss. This does
  not implement every intermediate caching mode, ordinary image masks or masked
  hit testing.
- `src/render/emote_scene.*` — bounded image/layout/child-motion evaluation and
  GLES rendering, including held/linear frames, loop timing, parameterized image
  changes, sprite origins and hierarchical transforms. Validate all reachable
  frames before accepting a model; reject unsupported blend/depth, inheritance,
  mesh/stencil and control semantics. Synthetic GPU fixtures exercise body/face
  alignment and resource recreation. SDK timeline controllers, physics and
  encrypted PSB remain absent (player integration: see emote_player below);
  complex public models still require unsupported rendering features.
- `src/render/emote_player.*`, `emote_scene.*`, `lua_engine.*` — E-mote playback
  on the bounded scene renderer: 60 fps frame clock with loop wrapping, main vs
  difference timelines, sequential queueing with in-place parallel restart,
  hold-end poses, fades with auto-stop and manual blend override, skip/pass,
  eased variable transitions and atomic reload. `e:createEmoteLayer` /
  `e:getEmoteLayer` expose the reference proxy surface (dual camelCase/PascalCase
  spellings); every load failure path reports explicitly, `lydel` tears the
  subtree down and invalidates stale proxies, and unregistered physics/hit-test
  methods fall through to a logging stub instead of faking SDK behavior.
  Physics, mesh/stencil deformation, encrypted PSB and complex public models
  remain unsupported; the test game ships no E-mote models, so the playback
  surface is covered by synthetic fixtures only.
- `src/render/snapshot_image.*`, `compositor.*`, `lua_engine.*` — `takess` retains
  a top-down scene framebuffer snapshot; `savess` writes an atomically replaced
  PNG with alpha-correct resizing. Saved images can be read through script file
  APIs and layer creation within the authorized save directory. Captures survive
  subsequent menu drawing; original embedded-thumbnail import is not implemented.

Full key roles/skip, all shader semantics, complete E-mote SDK parity, complex
typography and complete native snapshot interchange remain incomplete.
See `doc/artemis-compatibility-audit.md` at the repository root for validation
scope and the distinction between host and signed HarmonyOS device tests.
