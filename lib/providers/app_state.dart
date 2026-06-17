import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

/// Global application state managed via Provider.
class AppState extends ChangeNotifier {
  // ── Theme ──
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // ── Loan settings ──
  Map<String, dynamic> _interestRates = {};
  Map<String, dynamic> get interestRates => _interestRates;

  Map<String, dynamic> _feeRates = {};
  Map<String, dynamic> get feeRates => _feeRates;

  // ── Saved data ──
  List<Map<String, dynamic>> _savedLoans = [];
  List<Map<String, dynamic>> get savedLoans => _savedLoans;

  List<Map<String, dynamic>> _exportHistory = [];
  List<Map<String, dynamic>> get exportHistory => _exportHistory;

  // ── Document list ──
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> get documents => _documents;
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  String _sortBy = 'date'; // 'date', 'name', 'size'
  String get sortBy => _sortBy;

  // ── Loading state ──
  bool _initialized = false;
  bool get initialized => _initialized;

  /// Load all settings and saved data from the database.
  Future<void> initialize() async {
    if (_initialized) return;

    // Load settings
    final ratesStr = await DatabaseService.getSetting('interest_rates');
    if (ratesStr != null) {
      _interestRates = Map<String, dynamic>.from(jsonDecode(ratesStr));
    }

    final feesStr = await DatabaseService.getSetting('fee_rates');
    if (feesStr != null) {
      _feeRates = Map<String, dynamic>.from(jsonDecode(feesStr));
    }

    final themeStr = await DatabaseService.getSetting('theme_mode');
    if (themeStr != null) {
      _themeMode = _themeFromString(themeStr);
    }

    // Load saved data
    _savedLoans = await DatabaseService.getSavedLoans();
    _exportHistory = await DatabaseService.getExportHistory();

    _initialized = true;
    notifyListeners();
  }

  // ── Theme methods ──

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    DatabaseService.setSetting('theme_mode', _themeToString(mode));
    notifyListeners();
  }

  // ── Interest rates methods ──

  void updateInterestRates(Map<String, dynamic> rates) {
    _interestRates = Map<String, dynamic>.from(rates);
    DatabaseService.setSetting('interest_rates', jsonEncode(_interestRates));
    notifyListeners();
  }

  void updateFeeRates(Map<String, dynamic> rates) {
    _feeRates = Map<String, dynamic>.from(rates);
    DatabaseService.setSetting('fee_rates', jsonEncode(_feeRates));
    notifyListeners();
  }

  // ── Saved loans ──

  Future<void> addSavedLoan(Map<String, dynamic> loan) async {
    loan['created_at'] = DateTime.now().toIso8601String();
    await DatabaseService.saveLoan(loan);
    _savedLoans = await DatabaseService.getSavedLoans();
    notifyListeners();
  }

  Future<void> removeSavedLoan(int id) async {
    await DatabaseService.deleteLoan(id);
    _savedLoans = await DatabaseService.getSavedLoans();
    notifyListeners();
  }

  // ── Export history ──

  Future<void> addExportRecord(Map<String, dynamic> record) async {
    record['created_at'] = DateTime.now().toIso8601String();
    await DatabaseService.recordExport(record);
    _exportHistory = await DatabaseService.getExportHistory();
    notifyListeners();
  }

  Future<void> removeExportRecord(int id) async {
    await DatabaseService.deleteExportRecord(id);
    _exportHistory = await DatabaseService.getExportHistory();
    notifyListeners();
  }

  // ── Document list management ──

  void updateDocuments(List<Map<String, dynamic>> docs) {
    _documents = docs;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  // ── Helpers ──

  static ThemeMode _themeFromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }
}
