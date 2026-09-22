import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'archive_extractor.dart';
import 'document_archive_extractor.dart';
import 'android_document_file_system.dart';
import 'archive_volumes.dart';
import 'engine_runtime_guard.dart';
import 'game_manager.dart';
import 'local_file_service.dart';
import 'manager_file_kind.dart';
import 'manager_scope.dart';
import 'manager_storage.dart';

/// One-shot outcome the page turns into a toast. Only long tasks report
/// success; quick edits are visible in the refreshed listing.
enum ManagerNotice { completed }

/// Coordinates grant, file tasks, library relocate and engine safety.
class FileManagerController extends ChangeNotifier {
  FileManagerController({
    required this.gameManager,
    ManagerStorage? storage,
    ArchiveExtractor? extractor,
    EngineRuntimeGuard? runtimeGuard,
    this.fileSystem,
  }) : storage = storage ?? ManagerStorage(),
       extractor = extractor ?? ArchiveExtractor(),
       runtimeGuard = runtimeGuard ?? EngineRuntimeGuard.instance;

  final ManagerFileSystem? fileSystem;
  final GameManager gameManager;
  final ManagerStorage storage;
  final ArchiveExtractor extractor;
  final EngineRuntimeGuard runtimeGuard;

  ManagerGrant? grant;
  LocalFileService? files;
  String currentPath = '';
  List<LocalFileEntry> entries = const [];
  List<DeletedFile> trash = const [];
  final selected = <String>{};
  bool selecting = false;
  bool loading = false;
  bool get isBusy => files?.isBusy ?? false;
  bool get blocksLibraryScan => isBusy;
  bool get isSupported => storage.isSupported;
  FileTask? task;
  FileOperationException? lastError;
  ManagerNotice? notice;

