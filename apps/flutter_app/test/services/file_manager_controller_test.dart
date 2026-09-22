import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/models/game_info.dart';
import 'package:flutter_app/services/archive_volumes.dart';
import 'package:flutter_app/services/file_manager_controller.dart';
import 'package:flutter_app/services/game_manager.dart';
import 'package:flutter_app/services/local_file_service.dart';
import 'package:flutter_app/services/manager_scope.dart';
import 'package:flutter_app/services/manager_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory fixture;
  late FileManagerController controller;
  late GameManager games;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = Directory(
      await Directory.systemTemp
          .createTemp('krkr-manager-ctl-')
          .then((dir) => dir.resolveSymbolicLinks()),
    );
    final root = await Directory(
      p.join(fixture.path, 'Downloads', ManagerScope.ohosAndroidAppId),
    ).create(recursive: true);
    await Directory(p.join(root.path, 'games')).create();
    await File(
      p.join(root.path, 'games', '星空', 'data.xp3'),
    ).create(recursive: true);
    games = GameManager();
    await games.load();
    await games.addGame(
      GameInfo(path: p.join(root.path, 'games', '星空'), playDurationSeconds: 90),
    );
    controller = FileManagerController(
      gameManager: games,
      storage: ManagerStorage(
        platform: 'linux',
        pickDirectory: () async => root.path,
      ),
    );
    await controller.authorize();
  });

  tearDown(() async {
    controller.dispose();
    if (await fixture.exists()) await fixture.delete(recursive: true);
  });

  test('Android opens the games directory used by HarmonyOS', () async {
    const channel = MethodChannel('android-manager-controller-test');
    final root = controller.files!.rootPath;
    await File(
      p.join(root, 'games', 'FolderGame', 'data.xp3'),
    ).create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => {'root': root});
    final android = FileManagerController(
      gameManager: games,
      storage: ManagerStorage(platform: 'android', channel: channel),
      fileSystem: LocalManagerFileSystem(),
    );
    try {
      await android.authorize();
      expect(android.lastError, isNull);
      expect(android.currentPath, p.join(root, 'games'));
      expect(
        android.entries.map((entry) => entry.name),
        contains('FolderGame'),
      );
      await android.load();
      expect(android.currentPath, p.join(root, 'games'));
      expect(android.canGoBack, isTrue);
    } finally {
      android.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  test('rename updates library path and keeps the save folder name', () async {
    final source = p.join(controller.files!.gamesPath, '星空');
    await controller.rename(source, '星空改');
    expect(games.games.single.path, p.join(controller.files!.gamesPath, '星空改'));
    expect(games.games.single.saveDirectoryName, '星空');
    expect(games.games.single.available, isTrue);
  });

  test('trash keeps history and restore brings the folder back', () async {
    final source = p.join(controller.files!.gamesPath, '星空');
    controller.selected.add(source);
    await controller.trashSelected();
    expect(games.games.single.available, isFalse);
    expect(games.games.single.playDurationSeconds, 90);
    expect(await Directory(source).exists(), isFalse);
    await controller.restore(controller.trash.single);
    expect(games.games.single.available, isTrue);
    expect(await Directory(source).exists(), isTrue);
  });

  test('extract destination for a split archive is the group prefix', () {
    expect(ArchiveVolumes.extractFolderName('dlc.7z.001'), 'dlc.7z');
  });

  test(
    'a failing item stops the batch and the listing shows what moved',
    () async {
      final gamesPath = controller.files!.gamesPath;
      await File(p.join(gamesPath, 'a.txt')).writeAsString('a');
      await File(p.join(gamesPath, 'b.txt')).writeAsString('b');
      final target = await Directory(p.join(gamesPath, 'target')).create();
      // b.txt already exists at the destination, so the second move conflicts.
      await File(p.join(target.path, 'b.txt')).writeAsString('old');
      await controller.refresh();
      controller.selected.addAll([
        p.join(gamesPath, 'a.txt'),
        p.join(gamesPath, 'b.txt'),
      ]);

      await controller.moveTo(target.path);

      expect(controller.lastError?.code, FileErrorCode.conflict);
      expect(await File(p.join(target.path, 'a.txt')).exists(), isTrue);
      expect(await File(p.join(gamesPath, 'b.txt')).exists(), isTrue);
      expect(await File(p.join(target.path, 'b.txt')).readAsString(), 'old');
      // The listing was refreshed even though the batch failed.
      expect(controller.entries.map((e) => e.name), isNot(contains('a.txt')));
      expect(controller.entries.map((e) => e.name), contains('b.txt'));
    },
  );

  test('copy reports completion once and hides progress afterwards', () async {
    final gamesPath = controller.files!.gamesPath;
    await File(p.join(gamesPath, 'readme.txt')).writeAsString('hello');
    final target = await Directory(p.join(gamesPath, 'copies')).create();
    await controller.refresh();
    controller.selected.add(p.join(gamesPath, 'readme.txt'));

    await controller.copyTo(target.path);

    expect(controller.notice, ManagerNotice.completed);
    expect(controller.task, isNull);
    expect(controller.lastError, isNull);
    expect(
      await File(p.join(target.path, 'readme.txt')).readAsString(),
      'hello',
    );
  });

  test('trashing a parent folder hides every game inside it', () async {
    final gamesPath = controller.files!.gamesPath;
    final bundle = await Directory(p.join(gamesPath, '合集')).create();
    await File(p.join(bundle.path, '甲', 'data.xp3')).create(recursive: true);
    await File(p.join(bundle.path, '乙', 'data.xp3')).create(recursive: true);
    await games.addGame(GameInfo(path: p.join(bundle.path, '甲')));
    await games.addGame(GameInfo(path: p.join(bundle.path, '乙')));
    await controller.refresh();
    controller.selected.add(bundle.path);

    await controller.trashSelected();
    expect(
      games.games
          .where((g) => g.path.startsWith(bundle.path))
          .map((g) => g.available),
      everyElement(isFalse),
    );
    expect(games.games.length, 3, reason: 'history entries are kept');

    await controller.restore(controller.trash.single);
    expect(
      games.games
          .where((g) => g.path.startsWith(bundle.path))
          .map((g) => g.available),
      everyElement(isTrue),
    );
  });

  test('protected entries cannot be selected or mutated', () async {
    final service = controller.files!;
    await controller.openBreadcrumb(0);
    expect(controller.currentPath, service.rootPath);
    expect(controller.canMutate(service.gamesPath), isFalse);
    expect(controller.canMutate(service.rootPath), isFalse);
    expect(controller.canMutate(p.join(service.gamesPath, '星空')), isTrue);

    controller.toggleSelecting(true);
    controller.toggle(service.gamesPath);
    controller.selectAll();
    expect(controller.selected, isEmpty);
  });

  test('viewing a folder that disappears falls back to games', () async {
    final gamesPath = controller.files!.gamesPath;
    final folder = await Directory(p.join(gamesPath, 'temp')).create();
    await controller.open(folder.path);
    expect(controller.currentPath, folder.path);

    await folder.delete();
    await controller.refresh();

    expect(controller.currentPath, gamesPath);
  });

  test('folder details count what the listing shows', () async {
    final service = controller.files!;
    final game = p.join(service.gamesPath, '星空');
    await File(p.join(game, 'sub', 'a.bin')).create(recursive: true);
    await File(p.join(game, 'sub', 'a.bin')).writeAsBytes(List.filled(10, 1));
    await File(p.join(game, 'data.xp3')).writeAsBytes(List.filled(5, 1));
    // Neither a link nor private work counts towards the totals.
    await Link(p.join(game, 'loop')).create(game);
    await File(
      p.join(game, LocalFileService.privateName, 'x'),
    ).create(recursive: true);

    final summary = await controller.summarize(game, FileTask());
    // data.xp3, sub, sub/a.bin
    expect(summary.items, 3);
    expect(summary.bytes, 15);

    final cancelled = FileTask()..cancelled = true;
    await expectLater(
      controller.summarize(game, cancelled),
      throwsA(
        isA<FileOperationException>().having(
          (e) => e.code,
          'code',
          FileErrorCode.cancelled,
        ),
      ),
    );
  });

  test('location is shown under the breadcrumb root, never absolute', () {
    final service = controller.files!;
    final root = controller.grant!.displayRoot;
    expect(root, 'Download/${ManagerScope.ohosAndroidAppId}');
    expect(
      controller.locationOf(p.join(service.gamesPath, '星空')),
      '$root/games',
    );
    expect(controller.locationOf(service.gamesPath), root);
    expect(
      controller.locationOf(p.join(service.gamesPath, '星空', 'data.xp3')),
      '$root/games/星空',
    );
    expect(
      controller.locationOf(service.gamesPath),
      isNot(contains(fixture.path)),
    );
  });

  test('pull-to-refresh reports a listing failure', () async {
    final service = controller.files!;
    controller.currentPath = p.join(service.gamesPath, 'missing');
    // The vanished folder is recovered rather than reported.
    await controller.reload();
    expect(controller.currentPath, service.gamesPath);
    expect(controller.lastError, isNull);

    controller.currentPath = p.join(fixture.path, 'outside');
    await Directory(controller.currentPath).create();
    await controller.reload();
    expect(controller.lastError?.code, FileErrorCode.outsideRoot);
  });
}
