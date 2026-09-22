import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/engine_bridge.dart';
import '../engine/flutter_engine_bridge_adapter.dart';
import '../engine/virtual_input_controller.dart';
import '../constants/prefs_keys.dart';
import '../l10n/app_localizations.dart';
import '../models/game_engine.dart';
import '../services/android_document_file_system.dart';
import '../services/manager_file_system.dart';
import '../services/manager_storage.dart';
import '../services/game_directory_scanner.dart';
import '../services/engine_runtime_guard.dart';
import '../services/game_manager.dart';
import '../widgets/engine_surface.dart';
import '../ui/ui.dart';
import '../widgets/performance_overlay.dart';
import '../widgets/virtual_game_controls.dart';

/// The game running page — full-screen engine surface with auto-start flow.
class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.gamePath,
    this.engine,
    this.title,
    this.coverPath,
    this.saveDirectoryName,
    this.ffiLibraryPath,
    this.engineBridgeBuilder = createEngineBridge,
    this.orientation = PrefsKeys.gameOrientationLandscape,
    this.gameManager,
  });

  final String gamePath;
  final GameEngine? engine;
  final String? title;
  final String? coverPath;
  final String? saveDirectoryName;
  final String? ffiLibraryPath;
  final EngineBridgeBuilder engineBridgeBuilder;

  /// Initial screen orientation while the game runs: one of
  /// [PrefsKeys.gameOrientationValues], configured in the settings page.
  final String orientation;

  /// If set, play duration is recorded when leaving this page.
  final GameManager? gameManager;

  @override
  State<GamePage> createState() => _GamePageState();
}

/// Process-level engine runtime session.
///
/// Leaving the page parks the current runtime so re-entering the same game is
/// instant. Switching games destroys the parked project session and mounts the
/// new one on the retained process-wide renderer without restarting Flutter.
_EngineRuntimeSession? _activeEngineRuntime;

Future<void> _destroyParkedEngineRuntime() async {
  final parked = _activeEngineRuntime;
  if (parked == null) return;
  try {
    await parked.bridge.engineDestroy();
  } finally {
    if (identical(_activeEngineRuntime, parked)) {
      _activeEngineRuntime = null;
    }
    GameRuntimeBinding.clearParked(parked.gamePath);
  }
}

class _EngineRuntimeSession {
  _EngineRuntimeSession({
    required this.bridge,
    required this.gamePath,
    required this.canResume,
  });

  final EngineBridge bridge;
  final String gamePath;
  final bool canResume;
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  static const int _engineResultOk = 0;
  static const MethodChannel _platformChannel = MethodChannel(
    'flutter_engine_bridge',
  );

  late EngineBridge _bridge;

  /// Re-entering the same parked game: skip create/open and resume.
  bool _reuseRuntime = false;

  /// Only the page that created the bridge may destroy it.
  bool _ownsBridge = false;

  /// Another game already owns the in-process runtime.
  bool _engineConflict = false;

  /// Prevent duplicate runtime replacement requests.
  bool _switchInFlight = false;

  /// Prevent back-button and engine-termination callbacks from racing.
  bool _exitInFlight = false;

  /// [enginePause] has already been issued for this visit; dispose
  /// must not destroy or pause again.
  bool _runtimeParked = false;

  /// After resume, keep polling a few frames even if the static-frame
  /// gate reports "not rendered" so a newly built [EngineSurface]
  /// receives the cached last frame.
  int _forcePresentFrames = 0;

  final GlobalKey<EngineSurfaceState> _surfaceKey =
      GlobalKey<EngineSurfaceState>();
  late final _virtualInput = VirtualInputController(
    send: (event) async => _surfaceKey.currentState?.sendVirtualInput(event),
    onError: (error) => _log('Virtual input failed: $error'),
  );
  bool _showVirtualControls = false;

  Ticker? _ticker;
  // Fallback driver used only if the OHOS DisplaySync callback does not start.
  Timer? _ohosTickTimer;
  Stopwatch? _ohosTickClock;
  bool _receivedOhosVsync = false;
  bool _tickInFlight = false;
  bool _isTicking = false;
  bool _autoPausedByLifecycle = false;
  bool _resumeTickAfterLifecycle = false;
  bool _lifecycleTransitionInFlight = false;

  /// When true, a resume was requested while a pause transition was
  /// still in flight. The pause handler checks this on completion and
  /// triggers a resume automatically.
  bool _pendingLifecycleResumed = false;

  // Frame rate
  int _targetFps = PrefsKeys.defaultFps;
  bool _fpsLimitEnabled = false;

  // Performance overlay
  bool _showPerfOverlay = false;
  String _rendererInfo = '';
  final GlobalKey<EnginePerformanceOverlayState> _perfOverlayKey0 =
      GlobalKey<EnginePerformanceOverlayState>();

  // Orientation currently applied to the window (landscape / portrait / auto).
  late final String _orientation = widget.orientation;

  // Which native runtime this entry runs on (drives preflight + the
  // `engine` option handed to the bridge).
  late final GameEngine _engine =
      widget.engine ?? GameEngine.detect(_normalizeGamePath(widget.gamePath));

  ManagerFileSystem _gameFiles = LocalManagerFileSystem();

  // State
  _EnginePhase _phase = _EnginePhase.initializing;
  String? _errorMessage;
  bool _showOverlay = false;
  bool _showDebug = false;
  int _tickCount = 0;
  final List<String> _logs = [];
  static const int _maxLogs = 2000;
  bool _showBootLogs = false;

  // ScrollController for boot log auto-scroll
  final ScrollController _bootLogScrollController = ScrollController();
  Timer? _startupPollTimer;
  bool _startupPollInFlight = false;
  Timer? _memoryStatsTimer;
  bool _memoryStatsPollInFlight = false;

  String _playSessionId = '';
  int _playActiveMillis = 0;
  final Stopwatch _playStopwatch = Stopwatch();
  int? _playRunningSinceEpochMs;
  bool _playSessionFinalized = false;

  // Documents dir captured at engine_create — anchor for the Dart-side
  // perf log (readable from shell next to the engine funnel log).
  String? _writablePath;

