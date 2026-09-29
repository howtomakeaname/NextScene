import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../engine/engine_bridge.dart';
import '../ui/theme/ui_theme.dart';

/// True on the OpenHarmony Flutter fork. The fork reports 'ohos' through
/// Platform.operatingSystem but the standard SDK has no Platform.isOhos,
/// so compare the string directly.
bool get _isOhos => Platform.operatingSystem == 'ohos';

/// Rendering mode for the engine surface.
enum EngineSurfaceMode {
  /// GPU zero-copy mode (macOS: IOSurface, Android: SurfaceTexture).
  gpuZeroCopy,

  /// Flutter Texture with RGBA pixel upload (cross-platform, slower).
  texture,

  /// Pure software decoding via RawImage (slowest, always works).
  software,
}

class EngineSurface extends StatefulWidget {
  const EngineSurface({
    super.key,
    required this.bridge,
    required this.active,
    this.surfaceMode = EngineSurfaceMode.gpuZeroCopy,
    this.externalTickDriven = false,
    this.onLog,
    this.onError,
    this.onPointerPosition,
  });

  final EngineBridge bridge;
  final bool active;
  final EngineSurfaceMode surfaceMode;

  /// When true, the internal frame polling timer is disabled.
  /// The parent widget must call [EngineSurfaceState.pollFrame()] after each
  /// engine tick to eliminate the dual-timer phase mismatch.
  final bool externalTickDriven;
  final ValueChanged<String>? onLog;
  final ValueChanged<String>? onError;
  final ValueChanged<Offset>? onPointerPosition;

  @override
  EngineSurfaceState createState() => EngineSurfaceState();
}

