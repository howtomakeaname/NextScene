import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/engine_bridge.dart';
import 'package:flutter_app/ui/ui.dart';
import 'package:flutter_app/widgets/engine_surface.dart';

class _Bridge implements EngineBridge {
  final create = Completer<Map<String, dynamic>?>();
  final resize = Completer<Map<String, dynamic>?>();
  final calls = <String>[];

  @override
  Future<int> engineSetSurfaceSize({
    required int width,
    required int height,
  }) async {
    calls.add('surface $width $height');
    return 0;
  }

  @override
  Future<Map<String, dynamic>?> createIOSurfaceTexture({
    required int width,
    required int height,
  }) {
    calls.add('create $width $height');
    return create.future;
  }

  @override
  Future<Map<String, dynamic>?> resizeIOSurfaceTexture({
    required int textureId,
    required int width,
    required int height,
  }) {
    calls.add('resize $width $height');
    return resize.future;
  }

  @override
  Future<int> engineSetRenderTargetIOSurface({
    required int iosurfaceId,
    required int width,
    required int height,
  }) async {
    calls.add('attach $iosurfaceId $width $height');
    return 0;
  }

  @override
  Future<void> disposeIOSurfaceTexture({required int textureId}) async {
    calls.add('dispose $textureId');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    _Bridge bridge,
    GlobalKey<EngineSurfaceState> key,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark(),
        home: EngineSurface(
          key: key,
          bridge: bridge,
          active: true,
          externalTickDriven: true,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'rotation during create and resize keeps native geometry coherent',
    (tester) async {
      final bridge = _Bridge();
      final key = GlobalKey<EngineSurfaceState>();
      await mount(tester, bridge, key);
      tester.view.physicalSize = const Size(800, 400);
      await tester.pump();
      bridge.create.complete({'textureId': 1, 'ioSurfaceID': 11});
      await tester.pump();
      expect(bridge.calls, [
        'surface 400 800',
        'create 400 800',
        'attach 11 400 800',
        'surface 800 400',
        'resize 800 400',
      ]);

      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      bridge.resize.complete({'ioSurfaceID': 12});
      await tester.pump();
      expect(bridge.calls.sublist(5), [
        'attach 12 800 400',
        'surface 400 800',
        'resize 400 800',
        'attach 12 400 800',
      ]);
      await key.currentState!.releaseRenderTargets();
      expect(bridge.calls.sublist(bridge.calls.length - 2), [
        'attach 0 0 0',
        'dispose 1',
      ]);
    },
  );

  testWidgets('exit waits for pending creation and disposes its result', (
    tester,
  ) async {
    final bridge = _Bridge();
    final key = GlobalKey<EngineSurfaceState>();
    await mount(tester, bridge, key);
    var released = false;
    final release = key.currentState!.releaseRenderTargets().then((_) {
      released = true;
    });
    await tester.pump();
    expect(released, isFalse);
    bridge.create.complete({'textureId': 1, 'ioSurfaceID': 11});
    await tester.pump();
    await release;
    expect(bridge.calls, ['surface 400 800', 'create 400 800', 'dispose 1']);
    expect(tester.takeException(), isNull);
  });
}
