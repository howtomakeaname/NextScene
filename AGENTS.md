# NextScene contributor instructions

## Artemis integration

- Preserve both consumers of artemis-compat: its standalone Android `libartemis.so`
  with the official JNI/NativeActivity contract, and NextScene's embedded runtime.
  Flutter, NextScene UI and game-library policy must not become upstream dependencies.
- Keep engine semantics and reusable platform backends in artemis-compat. Keep
  Flutter textures, window ownership, permissions and UI in NextScene's host layer.
  Follow the upstream `AGENTS.md` and `AGENT.md` when changing engine sources.
- Pin a reproducible engine commit. Publish the engine commit before committing a
  submodule pointer. Never require an unpublished local commit or silently follow
  upstream main during a build. Use an explicit source override for local joint work.
- Make small commits by subsystem. Keep dependency upgrades separate from UI work;
  record the matching engine revision and host-interface changes for rollback.
- Preserve unrelated working-tree changes, signing profiles and generated files.
  Do not commit commercial game assets, private logs, credentials or specific game
  names in PR titles/descriptions.

## Validation

- Build the embedded consumer with the upstream JNI/CLI/macOS host disabled. Test
  linkage, not just static archive creation, so missing platform dependencies fail.
- Engine/build changes must also build upstream's Android `libartemis.so` and check
  its required JNI and NativeActivity exports. Export presence is not jar behavior
  compatibility; report original-shell device testing separately.
- Run synthetic engine regressions plus the GLES compositor suite for render changes.
  Check SDK 20 arm64 integration for HarmonyOS. iOS/Android support requires their
  own builds and runtime validation; host stubs or macOS success do not prove it.
- Lifecycle changes require startup, exit/re-entry, cross-engine switching,
  background/resume and surface recreation checks. GPU ownership and audio callback
  teardown must finish before their host resources are destroyed.
- Report unavailable SDKs/devices and failed baseline tests explicitly. Never weaken
  assertions or silently select headless/audio-null backends to make production
  builds pass.

The implementation plan and evidence are in `doc/artemis-embedding-work.md`.
