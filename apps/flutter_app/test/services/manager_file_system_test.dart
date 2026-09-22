import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_app/models/game_engine.dart';
import 'package:flutter_app/services/android_document_file_system.dart';
import 'package:flutter_app/services/game_directory_scanner.dart';
import 'package:flutter_app/services/local_file_service.dart';

// The logical tree deliberately does not exist on the test host. Direct dart:io
// calls in the file manager or discovery would fail these operations.
class MappedFiles extends ManagerFileSystem {
  MappedFiles(this.physical);
  static const root = '/provider-only/Download/com.nextscene.app';
  final String physical;
  final local = LocalManagerFileSystem();
  String map(String path) => p.join(physical, p.relative(path, from: root));
  @override
  Future<FileStat> stat(String path) => local.stat(map(path));
  @override
  Future<List<LocalFileEntry>> list(String path) async =>
      (await local.list(map(path)))
          .map(
            (e) => LocalFileEntry(
              p.join(root, p.relative(e.path, from: physical)),
              e.stat,
            ),
          )
          .toList();
  @override
  Future<void> mkdir(String path, {bool recursive = false}) =>
      local.mkdir(map(path), recursive: recursive);
  @override
  Future<void> rename(String from, String to) =>
      local.rename(map(from), map(to));
  @override
  Future<void> delete(String path, {bool recursive = false}) =>
      local.delete(map(path), recursive: recursive);
  @override
  Stream<List<int>> read(String path) => local.read(map(path));
  @override
  Future<FileWriter> writer(String path) => local.writer(map(path));
  @override
  Future<void> validateAncestors(String root, String path) =>
      local.validateAncestors(physical, map(path));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory fixture;
  late MappedFiles io;
  late LocalFileService service;
  const root = MappedFiles.root;
  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('document-files-test');
    io = MappedFiles(await fixture.resolveSymbolicLinks());
    service = LocalFileService(rootPath: root, fileSystem: io);
    await io.mkdir('$root/games', recursive: true);
  });
  tearDown(() async {
    await fixture.delete(recursive: true);
  });

  test(
    'provider paths support copy, move, trash, restore and publish',
    () async {
      await service.createDirectory('$root/games', '原始😀');
      await io.writeText('$root/games/原始😀/data.xp3', 'archive');
      await service.copy('$root/games/原始😀', '$root/games/副本', FileTask());
      expect(await io.readText('$root/games/副本/data.xp3'), 'archive');
      await service.rename('$root/games/副本', '改名');
      final item = await service.trash('$root/games/改名');
      expect(await io.exists(item.originalPath), false);
      expect(
        (await service.deletedFiles()).single.originalPath,
        item.originalPath,
      );
      await service.restore(item);
      expect(await io.readText('${item.originalPath}/data.xp3'), 'archive');
      await service.extract(
        '$root/games/解压',
        (output) => io.writeText('$output/startup.tjs', 'script'),
      );
      expect((await service.summarize('$root/games/解压', FileTask())).bytes, 6);
      expect((await service.list(root)).map((e) => e.name), ['games']);
      final deleted = await service.trash('$root/games/解压');
      await service.permanentlyDelete(deleted);
      expect(await service.deletedFiles(), isEmpty);
    },
  );

  test('cancelled copy never publishes a partial provider file', () async {
    await io.writeText('$root/games/source.xp3', 'payload');
    final task = FileTask()..cancelled = true;
    await expectLater(
      service.copy('$root/games/source.xp3', '$root/games/result.xp3', task),
      throwsA(isA<FileOperationException>()),
    );
    expect(await io.exists('$root/games/result.xp3'), false);
  });

  test(
    'discovery groups archive chains and excludes private task files',
    () async {
      for (final path in [
        'Novel/data.xp3',
        'Novel/patch.xp3',
        'Packed/root.pfs',
        'Packed/root.pfs.001',
        'Loose/startup.tjs',
        '.krkr-manager/tasks/hidden/data.xp3',
      ]) {
        final file = '$root/games/$path';
        await io.mkdir(p.dirname(file), recursive: true);
        await io.writeText(file, 'fixture');
      }
      final scanner = GameDirectoryScanner(io);
      final games = await scanner.scan('$root/games');
      expect(games, {
        '$root/games/Novel': GameEngine.krkr2,
        '$root/games/Packed': GameEngine.artemis,
        '$root/games/Loose': GameEngine.krkr2,
      });
      expect(
        await scanner.launchPath('$root/games/Novel'),
        '$root/games/Novel/data.xp3',
      );
      expect(
        await scanner.launchPath('$root/games/Loose'),
        '$root/games/Loose',
      );
    },
  );

  test(
    'SAF metadata is read via channel and revoked grants fail closed',
    () async {
      const channel = MethodChannel('documents-test');
      var revoked = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (revoked) throw PlatformException(code: 'permission_denied');
            expect(call.method, 'documentStat');
            return {'directory': false, 'size': 42, 'modified': 1000};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final documents = AndroidDocumentFileSystem(root, channel: channel);
      expect((await documents.stat('$root/games/file')).size, 42);
      await expectLater(
        documents.validateAncestors(root, '$root/../outside'),
        throwsA(
          isA<FileOperationException>().having(
            (e) => e.code,
            'code',
            FileErrorCode.outsideRoot,
          ),
        ),
      );
      revoked = true;
      await expectLater(
        documents.stat('$root/games/file'),
        throwsA(
          isA<FileOperationException>().having(
            (e) => e.code,
            'code',
            FileErrorCode.permissionDenied,
          ),
        ),
      );
    },
  );
}
