import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'file_operation_error.dart';

class LocalFileEntry {
  const LocalFileEntry(this.path, this.stat);
  final String path;
  final FileStat stat;
  String get name => p.basename(path);
  bool get isDirectory => stat.type == FileSystemEntityType.directory;
}

abstract class FileWriter {
  Future<void> writeFrom(List<int> bytes);
  Future<void> flush();
  Future<void> close();
}

/// Logical paths remain stable in the library; a backend controls actual access.
abstract class ManagerFileSystem {
  Future<FileStat> stat(String path);
  Future<List<LocalFileEntry>> list(String path);
  Future<void> mkdir(String path, {bool recursive = false});
  Future<void> rename(String from, String to);
  Future<void> delete(String path, {bool recursive = false});
  Stream<List<int>> read(String path);
  Future<FileWriter> writer(String path);
  Future<void> validateAncestors(String root, String path);
  Future<FileSystemEntityType> type(String path) async =>
      (await stat(path)).type;
  Future<bool> exists(String path) async =>
      await type(path) != FileSystemEntityType.notFound;
  Future<Uint8List> readBytes(String path, {int? limit}) async {
    final result = BytesBuilder(copy: false);
    await for (final chunk in read(path)) {
      final remaining = limit == null ? chunk.length : limit - result.length;
      result.add(
        chunk.length <= remaining ? chunk : chunk.sublist(0, remaining),
      );
      if (limit != null && result.length >= limit) break;
    }
    return result.takeBytes();
  }

  Future<String> readText(String path) async =>
      utf8.decode(await readBytes(path));
  Future<void> writeText(String path, String value) async {
    final output = await writer(path);
    try {
      await output.writeFrom(utf8.encode(value));
      await output.flush();
    } finally {
      await output.close();
    }
  }
}

class LocalManagerFileSystem extends ManagerFileSystem {
  @override
  Future<FileStat> stat(String path) => FileStat.stat(path);
  @override
  Future<FileSystemEntityType> type(String path) =>
      FileSystemEntity.type(path, followLinks: false);
  @override
  Future<List<LocalFileEntry>> list(String path) async {
    final entries = <LocalFileEntry>[];
    await for (final item in Directory(path).list(followLinks: false)) {
      entries.add(LocalFileEntry(item.path, await item.stat()));
    }
    return entries;
  }

  @override
  Future<void> mkdir(String path, {bool recursive = false}) async {
    await Directory(path).create(recursive: recursive);
  }

  @override
  Future<void> rename(String from, String to) async {
    if (await type(from) == FileSystemEntityType.directory) {
      await Directory(from).rename(to);
    } else {
      await File(from).rename(to);
    }
  }

  @override
  Future<void> delete(String path, {bool recursive = false}) async {
    if (await type(path) == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: recursive);
    } else {
      await File(path).delete();
    }
  }

  @override
  Stream<List<int>> read(String path) => File(path).openRead();
  @override
  Future<FileWriter> writer(String path) async =>
      _LocalWriter(await File(path).open(mode: FileMode.writeOnly));
  @override
  Future<void> validateAncestors(String root, String path) async {
    var cursor = p.rootPrefix(path);
    for (final part in p.split(path).skip(1)) {
      cursor = p.join(cursor, part);
      if (await type(cursor) == FileSystemEntityType.link) {
        throw const FileOperationException(FileErrorCode.unsupportedLink);
      }
    }
  }
}

class _LocalWriter implements FileWriter {
  _LocalWriter(this.file);
  final RandomAccessFile file;
  @override
  Future<void> writeFrom(List<int> bytes) async {
    await file.writeFrom(bytes);
  }

  @override
  Future<void> flush() async {
    await file.flush();
  }

  @override
  Future<void> close() async {
    await file.close();
  }
}
