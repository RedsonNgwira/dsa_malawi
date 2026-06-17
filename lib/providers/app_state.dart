import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AppState extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  Map<String, dynamic> _interestRates = {};
  Map<String, dynamic> get interestRates => _interestRates;
  Map<String, dynamic> _feeRates = {};
  Map<String, dynamic> get feeRates => _feeRates;
  List<Map<String, dynamic>> _savedLoans = [];
  List<Map<String, dynamic>> get savedLoans => _savedLoans;
  List<Map<String, dynamic>> _exportHistory = [];
  List<Map<String, dynamic>> get exportHistory => _exportHistory;
  List<Map<String, dynamic>> _emailTemplates = [];
  List<Map<String, dynamic>> get emailTemplates => _emailTemplates;
  List<Map<String, dynamic>> _savedContacts = [];
  List<Map<String, dynamic>> get savedContacts => _savedContacts;
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> get documents => _documents;
  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  String _sortBy = 'date';
  String get sortBy => _sortBy;
  bool _initialized = false;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await _loadSettings();
    await _loadSavedData();
    await _loadTemplatesAndContacts();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final ratesStr = await DatabaseService.getSetting('interest_rates');
    if (ratesStr != null) _interestRates = Map<String, dynamic>.from(jsonDecode(ratesStr));
    final feesStr = await DatabaseService.getSetting('fee_rates');
    if (feesStr != null) _feeRates = Map<String, dynamic>.from(jsonDecode(feesStr));
    final themeStr = await DatabaseService.getSetting('theme_mode');
    if (themeStr != null) _themeMode = _themeFromString(themeStr);
  }

  Future<void> _loadSavedData() async {
    _savedLoans = await DatabaseService.getSavedLoans();
    _exportHistory = await DatabaseService.getExportHistory();
  }

  Future<void> _loadTemplatesAndContacts() async {
    _emailTemplates = await DatabaseService.getTemplates();
    _savedContacts = await DatabaseService.getContacts();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode; DatabaseService.setSetting('theme_mode', _themeToString(mode)); notifyListeners();
  }

  void updateInterestRates(Map<String, dynamic> rates) {
    _interestRates = Map<String, dynamic>.from(rates);
    DatabaseService.setSetting('interest_rates', jsonEncode(_interestRates)); notifyListeners();
  }

  void updateFeeRates(Map<String, dynamic> rates) {
    _feeRates = Map<String, dynamic>.from(rates);
    DatabaseService.setSetting('fee_rates', jsonEncode(_feeRates)); notifyListeners();
  }

  Future<void> addSavedLoan(Map<String, dynamic> loan) async {
    loan['created_at'] = DateTime.now().toIso8601String();
    await DatabaseService.saveLoan(loan);
    _savedLoans = await DatabaseService.getSavedLoans(); notifyListeners();
  }

  Future<void> removeSavedLoan(int id) async {
    await DatabaseService.deleteLoan(id);
    _savedLoans = await DatabaseService.getSavedLoans(); notifyListeners();
  }

  Future<void> addExportRecord(Map<String, dynamic> record) async {
    record['created_at'] = DateTime.now().toIso8601String();
    await DatabaseService.recordExport(record);
    _exportHistory = await DatabaseService.getExportHistory(); notifyListeners();
  }

  Future<void> removeExportRecord(int id) async {
    await DatabaseService.deleteExportRecord(id);
    _exportHistory = await DatabaseService.getExportHistory(); notifyListeners();
  }

  Future<void> addTemplate(Map<String, dynamic> template) async {
    await DatabaseService.saveTemplate(template);
    _emailTemplates = await DatabaseService.getTemplates(); notifyListeners();
  }

  Future<void> updateTemplate(int id, Map<String, dynamic> template) async {
    await DatabaseService.updateTemplate(id, template);
    _emailTemplates = await DatabaseService.getTemplates(); notifyListeners();
  }

  Future<void> removeTemplate(int id) async {
    await DatabaseService.deleteTemplate(id);
    _emailTemplates = await DatabaseService.getTemplates(); notifyListeners();
  }

  Future<void> addContact(Map<String, dynamic> contact) async {
    await DatabaseService.saveContact(contact);
    _savedContacts = await DatabaseService.getContacts(); notifyListeners();
  }

  Future<void> updateContact(int id, Map<String, dynamic> contact) async {
    await DatabaseService.updateContact(id, contact);
    _savedContacts = await DatabaseService.getContacts(); notifyListeners();
  }

  Future<void> removeContact(int id) async {
    await DatabaseService.deleteContact(id);
    _savedContacts = await DatabaseService.getContacts(); notifyListeners();
  }

  void updateDocuments(List<Map<String, dynamic>> docs) { _documents = docs; notifyListeners(); }
  void setSearchQuery(String query) { _searchQuery = query; notifyListeners(); }
  void setSortBy(String sort) { _sortBy = sort; notifyListeners(); }

  static ThemeMode _themeFromString(String s) {
    switch (s) { case 'light': return ThemeMode.light; case 'dark': return ThemeMode.dark; default: return ThemeMode.system; }
  }

  static String _themeToString(ThemeMode mode) {
    switch (mode) { case ThemeMode.light: return 'light'; case ThemeMode.dark: return 'dark'; default: return 'system'; }
  }
}
