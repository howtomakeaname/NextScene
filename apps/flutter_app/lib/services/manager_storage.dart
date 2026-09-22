import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_operation_error.dart';
import 'manager_scope.dart';

/// Resolves and persists the `Downloads/<appId>` grant. Failed authorization
/// never falls back to the private sandbox or the whole Downloads folder.
///
/// Platform coverage in this change:
/// - HarmonyOS: `ensureManagerRoot` (DOWNLOAD picker) through the bridge.
/// - macOS / Linux / Windows: one directory pick validated by [ManagerScope];
///   `dart:io` can use the returned path directly.
/// - Android: native Downloads paths after storage permission is granted.
/// - iOS: file-provider locations still require a separate adapter.
class ManagerStorage {
  ManagerStorage({
    MethodChannel? channel,
    Future<String?> Function()? pickDirectory,
    String? platform,
  }) : _channel = channel ?? const MethodChannel('flutter_engine_bridge'),
       _pickDirectory = pickDirectory,
       _platform = platform ?? Platform.operatingSystem;

  static const _prefsKey = 'krkr2_manager_grant';
  static const _pathBackedPlatforms = {
    'ohos',
    'android',
    'macos',
    'linux',
    'windows',
  };

  final MethodChannel _channel;
  final Future<String?> Function()? _pickDirectory;
  final String _platform;

  bool get usesAndroidStoragePermission => _platform == 'android';

  String get appId => ManagerScope.expectedAppId(_platform);

  /// True when file management can run on this platform at all.
  bool get isSupported => _pathBackedPlatforms.contains(_platform);

  Future<ManagerGrant?> currentGrant() async {
    if (!isSupported) {
      throw const FileOperationException(FileErrorCode.unsupportedPlatform);
    }
    if (_platform == 'ohos' || _platform == 'android') {
      try {
        return await _ensureNativeRoot(promptIfMissing: false);
      } on FileOperationException catch (error) {
        if (error.code == FileErrorCode.permissionDenied ||
            error.code == FileErrorCode.cancelled) {
          return null;
        }
        rethrow;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final grant = ManagerGrant.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!ManagerScope.matches(grant, appId: appId, platform: _platform)) {
        await prefs.remove(_prefsKey);
        return null;
      }
      if (!await Directory(grant.rootPath).exists()) {
        await prefs.remove(_prefsKey);
        return null;
      }
      await Directory(grant.gamesPath).create(recursive: true);
      return grant;
    } catch (_) {
      await prefs.remove(_prefsKey);
      return null;
    }
  }

  Future<ManagerGrant> authorize() async {
    if (!isSupported) {
      throw const FileOperationException(FileErrorCode.unsupportedPlatform);
    }
    if (_platform == 'ohos' || _platform == 'android') {
      final grant = await _ensureNativeRoot(promptIfMissing: true);
      if (grant == null) {
        throw const FileOperationException(FileErrorCode.permissionDenied);
      }
      return grant;
    }

    final selected = await (_pickDirectory ?? _defaultPick)();
    if (selected == null || selected.isEmpty) {
      throw const FileOperationException(FileErrorCode.cancelled);
    }
    final grant = ManagerScope.grantFromSelection(
      selected,
      appId: appId,
      platform: _platform,
    );
    if (grant == null) {
      throw const FileOperationException(FileErrorCode.outsideRoot);
    }
    await Directory(grant.gamesPath).create(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(grant.toJson()));
    return grant;
  }

  Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<ManagerGrant?> _ensureNativeRoot({
    required bool promptIfMissing,
  }) async {
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>(
        'ensureManagerRoot',
        <String, dynamic>{'prompt': promptIfMissing},
      );
      final root = info?['root'] as String?;
      if (root == null || root.isEmpty) return null;
      final grant = ManagerScope.grantFromSelection(
        root,
        appId: appId,
        platform: _platform,
      );
      if (grant == null) {
        throw const FileOperationException(FileErrorCode.outsideRoot);
      }
      // Derive child paths locally so a malformed native response cannot
      // move file operations outside the validated app directory.
      return grant;
    } on PlatformException catch (error) {
      throw FileOperationException.from(error);
    } on MissingPluginException {
      throw const FileOperationException(FileErrorCode.unsupportedPlatform);
    }
  }

  Future<String?> _defaultPick() {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: ManagerScope.displayRoot(appId),
    );
  }
}
