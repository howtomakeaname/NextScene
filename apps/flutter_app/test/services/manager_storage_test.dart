import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/services/file_operation_error.dart';
import 'package:flutter_app/services/manager_scope.dart';
import 'package:flutter_app/services/manager_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory fixture;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture = Directory(
      await Directory.systemTemp
          .createTemp('krkr-manager-grant-')
          .then((dir) => dir.resolveSymbolicLinks()),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_engine_bridge'),
          null,
        );
    if (await fixture.exists()) await fixture.delete(recursive: true);
  });

  test(
    'Android rechecks permission and awaits authorization without a picker',
    () async {
      const channel = MethodChannel('flutter_engine_bridge');
      var authorized = false;
      final prompts = <bool>[];
      final root = p.join(
        fixture.path,
        'Download',
        ManagerScope.ohosAndroidAppId,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'ensureManagerRoot');
            final prompt = (call.arguments as Map)['prompt'] as bool;
            prompts.add(prompt);
            if (prompt) authorized = true;
            return authorized ? {'root': root} : null;
          });
      final storage = ManagerStorage(
        platform: 'android',
        channel: channel,
        pickDirectory: () =>
            throw StateError('SAF must not supply a native path'),
      );
      expect(storage.isSupported, isTrue);
      expect(await storage.currentGrant(), isNull);
      final grant = await storage.authorize();
      expect(grant.rootPath, root);
      expect(grant.platform, 'android');
      expect((await storage.currentGrant())?.rootPath, root);
      authorized = false;
      expect(await storage.currentGrant(), isNull);
      expect(prompts, [false, true, false, false]);
    },
  );

  test('Android denial never persists a usable grant', () async {
    const channel = MethodChannel('flutter_engine_bridge');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'permission_denied');
        });
    final storage = ManagerStorage(platform: 'android', channel: channel);
    await expectLater(
      storage.authorize(),
      throwsA(
        isA<FileOperationException>().having(
          (e) => e.code,
          'code',
          FileErrorCode.permissionDenied,
        ),
      ),
    );
    expect(await storage.currentGrant(), isNull);
  });

  test(
    'native appId and games fields cannot redirect Android file operations',
    () async {
      const channel = MethodChannel('flutter_engine_bridge');
      var root = '/storage/emulated/0/Download/other.app';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => {
              'root': root,
              'appId': 'other.app',
              'games': '/storage/emulated/0',
            },
          );
      final storage = ManagerStorage(platform: 'android', channel: channel);
      await expectLater(
        storage.authorize(),
        throwsA(
          isA<FileOperationException>().having(
            (e) => e.code,
            'code',
            FileErrorCode.outsideRoot,
          ),
        ),
      );
      root = '/storage/emulated/0/Download/${ManagerScope.ohosAndroidAppId}';
      final grant = await storage.authorize();
      expect(grant.gamesPath, '$root/games');
      expect(grant.appId, ManagerScope.ohosAndroidAppId);
    },
  );

  test(
    'desktop authorize accepts only the dedicated Downloads child',
    () async {
      final allowed = await Directory(
        p.join(fixture.path, 'Downloads', ManagerScope.ohosAndroidAppId),
      ).create(recursive: true);
      final storage = ManagerStorage(
        platform: 'linux',
        pickDirectory: () async => allowed.path,
      );
      final grant = await storage.authorize();
      expect(grant.rootPath, allowed.path);
      expect(await Directory(grant.gamesPath).exists(), isTrue);
      expect((await storage.currentGrant())?.rootPath, allowed.path);
    },
  );

  test('platforms without a storage adapter never reach the picker', () async {
    for (final platform in ['ios']) {
      var picked = false;
      final storage = ManagerStorage(
        platform: platform,
        pickDirectory: () async {
          picked = true;
          return p.join(
            fixture.path,
            'Download',
            ManagerScope.ohosAndroidAppId,
          );
        },
      );
      expect(storage.isSupported, isFalse);
      for (final call in [storage.currentGrant, storage.authorize]) {
        await expectLater(
          call(),
          throwsA(
            isA<FileOperationException>().having(
              (error) => error.code,
              'code',
              FileErrorCode.unsupportedPlatform,
            ),
          ),
        );
      }
      expect(picked, isFalse, reason: '$platform must not open a picker');
    }
  });

  test('desktop authorize rejects a user-chosen sandbox or sibling', () async {
    final other = await Directory(
      p.join(fixture.path, 'Downloads', 'other.app'),
    ).create(recursive: true);
    final storage = ManagerStorage(
      platform: 'linux',
      pickDirectory: () async => other.path,
    );
    await expectLater(
      storage.authorize(),
      throwsA(
        isA<FileOperationException>().having(
          (error) => error.code,
          'code',
          FileErrorCode.outsideRoot,
        ),
      ),
    );
    expect(await storage.currentGrant(), isNull);
  });

  test(
    'HarmonyOS maps native errors and never treats null as an empty root',
    () async {
      final channel = const MethodChannel('flutter_engine_bridge');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'ensureManagerRoot') {
              throw PlatformException(code: 'permission_denied');
            }
            return null;
          });
      final storage = ManagerStorage(platform: 'ohos', channel: channel);
      await expectLater(
        storage.authorize(),
        throwsA(
          isA<FileOperationException>().having(
            (error) => error.code,
            'code',
            FileErrorCode.permissionDenied,
          ),
        ),
      );
    },
  );

  test(
    'HarmonyOS rejects a native root that is not Download/<appId>',
    () async {
      final channel = const MethodChannel('flutter_engine_bridge');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'ensureManagerRoot') {
              return <String, dynamic>{
                'root': '/storage/Users/currentUser/Download/other.app',
                'games': '/storage/Users/currentUser/Download/other.app/games',
                'appId': ManagerScope.ohosAndroidAppId,
              };
            }
            return null;
          });
      final storage = ManagerStorage(platform: 'ohos', channel: channel);
      await expectLater(
        storage.authorize(),
        throwsA(
          isA<FileOperationException>().having(
            (error) => error.code,
            'code',
            FileErrorCode.outsideRoot,
          ),
        ),
      );
    },
  );
}
