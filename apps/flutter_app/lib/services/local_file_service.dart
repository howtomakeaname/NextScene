import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'file_operation_error.dart';
import 'manager_file_system.dart';
export 'manager_file_system.dart';
export 'file_operation_error.dart';

class FileTask {
  FileTask({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  bool cancelled = false;
  int completed = 0;
  int total = 0;
  String currentName = '';
  void Function()? onProgress;

  /// Windowed bytes/second, or null until the first full sample lands.
  /// Copy and extract both feed [completed] in bytes, so the same figure
  /// is the transfer rate the progress row shows.
  double? bytesPerSecond;

  DateTime? _windowStartedAt;
  int _windowStartedBytes = 0;

  /// A sample shorter than this is too noisy: a single 64 KB chunk would
  /// look like hundreds of MB/s if we divided by a few milliseconds.
  static const _window = Duration(milliseconds: 300);

  void check() {
    if (cancelled) throw const FileOperationException(FileErrorCode.cancelled);
  }

  void report() {
    _updateRate();
    onProgress?.call();
  }

  void _updateRate() {
    final now = _now();
    final started = _windowStartedAt;
    if (started == null) {
      _windowStartedAt = now;
      _windowStartedBytes = completed;
      return;
    }
    final elapsed = now.difference(started);
    if (elapsed < _window) return;
    final delta = completed - _windowStartedBytes;
    if (delta < 0) {
      // A reused task that reset [completed] starts a fresh window.
      bytesPerSecond = null;
    } else {
      final seconds = elapsed.inMicroseconds / 1e6;
      final instant = seconds > 0 ? delta / seconds : 0.0;
      bytesPerSecond = bytesPerSecond == null
          ? instant
          : bytesPerSecond! * 0.4 + instant * 0.6;
    }
    _windowStartedAt = now;
    _windowStartedBytes = completed;
  }
}

/// 1024-based rate so it matches the listing's size labels. Units step
/// KB/s → MB/s → GB/s; anything under 1 KB/s still shows as KB/s.
String formatTransferSpeed(double bytesPerSecond) {
  const kb = 1024.0;
  const mb = kb * 1024;
  const gb = mb * 1024;
  final rate = bytesPerSecond.isFinite && bytesPerSecond > 0
      ? bytesPerSecond
      : 0.0;
  final String unit;
  final double value;
  if (rate >= gb) {
    value = rate / gb;
    unit = 'GB/s';
  } else if (rate >= mb) {
    value = rate / mb;
    unit = 'MB/s';
  } else {
    value = rate / kb;
    unit = 'KB/s';
  }
  final digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(digits)} $unit';
}

class DeletedFile {
  const DeletedFile({
    required this.id,
    required this.originalPath,
    required this.deletedAt,
  });
  final String id;
  final String originalPath;
  final DateTime deletedAt;
}

/// Recursive size and item count for the details sheet. Links and private
/// work are skipped, matching what the listing shows.
class DirectorySummary {
  const DirectorySummary({required this.bytes, required this.items});
  final int bytes;
  final int items;
}

/// A single-writer file service. No operation may leave [rootPath], follow a
/// symbolic link or overwrite an existing item. Private work is excluded from
/// directory listings and game discovery, including while a copy is incomplete.
class LocalFileService {
  LocalFileService({
    required String rootPath,
    this.onPathChanged,
    ManagerFileSystem? fileSystem,
  }) : rootPath = p.normalize(p.absolute(rootPath)),
       io = fileSystem ?? LocalManagerFileSystem();

  final ManagerFileSystem io;

