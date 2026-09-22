import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'file_operation_error.dart';
import 'manager_file_system.dart';

/// ContentResolver opens the document once; libc consumes that descriptor.
/// Reopening /proc/self/fd would reapply path-based scoped-storage checks.
class AndroidDocumentFileSystem extends ManagerFileSystem {
  AndroidDocumentFileSystem(this.root, {MethodChannel? channel})
    : channel = channel ?? const MethodChannel('flutter_engine_bridge');
  final String root;
  final MethodChannel channel;
  Future<T?> _call<T>(String method, Map<String, Object> args) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } catch (error) {
      throw FileOperationException.from(error);
    }
  }

  @override
  Future<FileStat> stat(String path) async =>
      _DocumentStat(await _call<Map>('documentStat', {'path': path}));
  @override
  Future<List<LocalFileEntry>> list(String path) async {
    final entries = await _call<List>('documentList', {'path': path}) ?? [];
    return entries
        .map(
          (item) => LocalFileEntry(
            item['path'] as String,
            _DocumentStat(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> mkdir(String path, {bool recursive = false}) =>
      _call('documentMkdir', {'path': path, 'recursive': recursive});
  @override
  Future<void> rename(String from, String to) =>
      _call('documentRename', {'from': from, 'to': to});
  @override
  Future<void> delete(String path, {bool recursive = false}) =>
      _call('documentDelete', {'path': path, 'recursive': recursive});
  Future<Uri> documentUri(String path) async =>
      Uri.parse((await _call<String>('documentUri', {'path': path}))!);
  Future<int> _open(String path, String mode) async =>
      (await _call<int>('documentOpen', {'path': path, 'mode': mode}))!;
  @override
  Stream<List<int>> read(String path) async* {
    final fd = await _open(path, 'r');
    final bytes = calloc<Uint8>(65536);
    try {
      while (true) {
        final count = _Posix.read(fd, bytes, 65536);
        if (count < 0) {
          if (_Posix.errno() == 4) continue;
          _Posix.fail(path);
        }
        if (count == 0) break;
        yield Uint8List.fromList(bytes.asTypedList(count));
      }
    } finally {
      calloc.free(bytes);
      _Posix.close(fd);
    }
  }

  @override
  Future<FileWriter> writer(String path) async =>
      _DocumentWriter(await _open(path, 'rwt'), path);
  @override
  Future<void> validateAncestors(String root, String path) async {
    if (p.normalize(path) != this.root &&
        !p.isWithin(this.root, p.normalize(path))) {
      throw const FileOperationException(FileErrorCode.outsideRoot);
    }
    // The external-storage provider resolves components inside the granted tree.
    // Check the grant on every operation, including after returning from settings.
    await stat(this.root);
  }
}

class _DocumentStat implements FileStat {
  _DocumentStat(Map? value)
    : type = value == null
          ? FileSystemEntityType.notFound
          : value['directory'] == true
          ? FileSystemEntityType.directory
          : FileSystemEntityType.file,
      size = (value?['size'] as num?)?.toInt() ?? 0,
      modified = DateTime.fromMillisecondsSinceEpoch(
        (value?['modified'] as num?)?.toInt() ?? 0,
      );
  @override
  final FileSystemEntityType type;
  @override
  final int size;
  @override
  final DateTime modified;
  @override
  DateTime get accessed => modified;
  @override
  DateTime get changed => modified;
  @override
  int get mode => type == FileSystemEntityType.directory ? 0x41c0 : 0x8180;
  @override
  String modeString() =>
      type == FileSystemEntityType.directory ? 'rwx------' : 'rw-------';
}

class _Posix {
  static final lib = DynamicLibrary.open('libc.so');
  static final read = lib
      .lookupFunction<
        IntPtr Function(Int32, Pointer<Uint8>, UintPtr),
        int Function(int, Pointer<Uint8>, int)
      >('read');
  static final write = lib
      .lookupFunction<
        IntPtr Function(Int32, Pointer<Uint8>, UintPtr),
        int Function(int, Pointer<Uint8>, int)
      >('write');
  static final close = lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('close');
  static final fsync = lib
      .lookupFunction<Int32 Function(Int32), int Function(int)>('fsync');
  static final _errno = lib
      .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
        '__errno',
      );
  static int errno() => _errno().value;
  static Never fail(String path) => throw FileOperationException.from(
    FileSystemException('Document I/O failed', path, OSError('', errno())),
  );
}

class _DocumentWriter implements FileWriter {
  _DocumentWriter(this.fd, this.path);
  int fd;
  final String path;
  @override
  Future<void> writeFrom(List<int> bytes) async {
    if (fd < 0) throw StateError('Writer is closed');
    final buffer = calloc<Uint8>(bytes.length);
    try {
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      var offset = 0;
      while (offset < bytes.length) {
        final written = _Posix.write(
          fd,
          buffer + offset,
          bytes.length - offset,
        );
        if (written < 0 && _Posix.errno() == 4) continue;
        if (written <= 0) _Posix.fail(path);
        offset += written;
      }
    } finally {
      calloc.free(buffer);
    }
  }

  @override
  Future<void> flush() async {
    if (_Posix.fsync(fd) < 0) _Posix.fail(path);
  }

  @override
  Future<void> close() async {
    if (fd >= 0) {
      final owned = fd;
      fd = -1;
      _Posix.close(owned);
    }
  }
}