  Future<void> load() async {
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      grant = await storage.currentGrant();
      _bindService();
      if (files == null) _clearGrant();
      if (files != null) {
        currentPath = files!.gamesPath;
        await files!.io.mkdir(currentPath, recursive: true);
        await refresh();
      }
    } on FileOperationException catch (error) {
      // The empty state already explains an unsupported platform; a toast
      // on every load would only repeat it.
      if (error.code != FileErrorCode.unsupportedPlatform) lastError = error;
    } catch (error) {
      lastError = FileOperationException.from(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> authorize() async {
    lastError = null;
    notifyListeners();
    try {
      grant = await storage.authorize();
      _bindService();
      currentPath = files!.gamesPath;
      await files!.io.mkdir(currentPath, recursive: true);
      await refresh();
    } on FileOperationException catch (error) {
      if (error.code == FileErrorCode.cancelled) return;
      lastError = error;
    } catch (error) {
      lastError = FileOperationException.from(error);
    } finally {
      notifyListeners();
    }
  }

  void _clearGrant() {
    grant = null;
    files = null;
    currentPath = '';
    entries = const [];
    trash = const [];
    selected.clear();
    selecting = false;
    notifyListeners();
  }

  void _bindService() {
    final root = grant;
    files = root == null
        ? null
        : LocalFileService(
            rootPath: root.rootPath,
            fileSystem:
                fileSystem ??
                (root.platform == 'android'
                    ? AndroidDocumentFileSystem(root.rootPath)
                    : null),
            onPathChanged: gameManager.relocateBoundPaths,
          );
  }

  Future<void> refresh() async {
    final service = files;
    if (service == null) return;
    // The folder being viewed can disappear underneath us (another app,
    // or a restore that recreated a parent). Fall back to games/ rather
    // than showing an empty listing for a path that no longer exists.
    if (!await service.io.exists(currentPath)) {
      currentPath = await service.io.exists(service.gamesPath)
          ? service.gamesPath
          : service.rootPath;
      selected.clear();
    }
    entries = await service.list(currentPath);
    trash = await service.deletedFiles();
    selected.removeWhere(
      (path) => entries.every((entry) => entry.path != path),
    );
    notifyListeners();
  }

  /// Pull-to-refresh. Unlike [refresh], which callers use after their own
  /// operation, this is user-initiated: a failure is reported rather than
  /// left for the next operation to surface.
  Future<void> reload() async {
    if (files == null || task != null) return;
    lastError = null;
    try {
      if (storage.usesAndroidDocumentTree &&
          await storage.currentGrant() == null) {
        _clearGrant();
        return;
      }
      await refresh();
    } on FileOperationException catch (error) {
      lastError = error;
      if (error.code == FileErrorCode.permissionDenied) _clearGrant();
      notifyListeners();
    } catch (error) {
      lastError = FileOperationException.from(error);
      notifyListeners();
    }
  }

  /// Folder totals for the details sheet. Cancel [task] to stop walking a
  /// large game folder once the sheet is dismissed.
  Future<DirectorySummary> summarize(String path, FileTask task) {
    final service = files;
    if (service == null) {
      throw const FileOperationException(FileErrorCode.unsupportedPlatform);
    }
    return service.summarize(path, task);
  }

  /// Where an entry sits, anchored at the same label the breadcrumb uses for
  /// the root (`Download/<appId>`) so the sheet never leaks the sandbox path.
  String locationOf(String path) {
    final service = files;
    if (service == null) return path;
    final root = grant?.displayRoot ?? p.basename(service.rootPath);
    final relative = p.relative(p.dirname(path), from: service.rootPath);
    if (relative == '.') return root;
    return p.posix.joinAll([root, ...p.split(relative)]);
  }

  Future<void> open(String path) async {
    if (selecting) {
      toggle(path);
      return;
    }
    currentPath = path;
    selected.clear();
    await refresh();
  }

  Future<void> openParent() async {
    final service = files;
    if (service == null) return;
    if (p.equals(currentPath, service.rootPath)) return;
    currentPath = p.dirname(currentPath);
    selected.clear();
    await refresh();
  }

  /// System back while this tab is visible: leave selection first, then walk
  /// up one folder. Only at the authorized root does back fall through to
  /// the default route behaviour.
  bool get canGoBack =>
      selecting || (files != null && !p.equals(currentPath, files!.rootPath));

  Future<void> goBack() async {
    if (selecting) {
      toggleSelecting(false);
      return;
    }
    await openParent();
  }

  void toggleSelecting(bool value) {
    selecting = value;
    if (!value) selected.clear();
    notifyListeners();
  }

  /// False for the root, the `games` container and private work.
  bool canMutate(String path) => files != null && !files!.isProtected(path);

  void toggle(String path) {
    if (!canMutate(path)) return;
    if (!selected.add(path)) selected.remove(path);
    notifyListeners();
  }

  void selectAll() {
    selected
      ..clear()
      ..addAll(entries.map((entry) => entry.path).where(canMutate));
    notifyListeners();
  }

  List<String> get _targets =>
      selected.isEmpty ? const [] : selected.toList(growable: false);

  Future<void> createFolder(String name) =>
      _run(() => files!.createDirectory(currentPath, name));

  Future<void> rename(String source, String name) async {
    await _run(() async {
      final group = _groupFor(source);
      if (group.length == 1) {
        await files!.rename(source, name);
        return;
      }
      final fromName = p.basename(source);
      for (final member in group) {
        await files!.rename(
          member,
          ArchiveVolumes.renamedMember(p.basename(member), fromName, name),
        );
      }
    });
  }

  Future<void> copyTo(String destinationDir) => _run(() async {
    final progress = _beginTask();
    for (final source in _expand(_targets)) {
      await files!.copy(
        source,
        p.join(destinationDir, p.basename(source)),
        progress,
      );
    }
  }, announce: true);

  Future<void> moveTo(String destinationDir) => _run(() async {
    for (final source in _expand(_targets)) {
      await files!.move(source, p.join(destinationDir, p.basename(source)));
    }
  });

  Future<void> trashSelected() => _run(() async {
    for (final source in _expand(_targets)) {
      await files!.trash(source);
      await gameManager.markUnavailable(source);
    }
  });

  Future<void> restore(DeletedFile item) => _run(() async {
    await files!.restore(item);
    await gameManager.markAvailable(item.originalPath);
  });

  Future<void> permanentlyDelete(DeletedFile item) =>
      _run(() => files!.permanentlyDelete(item));

  Future<void> extract(
    String source, {
    String? password,
    int legacyCodepage = 65001,
  }) {
    final destination = p.join(
      p.dirname(source),
      ArchiveVolumes.extractFolderName(p.basename(source)),
    );
    return _run(() async {
      await runtimeGuard.prepareMutation(source);
      await files!.extract(
        destination,
        (output) => files!.io is AndroidDocumentFileSystem
            ? unpackDocumentArchive(
                io: files!.io,
                extractor: extractor,
                volumes: _groupFor(source),
                source: source,
                output: output,
                password: password,
                legacyCodepage: legacyCodepage,
                task: _beginTask(),
              )
            : extractor.unpack(
                root: files!.rootPath,
                source: source,
                destination: output,
                password: password,
                legacyCodepage: legacyCodepage,
                task: _beginTask(),
              ),
      );
    }, announce: true);
  }

  void cancelTask() {
    task?.cancelled = true;
  }

  bool get canMutateCurrent =>
      files != null &&
      !p.equals(currentPath, files!.rootPath) &&
      !p.equals(currentPath.toLowerCase(), files!.gamesPath.toLowerCase());

  List<String> breadcrumbLabels() {
    final service = files;
    if (service == null) return const [];
    final relative = p.relative(currentPath, from: service.rootPath);
    if (relative == '.') return const [''];
    return ['', ...p.split(relative)];
  }

  Future<void> openBreadcrumb(int index) async {
    final service = files;
    if (service == null) return;
    if (index <= 0) {
      currentPath = service.rootPath;
    } else {
      currentPath = p.joinAll([
        service.rootPath,
        ...breadcrumbLabels().skip(1).take(index),
      ]);
    }
    selected.clear();
    await refresh();
  }

  bool looksLikeArchive(String name) =>
      ManagerFileKind.ofName(name) == ManagerFileKind.archive;

  /// Multi-item operations stop at the first failure and report that code;
  /// items handled before it stay where they were put. The listing is
  /// refreshed on every exit so the page never shows the pre-failure state.
  Future<void> _run(
    Future<void> Function() operation, {
    bool announce = false,
  }) async {
    lastError = null;
    notice = null;
    notifyListeners();
    try {
      for (final path in {..._targets, currentPath}) {
        await runtimeGuard.prepareMutation(path);
      }
      await operation();
      selected.clear();
      selecting = false;
      if (announce) notice = ManagerNotice.completed;
    } on FileOperationException catch (error) {
      if (error.code != FileErrorCode.cancelled) lastError = error;
      if (error.code == FileErrorCode.permissionDenied) _clearGrant();
    } catch (error) {
      lastError = FileOperationException.from(error);
    } finally {
      task = null;
      try {
        await refresh();
      } catch (_) {
        // The operation outcome is what matters; a stale listing is
        // corrected by the next refresh.
      }
      notifyListeners();
    }
  }

  FileTask _beginTask() {
    final next = FileTask();
    next.onProgress = notifyListeners;
    task = next;
    return next;
  }

  List<String> _groupFor(String path) {
    return ArchiveVolumes.members(
      p.basename(path),
      entries.map((entry) => entry.name),
    ).map((name) => p.join(p.dirname(path), name)).toList();
  }

  List<String> _expand(List<String> paths) {
    final seen = <String>{};
    for (final path in paths) {
      seen.addAll(_groupFor(path));
    }
    return seen.toList();
  }
}
