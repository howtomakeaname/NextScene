import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/l10n/app_localizations.dart';
import 'package:flutter_app/pages/manager_media_page.dart';
import 'package:flutter_app/pages/manager_page.dart';
import 'package:flutter_app/services/file_manager_controller.dart';
import 'package:flutter_app/services/game_manager.dart';
import 'package:flutter_app/services/local_file_service.dart';
import 'package:flutter_app/services/manager_scope.dart';
import 'package:flutter_app/services/manager_storage.dart';
import 'package:flutter_app/ui/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory fixture;
  late FileManagerController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = Directory(
      await Directory.systemTemp
          .createTemp('krkr-manager-page-')
          .then((dir) => dir.resolveSymbolicLinks()),
    );
    final root = await Directory(
      p.join(fixture.path, 'Downloads', ManagerScope.ohosAndroidAppId),
    ).create(recursive: true);
    await Directory(p.join(root.path, 'games')).create();
    await File(p.join(root.path, 'games', '中文 🐈.txt')).writeAsString('ok');
    await File(p.join(root.path, 'games', 'notes.bin')).writeAsBytes([0, 1]);
    final games = GameManager();
    await games.load();
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

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      UiThemeScope(
        controller: UiThemeController(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: UiTheme.light(),
          home: Scaffold(body: ManagerPage(controller: controller)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Widget tests run inside FakeAsync, where dart:io futures never resolve on
  // their own. Disk setup done in a test body therefore goes through
  // [tester.runAsync]; IO started by the UI (a refresh, a folder walk) only
  // advances when the fake microtask queue is flushed, which [settleIo] does
  // one round trip at a time until [until] shows up.
  Future<void> io(WidgetTester tester, Future<void> Function() work) =>
      tester.runAsync(work);

  Future<void> settleIo(WidgetTester tester, Finder until) async {
    for (var i = 0; i < 200 && until.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(until, findsOneWidget);
    await tester.pumpAndSettle();
  }

  /// Location shown in the details sheet: breadcrumb root plus folders.
  String location(String path) => controller.locationOf(path);

  testWidgets('lists files without a glass row background', (tester) async {
    await pumpPage(tester);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('中文 🐈.txt'), findsOneWidget);
    expect(find.byType(UiGlassSurface), findsNothing);
  });

  testWidgets('shows authorization empty state before a grant exists', (
    tester,
  ) async {
    await controller.storage.revoke();
    final empty = FileManagerController(
      gameManager: GameManager(),
      storage: ManagerStorage(
        platform: 'linux',
        pickDirectory: () async => null,
      ),
    );
    await tester.pumpWidget(
      UiThemeScope(
        controller: UiThemeController(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: UiTheme.light(),
          home: Scaffold(body: ManagerPage(controller: empty)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Authorize Folder'), findsOneWidget);
    empty.dispose();
  });

  testWidgets('system back leaves selection, then walks up, then yields', (
    tester,
  ) async {
    final gamesPath = controller.files!.gamesPath;
    await io(tester, () async {
      await Directory(p.join(gamesPath, 'sub')).create();
      await controller.open(p.join(gamesPath, 'sub'));
    });
    controller.toggleSelecting(true);
    await pumpPage(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    // Back is handled inside the tab; goBack() then lists the parent, which
    // is real IO, so the pop is issued where that IO can complete.
    Future<void> back({required bool handled}) => io(tester, () async {
      expect(await navigator.maybePop(), handled);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    await back(handled: true);
    await tester.pumpAndSettle();
    expect(controller.selecting, isFalse);
    expect(controller.currentPath, p.join(gamesPath, 'sub'));

    await back(handled: true);
    await tester.pumpAndSettle();
    expect(controller.currentPath, gamesPath);

    await back(handled: true);
    await tester.pumpAndSettle();
    expect(controller.currentPath, controller.files!.rootPath);

    // At the authorized root the tab no longer claims back.
    await back(handled: false);
  });

  testWidgets('an inactive tab never intercepts back', (tester) async {
    final gamesPath = controller.files!.gamesPath;
    await io(tester, () async {
      await Directory(p.join(gamesPath, 'sub')).create();
      await controller.open(p.join(gamesPath, 'sub'));
    });
    await tester.pumpWidget(
      UiThemeScope(
        controller: UiThemeController(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: UiTheme.light(),
          home: Scaffold(
            body: ManagerPage(controller: controller, active: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(await navigator.maybePop(), isFalse);
    expect(controller.currentPath, p.join(gamesPath, 'sub'));
  });

  testWidgets('explains an unsupported platform instead of offering a picker', (
    tester,
  ) async {
    final unsupported = FileManagerController(
      gameManager: GameManager(),
      storage: ManagerStorage(platform: 'ios'),
    );
    await tester.pumpWidget(
      UiThemeScope(
        controller: UiThemeController(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: UiTheme.light(),
          home: Scaffold(body: ManagerPage(controller: unsupported)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Authorize Folder'), findsNothing);
    // Shown inline exactly once: the load error must not also toast it.
    expect(
      find.text('Folder access is not available on this platform yet.'),
      findsOneWidget,
    );
    unsupported.dispose();
  });

  testWidgets('tapping a binary file opens its details', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('notes.bin'));
    await tester.pumpAndSettle();

    // The list row shows the size too, so look inside the sheet only.
    final sheet = find.byKey(const Key('manager-details'));
    expect(sheet, findsOneWidget);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(find.byType(UiListSection), findsNothing);
    expect(inSheet('Kind'), findsOneWidget);
    expect(inSheet('File'), findsOneWidget);
    expect(inSheet('2 B'), findsOneWidget);
    expect(inSheet('Modified'), findsOneWidget);
    // Anchored at the breadcrumb root, never the temp dir the fixture lives in.
    final gamesPath = controller.files!.gamesPath;
    expect(location(gamesPath), 'Download/${ManagerScope.ohosAndroidAppId}');
    expect(find.text('${location(gamesPath)}/games'), findsOneWidget);
    expect(find.textContaining(fixture.path), findsNothing);
  });

  testWidgets('tapping a text file opens the preview', (tester) async {
    await pumpPage(tester);
    expect(find.byIcon(CupertinoIcons.doc_text), findsOneWidget);

    await tester.tap(find.text('中文 🐈.txt'));
    await tester.pump();
    await settleIo(tester, find.text('ok'));

    expect(find.byType(ManagerMediaPage), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.byKey(const Key('manager-details')), findsNothing);
  });

  testWidgets('folder details total the contents after opening', (
    tester,
  ) async {
    final gamesPath = controller.files!.gamesPath;
    await io(tester, () async {
      final file = await File(
        p.join(gamesPath, 'pack', 'a.bin'),
      ).create(recursive: true);
      await file.writeAsBytes(List.filled(3, 0));
      await controller.refresh();
    });
    await pumpPage(tester);

    await tester.longPress(find.text('pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();

    // The sheet opens at once and fills the total in once the walk is done.
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('Calculating…'), findsOneWidget);
    await settleIo(tester, find.text('3 B · 1 items'));
    expect(find.text('Calculating…'), findsNothing);
  });

  Future<void> renameListedFile(
    WidgetTester tester,
    String from,
    String to,
  ) async {
    await tester.longPress(find.text(from));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), to);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  testWidgets('renaming a file warns when the extension changes', (
    tester,
  ) async {
    await pumpPage(tester);
    await renameListedFile(tester, 'notes.bin', 'notes.dat');

    expect(find.text('Change the file extension?'), findsOneWidget);
    expect(
      find.text(
        'Changing the extension from .bin to .dat may change how this file is classified (preview, extract, game data). Only continue if you meant to do that.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('notes.bin'), findsOneWidget);
    expect(find.text('notes.dat'), findsNothing);
  });

  testWidgets('confirming an extension change renames the file', (tester) async {
    await pumpPage(tester);
    await renameListedFile(tester, 'notes.bin', 'notes.dat');
    await tester.tap(find.text('Continue'));
    await settleIo(tester, find.text('notes.dat'));
    expect(find.text('notes.bin'), findsNothing);
  });

  testWidgets('renaming without changing the extension does not warn', (
    tester,
  ) async {
    await pumpPage(tester);
    await renameListedFile(tester, 'notes.bin', 'other.bin');
    expect(find.text('Change the file extension?'), findsNothing);
    await settleIo(tester, find.text('other.bin'));
    expect(find.text('notes.bin'), findsNothing);
  });

  testWidgets('a protected folder still offers details, nothing else', (
    tester,
  ) async {
    await io(tester, () => controller.openBreadcrumb(0));
    await pumpPage(tester);

    await tester.longPress(find.text('games'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Rename'), findsNothing);
    expect(find.text('Move to Recently Deleted'), findsNothing);
  });

  // Drags past the trigger distance and lets the refresh run to completion:
  // the listing IO, the success hold and the indicator collapsing again.
  Future<void> pullToRefresh(WidgetTester tester, Finder appears) async {
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await settleIo(tester, appears);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Refreshing'), findsNothing);
  }

  testWidgets('pulling down reloads the listing', (tester) async {
    await pumpPage(tester);
    final gamesPath = controller.files!.gamesPath;
    await io(
      tester,
      () => File(p.join(gamesPath, 'late.txt')).writeAsString('x'),
    );
    expect(find.text('late.txt'), findsNothing);

    await pullToRefresh(tester, find.text('late.txt'));
  });

  testWidgets('an empty folder can still be pulled to refresh', (tester) async {
    final gamesPath = controller.files!.gamesPath;
    final empty = Directory(p.join(gamesPath, 'empty'));
    await io(tester, () async {
      await empty.create();
      await controller.open(empty.path);
    });
    await pumpPage(tester);
    expect(find.text('This folder is empty'), findsOneWidget);

    await io(
      tester,
      () => File(p.join(empty.path, 'new.txt')).writeAsString('x'),
    );
    await pullToRefresh(tester, find.text('new.txt'));
    expect(find.text('This folder is empty'), findsNothing);
  });

  testWidgets('a running copy shows the transfer speed next to the name', (
    tester,
  ) async {
    await pumpPage(tester);
    controller.task = FileTask()
      ..currentName = 'pack.7z'
      ..completed = 10 * 1024 * 1024
      ..total = 20 * 1024 * 1024
      ..bytesPerSecond = 2.5 * 1024 * 1024;
    controller.notifyListeners();
    await tester.pump();

    expect(find.text('pack.7z'), findsOneWidget);
    expect(find.text('2.50 MB/s'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('a dat file is marked as game data and opens details', (
    tester,
  ) async {
    await io(tester, () async {
      await File(
        p.join(controller.files!.gamesPath, 'save0001.dat'),
      ).writeAsBytes(const []);
      await controller.refresh();
    });
    await pumpPage(tester);
    expect(find.byIcon(CupertinoIcons.square_stack_3d_up), findsOneWidget);

    await tester.tap(find.text('save0001.dat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manager-details')), findsOneWidget);
    expect(find.text('Game data'), findsOneWidget);
  });

  testWidgets('an xp3 pack is marked as a game and opens details', (
    tester,
  ) async {
    await io(tester, () async {
      await File(
        p.join(controller.files!.gamesPath, 'data.xp3'),
      ).writeAsBytes(const []);
      await controller.refresh();
    });
    await pumpPage(tester);
    expect(find.byIcon(CupertinoIcons.game_controller), findsOneWidget);

    await tester.tap(find.text('data.xp3'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manager-details')), findsOneWidget);
    expect(find.text('Game'), findsOneWidget);
  });

  testWidgets('tapping an image opens the preview', (tester) async {
    await io(tester, () async {
      await File(
        p.join(controller.files!.gamesPath, 'cover.png'),
      ).writeAsBytes(_onePixelPng);
      await controller.refresh();
    });
    await pumpPage(tester);
    expect(find.byIcon(CupertinoIcons.photo), findsOneWidget);

    await tester.tap(find.text('cover.png'));
    await tester.pumpAndSettle();
    expect(find.byType(UiImageViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}

/// 1×1 transparent PNG so the preview has a real decodeable file.
const _onePixelPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
