import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../services/manager_file_kind.dart';
import '../services/manager_file_system.dart';
import '../services/android_document_file_system.dart';
import '../ui/ui.dart';

/// Full-screen preview for a managed image, audio, video or text file.
class ManagerMediaPage extends StatelessWidget {
  const ManagerMediaPage({
    super.key,
    required this.path,
    required this.kind,
    this.fileSystem,
  });

  final String path;
  final ManagerFileKind kind;
  final ManagerFileSystem? fileSystem;

  static Future<void> open(
    BuildContext context, {
    required String path,
    required ManagerFileKind kind,
    ManagerFileSystem? fileSystem,
  }) async {
    if (kind == ManagerFileKind.image && !path.toLowerCase().endsWith('.svg')) {
      final ImageProvider image;
      if (fileSystem is AndroidDocumentFileSystem) {
        image = MemoryImage(await fileSystem.readBytes(path));
        if (!context.mounted) return;
      } else {
        image = FileImage(File(path));
      }
      return UiImageViewer.show(context, images: [image]);
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ManagerMediaPage(path: path, kind: kind, fileSystem: fileSystem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.uiColors.background,
      appBar: AppBar(
        title: Text(p.basename(path)),
        backgroundColor: context.uiColors.background,
        automaticallyImplyLeading: false,
        leading: UiBarIconButton(
          icon: LucideIcons.arrowLeft,
          semanticLabel: l10n.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: switch (kind) {
        ManagerFileKind.image => _ImagePreview(
          path: path,
          io: fileSystem ?? LocalManagerFileSystem(),
        ),
        ManagerFileKind.text => _TextPreview(
          path: path,
          io: fileSystem ?? LocalManagerFileSystem(),
        ),
        _ => _AvPreview(
          path: path,
          kind: kind,
          io: fileSystem ?? LocalManagerFileSystem(),
        ),
      },
    );
  }
}

class _ImagePreview extends StatefulWidget {
  const _ImagePreview({required this.path, required this.io});
  final String path;
  final ManagerFileSystem io;
  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  late final Future<Uint8List> _load = widget.io.readBytes(widget.path);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _MediaError(
          message: AppLocalizations.of(context)!.managerMediaFailed,
        );
      }
      final data = snapshot.data;
      if (data == null) return const Center(child: UiLoader());
      final image = widget.path.toLowerCase().endsWith('.svg')
          ? SvgPicture.memory(data, fit: BoxFit.contain)
          : Image.memory(data, fit: BoxFit.contain);
      return Center(
        child: InteractiveViewer(minScale: 0.5, maxScale: 8, child: image),
      );
    },
  );
}

class _TextPreview extends StatefulWidget {
  const _TextPreview({required this.path, required this.io});
  final ManagerFileSystem io;

  final String path;

  @override
  State<_TextPreview> createState() => _TextPreviewState();
}

class _TextPreviewState extends State<_TextPreview> {
  late final Future<ManagerTextPreview> _load = widget.io
      .readBytes(widget.path, limit: managerTextPreviewLimit + 1)
      .then(decodeManagedText);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<ManagerTextPreview>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MediaError(message: l10n.managerMediaFailed);
        }
        final preview = snapshot.data;
        if (preview == null) {
          return const Center(child: UiLoader());
        }
        if (preview.text.isEmpty) {
          return Center(
            child: Text(
              l10n.managerTextEmpty,
              style: context.uiType.body.copyWith(
                color: context.uiColors.textSecondary,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (preview.truncated)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.managerTextTruncated,
                  style: context.uiType.caption.copyWith(
                    color: context.uiColors.textSecondary,
                  ),
                ),
              ),
            SelectableText(
              preview.text,
              style: context.uiType.body.copyWith(height: 1.45),
            ),
          ],
        );
      },
    );
  }
}

class _AvPreview extends StatefulWidget {
  const _AvPreview({required this.path, required this.kind, required this.io});
  final ManagerFileSystem io;

  final String path;
  final ManagerFileKind kind;

  @override
  State<_AvPreview> createState() => _AvPreviewState();
}

class _AvPreviewState extends State<_AvPreview> {
  VideoPlayerController? _player;
  var _seeking = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  bool _loadFailed = false;
  Future<void> _initialize() async {
    try {
      final io = widget.io;
      final player = io is AndroidDocumentFileSystem
          ? VideoPlayerController.contentUri(await io.documentUri(widget.path))
          : VideoPlayerController.file(File(widget.path));
      if (!mounted) {
        await player.dispose();
        return;
      }
      _player = player;
      player.addListener(_onTick);
      await player.initialize();
      if (!mounted) return;
      setState(() {});
      await player.play();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _player
      ?..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _onTick() {
    if (!_seeking && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final player = _player;
    if (_loadFailed) return _MediaError(message: l10n.managerMediaFailed);
    if (player == null) {
      return const Center(child: UiLoader());
    }
    final error = player.value.errorDescription;
    if (error != null) {
      return _MediaError(message: l10n.managerMediaFailed);
    }
    if (!player.value.isInitialized) {
      return const Center(child: UiLoader());
    }

    final colors = context.uiColors;
    final duration = player.value.duration;
    final position = player.value.position;
    final totalMs = duration.inMilliseconds;
    final audioOnly =
        widget.kind == ManagerFileKind.audio ||
        player.value.size.isEmpty ||
        player.value.size.longestSide < 2;

    return Column(
      children: [
        Expanded(
          child: audioOnly
              ? Center(
                  child: Icon(
                    CupertinoIcons.music_note_2,
                    size: 88,
                    color: colors.brand,
                  ),
                )
              : Center(
                  child: AspectRatio(
                    aspectRatio: player.value.aspectRatio == 0
                        ? 16 / 9
                        : player.value.aspectRatio,
                    child: VideoPlayer(player),
                  ),
                ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              UiSlider(
                value: totalMs <= 0
                    ? 0
                    : position.inMilliseconds.clamp(0, totalMs).toDouble(),
                max: totalMs <= 0 ? 1 : totalMs.toDouble(),
                onChanged: (value) {
                  _seeking = true;
                  player.seekTo(Duration(milliseconds: value.round()));
                },
                onChangeEnd: (_) => _seeking = false,
              ),
              Row(
                children: [
                  Text(
                    _clock(position),
                    style: context.uiType.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  UiBarIconButton(
                    icon: player.value.isPlaying
                        ? LucideIcons.pause
                        : LucideIcons.play,
                    semanticLabel: player.value.isPlaying
                        ? l10n.managerPause
                        : l10n.managerPlay,
                    onPressed: () {
                      if (player.value.isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                  ),
                  const Spacer(),
                  Text(
                    _clock(duration),
                    style: context.uiType.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _clock(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(UiSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.uiType.body.copyWith(
            color: context.uiColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