  static const privateName = '.krkr-manager';
  final String rootPath;
  final Future<void> Function(String from, String to)? onPathChanged;
  bool _busy = false;
  bool get isBusy => _busy;
  String get gamesPath => p.join(rootPath, 'games');
  String get _privatePath => p.join(rootPath, privateName);

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_busy) throw const FileOperationException(FileErrorCode.busy);
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }

  static bool isPrivatePath(String path) =>
      p.split(path).any((part) => part.toLowerCase() == privateName);

  /// Root, the fixed `games` container and private work cannot be renamed,
  /// moved, copied or trashed. UI uses this to hide those actions up front.
  bool isProtected(String path) {
    final normalized = p.normalize(p.absolute(path));
    return normalized == rootPath ||
        normalized.toLowerCase() == gamesPath.toLowerCase() ||
        isPrivatePath(p.relative(normalized, from: rootPath));
  }

  static void validateName(String name) {
    if (name.trim().isEmpty ||
        name == '.' ||
        name == '..' ||
        name.endsWith('.') ||
        name.endsWith(' ') ||
        name.toLowerCase() == privateName ||
        RegExp(r'[\x00-\x1f/\\:*?"<>|]').hasMatch(name) ||
        utf8.encode(name).length > 255) {
      throw const FileOperationException(FileErrorCode.invalidName);
    }
  }

  Future<String> validatePath(
    String input, {
    bool internal = false,
    bool mutate = false,
  }) async {
    final path = p.normalize(p.absolute(input));
    if (path != rootPath && !p.isWithin(rootPath, path)) {
      throw const FileOperationException(FileErrorCode.outsideRoot);
    }
    if (!internal && isPrivatePath(p.relative(path, from: rootPath))) {
      throw const FileOperationException(FileErrorCode.protectedDirectory);
    }
    if (mutate &&
        (path == rootPath || path.toLowerCase() == gamesPath.toLowerCase())) {
      throw const FileOperationException(FileErrorCode.protectedDirectory);
    }
    await io.validateAncestors(rootPath, path);
    return path;
  }

  Future<List<LocalFileEntry>> list(String directory) async {
    final path = await validatePath(directory);
    final result = <LocalFileEntry>[];
    for (final entry in await io.list(path)) {
      if (p.basename(entry.path).toLowerCase() == privateName) continue;
      if (await io.type(entry.path) == FileSystemEntityType.link) {
        continue;
      }
      result.add(LocalFileEntry(entry.path, entry.stat));
    }
    result.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  /// Walks a folder for the details sheet. Read-only, so it does not take the
  /// writer lock; [task] lets the sheet abandon a large game folder early.
  Future<DirectorySummary> summarize(String directory, FileTask task) async {
    final path = await validatePath(directory);
    var bytes = 0;
    var items = 0;
    Future<void> walk(String current) async {
      for (final entry in await io.list(current)) {
        task.check();
        final name = p.basename(entry.path).toLowerCase();
        if (name == privateName) continue;
        final type = await io.type(entry.path);
        if (type == FileSystemEntityType.link) continue;
        items++;
        if (type == FileSystemEntityType.directory) {
          await walk(entry.path);
        } else {
          bytes += (entry.stat).size;
        }
      }
    }

    await walk(path);
    return DirectorySummary(bytes: bytes, items: items);
  }

  Future<void> _requireVacant(
    String destination, {
    bool internal = false,
  }) async {
    await validatePath(destination, internal: internal);
    final parent = p.dirname(destination);
    if (!await io.exists(parent)) {
      throw const FileOperationException(FileErrorCode.notFound);
    }
    // Download is case-insensitive. Keep the same collision policy in tests
    // and on other hosts, including for an empty destination directory.
    for (final entry in await io.list(parent)) {
      if (p.basename(entry.path).toLowerCase() ==
          p.basename(destination).toLowerCase()) {
        throw const FileOperationException(FileErrorCode.conflict);
      }
    }
  }

  Future<void> createDirectory(String parent, String name) =>
      _exclusive(() async {
        validateName(name);
        await validatePath(parent);
        final destination = p.join(parent, name);
        await _requireVacant(destination);
        await io.mkdir(destination);
      });

  Future<void> rename(String source, String name) {
    validateName(name);
    return move(source, p.join(p.dirname(source), name));
  }

  Future<void> move(String source, String destination) => _exclusive(() async {
    final from = await validatePath(source, mutate: true);
    final to = await validatePath(destination);
    if (from == to || p.isWithin(from, to)) {
      throw const FileOperationException(FileErrorCode.recursiveTarget);
    }
    await _requireVacant(to);
    await _relocate(from, to);
  });

  Future<void> _relocate(String from, String to, {bool notify = true}) async {
    await _renameEntity(from, to);
    if (!notify) return;
    try {
      await onPathChanged?.call(from, to);
    } catch (_) {
      // Metadata must not silently point at a path that no longer exists.
      await _renameEntity(to, from);
      rethrow;
    }
  }

  Future<void> _renameEntity(String from, String to) async {
    await validatePath(from, internal: true);
    await validatePath(to, internal: true);
    await io.rename(from, to);
  }

  String _newId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<String> _workspace(String kind) async {
    final path = p.join(_privatePath, kind, _newId());
    await validatePath(path, internal: true);
    await io.mkdir(path, recursive: true);
    return path;
  }

  Future<void> copy(String source, String destination, FileTask task) =>
      _exclusive(() async {
        final from = await validatePath(source, mutate: true);
        final to = await validatePath(destination);
        if (from == to || p.isWithin(from, to)) {
          throw const FileOperationException(FileErrorCode.recursiveTarget);
        }
        await _requireVacant(to);
        final work = await _workspace('tasks');
        try {
          task.total = await _measure(from, task);
          await _copyEntity(from, p.join(work, 'item'), task);
          task.check();
          await _requireVacant(to);
          await _renameEntity(p.join(work, 'item'), to);
        } finally {
          await _deletePrivateWorkspace(work);
        }
      });

  Future<int> _measure(String path, FileTask task) async {
    task.check();
    await validatePath(path);
    if (await io.type(path) != FileSystemEntityType.directory) {
      return (await io.stat(path)).size;
    }
    var bytes = 0;
    for (final entry in await io.list(path)) {
      bytes += await _measure(entry.path, task);
    }
    return bytes;
  }

  Future<void> _copyEntity(String from, String to, FileTask task) async {
    task.check();
    await validatePath(from);
    await validatePath(to, internal: true);
    if (await io.type(from) == FileSystemEntityType.directory) {
      await io.mkdir(to);
      for (final entry in await io.list(from)) {
        await _copyEntity(entry.path, p.join(to, p.basename(entry.path)), task);
      }
      return;
    }
    task.currentName = p.basename(from);
    final output = await io.writer(to);
    try {
      await for (final bytes in io.read(from)) {
        task.check();
        await output.writeFrom(bytes);
        task.completed += bytes.length;
        task.report();
      }
      await output.flush();
    } finally {
      await output.close();
    }
  }

  Future<DeletedFile> trash(String source) => _exclusive(() async {
    final from = await validatePath(source, mutate: true);
    final work = await _workspace('trash');
    final item = DeletedFile(
      id: p.basename(work),
      originalPath: from,
      deletedAt: DateTime.now(),
    );
    final manifest = p.join(work, 'entry.json');
    await io.writeText(
      manifest,
      jsonEncode({
        'path': p.relative(from, from: rootPath),
        'deletedAt': item.deletedAt.toIso8601String(),
      }),
    );
    try {
      // Trash is not a library relocate. GameManager keeps the original
      // path and marks the entry unavailable so history is not rewritten
      // into `.krkr-manager/trash`.
      await _relocate(from, p.join(work, 'item'), notify: false);
    } catch (_) {
      await _deletePrivateWorkspace(work);
      rethrow;
    }
    return item;
  });

  String _trashWorkspace(String id) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(id)) {
      throw const FileOperationException(FileErrorCode.trashCorrupt);
    }
    return p.join(_privatePath, 'trash', id);
  }

  Future<List<DeletedFile>> deletedFiles() async {
    final trashPath = p.join(_privatePath, 'trash');
    await validatePath(trashPath, internal: true);
    if (!await io.exists(trashPath)) return [];
    final items = <DeletedFile>[];
    for (final entry in await io.list(trashPath)) {
      final work = entry.path;
      if (!entry.isDirectory ||
          !RegExp(r'^[0-9a-f]{32}$').hasMatch(p.basename(work))) {
        continue;
      }
      await validatePath(work, internal: true);
      final manifest = p.join(work, 'entry.json');
      await validatePath(manifest, internal: true);
      final payload = p.join(work, 'item');
      await validatePath(payload, internal: true);
      if (await io.type(payload) == FileSystemEntityType.notFound) {
        continue;
      }
      final data =
          jsonDecode(await io.readText(manifest)) as Map<String, dynamic>;
      final relative = data['path'] as String;
      if (p.isAbsolute(relative)) {
        throw const FileOperationException(FileErrorCode.trashCorrupt);
      }
      final original = await validatePath(
        p.join(rootPath, relative),
        mutate: true,
      );
      items.add(
        DeletedFile(
          id: p.basename(work),
          originalPath: original,
          deletedAt: DateTime.parse(data['deletedAt'] as String),
        ),
      );
    }
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  Future<void> restore(DeletedFile item) => _exclusive(() async {
    // Resolve the persisted record again; never trust a caller-supplied target.
    final persisted = (await deletedFiles()).firstWhere((e) => e.id == item.id);
    final to = await validatePath(persisted.originalPath, mutate: true);
    await _requireVacant(to);
    final work = _trashWorkspace(item.id);
    await _relocate(p.join(work, 'item'), to);
    await _deletePrivateWorkspace(work);
  });

  Future<void> permanentlyDelete(DeletedFile item) => _exclusive(() async {
    if (!(await deletedFiles()).any((e) => e.id == item.id)) {
      throw const FileOperationException(FileErrorCode.notFound);
    }
    await _deletePrivateWorkspace(_trashWorkspace(item.id));
  });

  Future<void> _deletePrivateWorkspace(String path) async {
    final normalized = await validatePath(path, internal: true);
    final rel = p.split(p.relative(normalized, from: _privatePath));
    if (rel.length != 2 ||
        !{'trash', 'tasks'}.contains(rel.first) ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(rel.last)) {
      throw const FileOperationException(FileErrorCode.outsideRoot);
    }
    // Directory.delete does not follow child links. The workspace itself has
    // already been checked and is always a single generated task directory.
    if (await io.exists(normalized)) {
      await io.delete(normalized, recursive: true);
    }
  }

  /// Native extraction writes only into a newly created task directory. Publish
  /// it after success so the library never discovers a partially unpacked game.
  Future<void> extract(
    String destination,
    Future<void> Function(String output) unpack,
  ) => _exclusive(() async {
    await _requireVacant(destination);
    final work = await _workspace('tasks');
    final output = p.join(work, 'item');
    await io.mkdir(output);
    try {
      await unpack(output);
      await _requireVacant(destination);
      await _renameEntity(output, destination);
    } finally {
      await _deletePrivateWorkspace(work);
    }
  });
}
