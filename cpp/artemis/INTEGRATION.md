# Artemis in NextScene

`upstream/` is the complete artemis-compat Git submodule, pinned by the parent
repository. The current integration uses upstream commit
`a4d922bb3a9e90b9e65502a3baf30f1b849346bd` from `feat/embedded-host-support`.
That commit is published in the upstream repository; builds never follow a branch.

```sh
git submodule update --init --recursive
```

The wrapper links `artemis::core`; it disables upstream's CLI, Android JNI and
macOS host targets. NextScene owns EGL/Flutter presentation and the frame loop.
`bridge/engine_api/src/artemis_runtime.cpp` owns one `EngineContext`, and releases
it before host EGL teardown. OHAudio and engine regressions live upstream.
Android's official-shell `libartemis.so` remains an independent upstream target.

For engine work, edit a separate upstream checkout on a feature branch:

```sh
cmake -S . -B build/ohos/dev <existing toolchain options> \
  -DNEXTSCENE_ARTEMIS_SOURCE_DIR=/absolute/path/to/artemis-compat
```

Run both repositories' tests, publish the engine feature branch, then update the
submodule to that commit and commit its pointer with the corresponding host
change. For a release, prefer an upstream merged commit. To return to the pin,
remove the override from a fresh build directory or set it to the absolute
`cpp/artemis/upstream` path. Never publish a pointer to an unpublished local commit.

Existing engine test commands remain available:

```sh
cmake -S cpp/artemis/tests -B build/artemis-tests -DARTC_ENABLE_FFMPEG=OFF
cmake --build build/artemis-tests -j8
ctest --test-dir build/artemis-tests --output-on-failure
```

Upstream `docs/embedding.md` documents backends, Android exports and lifecycle.
`doc/artemis-embedding-work.md` records this migration's validation and limits.
The application still enables Artemis by default only on OHOS. Android and iOS
require their own host validation; iOS audio and asynchronous Flutter dialogs
remain separate feature work.

The earlier partial vendoring at `2c44929` plus PF8 backport `2dcab32` is preserved
in parent Git history. Revert the dependency/host migration together to return to
that integration; reverting only the submodule breaks the new ownership API.
