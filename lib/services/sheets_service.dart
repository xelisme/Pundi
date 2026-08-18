import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class SheetsService extends ChangeNotifier {
  final AuthService _authService;
  sheets.SheetsApi? _sheetsApi;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastSyncError;
  bool _unsyncedFlag = false;

  static const String _spreadsheetName = 'BudgetAI';
  static const String _sheetName = 'BudgetData';
  static const String _cellRange = '$_sheetName!A1';
  static const String _keySpreadsheetId = 'sheets_spreadsheet_id';
  static const String _keyUnsynced = 'sync_unsynced_flag';
  static const String _keyLastSync = 'sync_last_sync_time';

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastSyncError => _lastSyncError;
  bool get hasUnsyncedChanges => _unsyncedFlag;

  SheetsService(this._authService) {
    _loadUnsyncedFlag();
  }

  void _loadUnsyncedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    _unsyncedFlag = prefs.getBool(_keyUnsynced) ?? false;
  }

  Future<bool> _initSheetsApi() async {
    try {
      final client = _authService.authenticatedClient;
      if (client == null) {
        _lastSyncError = 'No authenticated client available - missing OAuth token';
        debugPrint('Sheets: _initSheetsApi failed: $_lastSyncError');
        notifyListeners();
        return false;
      }

      _sheetsApi = sheets.SheetsApi(client);
      return true;
    } catch (e) {
      _lastSyncError = 'Failed to initialize Sheets API: $e';
      debugPrint('Sheets: _initSheetsApi failed: $_lastSyncError');
      _sheetsApi = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _ensureSheetsApi() async {
    if (_sheetsApi != null) return true;
    return await _initSheetsApi();
  }

  Future<String?> _findOrCreateSpreadsheet() async {
    if (!await _ensureSheetsApi()) return null;

    try {
      // Check if we already have a stored spreadsheet ID
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString(_keySpreadsheetId);

      if (storedId != null) {
        // Verify the spreadsheet still exists and is accessible
        try {
          await _sheetsApi!.spreadsheets.get(storedId);
          return storedId;
        } catch (e) {
          debugPrint('Sheets: stored spreadsheet not found, creating new...');
        }
      }

      // Create new spreadsheet
      final spreadsheet = sheets.Spreadsheet()
        ..properties = (sheets.SpreadsheetProperties()
          ..title = _spreadsheetName)
        ..sheets = [
          sheets.Sheet()
            ..properties = (sheets.SheetProperties()
              ..title = _sheetName),
        ];

      final created = await _sheetsApi!.spreadsheets.create(spreadsheet);
      final spreadsheetId = created.spreadsheetId!;

      // Store the ID
      await prefs.setString(_keySpreadsheetId, spreadsheetId);

      debugPrint('Sheets: created spreadsheet "$_spreadsheetName" ($spreadsheetId)');
      return spreadsheetId;
    } catch (e) {
      debugPrint('Sheets: _findOrCreateSpreadsheet failed: $e');
      _lastSyncError = 'Failed to find/create spreadsheet: $e';
      notifyListeners();
      return null;
    }
  }

  Future<String?> uploadData(Map<String, dynamic> data) async {
    if (!await _ensureSheetsApi()) return null;

    try {
      final spreadsheetId = await _findOrCreateSpreadsheet();
      if (spreadsheetId == null) return null;

      final jsonContent = jsonEncode(data);

      // Write JSON data to the first cell
      final valueRange = sheets.ValueRange()
        ..values = [
          [jsonContent],
        ];

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        _cellRange,
        valueInputOption: 'RAW',
      );

      return spreadsheetId;
    } catch (e) {
      debugPrint('Sheets: uploadData failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> downloadData() async {
    if (!await _ensureSheetsApi()) return null;

    try {
      final spreadsheetId = await _findOrCreateSpreadsheet();
      if (spreadsheetId == null) return null;

      final response = await _sheetsApi!.spreadsheets.values.get(
        spreadsheetId,
        _cellRange,
      );

      if (response.values == null || response.values!.isEmpty) {
        return null;
      }

      final firstRow = response.values!.first;
      if (firstRow.isEmpty) return null;

      final jsonStr = firstRow.first?.toString();
      if (jsonStr == null || jsonStr.isEmpty) return null;

      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Sheets: downloadData failed: $e');
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
        debugPrint('Sheets: sync attempt ${i + 1} failed: $e');
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

  Future<void> clearSpreadsheetId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySpreadsheetId);
  }
}
