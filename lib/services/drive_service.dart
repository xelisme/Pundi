import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class DriveService extends ChangeNotifier {
  final AuthService _authService;
  drive.DriveApi? _driveApi;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastSyncError;
  bool _unsyncedFlag = false;

  static const String _folderName = 'BudgetAI';
  static const String _fileName = 'data.json';
  static const String _keyUnsynced = 'sync_unsynced_flag';
  static const String _keyLastSync = 'sync_last_sync_time';

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncError => _lastSyncError;
  bool get hasUnsyncedChanges => _unsyncedFlag;

  DriveService(this._authService) {
    _loadUnsyncedFlag();
  }

  void _loadUnsyncedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    _unsyncedFlag = prefs.getBool(_keyUnsynced) ?? false;
  }

  Future<bool> _initDriveApi() async {
    try {
      final client = await _authService.authenticatedClient;
      if (client == null) return false;

      _driveApi = drive.DriveApi(client);
      return true;
    } catch (e) {
      debugPrint('Drive: _initDriveApi failed: $e');
      _driveApi = null;
      return false;
    }
  }

  Future<bool> _ensureDriveApi() async {
    if (_driveApi != null) return true;
    return await _initDriveApi();
  }

  Future<String?> _findOrCreateFolder() async {
    if (!await _ensureDriveApi()) return null;

    try {
      final result = await _driveApi!.files.list(
        q: "name = '$_folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
        $fields: 'files(id)',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first.id;
      }

      final folder = drive.File();
      folder.name = _folderName;
      folder.mimeType = 'application/vnd.google-apps.folder';
      final created = await _driveApi!.files.create(folder);
      return created.id;
    } catch (e) {
      debugPrint('Drive: _findOrCreateFolder failed: $e');
      return null;
    }
  }

  Future<String?> _findFile(String folderId) async {
    if (!await _ensureDriveApi()) return null;

    try {
      final result = await _driveApi!.files.list(
        q: "'$folderId' in parents and name = '$_fileName' and trashed = false",
        $fields: 'files(id)',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Drive: _findFile failed: $e');
      return null;
    }
  }

  Future<String?> uploadData(Map<String, dynamic> data) async {
    if (!await _ensureDriveApi()) return null;

    try {
      final folderId = await _findOrCreateFolder();
      if (folderId == null) return null;

      final existingFileId = await _findFile(folderId);
      final jsonContent = jsonEncode(data);
      final media = drive.Media(
        Stream.value(utf8.encode(jsonContent)),
        jsonContent.length,
      );

      if (existingFileId != null) {
        await _driveApi!.files.update(
          drive.File(),
          existingFileId,
          uploadMedia: media,
        );
        return existingFileId;
      } else {
        final file = drive.File();
        file.name = _fileName;
        file.mimeType = 'application/json';
        file.parents = [folderId];
        final created = await _driveApi!.files.create(
          file,
          uploadMedia: media,
        );
        return created.id;
      }
    } catch (e) {
      debugPrint('Drive: uploadData failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> downloadData() async {
    if (!await _ensureDriveApi()) return null;

    try {
      final folderId = await _findOrCreateFolder();
      if (folderId == null) return null;

      final fileId = await _findFile(folderId);
      if (fileId == null) return null;

      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = await media.stream.first;
      final jsonStr = utf8.decode(bytes);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Drive: downloadData failed: $e');
      return null;
    }
  }

  Future<bool> syncWithRetry(Map<String, dynamic> localData) async {
    const maxRetries = 3;
    var delay = 1;

    for (var i = 0; i < maxRetries; i++) {
      try {
        final success = await _performSync(localData);
        if (success) return true;

        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: delay));
          delay *= 2;
        }
      } catch (e) {
        debugPrint('Drive: sync attempt ${i + 1} failed: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: delay));
          delay *= 2;
        }
      }
    }

    _lastSyncError = 'Sync gagal setelah $maxRetries percobaan';
    notifyListeners();
    return false;
  }

  Future<bool> _performSync(Map<String, dynamic> localData) async {
    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      final remoteData = await downloadData();

      if (remoteData == null) {
        await uploadData(localData);
      } else {
        final merged = _mergeData(localData, remoteData);
        await uploadData(merged);
      }

      _lastSyncTime = DateTime.now();
      _isSyncing = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSync, _lastSyncTime!.toIso8601String());
      await prefs.setBool(_keyUnsynced, false);
      _unsyncedFlag = false;

      notifyListeners();
      return true;
    } catch (e) {
      _isSyncing = false;
      _lastSyncError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic> _mergeData(
      Map<String, dynamic> local, Map<String, dynamic> remote) {
    final localTimestamp = local['timestamp'] as int? ?? 0;
    final remoteTimestamp = remote['timestamp'] as int? ?? 0;

    if (localTimestamp >= remoteTimestamp) {
      return local;
    } else {
      return remote;
    }
  }

  Future<void> markUnsynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUnsynced, true);
    _unsyncedFlag = true;
    notifyListeners();
  }

  Future<void> loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastSync);
    if (str != null) {
      _lastSyncTime = DateTime.tryParse(str);
      notifyListeners();
    }
  }
}