class EngineSurfaceState extends State<EngineSurface> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'engine-surface-focus');
  bool _vsyncScheduled = false;
  bool _frameInFlight = false;
  bool _textureInitInFlight = false;
  ui.Image? _frameImage;
  int _lastFrameSerial = -1;
  int _surfaceWidth = 0;
  int _surfaceHeight = 0;
  int _frameWidth = 0;
  int _frameHeight = 0;
  double _devicePixelRatio = 1.0;

  // Legacy texture mode
  int? _textureId;

  // IOSurface zero-copy mode (macOS)
  int? _ioSurfaceTextureId;
  // ignore: unused_field
  int? _ioSurfaceId;
  bool _ioSurfaceInitInFlight = false;

  // SurfaceTexture zero-copy mode (Android, OHOS)
  int? _surfaceTextureId;
  bool _surfaceTextureInitInFlight = false;
  // OHOS: raw OHNativeWindow* attached via FFI (0 = detached)
  int _nativeWindowPtr = 0;
  Size _lastRequestedLogicalSize = Size.zero;

  /// Logical size of this widget from the last build; used to map pointer
  /// positions onto the letterboxed RawImage frame (software path).
  Size _lastWidgetLogicalSize = Size.zero;
  double _lastRequestedDpr = 1.0;
  EngineInputEventData? _pendingPointerMoveEvent;
  bool _pointerMoveFlushScheduled = false;
  bool _renderTargetsReleased = false;
  Future<void>? _renderTargetReleaseFuture;
  Future<void> _surfaceSizeUpdate = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _reconcilePolling();
  }

  @override
  void didUpdateWidget(covariant EngineSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bridge != widget.bridge) {
      unawaited(_disposeAllTextures());
    }
    if (oldWidget.surfaceMode != widget.surfaceMode) {
      unawaited(_disposeAllTextures());
    }
    if (oldWidget.active != widget.active ||
        oldWidget.bridge != widget.bridge ||
        oldWidget.surfaceMode != widget.surfaceMode ||
        oldWidget.externalTickDriven != widget.externalTickDriven) {
      _reconcilePolling();
    }
  }

  @override
  void dispose() {
    // _vsyncScheduled will simply be ignored once disposed.
    _vsyncScheduled = false;
    _frameImage?.dispose();
    unawaited(releaseRenderTargets());
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _disposeAllTextures() async {
    await _disposeTexture();
    await _disposeIOSurfaceTexture();
    await _disposeSurfaceTexture();
  }

  /// Detach and unregister native render targets before the route is popped.
  ///
  /// `State.dispose` cannot await asynchronous platform/FFI cleanup. Exposing
  /// this step lets [GamePage] serialize detach -> pause -> pop, avoiding an
  /// old OHNativeWindow detach racing with the next resumed game surface.
  Future<void> releaseRenderTargets() {
    final ongoing = _renderTargetReleaseFuture;
    if (ongoing != null) return ongoing;
    _renderTargetsReleased = true;
    _vsyncScheduled = false;
    // Creation may still own a platform request even before it has a texture
    // ID. Drain it before releasing resources or letting the next game attach.
    return _renderTargetReleaseFuture = _surfaceSizeUpdate.whenComplete(
      _disposeAllTextures,
    );
  }

  void _reconcilePolling() {
    if (!widget.active || widget.externalTickDriven) {
      _vsyncScheduled = false;
      return;
    }

    _scheduleVsyncPoll();
    unawaited(_pollFrame());
  }

  /// Schedule a single vsync-aligned frame callback.
  /// This replaces Timer.periodic and aligns with Flutter's display refresh.
  void _scheduleVsyncPoll() {
    if (_vsyncScheduled || !widget.active || widget.externalTickDriven) {
      return;
    }
    _vsyncScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _vsyncScheduled = false;
      if (!mounted || !widget.active || widget.externalTickDriven) {
        return;
      }
      unawaited(_pollFrame());
      _scheduleVsyncPoll();
    });
  }

  /// Public entry point for the parent tick loop to drive frame polling.
  /// Call this immediately after [EngineBridge.engineTick] completes
  /// to eliminate the dual-timer phase mismatch.
  ///
  /// When [rendered] is provided (non-null), the IOSurface path uses it
  /// directly instead of calling [engineGetFrameRenderedFlag] again.
  /// This avoids the double-read problem where the flag is reset on the
  /// first read and the second read always sees false.
  Future<void> pollFrame({bool? rendered}) =>
      _pollFrame(externalRendered: rendered);

  Future<void> _ensureSurfaceSize(Size size, double devicePixelRatio) {
    // Keep the engine size, native buffer size and attachment metadata in one
    // transaction. Orientation can change while a platform create/resize is
    // pending; overwriting _surfaceWidth/Height then would attach a portrait
    // buffer as landscape and incorrectly skip the subsequent resize.
    return _surfaceSizeUpdate = _surfaceSizeUpdate
        .then((_) => _applySurfaceSize(size, devicePixelRatio))
        .catchError((Object error) {
          _reportError('surface resize failed: $error');
        });
  }

  Future<void> _applySurfaceSize(Size size, double devicePixelRatio) async {
    if (!mounted || !widget.active || _renderTargetsReleased) {
      return;
    }
    _devicePixelRatio = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    final int width = (size.width * _devicePixelRatio).round().clamp(1, 16384);
    final int height = (size.height * _devicePixelRatio).round().clamp(
      1,
      16384,
    );

    if (width == _surfaceWidth && height == _surfaceHeight) {
      await _ensureRenderTarget();
      return;
    }

    _surfaceWidth = width;
    _surfaceHeight = height;
    final int result = await widget.bridge.engineSetSurfaceSize(
      width: width,
      height: height,
    );
    if (result != 0) {
      _reportError(
        'engine_set_surface_size failed: result=$result, error=${widget.bridge.engineGetLastError()}',
      );
      return;
    }
    widget.onLog?.call(
      'surface resized: ${width}x$height (dpr=${_devicePixelRatio.toStringAsFixed(2)})',
    );
    await _ensureRenderTarget();
  }

  Future<void> _ensureRenderTarget() async {
    switch (widget.surfaceMode) {
      case EngineSurfaceMode.gpuZeroCopy:
        if (Platform.isAndroid || _isOhos) {
          // OHOS: the engine renders straight into the embedder texture's
          // OHNativeWindow (eglSwapBuffers). This used to deadlock while
          // the Dart UI isolate shared the platform thread — the raster
          // side could only drain the buffer queue once this isolate
          // yielded. EntryAbility now starts the engine with the UI thread
          // unmerged, so the raster thread consumes buffers independently
          // and the software RawImage path (glReadPixels + ~40 ms of
          // copy/decode per frame on this isolate) is no longer needed.
          await _ensureSurfaceTexture();
        } else {
          await _ensureIOSurfaceTexture();
        }
        break;
      case EngineSurfaceMode.texture:
        await _ensureTexture();
        break;
      case EngineSurfaceMode.software:
        // No texture needed
        break;
    }
  }

  // --- IOSurface zero-copy mode ---

  Future<void> _ensureIOSurfaceTexture() async {
    if (!widget.active ||
        _ioSurfaceInitInFlight ||
        _surfaceWidth <= 0 ||
        _surfaceHeight <= 0) {
      return;
    }

    // Check if we need to resize
    if (_ioSurfaceTextureId != null) {
      if (_frameWidth == _surfaceWidth && _frameHeight == _surfaceHeight) {
        return; // Already at correct size
      }
      // Resize needed
      _ioSurfaceInitInFlight = true;
      try {
        final result = await widget.bridge.resizeIOSurfaceTexture(
          textureId: _ioSurfaceTextureId!,
          width: _surfaceWidth,
          height: _surfaceHeight,
        );
        if (result != null && mounted) {
          final int newIOSurfaceId = result['ioSurfaceID'] as int;
          // Tell the engine about the new IOSurface
          final int setResult = await widget.bridge
              .engineSetRenderTargetIOSurface(
                iosurfaceId: newIOSurfaceId,
                width: _surfaceWidth,
                height: _surfaceHeight,
              );
          if (setResult == 0) {
            _ioSurfaceId = newIOSurfaceId;
            _frameWidth = _surfaceWidth;
            _frameHeight = _surfaceHeight;
            widget.onLog?.call(
              'IOSurface resized: ${_surfaceWidth}x$_surfaceHeight (iosurface=$newIOSurfaceId)',
            );
          } else {
            _reportError(
              'engine_set_render_target_iosurface failed after resize: $setResult',
            );
          }
        }
      } finally {
        _ioSurfaceInitInFlight = false;
      }
      return;
    }

    _ioSurfaceInitInFlight = true;
    try {
      final result = await widget.bridge.createIOSurfaceTexture(
        width: _surfaceWidth,
        height: _surfaceHeight,
      );

      if (!mounted || _renderTargetsReleased) {
        if (result != null) {
          await widget.bridge.disposeIOSurfaceTexture(
            textureId: result['textureId'] as int,
          );
        }
        return;
      }
      if (result == null) {
        widget.onLog?.call(
          'IOSurface texture unavailable, falling back to legacy texture mode',
        );
        // Fall back to legacy texture mode
        await _ensureTexture();
        return;
      }

      final int textureId = result['textureId'] as int;
      final int ioSurfaceId = result['ioSurfaceID'] as int;

      // Tell the C++ engine to render to this IOSurface
      final int setResult = await widget.bridge.engineSetRenderTargetIOSurface(
        iosurfaceId: ioSurfaceId,
        width: _surfaceWidth,
        height: _surfaceHeight,
      );

      if (setResult != 0) {
        _reportError(
          'engine_set_render_target_iosurface failed: $setResult, '
          'error=${widget.bridge.engineGetLastError()}',
        );
        // Clean up and fall back
        await widget.bridge.disposeIOSurfaceTexture(textureId: textureId);
        await _ensureTexture();
        return;
      }

      final ui.Image? previousImage = _frameImage;
      void publishTexture() {
        _ioSurfaceTextureId = textureId;
        _ioSurfaceId = ioSurfaceId;
        _textureId = null; // Dispose legacy texture if any
        _frameImage = null;
        _frameWidth = _surfaceWidth;
        _frameHeight = _surfaceHeight;
      }

      if (mounted) {
        setState(publishTexture);
      } else {
        // releaseRenderTargets waits for this operation and will detach it.
        publishTexture();
      }
      previousImage?.dispose();
      widget.onLog?.call(
        'IOSurface zero-copy mode enabled (textureId=$textureId, iosurface=$ioSurfaceId)',
      );
    } finally {
      _ioSurfaceInitInFlight = false;
    }
  }

  Future<void> _disposeIOSurfaceTexture() async {
    final int? textureId = _ioSurfaceTextureId;
    if (textureId == null) return;
    _ioSurfaceTextureId = null;
    _ioSurfaceId = null;
    // Detach from engine
    try {
      await widget.bridge.engineSetRenderTargetIOSurface(
        iosurfaceId: 0,
        width: 0,
        height: 0,
      );
    } catch (_) {}
    await widget.bridge.disposeIOSurfaceTexture(textureId: textureId);
  }

  // --- SurfaceTexture zero-copy mode (Android) ---

  Future<void> _ensureSurfaceTexture() async {
    if (!widget.active ||
        _surfaceTextureInitInFlight ||
        _surfaceWidth <= 0 ||
        _surfaceHeight <= 0) {
      return;
    }

    // Check if we need to resize
    if (_surfaceTextureId != null) {
      if (_frameWidth == _surfaceWidth && _frameHeight == _surfaceHeight) {
        return; // Already at correct size
      }
      // Resize needed
      _surfaceTextureInitInFlight = true;
      try {
        final result = await widget.bridge.resizeSurfaceTexture(
          textureId: _surfaceTextureId!,
          width: _surfaceWidth,
          height: _surfaceHeight,
        );
        if (result != null && mounted) {
          if (_isOhos && _nativeWindowPtr != 0) {
            // The ArkTS side only resized the buffer queue; the engine's
            // EGL window surface and draw-device size follow the same
            // OHNativeWindow, so re-attach with the new dimensions.
            await widget.bridge.engineSetRenderTargetNativeWindow(
              address: _nativeWindowPtr,
              width: _surfaceWidth,
              height: _surfaceHeight,
            );
          }
          _frameWidth = _surfaceWidth;
          _frameHeight = _surfaceHeight;
          widget.onLog?.call(
            'SurfaceTexture resized: ${_surfaceWidth}x$_surfaceHeight',
          );
        }
      } finally {
        _surfaceTextureInitInFlight = false;
      }
      return;
    }

    _surfaceTextureInitInFlight = true;
    try {
      final result = await widget.bridge.createSurfaceTexture(
        width: _surfaceWidth,
        height: _surfaceHeight,
      );

      if (!mounted || _renderTargetsReleased) {
        if (result != null) {
          await widget.bridge.disposeSurfaceTexture(
            textureId: result['textureId'] as int,
          );
        }
        return;
      }
      if (result == null) {
        widget.onLog?.call(
          'SurfaceTexture unavailable, falling back to legacy texture mode',
        );
        await _ensureTexture();
        return;
      }

      final int textureId = result['textureId'] as int;

      if (_isOhos) {
        // The ArkTS plugin returns the OHNativeWindow* (as a string) behind
        // its SurfaceTextureEntry; attach it through FFI, the OHOS analogue
        // of the Android JNI nativeSetSurface call.
        final String windowPtrStr = result['nativeWindowPtr'] as String? ?? '';
        final int windowPtr = int.tryParse(windowPtrStr) ?? 0;
        if (windowPtr == 0) {
          widget.onLog?.call(
            'SurfaceTexture missing nativeWindowPtr, falling back to legacy texture mode',
          );
          await widget.bridge.disposeSurfaceTexture(textureId: textureId);
          await _ensureTexture();
          return;
        }
        final int setResult = await widget.bridge
            .engineSetRenderTargetNativeWindow(
              address: windowPtr,
              width: _surfaceWidth,
              height: _surfaceHeight,
            );
        if (setResult != 0) {
          _reportError(
            'engine_set_render_target_surface failed: $setResult, '
            'error=${widget.bridge.engineGetLastError()}',
          );
          await widget.bridge.engineSetRenderTargetNativeWindow(
            address: 0,
            width: 0,
            height: 0,
          );
          await widget.bridge.disposeSurfaceTexture(textureId: textureId);
          await _ensureTexture();
          return;
        }
        _nativeWindowPtr = windowPtr;
      }

      // The SurfaceTexture/Surface is already passed to C++ via JNI
      // in the Kotlin plugin's createSurfaceTexture method.
      // The C++ engine_tick() will auto-detect the pending ANativeWindow
      // and attach it as the EGL WindowSurface render target.

      final ui.Image? previousImage = _frameImage;
      void publishTexture() {
        _surfaceTextureId = textureId;
        _textureId = null; // Dispose legacy texture if any
        _frameImage = null;
        _frameWidth = _surfaceWidth;
        _frameHeight = _surfaceHeight;
      }

      if (mounted) {
        setState(publishTexture);
      } else {
        publishTexture();
      }
      previousImage?.dispose();
      widget.onLog?.call(
        'SurfaceTexture zero-copy mode enabled (textureId=$textureId)',
      );
    } finally {
      _surfaceTextureInitInFlight = false;
    }
  }

  Future<void> _disposeSurfaceTexture() async {
    final int? textureId = _surfaceTextureId;
    if (textureId == null) return;
    _surfaceTextureId = null;
    if (_isOhos && _nativeWindowPtr != 0) {
      // Detach the OHNativeWindow from the engine before the embedder
      // releases it, mirroring the Android JNI detach in disposeSurfaceTexture.
      try {
        await widget.bridge.engineSetRenderTargetNativeWindow(
          address: 0,
          width: 0,
          height: 0,
        );
      } catch (_) {}
      _nativeWindowPtr = 0;
    }
    await widget.bridge.disposeSurfaceTexture(textureId: textureId);
  }

  // --- Legacy texture mode ---

  Future<void> _ensureTexture() async {
    if (!widget.active || _textureInitInFlight || _textureId != null) {
      return;
    }

    _textureInitInFlight = true;
    try {
      final int? textureId = await widget.bridge.createTexture(
        width: _surfaceWidth > 0 ? _surfaceWidth : 1,
        height: _surfaceHeight > 0 ? _surfaceHeight : 1,
      );

      if (!mounted) {
        if (textureId != null) {
          await widget.bridge.disposeTexture(textureId: textureId);
        }
        return;
      }
      if (textureId == null) {
        widget.onLog?.call('texture unavailable, fallback to software mode');
        return;
      }

      final ui.Image? previousImage = _frameImage;
      setState(() {
        _textureId = textureId;
        _frameImage = null;
      });
      previousImage?.dispose();
      widget.onLog?.call('texture mode enabled (id=$textureId)');
    } finally {
      _textureInitInFlight = false;
    }
  }

  Future<void> _disposeTexture() async {
    final int? textureId = _textureId;
    if (textureId == null) {
      return;
    }
    _textureId = null;
    await widget.bridge.disposeTexture(textureId: textureId);
  }

  // --- Frame polling ---

  /// Software RawImage-path perf counters live on [_EngineSurfacePerf]
  /// so [EngineSurfacePerf.take] actually sees what [_pollFrame] records.

  Future<void> _pollFrame({bool? externalRendered}) async {
    if (!widget.active || _frameInFlight) {
      return;
    }

    _frameInFlight = true;
    try {
      // IOSurface/SurfaceTexture zero-copy mode: just notify Flutter, no pixel transfer
      if (_ioSurfaceTextureId != null || _surfaceTextureId != null) {
        // When the caller already checked the flag (external tick-driven
        // mode), use that value directly to avoid the double-read problem.
        // engineGetFrameRenderedFlag resets the flag on read, so a second
        // read would always return false.
        final bool rendered =
            externalRendered ??
            await widget.bridge.engineGetFrameRenderedFlag();
        if (rendered && mounted) {
          final int activeZeroCopyTextureId =
              _ioSurfaceTextureId ?? _surfaceTextureId!;
          await widget.bridge.notifyFrameAvailable(
            textureId: activeZeroCopyTextureId,
          );
        }
        return;
      }

      // Do not start a software readback while a zero-copy texture is being
      // created. More importantly, a readback that started just before the
      // async texture creation must never publish its native 1280x720 frame
      // size after the texture has switched to a portrait window buffer.
      // Doing so makes _buildTextureView contain-fit the already-letterboxed
      // portrait buffer into a second 16:9 box, visibly crushing the game to
      // a thin horizontal strip.
      if (_ioSurfaceInitInFlight || _surfaceTextureInitInFlight) {
        return;
      }

      // Legacy path: read pixels
      final Stopwatch readSw = Stopwatch()..start();
      final EngineFrameData? frameData = await widget.bridge.engineReadFrame();
      readSw.stop();
      _EngineSurfacePerf.readCalls += 1;
      _EngineSurfacePerf.readUs += readSw.elapsedMicroseconds;
      if (frameData == null) {
        return;
      }
      if (_ioSurfaceTextureId != null || _surfaceTextureId != null) {
        return;
      }
      final EngineFrameInfo frameInfo = frameData.info;
      final Uint8List rgbaData = frameData.pixels;

      if (frameInfo.width <= 0 || frameInfo.height <= 0) {
        return;
      }
      if (frameInfo.frameSerial == _lastFrameSerial) {
        return;
      }

      final int expectedMinLength = frameInfo.strideBytes * frameInfo.height;
      if (expectedMinLength <= 0 || rgbaData.length < expectedMinLength) {
        _reportError(
          'engine_read_frame_rgba returned insufficient data: '
          'len=${rgbaData.length}, required=$expectedMinLength',
        );
        return;
      }

      final int? textureId = _textureId;
      if (textureId != null) {
        final bool updated = await widget.bridge.updateTextureRgba(
          textureId: textureId,
          rgba: rgbaData,
          width: frameInfo.width,
          height: frameInfo.height,
          rowBytes: frameInfo.strideBytes,
        );
        if (!updated) {
          _reportError(
            'updateTextureRgba failed, fallback to software mode: '
            '${widget.bridge.engineGetLastError()}',
          );
          await _disposeTexture();
        } else if (mounted) {
          setState(() {
            _frameWidth = frameInfo.width;
            _frameHeight = frameInfo.height;
            _lastFrameSerial = frameInfo.frameSerial;
          });
          return;
        }
      }

      final Stopwatch decodeSw = Stopwatch()..start();
      final ui.Image nextImage = await _decodeRgbaFrame(
        rgbaData,
        width: frameInfo.width,
        height: frameInfo.height,
        rowBytes: frameInfo.strideBytes,
      );
      decodeSw.stop();
      _EngineSurfacePerf.decodeCalls += 1;
      _EngineSurfacePerf.decodeUs += decodeSw.elapsedMicroseconds;

      if (!mounted) {
        nextImage.dispose();
        return;
      }
      if (_ioSurfaceTextureId != null || _surfaceTextureId != null) {
        nextImage.dispose();
        return;
      }

      final ui.Image? previousImage = _frameImage;
      setState(() {
        _frameImage = nextImage;
        _frameWidth = frameInfo.width;
        _frameHeight = frameInfo.height;
        _lastFrameSerial = frameInfo.frameSerial;
      });
      previousImage?.dispose();
    } catch (error) {
      _reportError('surface poll failed: $error');
    } finally {
      _frameInFlight = false;
    }
  }

  Future<ui.Image> _decodeRgbaFrame(
    Uint8List pixels, {
    required int width,
    required int height,
    required int rowBytes,
  }) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, width, height, ui.PixelFormat.rgba8888, (
      ui.Image image,
    ) {
      completer.complete(image);
    }, rowBytes: rowBytes);
    return completer.future;
  }

  void _reportError(String message) {
    widget.onError?.call(message);
  }

  Widget _buildTextureView(int textureId) {
    // Use physical pixel dimensions, but convert to logical pixels for layout.
    // The Texture widget renders at full physical resolution regardless of
    // the SizedBox logical size, so this only affects aspect ratio calculation.
    final double dpr = _devicePixelRatio > 0 ? _devicePixelRatio : 1.0;
    // Zero-copy textures contain the complete render-target buffer, including
    // the engine's own letterbox bars. Their layout aspect must therefore be
    // the buffer aspect, never a late software frame's native game aspect.
    final bool isZeroCopyTexture =
        textureId == _ioSurfaceTextureId || textureId == _surfaceTextureId;
    final int physW = isZeroCopyTexture && _surfaceWidth > 0
        ? _surfaceWidth
        : (_frameWidth > 0
              ? _frameWidth
              : (_surfaceWidth > 0 ? _surfaceWidth : 1));
    final int physH = isZeroCopyTexture && _surfaceHeight > 0
        ? _surfaceHeight
        : (_frameHeight > 0
              ? _frameHeight
              : (_surfaceHeight > 0 ? _surfaceHeight : 1));
    final double logicalW = physW / dpr;
    final double logicalH = physH / dpr;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: logicalW,
        height: logicalH,
        child: Texture(textureId: textureId, filterQuality: FilterQuality.none),
      ),
    );
  }

  /// Convert Flutter's button bitmask to engine button index.
  /// Flutter: kPrimaryButton=1, kSecondaryButton=2, kMiddleMouseButton=4
  /// Engine:  0=left, 1=right, 2=middle
  static int _flutterButtonsToEngineButton(int buttons) {
    if (buttons & kSecondaryButton != 0) return 1; // right
    if (buttons & kMiddleMouseButton != 0) return 2; // middle
    return 0; // left (default)
  }

  EngineInputEventData _buildPointerEventData({
    required int type,
    required PointerEvent event,
    double? deltaX,
    double? deltaY,
  }) {
    return _mapPointerEventData(EngineInputEventData(
      type: type,
      timestampMicros: event.timeStamp.inMicroseconds,
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      deltaX: deltaX ?? event.delta.dx,
      deltaY: deltaY ?? event.delta.dy,
      pointerId: event.pointer,
      button: _flutterButtonsToEngineButton(event.buttons),
    ));
  }

  /// Synthetic controls use the same logical viewport and letterbox mapping
  /// as direct input. Keyboard codes are already native virtual key codes.
  Future<void> sendVirtualInput(EngineInputEventData event) async {
    if (!widget.active || _renderTargetsReleased) return;
    await _sendInputEvent(event.type <= EngineInputEventType.pointerScroll
        ? _mapPointerEventData(event) : event);
  }

  EngineInputEventData _mapPointerEventData(EngineInputEventData event) {
    // Map pointer position from Listener's logical coordinate space
    // to the engine surface's physical pixel coordinates.
    //
    // Listener's localPosition is in logical pixels. The engine's
    // EGL surface is sized in physical pixels (logical * dpr), so
    // multiply by dpr to get surface coordinates.
    //
    // The C++ side (DrawDevice::TransformToPrimaryLayerManager)
    // then maps these surface coordinates → primary layer coordinates.
    final double dpr = _devicePixelRatio > 0 ? _devicePixelRatio : 1.0;
    double x = event.x * dpr;
    double y = event.y * dpr;
    double dX = event.deltaX * dpr;
    double dY = event.deltaY * dpr;

    // Software RawImage path: the displayed image is letterboxed inside the
    // widget (RawImage fit: BoxFit.contain) while the engine keeps its frame
    // at the game's native pixel size (e.g. 1280x720). Surface coordinates
    // (= widget physical size) therefore do not match frame coordinates on
    // screens with a different aspect (portrait phone showing a landscape
    // game): a tap at widget-y 1428 lands far outside the 720-tall layer
    // tree and every layer hit-test misses. Apply the same contain-fit
    // math the display uses: widget px → centered frame px.
    if (_mapsPointerToFramePixels) {
      final double widgetPhysW = _lastWidgetLogicalSize.width * dpr;
      final double widgetPhysH = _lastWidgetLogicalSize.height * dpr;
      if (widgetPhysW > 0 && widgetPhysH > 0) {
        final double scale = math.min(
          widgetPhysW / _frameWidth,
          widgetPhysH / _frameHeight,
        );
        final double offX = (widgetPhysW - _frameWidth * scale) / 2;
        final double offY = (widgetPhysH - _frameHeight * scale) / 2;
        x = (x - offX) / scale;
        y = (y - offY) / scale;
        dX /= scale;
        dY /= scale;
        // Clamp taps in the letterbox bars to the frame edges so they still
        // reach the engine (the engine ignores clicks that hit no layer).
        x = x.clamp(0.0, _frameWidth - 1.0);
        y = y.clamp(0.0, _frameHeight - 1.0);
      }
    }

    return EngineInputEventData(
      type: event.type,
      timestampMicros: event.timestampMicros,
      x: x,
      y: y,
      deltaX: dX,
      deltaY: dY,
      pointerId: event.pointerId,
      button: event.button,
      modifiers: event.modifiers,
    );
  }

  /// True when frames are shown via RawImage (software readback) and pointer
  /// positions must be mapped from widget coordinates to native frame pixels.
  bool get _mapsPointerToFramePixels =>
      _ioSurfaceTextureId == null &&
      _surfaceTextureId == null &&
      _textureId == null &&
      _frameWidth > 0 &&
      _frameHeight > 0;

  void _sendPointer({
    required int type,
    required PointerEvent event,
    double? deltaX,
    double? deltaY,
  }) {
    if (!widget.active) {
      return;
    }
    widget.onPointerPosition?.call(event.localPosition);
    unawaited(
      _sendInputEvent(
        _buildPointerEventData(
          type: type,
          event: event,
          deltaX: deltaX,
          deltaY: deltaY,
        ),
      ),
    );
  }

  void _sendCoalescedPointerMove(PointerEvent event) {
    if (!widget.active) {
      return;
    }
    widget.onPointerPosition?.call(event.localPosition);
    _pendingPointerMoveEvent = _buildPointerEventData(
      type: EngineInputEventType.pointerMove,
      event: event,
    );
    if (_pointerMoveFlushScheduled) {
      return;
    }
    _pointerMoveFlushScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _pointerMoveFlushScheduled = false;
      if (!mounted || !widget.active) {
        _pendingPointerMoveEvent = null;
        return;
      }
      final EngineInputEventData? pending = _pendingPointerMoveEvent;
      _pendingPointerMoveEvent = null;
      if (pending != null) {
        unawaited(_sendInputEvent(pending));
      }
    });
  }

  void _ensureSurfaceSizeIfNeeded(Size size, double devicePixelRatio) {
    if (!widget.active || !size.isFinite) {
      return;
    }
    final double normalizedDpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
    if ((_lastRequestedLogicalSize.width - size.width).abs() < 0.01 &&
        (_lastRequestedLogicalSize.height - size.height).abs() < 0.01 &&
        (_lastRequestedDpr - normalizedDpr).abs() < 0.001) {
      return;
    }
    _lastRequestedLogicalSize = size;
    _lastRequestedDpr = normalizedDpr;
    unawaited(_ensureSurfaceSize(size, normalizedDpr));
  }

  Future<void> _sendInputEvent(EngineInputEventData event) async {
    final int result = await widget.bridge.engineSendInput(event);
    if (result != 0) {
      _reportError(
        'engine_send_input failed: result=$result, error=${widget.bridge.engineGetLastError()}',
      );
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.active) {
      return KeyEventResult.ignored;
    }

    final bool isDown = event is KeyDownEvent;
    final bool isUp = event is KeyUpEvent;
    if (!isDown && !isUp) {
      return KeyEventResult.ignored;
    }

    final int type = isDown
        ? EngineInputEventType.keyDown
        : EngineInputEventType.keyUp;
    final int keyCode = event.logicalKey.keyId & 0xFFFFFFFF;
    unawaited(
      _sendInputEvent(
        EngineInputEventData(
          type: type,
          timestampMicros: event.timeStamp.inMicroseconds,
          keyCode: keyCode,
        ),
      ),
    );

    if (isDown &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack)) {
      unawaited(
        _sendInputEvent(
          EngineInputEventData(
            type: EngineInputEventType.back,
            timestampMicros: event.timeStamp.inMicroseconds,
            keyCode: keyCode,
          ),
        ),
      );
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final int? activeTextureId =
        _ioSurfaceTextureId ?? _surfaceTextureId ?? _textureId;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final double dpr = MediaQuery.of(context).devicePixelRatio;
        _lastWidgetLogicalSize = size;
        _ensureSurfaceSizeIfNeeded(size, dpr);

        return Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              _focusNode.requestFocus();
              _sendPointer(
                type: EngineInputEventType.pointerDown,
                event: event,
              );
            },
            onPointerMove: (event) {
              _sendCoalescedPointerMove(event);
            },
            onPointerUp: (event) {
              _sendPointer(type: EngineInputEventType.pointerUp, event: event);
            },
            onPointerHover: (event) {
              _sendCoalescedPointerMove(event);
            },
            onPointerSignal: (PointerSignalEvent signal) {
              if (signal is PointerScrollEvent) {
                _sendPointer(
                  type: EngineInputEventType.pointerScroll,
                  event: signal,
                  deltaX: signal.scrollDelta.dx,
                  deltaY: signal.scrollDelta.dy,
                );
              }
            },
            child: Container(
              // Game frames need a stable black matte regardless of app theme.
              color: context.uiColors.overlay.withValues(alpha: 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (activeTextureId != null)
                    _buildTextureView(activeTextureId)
                  else if (_frameImage == null)
                    const SizedBox.shrink()
                  else
                    RawImage(
                      image: _frameImage,
                      fit: BoxFit.contain,
                      // Native stage is typically 1280×720; nearest-neighbor
                      // upscale onto a 2K+ panel looks like a low-res blit.
                      filterQuality: FilterQuality.medium,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Snapshot accessor for the software RawImage-path perf counters
/// accumulated inside the engine surface state (see _pollFrame).
class EngineSurfacePerf {
  /// Returns a one-line summary of (and resets) the counters:
  /// `read=<calls>x/<ms> decode=<calls>x/<ms>`.
  static String take() {
    final int readCalls = _EngineSurfacePerf.readCalls;
    final int readUs = _EngineSurfacePerf.readUs;
    final int decodeCalls = _EngineSurfacePerf.decodeCalls;
    final int decodeUs = _EngineSurfacePerf.decodeUs;
    _EngineSurfacePerf.readCalls = 0;
    _EngineSurfacePerf.readUs = 0;
    _EngineSurfacePerf.decodeCalls = 0;
    _EngineSurfacePerf.decodeUs = 0;
    return 'read=${readCalls}x/${(readUs / 1000).toStringAsFixed(1)}ms '
        'decode=${decodeCalls}x/${(decodeUs / 1000).toStringAsFixed(1)}ms';
  }
}

class _EngineSurfacePerf {
  static int readCalls = 0;
  static int readUs = 0;
  static int decodeCalls = 0;
  static int decodeUs = 0;
}
