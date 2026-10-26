import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/engine/engine_bridge.dart';
import 'package:flutter_app/ui/ui.dart';
import 'package:flutter_app/widgets/engine_surface.dart';

class _Bridge implements EngineBridge {
  final events = <EngineInputEventData>[];
  @override
  Future<int> engineSetSurfaceSize({
    required int width,
    required int height,
  }) async => 0;
  @override
  Future<int> engineSendInput(EngineInputEventData event) async {
    events.add(event);
    return 0;
  }

  @override
  Future<EngineFrameData?> engineReadFrame() async => EngineFrameData(
    info: const EngineFrameInfo(
      width: 4,
      height: 2,
      strideBytes: 16,
      pixelFormat: 1,
      frameSerial: 1,
    ),
    pixels: Uint8List.fromList(List.filled(32, 255)),
  );
  @override
  Future<int> createTexture({required int width, required int height}) async =>
      1;
  @override
  Future<bool> updateTextureRgba({
    required int textureId,
    required Uint8List rgba,
    required int width,
    required int height,
    required int rowBytes,
  }) async => true;
  @override
  Future<void> disposeTexture({required int textureId}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'synthetic cursor shares DPR and letterbox mapping with direct touch',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _Bridge();
      final key = GlobalKey<EngineSurfaceState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: UiTheme.dark(),
          home: Scaffold(
            body: EngineSurface(
              key: key,
              bridge: bridge,
              active: true,
              externalTickDriven: true,
              surfaceMode: EngineSurfaceMode.software,
            ),
          ),
        ),
      );
      await tester.pump();
      await key.currentState!.sendVirtualInput(
        const EngineInputEventData(
          type: 1,
          x: 100,
          y: 250,
          button: 1,
          modifiers: 4,
        ),
      );
      expect((bridge.events.last.x, bridge.events.last.y), (200, 500));
      // Populate the native 2:1 frame: it occupies y=200..400 in this portrait viewport.
      await tester.runAsync(() => key.currentState!.pollFrame());
      await tester.pump();
      await tester.tapAt(const Offset(100, 250));
      await tester.pump();
      final direct = bridge.events[1];
      await key.currentState!.sendVirtualInput(
        const EngineInputEventData(
          type: 3,
          x: 100,
          y: 250,
          button: 1,
          modifiers: 4,
        ),
      );
      final synthetic = bridge.events.last;
      expect((direct.x, direct.y), (1, 0.5));
      expect((synthetic.x, synthetic.y), (direct.x, direct.y));
      expect((synthetic.button, synthetic.modifiers), (1, 4));
      await key.currentState!.releaseRenderTargets();
      final count = bridge.events.length;
      await key.currentState!.sendVirtualInput(
        const EngineInputEventData(type: 5, keyCode: 13),
      );
      expect(bridge.events.length, count);
    },
  );

  testWidgets('legacy texture uses the same frame letterbox mapping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bridge = _Bridge();
    final key = GlobalKey<EngineSurfaceState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: UiTheme.dark(),
        home: Scaffold(
          body: EngineSurface(
            key: key,
            bridge: bridge,
            active: true,
            externalTickDriven: true,
            surfaceMode: EngineSurfaceMode.texture,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() => key.currentState!.pollFrame());
    await tester.pump();
    await tester.tapAt(const Offset(100, 250));
    await tester.pump();
    expect((bridge.events.last.x, bridge.events.last.y), (1, 0.5));
    await key.currentState!.releaseRenderTargets();
  });
}