  @override
  void initState() {
    super.initState();
    _playSessionId = _createPlaySessionId();
    if (widget.gameManager != null) {
      unawaited(_savePendingPlaySession());
    }
    WidgetsBinding.instance.addObserver(this);
    if (Platform.operatingSystem == 'ohos') {
      _platformChannel.setMethodCallHandler(_handleOhosPlatformCall);
    }
    final session = _activeEngineRuntime;
    final normalizedPath = _normalizeGamePath(widget.gamePath);
    GameRuntimeBinding.enter(normalizedPath);
    if (session != null &&
        session.canResume &&
        session.gamePath == normalizedPath) {
      GameRuntimeBinding.clearParked(normalizedPath);
      _bridge = session.bridge;
      _reuseRuntime = true;
    } else if (session != null) {
      _bridge = session.bridge;
      _engineConflict = true;
    } else {
      _bridge = widget.engineBridgeBuilder(
        ffiLibraryPath: widget.ffiLibraryPath,
      );
      _ownsBridge = true;
    }
    _loadSettings();
    unawaited(_applyOrientation());
    _log('Initializing engine for: ${widget.gamePath}');
    if (widget.ffiLibraryPath != null) {
      _log('Using custom dylib: ${widget.ffiLibraryPath}');
    }
    // Defer engine startup until after the first frame is rendered,
    // so the boot-log UI is visible before blocking FFI calls begin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_autoStart());
      }
    });
  }

  String _createPlaySessionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$now-${widget.gamePath.hashCode}-${identityHashCode(this)}';
  }

  void _startPlaySessionRun({bool persist = true}) {
    if (widget.gameManager == null) return;
    if (_playSessionFinalized || _playStopwatch.isRunning) return;
    _playRunningSinceEpochMs = DateTime.now().millisecondsSinceEpoch;
    _playStopwatch.start();
    if (persist) {
      unawaited(_savePendingPlaySession());
    }
  }

  void _stopPlaySessionRun({bool persist = true}) {
    if (widget.gameManager == null) return;
    if (!_playStopwatch.isRunning) return;
    _playStopwatch.stop();
    _playActiveMillis += _playStopwatch.elapsedMilliseconds;
    _playStopwatch.reset();
    _playRunningSinceEpochMs = null;
    if (persist) {
      unawaited(_savePendingPlaySession());
    }
  }

  Future<void> _savePendingPlaySession() async {
    if (widget.gameManager == null || _playSessionId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final activeSeconds = _playActiveMillis ~/ 1000;
    await prefs.setString(
      PrefsKeys.pendingPlaySession,
      jsonEncode({
        'version': 2,
        'sessionId': _playSessionId,
        'path': widget.gamePath,
        'activeSeconds': activeSeconds,
        'isRunning': _playStopwatch.isRunning,
        'runningSinceEpochMs': _playRunningSinceEpochMs ?? 0,
      }),
    );
  }

  Future<void> _clearPendingPlaySession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.pendingPlaySession);
  }

  Future<void> _finalizePlaySession() async {
    if (widget.gameManager == null || _playSessionFinalized) return;
    _playSessionFinalized = true;
    _stopPlaySessionRun(persist: false);

    try {
      int seconds = _playActiveMillis ~/ 1000;
      if (seconds > 86400) seconds = 86400;
      if (seconds > 0) {
        await widget.gameManager!.recordPlaySession(
          widget.gamePath,
          seconds,
          _playSessionId,
        );
      }
    } finally {
      await _clearPendingPlaySession();
    }
  }

  @override
  void dispose() {
    _virtualInput.dispose();
    if (widget.gameManager != null) {
      unawaited(_finalizePlaySession());
    }
    _stopStartupPolling();
    _stopMemoryStatsPolling();
    if (Platform.operatingSystem == 'ohos') {
      _platformChannel.setMethodCallHandler(null);
    }
    _bootLogScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _stopTickLoop(notify: false);
    if (!_runtimeParked) {
      if (_engineConflict) {
        _runtimeParked = true;
      } else if (_reuseRuntime ||
          (_ownsBridge && _phase == _EnginePhase.running)) {
        unawaited(_parkRuntime());
      } else if (_ownsBridge) {
        unawaited(_bridge.engineDestroy());
      }
    }
    _restoreOrientation();
    GameRuntimeBinding.leave(_normalizeGamePath(widget.gamePath));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_resumeForLifecycle());
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Only pause when the app is truly invisible (hidden/paused).
        // On macOS desktop, switching windows only triggers 'inactive',
        // which should NOT pause the engine — the window is still
        // partially visible and the user expects the game to keep running.
        unawaited(_pauseForLifecycle());
        break;
      case AppLifecycleState.inactive:
        // On mobile, 'inactive' precedes 'hidden'/'paused' so we let those
        // handle the pause. On desktop, 'inactive' is just focus-lost and
        // should be ignored to avoid freezing the game on window switch.
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  // --- Auto-start flow: create → open → tick ---

  String _normalizeGamePath(String raw) {
    var p = raw.trim();
    if (p.startsWith('file://')) {
      p = Uri.parse(p).toFilePath();
    }
    // Engine accepts POSIX absolute paths on Android host mode.
    if (p.startsWith('./')) {
      p = '/${p.substring(2)}';
    }
    return p;
  }

  /// On Android, detect whether the user selected the game's `data/`
  /// sub-directory instead of the game root.
  ///
  /// The kirikiri2 engine expects the project directory to contain
  /// `startup.tjs` (or `data/system/Initialize.tjs`).  When the user
  /// picks a folder whose last component is `data` and it does NOT
  /// contain `startup.tjs` but DOES contain `system/Initialize.tjs`,
  /// we step up one level to the real game root — but ONLY if the
  /// parent directory has `startup.tjs` or `data/` pointing back here.
  Future<String> _adjustGamePathForAndroid(String path) async {
    if (!Platform.isAndroid ||
        _isArchivePath(path) ||
        _engine != GameEngine.krkr2) {
      return path;
    }

    final clean = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;

    // If the current directory already has startup.tjs, it IS the game
    // root (or at least a valid project dir). Do NOT adjust.
    for (final name in ['startup.tjs', 'Startup.tjs', 'STARTUP.TJS']) {
      if (await _gameFiles.exists('$clean/$name')) {
        _log('Game path has $name — no adjustment needed');
        return path;
      }
    }

    // If <path>/data/system/Initialize.tjs exists, this is already a
    // proper game root that uses the data/ sub-directory layout.
    for (final name in ['initialize.tjs', 'Initialize.tjs']) {
      if (await _gameFiles.exists('$clean/data/system/$name')) {
        _log('Game path has data/system/$name — no adjustment needed');
        return path;
      }
    }

    // The directory has neither startup.tjs nor data/system/Initialize.tjs.
    // Check if it looks like the user selected the `data/` folder itself:
    //   - last path component is "data"
    //   - contains system/Initialize.tjs directly
    final dirName = clean.substring(clean.lastIndexOf('/') + 1).toLowerCase();
    if (dirName != 'data') {
      // Not a `data/` directory — nothing to adjust.
      return path;
    }

    // Verify system/Initialize.tjs exists in the selected directory.
    bool hasSystemInit = false;
    for (final name in ['initialize.tjs', 'Initialize.tjs']) {
      if (await _gameFiles.exists('$clean/system/$name')) {
        hasSystemInit = true;
        break;
      }
    }

    if (!hasSystemInit) {
      // Doesn't look like a krkr2 data/ directory either.
      return path;
    }

    // Step up to the parent directory.
    final adjusted = clean.substring(0, clean.lastIndexOf('/'));
    _log('Auto-adjusted game path: $path → $adjusted (selected data/ folder)');
    return adjusted;
  }

  static bool _isArchivePath(String path) => GameEngine.isKrkrArchive(path);

  Future<String?> _preflightGamePath(String path) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (_isArchivePath(path) || GameEngine.isPfsPack(path)) {
        if (!await _gameFiles.exists(path)) {
          return l10n?.archiveNotExist(path);
        }
        return null;
      }

      if (await _gameFiles.type(path) != FileSystemEntityType.directory) {
        return l10n?.gamePathNotExist(path);
      }

      if (_engine == GameEngine.artemis) {
        // Artemis: the directory must hold a base pack; the runtime chains
        // patch volumes and reads system.ini out of the pack itself.
        if (!(await _gameFiles.list(path)).any(
          (entry) => !entry.isDirectory && GameEngine.isPfsPack(entry.path),
        )) {
          return l10n?.missingArtemisPack(path);
        }
        return null;
      }

      // Folder with only data.xp3: startup.tjs is inside the archive.
      final launchPath = await GameDirectoryScanner(
        _gameFiles,
      ).launchPath(path);
      if (_isArchivePath(launchPath)) {
        if (!await _gameFiles.exists(launchPath)) {
          return l10n?.archiveNotExist(launchPath);
        }
        return null;
      }

      // Loose startup.tjs, or unpacked data/system/initialize.tjs.
      if (!await GameDirectoryScanner(_gameFiles).hasStartup(launchPath)) {
        return l10n?.missingStartupScript(path);
      }
    } catch (e) {
      return l10n?.gamePathCheckFailed(e.toString());
    }
    return null;
  }

  Future<void> _autoStart() async {
    if (Platform.isAndroid && !await _ensureAndroidDirectoryAccess()) return;
    if (!mounted) return;
    if (_engineConflict) {
      if (Platform.isAndroid || Platform.operatingSystem == 'ohos') {
        await _replaceParkedRuntime();
        return;
      }
      _fail(
        AppLocalizations.of(context)?.engineRestartRequired ??
            'The engine is already running another game. '
                'Restart the app to play a different game.',
      );
      return;
    }
    if (_reuseRuntime) {
      _log('Reusing suspended engine runtime for this game');
      try {
        final docDir = await getApplicationDocumentsDirectory();
        _writablePath = docDir.path;
      } catch (_) {}
      if (!mounted) return;
      setState(() => _phase = _EnginePhase.running);
      try {
        await _applyFpsLimit();
        final int resumeResult = await _bridge.engineResume();
        if (resumeResult != _engineResultOk) {
          _fail(
            'engine_resume failed: result=$resumeResult, '
            'error=${_bridge.engineGetLastError()}',
          );
          return;
        }
      } catch (e, st) {
        _fail('engine resume error: $e\n$st');
        return;
      }
      _forcePresentFrames = 8;
      _startPlaySessionRun();
      _startTickLoop();
      return;
    }

    setState(() => _phase = _EnginePhase.creating);
    _log('engine_create...');

    // Yield to let the UI paint the current log state before the
    // synchronous FFI call blocks the main thread.
    await Future<void>.delayed(Duration.zero);

    // Give the engine a writable dir in the app sandbox. Native
    // engine_create exports it as KRKR_FILES_DIR (used for saves and as
    // the anchor for the OHOS engine log file).
    String? writablePath;
    String? cachePath;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      writablePath = docDir.path;
      final cacheDir = await getTemporaryDirectory();
      cachePath = cacheDir.path;
    } catch (_) {}
    _writablePath = writablePath;
    _log('engine_create(writable: $writablePath)...');
    final int createResult = await _bridge.engineCreate(
      writablePath: writablePath,
      cachePath: cachePath,
    );
    if (createResult != _engineResultOk) {
      _fail(
        'engine_create failed: result=$createResult, '
        'error=${_bridge.engineGetLastError()}',
      );
      return;
    }
    _log('engine_create => OK');

    // Set renderer pipeline (opengl / software) before opening the game
    final prefs = await SharedPreferences.getInstance();
    final renderer =
        prefs.getString(PrefsKeys.renderer) ?? PrefsKeys.rendererOpengl;
    _log('Setting renderer=$renderer');
    await _bridge.engineSetOption(
      key: PrefsKeys.optionRenderer,
      value: renderer,
    );

    // Set ANGLE backend (gles / vulkan) — Android only, others ignore
    if (Platform.isAndroid) {
      final angleBackend =
          prefs.getString(PrefsKeys.angleBackend) ?? PrefsKeys.angleBackendGles;
      _log('Setting angle_backend=$angleBackend');
      await _bridge.engineSetOption(
        key: PrefsKeys.optionAngleBackend,
        value: angleBackend,
      );
    }

    await _applyMemoryGovernorOptions();

    // Tell the bridge which backend this entry runs on. The C side detects
    // `.pfs` packs by itself, but an explicit choice keeps the two layers'
    // classification in lock-step (and lets the app override later).
    _log('Setting engine=${_engine.id}');
    await _bridge.engineSetOption(
      key: PrefsKeys.optionEngine,
      value: _engine.id,
    );

    final saveDirectory = widget.saveDirectoryName?.trim();
    if (saveDirectory != null &&
        saveDirectory.isNotEmpty &&
        !saveDirectory.contains('/') &&
        !saveDirectory.contains('\\')) {
      await _bridge.engineSetOption(
        key: PrefsKeys.optionSaveDir,
        value: saveDirectory,
      );
    }

    if (!mounted) return;
    setState(() => _phase = _EnginePhase.opening);
    _stopStartupPolling();
    var normalizedGamePath = _normalizeGamePath(widget.gamePath);
    // On Android, auto-detect if the user selected the data/ folder
    // itself and step up to the real game root.
    normalizedGamePath = await _adjustGamePathForAndroid(normalizedGamePath);
    if (_engine == GameEngine.krkr2) {
      final resolved = await GameDirectoryScanner(
        _gameFiles,
      ).launchPath(normalizedGamePath);
      if (resolved != normalizedGamePath) {
        _log('Resolved KrKr launch path: $normalizedGamePath → $resolved');
        normalizedGamePath = resolved;
      }
    }
    _log('engine_open_game($normalizedGamePath)...');
    _log('Starting application — this may take a moment...');

    final preflightError = await _preflightGamePath(normalizedGamePath);
    if (preflightError != null) {
      _fail(preflightError);
      return;
    }

    // Yield once so opening logs are painted before the async start call.
    await Future<void>.delayed(Duration.zero);

    final int openResult = await _bridge.engineOpenGameAsync(
      normalizedGamePath,
    );
    if (openResult != _engineResultOk) {
      _fail(
        'engine_open_game_async failed: result=$openResult, '
        'error=${_bridge.engineGetLastError()}',
      );
      return;
    }
    _log('engine_open_game_async => queued');
    _startStartupPolling();
  }

  /// Close the parked project and start a clean engine handle in this Flutter
  /// process. Native code retains only process-wide renderer/plugin state and
  /// explicitly resets project-owned VM, windows, timers, audio and mounts.
  Future<void> _replaceParkedRuntime() async {
    if (_switchInFlight) return;
    _switchInFlight = true;
    final parked = _activeEngineRuntime;
    _log('Closing the parked runtime before switching games');
    try {
      if (parked != null) {
        final result = await parked.bridge.engineDestroy();
        if (result != _engineResultOk) {
          throw StateError(
            'engine_destroy failed: result=$result, '
            'error=${parked.bridge.engineGetLastError()}',
          );
        }
        if (identical(_activeEngineRuntime, parked)) {
          _activeEngineRuntime = null;
        }
        GameRuntimeBinding.clearParked(parked.gamePath);
      }
      if (!mounted) return;
      _bridge = widget.engineBridgeBuilder(
        ffiLibraryPath: widget.ffiLibraryPath,
      );
      _engineConflict = false;
      _reuseRuntime = false;
      _ownsBridge = true;
      _runtimeParked = false;
      _log('Previous project unmounted; starting a clean engine instance');
      await _autoStart();
    } catch (e, st) {
      if (mounted) {
        _fail('Unable to close the previous game cleanly.\n$e\n$st');
      }
    } finally {
      _switchInFlight = false;
    }
  }

  Future<bool> _ensureAndroidDirectoryAccess({bool prompt = true}) async {
    try {
      final storage = ManagerStorage();
      final grant =
          await storage.currentGrant() ??
          (prompt ? await storage.authorize() : null);
      if (grant == null) throw StateError('Directory access was revoked');
      final io = AndroidDocumentFileSystem(grant.rootPath);
      await io.validateAncestors(
        grant.rootPath,
        _normalizeGamePath(widget.gamePath),
      );
      _gameFiles = io;
      return mounted;
    } catch (error) {
      _log('Directory access unavailable: $error');
      if (mounted) _fail(AppLocalizations.of(context)!.androidDirectoryAccess);
      return false;
    }
  }

  void _fail(String message) {
    _stopStartupPolling();
    _log('ERROR: $message');
    if (!mounted) return;
    setState(() {
      _phase = _EnginePhase.error;
      _errorMessage = message;
    });
  }

  // --- Tick loop ---

  // Track the elapsed timestamp of the last *rendered* frame so that
  // reportFrameDelta receives the true inter-frame interval instead of
  // the vsync interval (which is always ~16ms on a 60Hz display).
  Duration _lastRenderedElapsed = Duration.zero;
  Duration _lastTickElapsed = Duration.zero;
  int _tickDeltaCarryUs = 0;

  void _startTickLoop() {
    if (_isTicking) return;
    setState(() => _isTicking = true);
    _startPlaySessionRun();
    _log('Tick loop started');
    if (kDebugMode) _startMemoryStatsPolling();

    _lastTickElapsed = Duration.zero;
    _lastRenderedElapsed = Duration.zero;
    _tickDeltaCarryUs = 0;

    if (Platform.operatingSystem == 'ohos') {
      // A Flutter Ticker schedules a Flutter scene every vsync. OHOS external
      // textures already schedule a scene from their native frame-available
      // callback, so using both drivers makes the raster thread try to consume
      // each NativeImage buffer twice. The second acquire returns NO_BUFFER,
      // spams an error every frame, and adds input/raster jitter.
      //
      // Drive only the native producer from HarmonyOS DisplaySync callbacks and
      // let the texture callback be the sole compositor wake-up. DisplaySync
      // follows the cadence selected by the system, so the producer does not
      // render 120 frames into a display currently running at 90 Hz.
      unawaited(_startOhosTickDriver());
      return;
    }

    _ticker = Ticker((Duration elapsed) {
      unawaited(_runEngineTick(elapsed));
    });
    _ticker!.start();
  }

  Future<void> _startOhosTickDriver() async {
    _receivedOhosVsync = false;
    final int preferredFps = _fpsLimitEnabled ? _targetFps : 0;
    final int resolvedFps = await _setOhosGameFrameRate(preferredFps);
    if (!mounted || !_isTicking) return;

    final int tickFps = resolvedFps > 0
        ? resolvedFps
        : (_fpsLimitEnabled ? _targetFps : PrefsKeys.defaultFps);
    _log(
      'OHOS DisplaySync expected=$tickFps '
      '(limit=${_fpsLimitEnabled ? _targetFps : 'system maximum'})',
    );
    if (_receivedOhosVsync) return;

    // DisplaySync.start() normally dispatches immediately. Keep a conservative
    // fallback for older/broken plugin builds or a missing UI context, otherwise
    // the game would freeze completely instead of merely losing adaptive pace.
    _ohosTickTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || !_isTicking || _receivedOhosVsync) return;
      _log(
        'OHOS DisplaySync did not start; using timer fallback at $tickFps FPS',
      );
      final clock = Stopwatch()..start();
      _ohosTickClock = clock;
      _scheduleNextOhosFallbackTick(clock, tickFps, 1);
    });
  }

  Future<Object?> _handleOhosPlatformCall(MethodCall call) async {
    if (call.method != 'onGameVsync') {
      throw MissingPluginException(
        'Unknown OHOS platform call: ${call.method}',
      );
    }
    final Object? arguments = call.arguments;
    if (arguments is! List<Object?> || arguments.isEmpty) return false;
    final Object? timestampValue = arguments.first;
    if (timestampValue is! num) return false;

    _receivedOhosVsync = true;
    _ohosTickTimer?.cancel();
    _ohosTickTimer = null;
    _ohosTickClock?.stop();
    _ohosTickClock = null;
    if (!mounted || !_isTicking) return false;
    await _runEngineTick(Duration(microseconds: timestampValue.round()));
    return true;
  }

  void _scheduleNextOhosFallbackTick(
    Stopwatch clock,
    int tickFps,
    int frameNumber,
  ) {
    if (!mounted || !_isTicking || !identical(_ohosTickClock, clock)) return;

    final int elapsedUs = clock.elapsedMicroseconds;
    final int firstFutureFrame =
        (elapsedUs * tickFps ~/ Duration.microsecondsPerSecond) + 1;
    final int scheduledFrame = frameNumber < firstFutureFrame
        ? firstFutureFrame
        : frameNumber;
    final int targetUs =
        (scheduledFrame * Duration.microsecondsPerSecond + tickFps - 1) ~/
        tickFps;
    // OHOS timers have millisecond-level scheduling granularity. Round the
    // delay up and keep an absolute deadline so 120 FPS alternates 8/9 ms
    // instead of becoming a fixed 8 ms (125 FPS). If a tick is late, the
    // firstFutureFrame calculation skips expired deadlines without catch-up.
    final int delayMs = ((targetUs - elapsedUs + 999) ~/ 1000).clamp(1, 1000);
    _ohosTickTimer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_runEngineTick(clock.elapsed));
      _scheduleNextOhosFallbackTick(clock, tickFps, scheduledFrame + 1);
    });
  }

  Future<void> _runEngineTick(Duration elapsed) async {
    if (_tickInFlight || !_isTicking) return;

    final int deltaMs;
    if (_lastTickElapsed == Duration.zero) {
      deltaMs = 16;
    } else {
      final int deltaUs = (elapsed - _lastTickElapsed).inMicroseconds.clamp(
        Duration.microsecondsPerMillisecond,
        100 * Duration.microsecondsPerMillisecond,
      );
      final int accumulatedUs = deltaUs + _tickDeltaCarryUs;
      deltaMs = accumulatedUs ~/ Duration.microsecondsPerMillisecond;
      _tickDeltaCarryUs =
          accumulatedUs - deltaMs * Duration.microsecondsPerMillisecond;
    }
    _lastTickElapsed = elapsed;

    _tickInFlight = true;
    try {
      final int result = await _bridge.engineTick(deltaMs: deltaMs);
      if (!mounted || !_isTicking) return;

      if (result != _engineResultOk) {
        _cancelTickDriver();
        _stopPlaySessionRun();
        final error = _bridge.engineGetLastError();
        _log('Tick ended: result=$result, error=$error');
        if (error.contains('termination') || error.contains('terminated')) {
          _exitGame(runtimeTerminated: true);
          return;
        }
        setState(() {
          _isTicking = false;
          _phase = _EnginePhase.error;
          _errorMessage = 'engine_tick failed: $result ($error)';
        });
        return;
      }

      // Read the rendered flag exactly once. We pass it to pollFrame()
      // so that engine_surface does NOT read it a second time (which
      // would always see false because the flag is reset on read).
      final bool rendered = await _bridge.engineGetFrameRenderedFlag();
      final bool forcePresent = _forcePresentFrames > 0;
      if (forcePresent) {
        _forcePresentFrames -= 1;
      }
      if (rendered || forcePresent) {
        if (_rendererInfo.isEmpty) {
          _fetchRendererInfo();
        }
        // Compute the real inter-render interval for accurate FPS.
        final double renderDeltaMs = _lastRenderedElapsed == Duration.zero
            ? deltaMs.toDouble()
            : (elapsed - _lastRenderedElapsed).inMicroseconds.clamp(
                    Duration.microsecondsPerMillisecond,
                    200 * Duration.microsecondsPerMillisecond,
                  ) /
                  Duration.microsecondsPerMillisecond;
        _lastRenderedElapsed = elapsed;

        _perfOverlayKey0.currentState?.reportFrameDelta(
          renderDeltaMs.toDouble(),
        );
        // Kick the readback/decode off the tick critical path.
        // engineTick and engineReadFrame share a native mutex, so the
        // copy stays ordered; decodeImageFromPixels can overlap the
        // next vsync. _frameInFlight drops a late poll instead of
        // stacking them.
        unawaited(
          _surfaceKey.currentState?.pollFrame(
            rendered: rendered || forcePresent,
          ),
        );
      }
      _tickCount += 1;

      if (_tickCount % 300 == 0) {
        final String dartPerf = EngineSurfacePerf.take();
        _log('Tick alive: count=$_tickCount dartperf $dartPerf');
        _writeDartPerf(dartPerf);
      }
    } finally {
      _tickInFlight = false;
    }
  }

  void _cancelTickDriver() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _ohosTickTimer?.cancel();
    _ohosTickTimer = null;
    _ohosTickClock?.stop();
    _ohosTickClock = null;
    _receivedOhosVsync = false;
    _tickDeltaCarryUs = 0;
    if (Platform.operatingSystem == 'ohos') {
      unawaited(_setOhosGameFrameRate(-1));
    }
  }

  void _stopTickLoop({bool notify = true}) {
    _stopPlaySessionRun();
    _cancelTickDriver();
    _stopMemoryStatsPolling();

    _isTicking = false;
    if (notify && mounted) {
      setState(() {});
    }
  }

  Future<int> _setOhosGameFrameRate(int preferred) async {
    try {
      return await _platformChannel.invokeMethod<int>(
            'setGameFrameRate',
            <String, Object>{'preferred': preferred},
          ) ??
          preferred;
    } catch (e) {
      _log('setGameFrameRate($preferred) failed: $e');
      return preferred;
    }
  }

  void _startMemoryStatsPolling() {
    _stopMemoryStatsPolling();
    _memoryStatsTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!mounted || _phase != _EnginePhase.running || !_isTicking) {
        return;
      }
      if (_memoryStatsPollInFlight) {
        return;
      }
      _memoryStatsPollInFlight = true;
      try {
        final stats = await _bridge.engineGetMemoryStats();
        if (stats == null) {
          return;
        }
        final int graphicUsedMb = stats.graphicCacheBytes ~/ (1024 * 1024);
        final int graphicLimitMb =
            stats.graphicCacheLimitBytes ~/ (1024 * 1024);
        final int psbUsedMb = stats.psbCacheBytes ~/ (1024 * 1024);
        final int xp3SegMb = stats.xp3SegmentCacheBytes ~/ (1024 * 1024);
        _log(
          'MEM rss=${stats.selfUsedMb}MB free=${stats.systemFreeMb}MB '
          'g=${graphicUsedMb}MB/${graphicLimitMb}MB '
          'psb=${psbUsedMb}MB(${stats.psbCacheEntries}/${stats.psbCacheEntryLimit}) '
          'xp3=${xp3SegMb}MB '
          'arc=${stats.archiveCacheEntries}/${stats.archiveCacheLimit} '
          'ap=${stats.autopathCacheEntries}/${stats.autopathCacheLimit} '
          'tbl=${stats.autopathTableEntries}',
        );
      } finally {
        _memoryStatsPollInFlight = false;
      }
    });
  }

  void _stopMemoryStatsPolling() {
    _memoryStatsTimer?.cancel();
    _memoryStatsTimer = null;
  }

  void _startStartupPolling() {
    _stopStartupPolling();
    _startupPollTimer = Timer.periodic(const Duration(milliseconds: 100), (
      _,
    ) async {
      if (!mounted || _phase != _EnginePhase.opening) {
        _stopStartupPolling();
        return;
      }
      if (_startupPollInFlight) {
        return;
      }
      _startupPollInFlight = true;
      try {
        await _drainStartupLogs();
        final state = await _bridge.engineGetStartupState();
        if (!mounted || state == null) {
          return;
        }
        switch (state) {
          case EngineStartupState.idle:
          case EngineStartupState.running:
            return;
          case EngineStartupState.succeeded:
            _stopStartupPolling();
            _log('engine_open_game => OK');
            await _applyFpsLimit();
            if (!mounted) return;
            setState(() => _phase = _EnginePhase.running);
            _startTickLoop();
            return;
          case EngineStartupState.failed:
            _stopStartupPolling();
            _fail(
              'engine_open_game failed: error=${_bridge.engineGetLastError()}',
            );
            return;
        }
      } finally {
        _startupPollInFlight = false;
      }
    });
  }

  void _stopStartupPolling() {
    _startupPollTimer?.cancel();
    _startupPollTimer = null;
  }

  Future<void> _drainStartupLogs() async {
    // Drain in a short burst so high-volume native logs are shown in time
    // during startup and don't overflow the native startup queue.
    for (var i = 0; i < 8; i++) {
      final raw = await _bridge.engineDrainStartupLogs();
      if (raw.isEmpty) {
        break;
      }
      final lines = raw.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          _log(trimmed);
        }
      }
    }
  }

  // --- Lifecycle ---

  Future<void> _pauseForLifecycle() async {
    // If a resume comes while we are still pausing, record it so we
    // can bounce back after the pause finishes.
    if (_lifecycleTransitionInFlight) {
      // Another transition is running — just clear the pending-resume
      // flag; we want to stay paused.
      _pendingLifecycleResumed = false;
      return;
    }
    if (!mounted || _autoPausedByLifecycle || _phase != _EnginePhase.running) {
      return;
    }
    _lifecycleTransitionInFlight = true;
    _pendingLifecycleResumed = false;
    final bool wasTicking = _isTicking;
    if (wasTicking) _stopTickLoop();

    try {
      await _virtualInput.setEnabled(false);
      final int result = await _bridge.enginePause();
      if (result == _engineResultOk && mounted) {
        _autoPausedByLifecycle = true;
        _resumeTickAfterLifecycle = wasTicking;
        _log('Lifecycle paused');
      }
    } finally {
      _lifecycleTransitionInFlight = false;
    }

    // If a resume was requested while the pause was in-flight, honour
    // it now so the engine doesn't stay frozen.
    if (_pendingLifecycleResumed && mounted) {
      _pendingLifecycleResumed = false;
      await _resumeForLifecycle();
    }
  }

  Future<void> _resumeForLifecycle() async {
    // If a pause is still in-flight, record that we want to resume
    // once it completes.
    if (_lifecycleTransitionInFlight) {
      _pendingLifecycleResumed = true;
      return;
    }
    if (!mounted || !_autoPausedByLifecycle) {
      return;
    }
    _lifecycleTransitionInFlight = true;
    _pendingLifecycleResumed = false;

    try {
      if (Platform.isAndroid &&
          !await _ensureAndroidDirectoryAccess(prompt: false)) {
        await _exitGame(runtimeTerminated: true);
        return;
      }
      final int result = await _bridge.engineResume();
      if (result == _engineResultOk && mounted) {
        final bool resumeTick = _resumeTickAfterLifecycle;
        _autoPausedByLifecycle = false;
        _resumeTickAfterLifecycle = false;
        _log('Lifecycle resumed');
        if (resumeTick) {
          _forcePresentFrames = 8;
          _startTickLoop();
        }
      }
    } finally {
      _lifecycleTransitionInFlight = false;
    }
  }

  // --- Settings ---

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final fps = prefs.getInt(PrefsKeys.targetFps) ?? PrefsKeys.defaultFps;
      final fpsLimitEnabled = prefs.getBool(PrefsKeys.fpsLimitEnabled) ?? false;
      setState(() {
        _showPerfOverlay = prefs.getBool(PrefsKeys.perfOverlay) ?? false;
        _targetFps = fps;
        _fpsLimitEnabled = fpsLimitEnabled;
      });
    }
  }

  /// Push [_orientation] to the window. On OpenHarmony the Flutter embedder
  /// maps SystemChrome.setPreferredOrientations onto
  /// window.setPreferredOrientation (landscape pair → AUTO_ROTATION_LANDSCAPE,
  /// portrait pair → AUTO_ROTATION_PORTRAIT, all four → follows the system
  /// rotation lock), so the same call serves Android, iOS and OHOS.
  Future<void> _applyOrientation() async {
    if (!PrefsKeys.orientationSupported) return;
    final List<DeviceOrientation> wanted;
    switch (_orientation) {
      case PrefsKeys.gameOrientationPortrait:
        wanted = const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ];
        break;
      case PrefsKeys.gameOrientationAuto:
        wanted = DeviceOrientation.values;
        break;
      default:
        wanted = const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ];
    }
    try {
      await SystemChrome.setPreferredOrientations(wanted);
    } catch (e) {
      _log('setPreferredOrientations($_orientation) failed: $e');
    }
  }

  void _restoreOrientation() {
    if (!PrefsKeys.orientationSupported) return;
    unawaited(
      SystemChrome.setPreferredOrientations(
        DeviceOrientation.values,
      ).catchError((Object _) {}),
    );
  }

  /// Apply the current fps_limit setting to the C++ engine layer.
  /// When disabled (fpsLimitEnabled=false), sends fps_limit=0 so the
  /// engine renders every vsync. When enabled, sends the target FPS value.
  Future<void> _applyFpsLimit() async {
    final int fpsValue = _fpsLimitEnabled ? _targetFps : 0;
    _log(
      'Setting fps_limit=$fpsValue (enabled=$_fpsLimitEnabled, target=$_targetFps)',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionFpsLimit,
      value: fpsValue.toString(),
    );
  }

  Future<void> _applyMemoryGovernorOptions() async {
    const profile = PrefsKeys.memoryProfileAggressive;
    const budgetMb = 0; // 0 = native auto budget by system memory
    const logIntervalMs = 12000;
    const psbCacheMb = 128;
    const psbCacheEntries = 1024;
    const archiveCacheCount = 20;
    const autoPathCacheCount = 192;

    _log('Setting memory_profile=$profile');
    await _bridge.engineSetOption(
      key: PrefsKeys.optionMemoryProfile,
      value: profile,
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionMemoryBudgetMb,
      value: '$budgetMb',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionMemoryLogIntervalMs,
      value: '$logIntervalMs',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionPsbCacheMb,
      value: '$psbCacheMb',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionPsbCacheEntries,
      value: '$psbCacheEntries',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionArchiveCacheCount,
      value: '$archiveCacheCount',
    );
    await _bridge.engineSetOption(
      key: PrefsKeys.optionAutoPathCacheCount,
      value: '$autoPathCacheCount',
    );
  }

  void _fetchRendererInfo() {
    try {
      _rendererInfo = _bridge.engineGetRendererInfo();
      if (mounted) setState(() {});
    } catch (_) {
      // Renderer info is best-effort
    }
  }

  // --- Logging ---

  void _log(String message) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _logs.insert(0, '[$time] $message');
    if (_logs.length > _maxLogs) {
      _logs.removeRange(_maxLogs, _logs.length);
    }
    // Try to update the UI if we're in a loading phase
    if (mounted && _phase != _EnginePhase.running && _showBootLogs) {
      setState(() {});
    }
  }

  /// Append the periodic Dart-side perf line to perf-dart.log next to the
  /// engine funnel log (Dart print never reaches hilog, so a file under the
  /// app sandbox — reachable from shell via /mnt/debugtmp — is the channel).
  void _writeDartPerf(String line) {
    final String? dir = _writablePath;
    if (dir == null) return;
    final now = DateTime.now();
    final String stamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    unawaited(() async {
      try {
        await File(
          '$dir/perf-dart.log',
        ).writeAsString('[$stamp] $line\n', mode: FileMode.append);
      } catch (_) {}
    }());
  }

  // --- UI ---

  void _toggleOverlay() {
    unawaited(_virtualInput.setEnabled(false));
    setState(() => _showOverlay = !_showOverlay);
  }

  /// Consume the system back gesture while a game is running. The first back
  /// action reveals the in-game controls (including the explicit exit action)
  /// and a second one dismisses them, so an accidental gesture cannot leave
  /// the game. Loading and error screens retain their normal cancel behavior.
  void _handleSystemBack() {
    if (_phase == _EnginePhase.running) {
      _toggleOverlay();
      return;
    }
    unawaited(
      _exitGame(
        runtimeTerminated: _phase == _EnginePhase.error && !_engineConflict,
      ),
    );
  }

  void _selectGameMenuAction(_GameMenuAction action) {
    setState(() => _showOverlay = false);
    switch (action) {
      case _GameMenuAction.debug:
        unawaited(_toggleDebug());
        break;
      case _GameMenuAction.pause:
        unawaited(_togglePause());
        break;
      case _GameMenuAction.virtualControls:
        unawaited(_virtualInput.setEnabled(false));
        setState(() => _showVirtualControls = !_showVirtualControls);
        break;
      case _GameMenuAction.exit:
        unawaited(_exitGame());
        break;
    }
  }

  Future<void> _togglePause() async {
    if (_isTicking) {
      await _virtualInput.setEnabled(false);
      _stopTickLoop();
      await _bridge.enginePause();
      _log('User paused');
      return;
    }
    await _bridge.engineResume();
    _forcePresentFrames = 8;
    _startTickLoop();
    _log('User resumed');
  }

  Future<void> _toggleDebug() async {
    if (_showDebug) {
      await Navigator.of(context).maybePop();
      return;
    }

    setState(() => _showDebug = true);
    await UiBottomSheet.show<void>(
      context,
      title: 'Debug Log',
      showCloseButton: true,
      child: _GameDebugSheetContent(
        phase: () => _phase.name,
        tickCount: () => _tickCount,
        ticking: () => _isTicking,
        logs: () => _logs,
        onClear: _logs.clear,
      ),
    );
    if (mounted) {
      setState(() => _showDebug = false);
    }
  }

  Future<void> _parkRuntime({bool canResume = true}) async {
    if (_runtimeParked) return;
    _runtimeParked = true;
    await _virtualInput.setEnabled(false);
    _stopTickLoop(notify: false);
    // A conflict page does not own the in-process runtime — leave the
    // parked session (other game) untouched.
    if (_engineConflict) return;
    var parkedCleanly = canResume;
    if (canResume) {
      try {
        final result = await _bridge.enginePause();
        parkedCleanly = result == _engineResultOk;
        if (!parkedCleanly) {
          _log(
            'engine_pause failed while parking: result=$result, '
            'error=${_bridge.engineGetLastError()}',
          );
        }
      } catch (e) {
        parkedCleanly = false;
        _log('engine_pause threw while parking: $e');
      }
    }
    final parkedPath = _normalizeGamePath(widget.gamePath);
    _activeEngineRuntime = _EngineRuntimeSession(
      bridge: _bridge,
      gamePath: parkedPath,
      canResume: parkedCleanly,
    );
    GameRuntimeBinding.park(parkedPath, _destroyParkedEngineRuntime);
  }

  Future<void> _exitGame({bool runtimeTerminated = false}) async {
    if (_exitInFlight) return;
    _exitInFlight = true;
    await _virtualInput.setEnabled(false);
    _stopTickLoop(notify: false);
    _restoreOrientation();
    if (widget.gameManager != null) {
      await _finalizePlaySession();
    }
    await _surfaceKey.currentState?.releaseRenderTargets();
    if (runtimeTerminated) {
      _runtimeParked = true;
      final session = _activeEngineRuntime;
      if (session != null && identical(session.bridge, _bridge)) {
        _activeEngineRuntime = null;
      }
      final result = await _bridge.engineDestroy();
      if (result != _engineResultOk) {
        _log(
          'engine_destroy failed after termination: result=$result, '
          'error=${_bridge.engineGetLastError()}',
        );
      }
    } else {
      await _parkRuntime();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _retryStart() async {
    setState(() {
      _phase = _EnginePhase.initializing;
      _errorMessage = null;
      _tickCount = 0;
    });
    final session = _activeEngineRuntime;
    if (_engineConflict) {
      await _autoStart();
      return;
    }
    if (_reuseRuntime ||
        (session != null &&
            session.gamePath == _normalizeGamePath(widget.gamePath) &&
            session.canResume)) {
      _reuseRuntime = true;
      _ownsBridge = false;
      _runtimeParked = false;
      await _autoStart();
      return;
    }
    final result = await _bridge.engineDestroy();
    if (result != _engineResultOk) {
      _fail(
        'engine_destroy failed: result=$result, '
        'error=${_bridge.engineGetLastError()}',
      );
      return;
    }
    if (!mounted) return;
    _bridge = widget.engineBridgeBuilder(ffiLibraryPath: widget.ffiLibraryPath);
    _ownsBridge = true;
    _runtimeParked = false;
    await _autoStart();
  }

  @override
  Widget build(BuildContext context) {
    final bool surfaceActive = _phase == _EnginePhase.running;
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;
    final usesDarkMediaSurface =
        surfaceActive ||
        (_phase != _EnginePhase.error && _bootCoverFile != null);
    final appIsLight = Theme.of(context).brightness == Brightness.light;
    final systemBarColor = usesDarkMediaSurface
        ? colors.overlay.withValues(alpha: 1)
        : colors.background;
    final systemOverlayStyle =
        (usesDarkMediaSurface || !appIsLight
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: systemBarColor,
              systemNavigationBarColor: systemBarColor,
            );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleSystemBack();
        },
        child: Scaffold(
          // The live engine canvas is always black; pre-game and error states
          // use the selected application theme.
          backgroundColor: surfaceActive
              ? colors.overlay.withValues(alpha: 1)
              : colors.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Full-screen engine surface
              Positioned.fill(
                child: _phase == _EnginePhase.error
                    ? _buildErrorView()
                    : _phase == _EnginePhase.running
                    ? EngineSurface(
                        key: _surfaceKey,
                        bridge: _bridge,
                        active: surfaceActive,
                        surfaceMode: EngineSurfaceMode.gpuZeroCopy,
                        externalTickDriven: _isTicking,
                        onLog: (msg) => _log('surface: $msg'),
                        onError: (msg) => _log('surface error: $msg'),
                        onPointerPosition: _virtualInput.syncCursor,
                      )
                    : _buildBootLogView(),
              ),

              if (_showVirtualControls && _phase == _EnginePhase.running)
                Positioned.fill(
                  child: VirtualGameControls(
                    controller: _virtualInput,
                    enabled:
                        _isTicking &&
                        !_showOverlay &&
                        !_showDebug &&
                        !_exitInFlight &&
                        !_autoPausedByLifecycle,
                  ),
                ),

              // Performance overlay (top-left)
              if (_showPerfOverlay && _phase == _EnginePhase.running)
                EnginePerformanceOverlay(
                  key: _perfOverlayKey0,
                  rendererInfo: _rendererInfo,
                  engineName: _engine.label,
                  pacingMode: _fpsLimitEnabled
                      ? 'Cap $_targetFps FPS'
                      : Platform.operatingSystem == 'ohos'
                      ? 'DisplaySync'
                      : 'VSync',
                  hidden: _showOverlay,
                ),

              if (_phase == _EnginePhase.running)
                Positioned.fill(
                  key: const ValueKey('game-controls-dismiss-layer'),
                  child: IgnorePointer(
                    ignoring: !_showOverlay,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleOverlay,
                    ),
                  ),
                ),

              // Floating game controls — only while the game is up.
              if (_phase == _EnginePhase.running)
                Positioned(
                  key: const ValueKey('game-controls'),
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + 8,
                  child: _GameControls(
                    expanded: _showOverlay,
                    debugVisible: _showDebug,
                    ticking: _isTicking,
                    virtualControlsVisible: _showVirtualControls,
                    showDebugLabel: _showDebug
                        ? l10n.hideDebug
                        : l10n.showDebug,
                    pauseLabel: _isTicking ? l10n.pause : l10n.resume,
                    virtualControlsLabel: _showVirtualControls
                        ? l10n.hideVirtualControls
                        : l10n.showVirtualControls,
                    exitLabel: l10n.exitGame,
                    onToggle: _toggleOverlay,
                    onDebug: () => _selectGameMenuAction(_GameMenuAction.debug),
                    onPause: () => _selectGameMenuAction(_GameMenuAction.pause),
                    onVirtualControls: () =>
                        _selectGameMenuAction(_GameMenuAction.virtualControls),
                    onExit: () => _selectGameMenuAction(_GameMenuAction.exit),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _bootTitle {
    final title = widget.title;
    if (title != null && title.isNotEmpty) return title;
    final parts = widget.gamePath.split(RegExp(r'[/\\]'));
    return parts.lastWhere((p) => p.isNotEmpty, orElse: () => widget.gamePath);
  }

  File? get _bootCoverFile {
    final path = widget.coverPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  int get _bootStep {
    switch (_phase) {
      case _EnginePhase.initializing:
        return 0;
      case _EnginePhase.creating:
        return 1;
      case _EnginePhase.opening:
        return 2;
      default:
        return 2;
    }
  }

  /// 当前步骤从下方刷入、旧步骤向上刷出。
  Widget _buildBootStepTicker(String label, Color foreground) {
    return ClipRect(
      child: SizedBox(
        height: 28,
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: UiDuration.slow,
          switchInCurve: UiCurves.iosStandard,
          switchOutCurve: UiCurves.iosSmooth,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey<String>(label);
            final begin = incoming
                ? const Offset(0, 0.85)
                : const Offset(0, -0.85);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: begin,
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            label,
            key: ValueKey<String>(label),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBootLogView() {
    final l10n = AppLocalizations.of(context)!;
    final cover = _bootCoverFile;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final reversedLogs = _logs.reversed.toList();
    final step = _bootStep;
    final colors = context.uiColors;
    final foreground = cover == null ? colors.textPrimary : colors.textOnBrand;
    final secondaryForeground = cover == null
        ? colors.textSecondary
        : colors.textOnBrand.withValues(alpha: 0.72);
    final logSurface = cover == null
        ? colors.surfaceElevated
        : colors.overlay.withValues(alpha: 0.50);
    final logBorder = cover == null
        ? colors.border
        : colors.textOnBrand.withValues(alpha: 0.12);
    final stepLabels = [
      l10n.gamePreparingEngine,
      l10n.gameOpening,
      l10n.gameLoadingResources,
    ];

    if (_showBootLogs) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_bootLogScrollController.hasClients) {
          _bootLogScrollController.jumpTo(
            _bootLogScrollController.position.maxScrollExtent,
          );
        }
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: colors.background),
        if (cover != null)
          ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 46, sigmaY: 46),
              child: Transform.scale(
                scale: 1.18,
                child: Image.file(
                  cover,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        if (cover != null)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.overlay.withValues(alpha: 0.76),
                  colors.overlay.withValues(alpha: 0.66),
                  colors.overlay.withValues(alpha: 0.84),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: UiButton(
                    label: l10n.cancel,
                    variant: UiButtonVariant.ghost,
                    size: UiButtonSize.small,
                    onPressed: _exitGame,
                  ),
                ),
                Expanded(
                  flex: _showBootLogs ? 2 : 3,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cover != null && !landscape) ...[
                            SizedBox(
                              width: 84,
                              height: 112,
                              child: UiGameCover(
                                image: FileImage(cover),
                                borderRadius: UiRadius.brLg,
                                filterQuality: FilterQuality.medium,
                                semanticLabel: _bootTitle,
                                placeholder: const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: UiSpacing.lg),
                          ],
                          Text(
                            _bootTitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.gameEngine(_engine.label),
                            style: TextStyle(
                              color: secondaryForeground,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: UiSpacing.xl),
                          UiLoader(
                            size: UiLoaderSize.medium,
                            color: foreground,
                          ),
                          const SizedBox(height: UiSpacing.lg),
                          _buildBootStepTicker(stepLabels[step], foreground),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showBootLogs)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.34,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: logSurface,
                        borderRadius: UiRadius.brLg,
                        border: Border.all(color: logBorder),
                      ),
                      child: reversedLogs.isEmpty
                          ? Center(
                              child: Text(
                                l10n.gameStarting,
                                style: TextStyle(
                                  color: secondaryForeground.withValues(
                                    alpha: 0.48,
                                  ),
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _bootLogScrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: reversedLogs.length,
                              itemBuilder: (context, index) {
                                final log = reversedLogs[index];
                                final isError = log.contains('ERROR');
                                final isOk = log.contains('=> OK');
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      color: isError
                                          ? colors.danger
                                          : isOk
                                          ? colors.success
                                          : secondaryForeground.withValues(
                                              alpha: 0.72,
                                            ),
                                      fontSize: 11,
                                      height: 1.35,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                const SizedBox(height: UiSpacing.sm),
                UiButton(
                  label: _showBootLogs
                      ? l10n.gameHideBootLogs
                      : l10n.gameBootLogs,
                  variant: UiButtonVariant.ghost,
                  size: UiButtonSize.small,
                  onPressed: () =>
                      setState(() => _showBootLogs = !_showBootLogs),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.uiColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert, color: colors.danger, size: 64),
            const SizedBox(height: 16),
            Text(
              l10n.gameEngineError,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: SelectableText(
                _errorMessage ?? l10n.unknownError,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UiButton(
                  label: l10n.back,
                  leadingIcon: LucideIcons.chevronLeft,
                  variant: UiButtonVariant.outline,
                  onPressed: () =>
                      unawaited(_exitGame(runtimeTerminated: !_engineConflict)),
                ),
                const SizedBox(width: UiSpacing.lg),
                UiButton(
                  label: l10n.retry,
                  leadingIcon: LucideIcons.refreshCw,
                  onPressed: () => unawaited(_retryStart()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _GameMenuAction { debug, pause, virtualControls, exit }

class _GameDebugSheetContent extends StatefulWidget {
  const _GameDebugSheetContent({
    required this.phase,
    required this.tickCount,
    required this.ticking,
    required this.logs,
    required this.onClear,
  });

  final ValueGetter<String> phase;
  final ValueGetter<int> tickCount;
  final ValueGetter<bool> ticking;
  final ValueGetter<List<String>> logs;
  final VoidCallback onClear;

  @override
  State<_GameDebugSheetContent> createState() => _GameDebugSheetContentState();
}

class _GameDebugSheetContentState extends State<_GameDebugSheetContent> {
  late final Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final logs = List<String>.of(widget.logs());
    final height = (MediaQuery.sizeOf(context).height * 0.22)
        .clamp(176.0, 230.0)
        .toDouble();

    Widget metric(String label, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              height: 1.3,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0.2,
              height: 1.3,
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    metric('PHASE', widget.phase()),
                    metric('TICKS', '${widget.tickCount()}'),
                    metric('STATE', widget.ticking() ? 'running' : 'paused'),
                  ],
                ),
              ),
              UiButton(
                label: 'Clear',
                size: UiButtonSize.small,
                variant: UiButtonVariant.ghost,
                enableHaptic: false,
                onPressed: () {
                  widget.onClear();
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: UiSpacing.sm),
          Divider(height: 0.5, thickness: 0.5, color: colors.separator),
          const SizedBox(height: UiSpacing.sm),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No log entries',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) => Text(
                      logs[index],
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GameControls extends StatefulWidget {
  const _GameControls({
    required this.expanded,
    required this.debugVisible,
    required this.ticking,
    required this.virtualControlsVisible,
    required this.showDebugLabel,
    required this.pauseLabel,
    required this.virtualControlsLabel,
    required this.exitLabel,
    required this.onToggle,
    required this.onDebug,
    required this.onPause,
    required this.onVirtualControls,
    required this.onExit,
  });

  final bool expanded;
  final bool debugVisible;
  final bool ticking;
  final bool virtualControlsVisible;
  final String showDebugLabel;
  final String pauseLabel;
  final String virtualControlsLabel;
  final String exitLabel;
  final VoidCallback onToggle;
  final VoidCallback onDebug;
  final VoidCallback onPause;
  final VoidCallback onVirtualControls;
  final VoidCallback onExit;

  @override
  State<_GameControls> createState() => _GameControlsState();
}

class _GameControlsState extends State<_GameControls>
    with TickerProviderStateMixin {
  static const double _collapsedSize = 44;
  static const double _expandedWidth = 184;
  static const double _expandedHeight = 104;
  static final SpringDescription _expandSpring =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 420),
        bounce: 0.18,
      );
  static final SpringDescription _collapseSpring =
      SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 300),
        bounce: 0.04,
      );
  static const Curve _debugReveal = Interval(
    0.10,
    0.54,
    curve: Curves.easeOutCubic,
  );
  static const Curve _pauseReveal = Interval(
    0.16,
    0.60,
    curve: Curves.easeOutCubic,
  );
  static const Curve _virtualControlsReveal = Interval(
    0.22,
    0.66,
    curve: Curves.easeOutCubic,
  );
  static const Curve _exitReveal = Interval(
    0.28,
    0.78,
    curve: Curves.easeOutCubic,
  );
  static const Curve _dividerReveal = Interval(
    0.20,
    0.58,
    curve: Curves.easeOutCubic,
  );

  late final AnimationController _shapeController =
      AnimationController.unbounded(
        vsync: this,
        value: widget.expanded ? 1 : 0,
      );
  late final AnimationController _contentController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 210),
    value: widget.expanded ? 1 : 0,
  );

  void _animateShape(bool expanded) {
    _shapeController.animateWith(
      SpringSimulation(
        expanded ? _expandSpring : _collapseSpring,
        _shapeController.value,
        expanded ? 1 : 0,
        _shapeController.velocity,
        snapToEnd: true,
        tolerance: const Tolerance(distance: 0.001, velocity: 0.001),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _GameControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded == oldWidget.expanded) return;
    if (widget.expanded) {
      _animateShape(true);
      _contentController.forward();
    } else {
      _animateShape(false);
      _contentController.reverse();
    }
  }

  @override
  void dispose() {
    _shapeController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colors = context.uiColors;
    final mediaForeground = colors.textOnBrand;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_shapeController, _contentController]),
        builder: (context, _) {
          final shapeProgress = reduceMotion
              ? (widget.expanded ? 1.0 : 0.0)
              : _shapeController.value;
          final elasticProgress = shapeProgress.clamp(-0.018, 1.018);
          final visualProgress = shapeProgress.clamp(0.0, 1.0);
          final contentProgress = reduceMotion
              ? (widget.expanded ? 1.0 : 0.0)
              : _contentController.value;
          final width =
              _collapsedSize +
              ((_expandedWidth - _collapsedSize) * elasticProgress);
          final height =
              _collapsedSize +
              ((_expandedHeight - _collapsedSize) * elasticProgress);
          final target = widget.expanded ? 1.0 : 0.0;
          double reveal(Curve curve) =>
              reduceMotion ? target : curve.transform(contentProgress);
          final materialPulse = reduceMotion
              ? 0.0
              : (4 * contentProgress * (1 - contentProgress)).clamp(0.0, 1.0);
          final glassRadius = BorderRadius.circular(22 + (4 * visualProgress));

          return Semantics(
            container: true,
            label: 'Game controls',
            child: SizedBox(
              width: width,
              height: height,
              child: UiGlassSurface(
                variant: UiGlassVariant.clear,
                borderRadius: glassRadius,
                enableBlur: true,
                interaction: materialPulse * 0.72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 0,
                      height: 0.5,
                      child: ColoredBox(
                        color: mediaForeground.withValues(
                          alpha: 0.14 + (0.14 * visualProgress),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.16 * materialPulse,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0.82, -0.86),
                                radius: 1.05,
                                colors: [
                                  Color(0xB8FFFFFF),
                                  Color(0x24FFFFFF),
                                  Color(0x00FFFFFF),
                                ],
                                stops: [0, 0.34, 0.78],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      ignoring: !widget.expanded,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 4,
                            top: 4,
                            width: _collapsedSize,
                            height: _collapsedSize,
                            child: _ControlReveal(
                              progress: reveal(_debugReveal),
                              horizontalOffset: 10,
                              child: _GlassIconAction(
                                icon: LucideIcons.bug,
                                label: widget.showDebugLabel,
                                selected: widget.debugVisible,
                                onTap: widget.onDebug,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 48,
                            top: 4,
                            width: _collapsedSize,
                            height: _collapsedSize,
                            child: _ControlReveal(
                              progress: reveal(_pauseReveal),
                              horizontalOffset: 7,
                              child: _GlassIconAction(
                                icon: widget.ticking
                                    ? LucideIcons.pause
                                    : LucideIcons.play,
                                label: widget.pauseLabel,
                                onTap: widget.onPause,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 92,
                            top: 4,
                            width: _collapsedSize,
                            height: _collapsedSize,
                            child: _ControlReveal(
                              progress: reveal(_virtualControlsReveal),
                              horizontalOffset: 4,
                              child: _GlassIconAction(
                                icon: LucideIcons.gamepad2,
                                label: widget.virtualControlsLabel,
                                selected: widget.virtualControlsVisible,
                                onTap: widget.onVirtualControls,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 52,
                            child: Opacity(
                              opacity: reveal(_dividerReveal).clamp(0.0, 1.0),
                              child: Divider(
                                height: 0.5,
                                thickness: 0.5,
                                color: mediaForeground.withValues(alpha: 0.14),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 4,
                            top: 56,
                            height: 44,
                            child: _ControlReveal(
                              progress: reveal(_exitReveal),
                              verticalOffset: 5,
                              child: _GlassExitAction(
                                label: widget.exitLabel,
                                onTap: widget.onExit,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 4 * visualProgress,
                      top: 4 * visualProgress,
                      width: _collapsedSize,
                      height: _collapsedSize,
                      child: _MorphingMenuButton(
                        progress: contentProgress,
                        expanded: widget.expanded,
                        onTap: widget.onToggle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ControlReveal extends StatelessWidget {
  const _ControlReveal({
    required this.progress,
    required this.child,
    this.horizontalOffset = 0,
    this.verticalOffset = 7,
  });

  final double progress;
  final double horizontalOffset;
  final double verticalOffset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visibility = progress.clamp(0.0, 1.0);
    return Opacity(
      opacity: visibility,
      child: Transform.translate(
        offset: Offset(
          horizontalOffset * (1 - progress),
          verticalOffset * (1 - progress),
        ),
        child: Transform.scale(scale: 0.88 + (0.12 * progress), child: child),
      ),
    );
  }
}

class _MorphingMenuButton extends StatefulWidget {
  const _MorphingMenuButton({
    required this.progress,
    required this.expanded,
    required this.onTap,
  });

  final double progress;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_MorphingMenuButton> createState() => _MorphingMenuButtonState();
}

class _MorphingMenuButtonState extends State<_MorphingMenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  void _animatePress(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _press.value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(UiSprings.press, _press.value, target, _press.velocity),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final progress = widget.progress.clamp(0.0, 1.0);
    final dotsProgress = (progress / 0.46).clamp(0.0, 1.0);
    final closeProgress = ((progress - 0.22) / 0.58).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: widget.expanded ? 'Close game controls' : 'Open game controls',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _animatePress(1),
        onTapCancel: () => _animatePress(0),
        onTapUp: (_) => _animatePress(0),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final pressed = _press.value.clamp(0.0, 1.0);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                1 - (0.04 * pressed),
                1 - (0.10 * pressed),
                1,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: pressed,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.textOnBrand.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Opacity(
                    opacity: 1 - dotsProgress,
                    child: Transform.rotate(
                      angle: progress * 0.34,
                      child: Transform.scale(
                        scaleX: 1 - (0.24 * dotsProgress),
                        scaleY: 1 + (0.08 * dotsProgress),
                        child: UiIcon(
                          UiIcons.moreHorizontal,
                          size: 20,
                          color: colors.textOnBrand.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: closeProgress,
                    child: Transform.scale(
                      scale: 0.72 + (0.28 * closeProgress),
                      child: Transform.rotate(
                        angle: (1 - closeProgress) * -0.52,
                        child: UiIcon(
                          UiIcons.close,
                          size: 18,
                          color: colors.textOnBrand.withValues(alpha: 0.84),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GlassIconAction extends StatefulWidget {
  const _GlassIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  State<_GlassIconAction> createState() => _GlassIconActionState();
}

class _GlassIconActionState extends State<_GlassIconAction> {
  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return Semantics(
      selected: widget.selected,
      child: SizedBox.square(
        dimension: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: widget.selected ? 1 : 0,
              duration: UiDuration.fast,
              curve: UiCurves.iosSmooth,
              child: AnimatedScale(
                scale: widget.selected ? 1 : 0.72,
                duration: UiDuration.fast,
                curve: UiCurves.iosSmooth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 34),
                ),
              ),
            ),
            UiGlassIconButton(
              icon: widget.icon,
              semanticLabel: widget.label,
              size: 44,
              iconSize: 17,
              contained: false,
              enableHaptic: true,
              foregroundColor: widget.selected
                  ? colors.brand
                  : colors.textOnBrand.withValues(alpha: 0.90),
              onPressed: widget.onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassExitAction extends StatefulWidget {
  const _GlassExitAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_GlassExitAction> createState() => _GlassExitActionState();
}

class _GlassExitActionState extends State<_GlassExitAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  void _animatePress(double target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _press.value = target;
      return;
    }
    _press.animateWith(
      SpringSimulation(UiSprings.press, _press.value, target, _press.velocity),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _animatePress(1),
        onTapCancel: () => _animatePress(0),
        onTapUp: (_) => _animatePress(0),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final pressed = _press.value.clamp(0.0, 1.0);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                1 - (0.015 * pressed),
                1 - (0.045 * pressed),
                1,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.14 * pressed),
                  borderRadius: UiRadius.brLg,
                ),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                UiIcon(LucideIcons.logOut, size: 17, color: colors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.1,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _EnginePhase { initializing, creating, opening, running, error }
