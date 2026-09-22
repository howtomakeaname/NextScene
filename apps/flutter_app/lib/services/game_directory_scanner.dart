import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/game_engine.dart';
import 'local_file_service.dart';

/// Provider-aware discovery shared by library registration and launch checks.
class GameDirectoryScanner {
  GameDirectoryScanner(this.io);
  final ManagerFileSystem io;

  Future<bool> hasStartup(String path) async =>
      await io.exists(p.join(path, 'startup.tjs')) ||
      await io.exists(p.join(path, 'Startup.tjs')) ||
      await io.exists(p.join(path, 'data/system/initialize.tjs')) ||
      await io.exists(p.join(path, 'data/system/Initialize.tjs'));

  Future<String> launchPath(String path) async {
    if (await io.type(path) != FileSystemEntityType.directory ||
        await hasStartup(path)) {
      return path;
    }
    final packs = (await io.list(path))
        .where((e) => !e.isDirectory && e.name.toLowerCase().endsWith('.xp3'))
        .toList();
    if (packs.isEmpty) return path;
    packs.sort((a, b) => a.name.compareTo(b.name));
    return packs
        .firstWhere(
          (e) => e.name.toLowerCase() == 'data.xp3',
          orElse: () => packs.first,
        )
        .path;
  }

  Future<Map<String, GameEngine>> scan(String root) async {
    final found = <String, GameEngine>{};
    Future<void> walk(String path, int depth) async {
      final children = await io.list(path);
      final files = children.where((e) => !e.isDirectory).toList();
      if (path != root) {
        if (files.any((e) => GameEngine.isPfsPack(e.path))) {
          found[path] = GameEngine.artemis;
          return;
        }
        if (files.any((e) => e.name.toLowerCase().endsWith('.xp3')) ||
            await hasStartup(path)) {
          found[path] = GameEngine.krkr2;
          return;
        }
      }
      for (final entry in children) {
        if (LocalFileService.isPrivatePath(entry.path)) continue;
        if (entry.isDirectory) {
          if (depth < 3) await walk(entry.path, depth + 1);
        } else if (entry.name.toLowerCase().endsWith('.xp3')) {
          found[entry.path] = GameEngine.krkr2;
        } else if (GameEngine.isPfsPack(entry.path)) {
          found[entry.path] = GameEngine.artemis;
        }
      }
    }

    await walk(root, 0);
    return found;
  }
}
