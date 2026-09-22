import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_info.dart';
import '../constants/prefs_keys.dart';
import '../flows/game_metadata_scrape_flow.dart';
import '../l10n/app_localizations.dart';
import '../l10n/file_manager_localizations.dart';
import '../models/game_engine.dart';
import '../models/game_info.dart';
import '../services/android_document_file_system.dart';
import '../services/engine_runtime_guard.dart';
import '../services/game_directory_scanner.dart';
import '../services/file_manager_controller.dart';
import '../services/game_manager.dart';
import '../services/local_file_service.dart';
import '../ui/ui.dart';
import '../widgets/home_game_card.dart';
import '../widgets/home_profile_tab.dart';
import 'about_page.dart';
import 'game_detail_page.dart';
import 'game_page.dart';
import 'help_page.dart';
import 'manager_page.dart';
import 'play_statistics_page.dart';
import 'settings_page.dart';

/// Engine loading mode: built-in (bundled in .app) or custom (user-specified).
enum EngineMode { builtIn, custom }

/// The home / launcher page — manage and launch games.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _navBackdropKey = GlobalKey<GlassContentAwareScopeState>();
  final GameManager _gameManager = GameManager();
  late final FileManagerController _fileManager = FileManagerController(
    gameManager: _gameManager,
  );
  final GameMetadataScrapeFlow _scrapeFlow = GameMetadataScrapeFlow();
  bool _loading = true;
  bool _startupScanInProgress = false;
  String? _iosGamesDir;
  // Platform-provided public drop directory and its short display label.
  String? _publicGamesDir;
  String? _publicGamesDirDisplay;
  // On Android/iOS the engine is always built-in; EngineMode switching is
  // only meaningful on desktop platforms.
  EngineMode _engineMode = EngineMode.builtIn;
  String? _customDylibPath;
  String? _builtInDylibPath;
  bool _builtInAvailable = false;
  bool _perfOverlay = false;
  bool _fpsLimitEnabled = false;
  int _targetFps = PrefsKeys.defaultFps;
  String _renderer = PrefsKeys.rendererOpengl;
  String _angleBackend = PrefsKeys.angleBackendGles;
  String _gameOrientation = PrefsKeys.gameOrientationLandscape;
  bool _restartDeferred = false;
  int _selectedTab = 0;
  static const _manageTabIndex = 1;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchActive = false;
  String _searchQuery = '';

  String? _resolveBuiltInDylibPath() {
    if (Platform.isIOS) {
      return '__static_linked__';
    }
    if (Platform.isAndroid) {
      // On Android, native libs are bundled in the APK and loaded
      // automatically via DynamicLibrary.open('libengine_api.so').
      return '__bundled_in_apk__';
    }
    if (Platform.operatingSystem == 'ohos') {
      // Same as Android: libengine_api.so is packaged in the HAP and
      // resolved by the loader search path.
      return '__bundled_in_hap__';
    }
    try {
      final executablePath = Platform.resolvedExecutable;
      final execDir = File(executablePath).parent.path;
      final frameworksPath = '$execDir/../Frameworks/libengine_api.dylib';
      final resolved = File(frameworksPath);
      if (resolved.existsSync()) return resolved.path;
    } catch (_) {}
    return null;
  }

  String? get _effectiveDylibPath {
    if (_engineMode == EngineMode.builtIn) {
      // On iOS/Android/OHOS, the engine is loaded automatically by the system;
      // no explicit dylib path is needed.
      if (Platform.isIOS ||
          Platform.isAndroid ||
          Platform.operatingSystem == 'ohos') {
        return null;
      }
      return _builtInDylibPath;
    }
    return _customDylibPath;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fileManager.addListener(_onFileManagerChanged);
    _loadGames();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fileManager.removeListener(_onFileManagerChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fileManager.dispose();
    super.dispose();
  }

  void _onFileManagerChanged() {
    if (!mounted) return;
    // Progress ticks are the Manage tab's concern; the library only needs
    // to rebuild once a task finished and paths may have moved.
    if (_fileManager.task != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the file manager after copying a game in: pick it up
    // without making the user pull to refresh.
    if (state == AppLifecycleState.resumed &&
        (Platform.isAndroid || Platform.operatingSystem == 'ohos') &&
        !_loading &&
        !_startupScanInProgress &&
        !_fileManager.blocksLibraryScan) {
      unawaited(_refreshPublicGames(silent: true));
    }
  }

  Future<void> _loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    _builtInDylibPath = _resolveBuiltInDylibPath();
    _builtInAvailable = _builtInDylibPath != null;
    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile platforms always use the bundled engine; skip mode loading.
      _engineMode = EngineMode.builtIn;
      _customDylibPath = null;
    } else {
      final modeStr = prefs.getString(PrefsKeys.engineMode);
      _engineMode = modeStr == PrefsKeys.engineModeCustom
          ? EngineMode.custom
          : EngineMode.builtIn;
      _customDylibPath = prefs.getString(PrefsKeys.dylibPath);
    }
    _perfOverlay = prefs.getBool(PrefsKeys.perfOverlay) ?? false;
    _fpsLimitEnabled = prefs.getBool(PrefsKeys.fpsLimitEnabled) ?? false;
    _targetFps = prefs.getInt(PrefsKeys.targetFps) ?? PrefsKeys.defaultFps;
    if (!PrefsKeys.fpsOptions.contains(_targetFps)) {
      _targetFps = PrefsKeys.defaultFps;
    }
    _renderer = prefs.getString(PrefsKeys.renderer) ?? PrefsKeys.rendererOpengl;
    _angleBackend =
        prefs.getString(PrefsKeys.angleBackend) ?? PrefsKeys.angleBackendGles;
    _gameOrientation = PrefsKeys.readGameOrientation(
      prefs.getString(PrefsKeys.gameOrientation),
      legacyForceLandscape: prefs.getBool(PrefsKeys.forceLandscape),
    );
    await _gameManager.load();
    if (!mounted) return;

    final needsStartupScan =
        Platform.isIOS ||
        Platform.isAndroid ||
        Platform.operatingSystem == 'ohos';
    setState(() {
      _loading = false;
      _startupScanInProgress = needsStartupScan;
    });

    // Restore the persisted library first so the home shell and existing
    // cards can paint immediately. File-system discovery is non-critical and
    // starts only after that frame has reached the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_finishStartupTasks());
    });
  }

  Future<void> _finishStartupTasks() async {
    try {
      await _gameManager.applyPendingPlaySession();
      if (Platform.isIOS) {
        await _initIosGamesDir();
      } else if (Platform.isAndroid || Platform.operatingSystem == 'ohos') {
        await _initPublicGamesDir();
        await _scanPublicGamesDir();
      }
    } catch (error, stackTrace) {
      debugPrint('Background home initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() => _startupScanInProgress = false);
      }
    }
  }

  /// Both mobile adapters return `Download/{appId}/games`. Android requires
  /// storage authorization first. Resolve again on resume so
  /// revoked Android permission cannot leave a cached path in use.
  Future<void> _initPublicGamesDir() async {
    if (_publicGamesDir != null && !Platform.isAndroid) return;
    try {
      final info = await _platformChannel.invokeMapMethod<String, dynamic>(
        'ensurePublicGamesDir',
      );
      final path = info?['path'] as String?;
      if (path == null || path.isEmpty) {
        _publicGamesDir = null;
        if (Platform.isAndroid && !GameRuntimeBinding.pageActive) {
          await GameRuntimeBinding.releaseParked();
        }
        return;
      }
      _publicGamesDir = path;
      _publicGamesDirDisplay = (info?['display'] as String?) ?? path;
    } on PlatformException catch (e) {
      _publicGamesDir = null;
      debugPrint('ensurePublicGamesDir failed: ${e.code} ${e.message}');
    } on MissingPluginException {
      // Older native plugin without this method.
    }
  }

  /// Register games that appeared under [_publicGamesDir] and drop
  /// entries whose folder the user has since deleted. Returns the number of
  /// newly added games.
  Future<int> _scanPublicGamesDir() async {
    final dirPath = _publicGamesDir;
    if (dirPath == null) return 0;
    if (_fileManager.blocksLibraryScan) return 0;
    if (Platform.isAndroid) {
      final io = AndroidDocumentFileSystem(p.dirname(dirPath));
      final candidates = await GameDirectoryScanner(io).scan(dirPath);
      for (final game in List<GameInfo>.of(_gameManager.games)) {
        if (!p.isWithin(dirPath, game.path) ||
            LocalFileService.isPrivatePath(game.path)) {
          continue;
        }
        if (!await io.exists(game.path)) {
          await _gameManager.markUnavailable(game.path);
        } else if (!game.available) {
          await _gameManager.markAvailable(game.path);
        }
      }
      final registered = _gameManager.games.map((g) => g.path).toSet();
      var added = 0;
      for (final candidate in candidates.entries) {
        if (!registered.contains(candidate.key) &&
            await _gameManager.addGame(
              GameInfo(path: candidate.key, engine: candidate.value),
            )) {
          added++;
        }
      }
      return added;
    }
    final root = Directory(dirPath);
    if (!root.existsSync()) return 0;

    for (final game in List<GameInfo>.of(_gameManager.games)) {
      if (LocalFileService.isPrivatePath(game.path)) continue;
      if (!p.isWithin(dirPath, game.path) && game.path != dirPath) continue;
      final exists =
          Directory(game.path).existsSync() || File(game.path).existsSync();
      if (!exists) {
        await _gameManager.markUnavailable(game.path);
      } else if (!game.available) {
        await _gameManager.markAvailable(game.path);
      }
    }

    final candidates = <String>{};
    for (final dir in _scanSandboxForGameDirectories(root)) {
      candidates.add(dir.path);
    }
    for (final file in _scanSandboxForXp3(root)) {
      candidates.add(file.path);
    }
    // A folder is registered as one game; loose archives inside it
    // (data.xp3 + patch.xp3 ...) are part of that game, not separate ones.
    final dirs = candidates.where((c) => Directory(c).existsSync()).toSet();
    candidates.removeWhere(
      (c) => !dirs.contains(c) && dirs.any((d) => p.isWithin(d, c)),
    );

    final registered = _gameManager.games.map((g) => g.path).toSet();
    final fresh = candidates.where((c) => !registered.contains(c)).toList()
      ..sort();
    var added = 0;
    for (final path in fresh) {
      if (await _gameManager.addGame(GameInfo(path: path))) added++;
    }
    return added;
  }

  /// Rescan the public games folder. [silent] skips the result toast
  /// (lifecycle-triggered scans); pull-to-refresh and the menu report back.
  Future<void> _refreshPublicGames({bool silent = false}) async {
    try {
      await _initPublicGamesDir();
      final added = await _scanPublicGamesDir();
      if (!mounted) return;
      if (added > 0 || !silent) setState(() {});
      if (silent) return;
      final l10n = AppLocalizations.of(context)!;
      UiToast.show(
        context,
        message: added > 0 ? l10n.gamesImported(added) : l10n.noNewGamesFound,
        type: added > 0 ? UiToastType.success : UiToastType.info,
      );
    } catch (error) {
      if (!mounted || silent) return;
      UiToast.show(
        context,
        message: AppLocalizations.of(
          context,
        )!.fileOperationError(FileOperationException.from(error).code),
        type: UiToastType.error,
      );
    }
  }

  Future<void> _initIosGamesDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final gamesDir = Directory('${docDir.path}/Games');
    if (!await gamesDir.exists()) {
      await gamesDir.create(recursive: true);
    }
    _iosGamesDir = gamesDir.path;
    await _scanIosGamesDir();
  }

  Future<void> _scanIosGamesDir() async {
    if (_iosGamesDir == null) return;
    final gamesDir = Directory(_iosGamesDir!);
    if (!await gamesDir.exists()) return;

    // Remove stale entries whose directories no longer exist on disk
    // (handles iOS sandbox UUID changes leaving orphaned entries).
    final stale = <String>[];
    for (final g in _gameManager.games) {
      if (!await Directory(g.path).exists()) {
        stale.add(g.path);
      }
    }
    for (final path in stale) {
      await _gameManager.removeGame(path);
    }

    final existingByName = <String, GameInfo>{};
    for (final g in _gameManager.games) {
      existingByName[p.basename(g.path)] = g;
    }

    final entries = await gamesDir.list().toList();
    final scannedNames = <String>{};
    for (final entry in entries) {
      if (entry is Directory) {
        final name = p.basename(entry.path);
        scannedNames.add(name);
        final existing = existingByName[name];
        if (existing != null) {
          if (existing.path != entry.path) {
            await _gameManager.updateGamePath(existing.path, entry.path);
          }
        } else {
          final game = GameInfo(path: entry.path);
          await _gameManager.addGame(game);
        }
      }
    }

    final toRemove = _gameManager.games
        .where(
          (g) =>
              g.path.startsWith(_iosGamesDir!) &&
              !scannedNames.contains(p.basename(g.path)),
        )
        .map((g) => g.path)
        .toList();
    for (final path in toRemove) {
      await _gameManager.removeGame(path);
    }
  }

  Rect _fallbackMenuAnchor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    return Rect.fromLTWH(size.width - 64, pad.top + 8, 44, 44);
  }

  Future<void> _addGame({Rect? anchor}) async {
    if (Platform.isAndroid) {
      await _authorizeAndroidGamesDirectory();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    if (Platform.isIOS) {
      await _scanIosGamesDir();
      if (mounted) {
        setState(() {});
        _showIosImportGuide();
      }
      return;
    }

    final source = await UiPopupMenu.show<String>(
      context,
      anchor: anchor ?? _fallbackMenuAnchor(context),
      items: [
        UiMenuItem(
          label: l10n.selectGameArchive,
          icon: LucideIcons.archive,
          value: 'xp3',
        ),
        if (Platform.isAndroid || Platform.operatingSystem == 'ohos')
          UiMenuItem(
            label: l10n.rescanGamesDir,
            icon: LucideIcons.scanSearch,
            value: 'sandbox',
          ),
      ],
    );
    if (source == null || !mounted) return;

    if (source == 'sandbox' && Platform.isAndroid) {
      await _authorizeAndroidGamesDirectory();
    } else if (source == 'sandbox') {
      await _addGameFromSandbox();
    } else {
      await _addGameArchive();
    }
  }

  Future<void> _authorizeAndroidGamesDirectory() async {
    await _fileManager.authorize();
    if (!mounted) return;
    final error = _fileManager.lastError;
    if (error != null) {
      UiToast.show(
        context,
        message: AppLocalizations.of(context)!.fileOperationError(error.code),
        type: UiToastType.error,
      );
      return;
    }
    await _refreshPublicGames();
  }

  // Kept for future entry points; the home import menu currently hides it.
  // ignore: unused_element
  Future<void> _addGameDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    if (Platform.operatingSystem == 'ohos') {
      await _addGameDirectoryOhos();
      return;
    }
    final String? selectedDirectory = await FilePicker.platform
        .getDirectoryPath(dialogTitle: l10n.selectGameDirectory);
    if (selectedDirectory == null || !mounted) return;

    final game = GameInfo(path: selectedDirectory);
    final added = await _gameManager.addGame(game);
    if (mounted) {
      if (added) {
        setState(() {});
        _offerScrapeAfterAdd(selectedDirectory);
      } else {
        UiSnackbar.show(
          context,
          message: l10n.gameAlreadyExists(game.displayTitle),
          type: UiSnackbarType.warning,
        );
      }
    }
  }

  static const MethodChannel _platformChannel = MethodChannel(
    'flutter_engine_bridge',
  );

  Future<void> _addGameArchive() async {
    final l10n = AppLocalizations.of(context)!;

    if (Platform.isAndroid) {
      // Native picker: zero-copy, returns real filesystem path directly.
      final realPath = await _platformChannel.invokeMethod<String>('pickFile');
      if (realPath == null || !mounted) return;
      if (!realPath.toLowerCase().endsWith('.xp3')) {
        UiSnackbar.show(
          context,
          message: l10n.selectGameArchive,
          type: UiSnackbarType.warning,
        );
        return;
      }
      final game = GameInfo(path: realPath);
      final added = await _gameManager.addGame(game);
      if (mounted) {
        if (added) {
          setState(() {});
          _offerScrapeAfterAdd(realPath);
        } else {
          UiSnackbar.show(
            context,
            message: l10n.gameAlreadyExists(p.basename(realPath)),
            type: UiSnackbarType.warning,
          );
        }
      }
      return;
    }

    if (Platform.isMacOS) {
      // Using getDirectoryPath() causes macOS to grant powerbox-level access to the entire folder,
      // which persists across app launches and allows the engine to open all files within the directory.
      await _showMacosImportGuide();

      final selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: l10n.selectGameArchive,
      );
      if (selectedDir == null || !mounted) return;

      final xp3Files =
          Directory(selectedDir)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.xp3'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      if (xp3Files.isEmpty) {
        UiSnackbar.show(
          context,
          message: l10n.selectGameArchive,
          type: UiSnackbarType.warning,
        );
        return;
      }

      // Pick the main XP3 file.
      final File? selectedFile;
      if (xp3Files.length == 1) {
        selectedFile = xp3Files.first;
      } else {
        selectedFile = await _pickXp3File(xp3Files);
        if (selectedFile == null || !mounted) return;
      }

      final game = GameInfo(path: selectedFile.path);
      final added = await _gameManager.addGame(game);
      if (mounted) {
        if (added) {
          setState(() {});
          _offerScrapeAfterAdd(selectedFile.path);
        } else {
          UiSnackbar.show(
            context,
            message: l10n.gameAlreadyExists(p.basename(selectedFile.path)),
            type: UiSnackbarType.warning,
          );
        }
      }
      return;
    }

    if (Platform.operatingSystem == 'ohos') {
      await _addGameArchiveOhos();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.selectGameArchive,
      type: FileType.custom,
      allowedExtensions: ['xp3', 'XP3'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final xp3Files = result.files.where((f) {
      final path = f.path;
      if (path == null) return false;
      return path.toLowerCase().endsWith('.xp3');
    }).toList();

    if (xp3Files.isEmpty) {
      if (mounted) {
        UiSnackbar.show(
          context,
          message: l10n.selectGameArchive,
          type: UiSnackbarType.warning,
        );
      }
      return;
    }

    int addedCount = 0;
    String? lastAddedPath;
    for (final file in xp3Files) {
      final filePath = file.path;
      if (filePath == null) continue;
      final game = GameInfo(path: filePath);
      if (await _gameManager.addGame(game)) {
        addedCount++;
        lastAddedPath = filePath;
      }
    }
    if (mounted) {
      if (addedCount > 0) {
        setState(() {});
        if (addedCount == 1 && lastAddedPath != null) {
          _offerScrapeAfterAdd(lastAddedPath);
        }
      } else {
        UiSnackbar.show(
          context,
          message: l10n.gameAlreadyExists(xp3Files.first.name),
          type: UiSnackbarType.warning,
        );
      }
    }
  }

  /// OHOS import path. The system document picker only hands out docs://
  /// URIs, not POSIX paths, so the fopen-based engine can't consume what it
  /// returns — and every app is sandboxed anyway. Games therefore arrive by
  /// side-loading, and importing means scanning the sandbox plus a few
  /// well-known developer roots instead of running a system picker.
  static const List<String> _ohosExtraScanRoots = [
    '/data/local/tmp',
    // Sandbox files root (parent of the documents dir). `hdc file send`
    // can deliver multi-GB archives here at ~400 MB/s — far faster and
    // more reliable than the rport HTTP tunnel — and it stays inside the
    // app sandbox, so the engine can always read it.
    '/data/storage/el2/base/files',
  ];

  /// OHOS 导入：系统 DocumentViewPicker 选 .xp3（可多选）。
  ///
  /// 适配版 file_picker 的实现会把选中文件拷贝到应用 cache
  /// （`cache/file_picker/`）再返回路径；cache 可能被系统清理，所以这里把
  /// 副本改名移入应用 files 目录后再注册（同卷 rename 瞬时完成，失败时
  /// 回退拷贝）。多选让"进入文件夹勾选多个 .xp3"成为文件夹导入的兜底
  /// ——folder 选择模式在部分系统版本上没有确认按钮。
  Future<void> _addGameArchiveOhos() async {
    final l10n = AppLocalizations.of(context)!;
    // .xp3 不是常见后缀，且适配层把无点号扩展名直接传给 OHOS 的
    // fileSuffixFilters（格式不符会过滤失败），因此用 any 选择 + 自行校验。
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(allowMultiple: true);
    } on Exception {
      // 适配层在用户取消时可能抛异常而非返回 null，视同取消。
      result = null;
    }
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final selectedPaths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .toList();
    final cachePaths = selectedPaths
        .where((path) => path.toLowerCase().endsWith('.xp3'))
        .toList();
    // Artemis: a multi-select of `root.pfs` + its `.pfs.000…` patch volumes
    // (+ optional save/config .dat/.ini) is one game — group the copies
    // into a directory named after the base pack.
    final artemisFiles = selectedPaths.where((path) {
      final lower = path.toLowerCase();
      return GameEngine.isPfsVolume(path) ||
          lower.endsWith('.dat') ||
          lower.endsWith('.ini');
    }).toList();
    final hasArtemisPack = artemisFiles.any(GameEngine.isPfsPack);
    if (hasArtemisPack) {
      final docDir = await getApplicationDocumentsDirectory();
      final base = p.basenameWithoutExtension(
        artemisFiles.firstWhere(GameEngine.isPfsPack),
      );
      var destDir = p.join(docDir.path, base);
      var n = 2;
      while (Directory(destDir).existsSync() || File(destDir).existsSync()) {
        destDir = p.join(docDir.path, '$base-${n++}');
      }
      await Directory(destDir).create(recursive: true);
      for (final cachePath in artemisFiles) {
        final dest = p.join(destDir, p.basename(cachePath));
        try {
          await File(cachePath).rename(dest);
        } on FileSystemException {
          await File(cachePath).copy(dest);
          try {
            await File(cachePath).delete();
          } catch (_) {}
        }
      }
      if (!mounted) return;
      final added = await _gameManager.addGame(GameInfo(path: destDir));
      if (!mounted) return;
      if (added) {
        setState(() {});
        _offerScrapeAfterAdd(destDir);
      }
      if (cachePaths.isEmpty) return;
    }
    if (cachePaths.isEmpty || !mounted) {
      if (!hasArtemisPack) {
        UiSnackbar.show(
          context,
          message: l10n.selectGameArchive,
          type: UiSnackbarType.warning,
        );
      }
      return;
    }

    final registered = _gameManager.games.map((g) => g.path).toSet();
    var addedCount = 0;
    String? firstAdded;
    var alreadyCount = 0;
    for (final cachePath in cachePaths) {
      final String destPath = await _adoptOhosCacheFile(cachePath) ?? cachePath;
      if (registered.contains(destPath)) {
        alreadyCount++;
        continue;
      }
      final added = await _gameManager.addGame(GameInfo(path: destPath));
      if (added) {
        addedCount++;
        firstAdded ??= destPath;
        registered.add(destPath);
      }
    }
    if (!mounted) return;
    if (addedCount > 0) {
      setState(() {});
      _offerScrapeAfterAdd(firstAdded!);
      if (addedCount > 1 && mounted) {
        UiSnackbar.show(
          context,
          message: l10n.gamesImported(addedCount),
          type: UiSnackbarType.success,
        );
      }
    } else if (alreadyCount > 0) {
      UiSnackbar.show(
        context,
        message: l10n.gameAlreadyExists(p.basename(cachePaths.first)),
        type: UiSnackbarType.warning,
      );
    }
  }

  /// OHOS 目录导入：系统选择器选文件夹，导入其中全部 .xp3。
  ///
  /// 适配层（本地 file_picker fork 的 ArkTS 'dir' 分支）会列出选中文件夹
  /// 里的 .xp3 并逐个拷入应用 cache，以 JSON 字符串（路径数组）回给
  /// getDirectoryPath——这是 OHOS 分支特有的返回约定；其他平台该接口
  /// 返回的是普通目录路径字符串。
  Future<void> _addGameDirectoryOhos() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.selectGameDirectory,
    );
    if (raw == null || raw.isEmpty || !mounted) return;
    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return;
    }
    if (decoded.isEmpty || !mounted) {
      UiSnackbar.show(
        context,
        message: l10n.noXp3InFolder,
        type: UiSnackbarType.warning,
      );
      return;
    }

    final registered = _gameManager.games.map((g) => g.path).toSet();
    var addedCount = 0;
    String? firstAdded;
    for (final cachePath in decoded.cast<String>()) {
      // An Artemis folder comes back as one cache *directory* (pack chain +
      // saves copied together); KiriKiri archives come back as files.
      final destPath = Directory(cachePath).existsSync()
          ? await _adoptOhosCacheDirectory(cachePath)
          : await _adoptOhosCacheFile(cachePath);
      if (destPath == null || registered.contains(destPath)) continue;
      final added = await _gameManager.addGame(GameInfo(path: destPath));
      if (added) {
        addedCount++;
        firstAdded ??= destPath;
        registered.add(destPath);
      }
    }
    if (!mounted) return;
    if (addedCount > 0) {
      setState(() {});
      _offerScrapeAfterAdd(firstAdded!);
      if (addedCount > 1 && mounted) {
        UiSnackbar.show(
          context,
          message: l10n.gamesImported(addedCount),
          type: UiSnackbarType.success,
        );
      }
    } else {
      UiSnackbar.show(
        context,
        message: l10n.gameAlreadyExists(p.basename(decoded.first as String)),
        type: UiSnackbarType.warning,
      );
    }
  }

  /// 把适配层落在应用 cache 的整个游戏目录副本（Artemis 封包链）移入应用
  /// files 目录并返回最终路径；同名目录已存在时追加序号，避免覆盖存档。
  Future<String?> _adoptOhosCacheDirectory(String cacheDir) async {
    final docDir = await getApplicationDocumentsDirectory();
    final base = p.basename(cacheDir);
    var destPath = p.join(docDir.path, base);
    var n = 2;
    while (Directory(destPath).existsSync() || File(destPath).existsSync()) {
      destPath = p.join(docDir.path, '$base-${n++}');
    }
    final picked = Directory(cacheDir);
    try {
      await picked.rename(destPath);
    } on FileSystemException {
      // 跨卷 rename 等异常时退回逐文件拷贝。
      await Directory(destPath).create(recursive: true);
      await for (final entity in picked.list(followLinks: false)) {
        if (entity is File) {
          await entity.copy(p.join(destPath, p.basename(entity.path)));
        }
      }
      try {
        await picked.delete(recursive: true);
      } catch (_) {}
    }
    return destPath;
  }

  /// 把适配层落在应用 cache 的文件副本移入应用 files 目录并返回最终路径。
  Future<String?> _adoptOhosCacheFile(String cachePath) async {
    final docDir = await getApplicationDocumentsDirectory();
    final destPath = p.join(docDir.path, p.basename(cachePath));
    final picked = File(cachePath);
    try {
      if (destPath != cachePath) {
        await picked.rename(destPath);
      }
    } on FileSystemException {
      // 跨卷 rename 等异常时退回拷贝。
      try {
        await File(destPath).delete();
      } catch (_) {}
      await picked.copy(destPath);
      try {
        await picked.delete();
      } catch (_) {}
    }
    return destPath;
  }

  /// Register games that were side-loaded into the app sandbox (or one
  /// of the developer roots) with `hdc file send`. Finds KiriKiri archives,
  /// unpacked KiriKiri directories and Artemis pack directories alike.
  Future<void> _addGameFromSandbox() async {
    final l10n = AppLocalizations.of(context)!;
    final docDir = await getApplicationDocumentsDirectory();

    // A set: the scan of a root and the direct probe of the same root can
    // both surface <root>/data.xp3.
    // Public games folder first: it is the documented drop location, so
    // anything new there should surface even if the scan roots below fail.
    await _initPublicGamesDir();
    final candidates = <String>{};
    final roots = <Directory>[docDir];
    final publicGames = _publicGamesDir;
    if (publicGames != null && Directory(publicGames).existsSync()) {
      roots.add(Directory(publicGames));
    }
    for (final root in _ohosExtraScanRoots) {
      if (Directory(root).existsSync()) roots.add(Directory(root));
    }
    for (final root in roots) {
      for (final dir in _scanSandboxForGameDirectories(root)) {
        candidates.add(dir.path);
      }
      for (final file in _scanSandboxForXp3(root)) {
        candidates.add(file.path);
      }
    }
    for (final root in _ohosExtraScanRoots) {
      // The developer roots are not listable by the app (mode --x for
      // other uids), so directory scans come back empty there — but
      // traversing a KNOWN path is allowed. Probe the conventional
      // KrKr archive name directly.
      final direct = File('$root/data.xp3');
      if (direct.existsSync()) candidates.add(direct.path);
    }
    // Directories are registered as a whole; drop archives that live inside
    // a directory we already list (an unpacked game beside its data.xp3).
    final dirs = candidates.where((c) => Directory(c).existsSync()).toSet();
    candidates.removeWhere(
      (c) => !dirs.contains(c) && dirs.any((d) => p.isWithin(d, c)),
    );

    final registered = _gameManager.games.map((g) => g.path).toSet();
    final fresh = candidates.where((c) => !registered.contains(c)).toList()
      ..sort();
    if (!mounted) return;
    if (fresh.isEmpty) {
      UiToast.show(
        context,
        message: candidates.isEmpty
            ? l10n.noGamesFoundInSandbox
            : l10n.allSandboxGamesRegistered,
        type: UiToastType.info,
      );
      return;
    }

    final String selected;
    if (fresh.length == 1) {
      selected = fresh.first;
    } else {
      final picked = await _pickCandidatePath(fresh);
      if (picked == null || !mounted) return;
      selected = picked;
    }

    final game = GameInfo(path: selected);
    final added = await _gameManager.addGame(game);
    if (!mounted) return;
    if (added) {
      setState(() {});
      _offerScrapeAfterAdd(selected);
    } else {
      UiSnackbar.show(
        context,
        message: l10n.gameAlreadyExists(p.basename(selected)),
        type: UiSnackbarType.warning,
      );
    }
  }

  /// 目录里有多个 XP3 时让用户选择主归档（默认选中第一个）。
  Future<File?> _pickXp3File(List<File> xp3Files) async {
    final picked = await _pickCandidatePath(
      xp3Files.map((f) => f.path).toList(),
    );
    return picked == null ? null : File(picked);
  }

  /// 多个候选（归档或游戏目录）时让用户选择一个（默认选中第一个）。
  /// 每项显示文件名并附引擎标签，便于区分 KiriKiri / Artemis 条目。
  Future<String?> _pickCandidatePath(List<String> paths) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ValueNotifier<int>(0);
    final future = UiDialog.show<String>(
      context,
      title: l10n.selectGameArchive,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 360),
        child: ValueListenableBuilder<int>(
          valueListenable: selected,
          builder: (ctx, idx, _) => ListView.builder(
            shrinkWrap: true,
            itemCount: paths.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: UiSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: UiRadio<int>(
                      value: i,
                      groupValue: idx,
                      onChanged: (v) => selected.value = v,
                      label: p.basename(paths[i]),
                    ),
                  ),
                  const SizedBox(width: UiSpacing.sm),
                  UiTag(
                    label: GameEngine.detect(paths[i]).label,
                    tone: GameEngine.detect(paths[i]) == GameEngine.artemis
                        ? UiTagTone.brand
                        : UiTagTone.neutral,
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        UiDialogAction(label: l10n.cancel),
        UiDialogAction(
          label: l10n.addGame,
          isDefault: true,
          onPressed: () => Navigator.pop(context, paths[selected.value]),
        ),
      ],
    );
    future.whenComplete(
      () => Future<void>.delayed(
        const Duration(milliseconds: 500),
        selected.dispose,
      ),
    );
    return future;
  }

  /// Finds .xp3 archives under [root], up to a small depth so an accidental
  /// scan of a huge tree stays bounded.
  static List<File> _scanSandboxForXp3(Directory root) {
    final results = <File>[];
    void walk(Directory dir, int depth) {
      if (depth > 3) return;
      try {
        for (final entity in dir.listSync(followLinks: false)) {
          if (p.basename(entity.path).toLowerCase() ==
              LocalFileService.privateName) {
            continue;
          }
          if (entity is File && entity.path.toLowerCase().endsWith('.xp3')) {
            results.add(entity);
          } else if (entity is Directory) {
            walk(entity, depth + 1);
          }
        }
      } on FileSystemException {
        // Unreadable entries (pickers' cache, other users' dirs) — skip.
      }
    }

    walk(root, 0);
    results.sort((a, b) => a.path.compareTo(b.path));
    return results;
  }

  /// Finds directories that look like a game root: an unpacked KrKr game
  /// (directly containing a .xp3 archive or a startup.tjs) or an Artemis
  /// game (directly containing a .pfs pack).
  static List<File> _scanSandboxForGameDirectories(Directory root) {
    final results = <File>[];
    void walk(Directory dir, int depth) {
      if (depth > 3) return;
      final List<FileSystemEntity> entries;
      try {
        entries = dir.listSync(followLinks: false).toList();
      } on FileSystemException {
        return;
      }
      for (final entity in entries) {
        if (entity is! Directory) continue;
        if (p.basename(entity.path).toLowerCase() ==
            LocalFileService.privateName) {
          continue;
        }
        try {
          final looksLikeGame = entity
              .listSync(followLinks: false)
              .any(
                (child) =>
                    child is File &&
                    (child.path.toLowerCase().endsWith('.xp3') ||
                        child.path.toLowerCase().endsWith('startup.tjs') ||
                        GameEngine.isPfsPack(child.path)),
              );
          if (looksLikeGame) {
            results.add(File(entity.path));
          } else {
            walk(entity, depth + 1);
          }
        } on FileSystemException {
          continue;
        }
      }
    }

    walk(root, 0);
    results.sort((a, b) => a.path.compareTo(b.path));
    return results;
  }

  void _showIosImportGuide() {
    final l10n = AppLocalizations.of(context)!;
    UiDialog.show<void>(
      context,
      title: l10n.importGames,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.importGamesDesc,
            style: context.uiType.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.uiColors.groupedBackground,
              borderRadius: UiRadius.brSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.importStep1,
                  style: context.uiType.body.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.importStep2(AppInfo.nameForLanguage(l10n.localeName)),
                  style: context.uiType.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.importStep3,
                  style: context.uiType.body.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.importStep4,
                  style: context.uiType.body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.gamesDirectory,
            style: context.uiType.footnote.copyWith(
              fontFamily: 'monospace',
              color: context.uiColors.textTertiary,
            ),
          ),
        ],
      ),
      actions: [UiDialogAction(label: l10n.gotIt, isDefault: true)],
    );
  }

  Future<void> _showMacosImportGuide() async {
    final l10n = AppLocalizations.of(context)!;
    await UiDialog.show<void>(
      context,
      title: l10n.importGames,
      message: l10n.macosImportTip,
      actions: [UiDialogAction(label: l10n.gotIt, isDefault: true)],
    );
  }

  Future<void> _removeGame(GameInfo game) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await UiDialog.show<bool>(
      context,
      title: l10n.removeGame,
      message: l10n.removeGameConfirm(game.displayTitle),
      actions: [
        UiDialogAction(label: l10n.cancel, returnValue: false),
        UiDialogAction(
          label: l10n.remove,
          isDestructive: true,
          returnValue: true,
        ),
      ],
    );
    if (confirmed == true && mounted) {
      await _gameManager.removeGame(game.path);
      setState(() {});
    }
  }

  Future<void> _renameGame(GameInfo game) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: game.displayTitle);
    final newName = await UiDialog.show<String>(
      context,
      title: l10n.renameGame,
      content: Builder(
        builder: (ctx) => UiInput(
          controller: controller,
          autofocus: true,
          label: l10n.displayTitle,
          onSubmitted: (value) => Navigator.pop(ctx, value),
        ),
      ),
      actions: [
        UiDialogAction(label: l10n.cancel),
        UiDialogAction(
          label: l10n.save,
          isDefault: true,
          onPressed: () => Navigator.pop(context, controller.text),
        ),
      ],
    );
    // 等对话框退场动画结束再释放，避免输入框在动画中访问已释放的 controller。
    Future<void>.delayed(const Duration(milliseconds: 500), controller.dispose);
    if (newName != null && newName.isNotEmpty && mounted) {
      await _gameManager.renameGame(game.path, newName);
      setState(() {});
    }
  }

  Future<void> _launchGame(GameInfo game) async {
    final l10n = AppLocalizations.of(context)!;
    final dylibPath = _effectiveDylibPath;
    final isSystemLoadedBuiltIn =
        (Platform.isIOS ||
            Platform.isAndroid ||
            Platform.operatingSystem == 'ohos') &&
        _engineMode == EngineMode.builtIn;
    if (dylibPath == null && !isSystemLoadedBuiltIn) {
      final msg = _engineMode == EngineMode.builtIn
          ? l10n.engineNotFoundBuiltIn
          : l10n.engineNotFoundCustom;
      UiSnackbar.show(
        context,
        message: msg,
        type: UiSnackbarType.error,
        actionLabel: l10n.settings,
        onAction: _openSettings,
      );
      return;
    }
    _gameManager.markPlayed(game.path);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(
          gamePath: game.path,
          engine: game.engine,
          title: game.displayTitle,
          coverPath: game.coverPath,
          saveDirectoryName: game.saveDirectoryName,
          ffiLibraryPath: dylibPath,
          orientation: _gameOrientation,
          gameManager: _gameManager,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openGameDetail(GameInfo game) async {
    final result = await Navigator.of(context).push<GameDetailResult>(
      MaterialPageRoute<GameDetailResult>(
        builder: (_) => GameDetailPage(game: game, gameManager: _gameManager),
      ),
    );
    if (result == null || !mounted) return;
    if (result.needsRefresh) setState(() {});
    if (result.shouldLaunch) _launchGame(game);
  }

  Future<void> _openGameScrape(GameInfo game) async {
    final applied = await _scrapeFlow.start(
      context,
      game: game,
      gameManager: _gameManager,
    );
    if (applied && mounted) setState(() {});
  }

  /// After adding a game, offer to start the shared metadata scrape flow.
  Future<void> _offerScrapeAfterAdd(String addedPath) async {
    final l10n = AppLocalizations.of(context)!;
    final idx = _gameManager.games.indexWhere((g) => g.path == addedPath);
    if (idx < 0 || !mounted) return;
    final game = _gameManager.games[idx];
    final shouldScrape = await UiDialog.show<bool>(
      context,
      title: l10n.scrapeMetadata,
      message: l10n.scrapeAfterAddPrompt,
      actions: [
        UiDialogAction(label: l10n.scrapeAfterAddNo, returnValue: false),
        UiDialogAction(
          label: l10n.scrapeAfterAddYes,
          isDefault: true,
          returnValue: true,
        ),
      ],
    );
    if (shouldScrape != true || !mounted) return;
    await _openGameScrape(game);
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<SettingsResult>(
      MaterialPageRoute<SettingsResult>(
        builder: (_) => SettingsPage(
          engineMode: _engineMode,
          customDylibPath: _customDylibPath,
          builtInDylibPath: _builtInDylibPath,
          builtInAvailable: _builtInAvailable,
          perfOverlay: _perfOverlay,
          fpsLimitEnabled: _fpsLimitEnabled,
          targetFps: _targetFps,
          renderer: _renderer,
          angleBackend: _angleBackend,
          gameOrientation: _gameOrientation,
          restartPending: _restartDeferred,
          publicGamesDir: _publicGamesDirDisplay,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        // On mobile the engine mode is always builtIn, so we skip updating it.
        if (!Platform.isAndroid &&
            !Platform.isIOS &&
            Platform.operatingSystem != 'ohos') {
          _engineMode = result.engineMode;
          _customDylibPath = result.customDylibPath;
        }
        _perfOverlay = result.perfOverlay;
        _fpsLimitEnabled = result.fpsLimitEnabled;
        _targetFps = result.targetFps;
        _renderer = result.renderer;
        _angleBackend = result.angleBackend;
        _gameOrientation = result.gameOrientation;
        if (result.restartPending) _restartDeferred = true;
      });
    }
  }

  int _gridCrossAxisCount(double width) {
    if (width >= 1200) return 5;
    if (width >= 800) return 4;
    if (width >= 400) return 3;
    return 2;
  }

  List<GameInfo> get _sortedGames {
    final sorted = List<GameInfo>.from(_gameManager.games)
      ..sort((a, b) {
        if (a.lastPlayed != null && b.lastPlayed != null) {
          return b.lastPlayed!.compareTo(a.lastPlayed!);
        }
        if (a.lastPlayed != null) return -1;
        if (b.lastPlayed != null) return 1;
        return a.displayTitle.compareTo(b.displayTitle);
      });
    return sorted;
  }

  void _beginSearch() {
    if (_loading || _searchActive) return;
    setState(() => _searchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
      _searchFocusNode.requestFocus();
    });
  }

  void _finishSearch() {
    _searchFocusNode.unfocus();
    if (_searchActive) setState(() => _searchActive = false);
  }

  void _updateSearch(String value) {
    if (value == _searchQuery) return;
    setState(() => _searchQuery = value);
  }

  void _selectTab(int index) {
    if (index != 0) {
      _searchFocusNode.unfocus();
      _searchActive = false;
    }
    setState(() => _selectedTab = index);
  }

  List<GameInfo> _filterGames(List<GameInfo> games) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return games;
    return games
        .where((game) {
          final searchable = <String>[
            game.displayTitle,
            ?game.developer,
            ...game.keywords,
          ].join('\n').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  void _openHelp() => UiMotion.push<void>(context, const HelpPage());

  void _openAbout() => UiMotion.push<void>(context, const AboutPage());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allGames = _sortedGames;
    final visibleGames = allGames.where((game) => game.available).toList();
    final games = _filterGames(visibleGames);
    final isDesktop =
        !Platform.isAndroid &&
        !Platform.isIOS &&
        Platform.operatingSystem != 'ohos';
    // Mobile libraries rescan their public drop directory on refresh.
    final hasPublicDropDirectory =
        Platform.isAndroid || Platform.operatingSystem == 'ohos';
    final canPullRefresh = hasPublicDropDirectory || Platform.isIOS;

    // The title bar stays put; only the library below it scrolls and pulls.
    const collapsedToolbarWidth = 94.0;
    final Widget header = UiTabHeader(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.centerRight,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: collapsedToolbarWidth + 8,
                top: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  excluding: _searchActive,
                  child: AnimatedOpacity(
                    key: const ValueKey<String>('home-app-title'),
                    opacity: _searchActive ? 0 : 1,
                    duration: UiDuration.fast,
                    curve: UiCurves.iosSmooth,
                    child: AnimatedSlide(
                      offset: _searchActive
                          ? const Offset(-0.04, 0)
                          : Offset.zero,
                      duration: UiDuration.fast,
                      curve: UiCurves.iosSmooth,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              AppInfo.nameForLanguage(l10n.localeName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UiTabHeader.titleStyleOf(context),
                            ),
                          ),
                          if (isDesktop && !_loading) ...[
                            const SizedBox(width: UiSpacing.sm),
                            Tooltip(
                              message: _engineMode == EngineMode.builtIn
                                  ? (_builtInAvailable
                                        ? l10n.builtInReady
                                        : l10n.builtInNotReady)
                                  : (_customDylibPath != null
                                        ? _customDylibPath!.split('/').last
                                        : l10n.customNotSet),
                              child: Icon(
                                _engineMode == EngineMode.builtIn
                                    ? LucideIcons.packageOpen
                                    : LucideIcons.puzzle,
                                color: _engineReady
                                    ? context.uiColors.brand
                                    : context.uiColors.danger,
                                size: 22,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                left: _searchActive
                    ? 0
                    : constraints.maxWidth - collapsedToolbarWidth,
                width: _searchActive
                    ? constraints.maxWidth
                    : collapsedToolbarWidth,
                top: 0,
                bottom: 0,
                duration: UiSprings.materializeDuration,
                curve: UiSprings.materializeCurve,
                child: UiGlassToolbar.custom(
                  key: const ValueKey<String>('home-search-toolbar'),
                  variant: UiGlassVariant.clear,
                  interactive: !_searchActive,
                  padding: const EdgeInsets.all(2),
                  child: AnimatedSwitcher(
                    duration: UiDuration.fast,
                    switchInCurve: UiCurves.iosSmooth,
                    switchOutCurve: UiCurves.iosSmooth,
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.centerRight,
                      children: <Widget>[...previousChildren, ?currentChild],
                    ),
                    child: _searchActive
                        ? Row(
                            key: const ValueKey<String>('search-editor'),
                            children: [
                              const SizedBox(width: 10),
                              Icon(
                                LucideIcons.search,
                                size: 18,
                                color: context.uiColors.textSecondary,
                              ),
                              const SizedBox(width: UiSpacing.sm),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey<String>(
                                    'home-search-field',
                                  ),
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  textInputAction: TextInputAction.done,
                                  onChanged: _updateSearch,
                                  onSubmitted: (_) => _finishSearch(),
                                  style: context.uiType.body.copyWith(
                                    color: context.uiColors.textPrimary,
                                  ),
                                  cursorColor: context.uiColors.brand,
                                  decoration: InputDecoration.collapsed(
                                    hintText: l10n.searchGamesHint,
                                    hintStyle: context.uiType.body.copyWith(
                                      color: context.uiColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ),
                              UiGlassIconButton(
                                icon: LucideIcons.check,
                                semanticLabel: l10n.done,
                                contained: false,
                                onPressed: _finishSearch,
                              ),
                            ],
                          )
                        : Row(
                            key: const ValueKey<String>('home-actions'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UiGlassIconButton(
                                icon: LucideIcons.search,
                                semanticLabel: l10n.search,
                                contained: false,
                                onPressed: _loading ? null : _beginSearch,
                              ),
                              Builder(
                                builder: (btnContext) => UiGlassIconButton(
                                  icon: LucideIcons.plus,
                                  semanticLabel: l10n.importGames,
                                  contained: false,
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          _addGame(
                                            anchor: UiPopupMenu.rectOf(
                                              btnContext,
                                            ),
                                          );
                                        },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final showLibrarySkeleton =
        _loading || (_startupScanInProgress && visibleGames.isEmpty);
    Widget content;
    if (showLibrarySkeleton) {
      content = _buildLibrarySkeleton();
    } else {
      content = CustomScrollView(
        slivers: [
          if (_restartDeferred)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverToBoxAdapter(
                child: UiBanner(
                  tone: UiBannerTone.warning,
                  message: l10n.restartPendingBanner,
                  actionLabel: l10n.restartNow,
                  onAction: restartKrkr2App,
                ),
              ),
            ),
          if (games.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: visibleGames.isEmpty
                  ? _buildEmptyState(l10n)
                  : UiEmpty(
                      icon: LucideIcons.search,
                      title: l10n.searchNoResults,
                    ),
            )
          else
            _buildGameGrid(games, l10n),
          const SliverPadding(padding: EdgeInsets.only(bottom: 112)),
        ],
      );
      if (canPullRefresh && !_startupScanInProgress) {
        content = UiPullRefresh(
          pullingText: l10n.pullToRefresh,
          readyText: l10n.releaseToRefresh,
          refreshingText: l10n.refreshing,
          doneText: l10n.refreshDone,
          onRefresh: () async {
            if (Platform.isAndroid && _publicGamesDir == null) {
              await _authorizeAndroidGamesDirectory();
            } else if (hasPublicDropDirectory) {
              await _refreshPublicGames();
            } else {
              await _scanIosGamesDir();
              if (mounted) setState(() {});
            }
          },
          child: content,
        );
      }
    }

    final tabs = <Widget>[
      ColoredBox(
        color: context.uiColors.background,
        child: Column(
          children: [
            header,
            Expanded(
              child: AnimatedSwitcher(
                duration: UiDuration.fast,
                switchInCurve: UiCurves.iosSmooth,
                switchOutCurve: UiCurves.iosSmooth,
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: KeyedSubtree(
                  key: ValueKey<bool>(showLibrarySkeleton),
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
      ManagerPage(
        controller: _fileManager,
        active: _selectedTab == _manageTabIndex,
      ),
      PlayStatisticsPage(
        games: allGames,
        playSessions: _gameManager.playSessions,
      ),
      HomeProfileTab(
        games: visibleGames,
        onOpenLibrary: () => _selectTab(0),
        onOpenGame: _openGameDetail,
        onOpenSettings: _openSettings,
        onOpenHelp: _openHelp,
        onOpenAbout: _openAbout,
      ),
    ];

    // Tab changes and library loads do not emit scroll notifications.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navBackdropKey.currentState?.requestSample();
    });
    return GlassContentAwareScope(
      key: _navBackdropKey,
      backgroundColor: context.uiColors.background,
      child: Scaffold(
        backgroundColor: context.uiColors.background,
        extendBody: true,
        // Native tab bars switch content immediately; the continuity lives in
        // the moving glass lens below. IndexedStack also preserves each tab's
        // scroll position without repainting hidden pages.
        body: GlassContentAwareContent(
          child: IndexedStack(index: _selectedTab, children: tabs),
        ),
        bottomNavigationBar: UiNavBar(
          currentIndex: _selectedTab,
          onChanged: _selectTab,
          items: [
            UiNavItem(
              icon: CupertinoIcons.house,
              activeIcon: CupertinoIcons.house_fill,
              label: l10n.tabHome,
            ),
            UiNavItem(
              icon: CupertinoIcons.folder,
              activeIcon: CupertinoIcons.folder_fill,
              label: l10n.tabManage,
            ),
            UiNavItem(
              icon: CupertinoIcons.chart_bar,
              activeIcon: CupertinoIcons.chart_bar_fill,
              label: l10n.tabStatistics,
            ),
            UiNavItem(
              icon: CupertinoIcons.person,
              activeIcon: CupertinoIcons.person_fill,
              label: l10n.tabProfile,
            ),
          ],
        ),
      ),
    );
  }

  /// 引擎状态：显式 dylib 存在，或移动端/OHOS 由系统加载的内置引擎。
  bool get _engineReady {
    if (_effectiveDylibPath != null) return true;
    return (Platform.isAndroid ||
            Platform.isIOS ||
            Platform.operatingSystem == 'ohos') &&
        _engineMode == EngineMode.builtIn;
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final String description;
    if (Platform.isIOS) {
      description = l10n.noGamesHintIos(
        AppInfo.nameForLanguage(l10n.localeName),
      );
    } else if (Platform.isAndroid || Platform.operatingSystem == 'ohos') {
      description = l10n.noGamesHintOhos(
        _publicGamesDirDisplay ?? 'Download/${AppInfo.bundleId}/games',
      );
    } else {
      description = l10n.noGamesHintDesktop;
    }
    return UiEmpty(
      icon: LucideIcons.gamepad2,
      title: l10n.noGamesYet,
      description: description,
      actionLabel: Platform.isIOS ? l10n.howToImport : l10n.addGame,
      onAction: Platform.isIOS ? _showIosImportGuide : _addGame,
    );
  }

  Widget _buildLibrarySkeleton() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _gridCrossAxisCount(
              constraints.crossAxisExtent,
            );
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 3 / 4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => LayoutBuilder(
                    builder: (context, constraints) => UiSkeleton(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      borderRadius: UiRadius.brLg,
                    ),
                  ),
                  childCount: crossAxisCount * 2,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGameGrid(List<GameInfo> games, AppLocalizations l10n) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _gridCrossAxisCount(constraints.crossAxisExtent);
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final game = games[index];
              return HomeGameCard(
                game: game,
                l10n: l10n,
                onTap: () => _openGameDetail(game),
                onLaunch: () => _launchGame(game),
                onScrape: () => _openGameScrape(game),
                onRename: () => _renameGame(game),
                onRemove: () => _removeGame(game),
              );
            }, childCount: games.length),
          ),
        );
      },
    );
  }
}
