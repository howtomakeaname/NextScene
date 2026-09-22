import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'archive_extractor.dart';
import 'local_file_service.dart';

/// Stage just this archive job for the native seekable-path API. Game playback
/// reads descriptors directly and does not use the cache.
Future<void> unpackDocumentArchive({
  required ManagerFileSystem io,
  required ArchiveExtractor extractor,
  required List<String> volumes,
  required String source,
  required String output,
  required FileTask task,
  String? password,
  int legacyCodepage = 65001,
}) async {
  final cache = await getTemporaryDirectory();
  final work = await Directory(
    p.join(cache.path, 'document-archive'),
  ).createTemp();
  final local = LocalManagerFileSystem();
  Future<void> transfer(
    ManagerFileSystem reader,
    String from,
    ManagerFileSystem writer,
    String to,
  ) async {
    task.check();
    if (await reader.type(from) == FileSystemEntityType.directory) {
      await writer.mkdir(to);
      for (final child in await reader.list(from)) {
        await transfer(reader, child.path, writer, p.join(to, child.name));
      }
      return;
    }
    final destination = await writer.writer(to);
    try {
      task.currentName = p.basename(from);
      await for (final bytes in reader.read(from)) {
        task.check();
        await destination.writeFrom(bytes);
        task.completed += bytes.length;
        task.report();
      }
      await destination.flush();
    } finally {
      await destination.close();
    }
  }

  try {
    final input = p.join(work.path, 'input');
    final extracted = p.join(work.path, 'output');
    await local.mkdir(input);
    await local.mkdir(extracted);
    for (final volume in volumes) {
      await transfer(io, volume, local, p.join(input, p.basename(volume)));
    }
    task.check();
    await extractor.unpack(
      root: work.path,
      source: p.join(input, p.basename(source)),
      destination: extracted,
      password: password,
      legacyCodepage: legacyCodepage,
      task: task,
    );
    for (final child in await local.list(extracted)) {
      await transfer(local, child.path, io, p.join(output, child.name));
    }
    task.check();
  } finally {
    await work.delete(recursive: true);
  }
}
