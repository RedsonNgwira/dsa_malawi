import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Persistent local database for saved loans, export history, and app settings.
class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'dsa_malawi.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Saved loan calculations
        await db.execute('''
          CREATE TABLE saved_loans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT,
            loan_amount REAL NOT NULL,
            term_months INTEGER NOT NULL,
            platinum INTEGER NOT NULL DEFAULT 0,
            existing_debt REAL DEFAULT 0,
            annual_rate REAL NOT NULL,
            admin_fee REAL NOT NULL,
            monthly_instalment REAL NOT NULL,
            total_repayable REAL NOT NULL,
            net_pay REAL NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        // Export history
        await db.execute('''
          CREATE TABLE export_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_type TEXT NOT NULL,
            page_count INTEGER NOT NULL DEFAULT 0,
            file_size INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');

        // App settings (key-value)
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        // Seed default settings
        await db.insert('app_settings', {
          'key': 'interest_rates',
          'value': jsonEncode({
            'term_12_36': 0.475,
            'term_42_52': 0.465,
            'term_60': 0.425,
            'platinum_60': 0.38,
          }),
        });
        await db.insert('app_settings', {
          'key': 'fee_rates',
          'value': jsonEncode({
            'admin_fee_standard': 0.025,
            'admin_fee_platinum': 0.07,
            'monthly_insurance': 0.00125,
          }),
        });
        await db.insert('app_settings', {
          'key': 'theme_mode',
          'value': 'system',
        });
      },
    );
  }

  // ── Settings ──

  static Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  static Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Saved Loans ──

  static Future<int> saveLoan(Map<String, dynamic> loan) async {
    final db = await database;
    return db.insert('saved_loans', loan);
  }

  static Future<List<Map<String, dynamic>>> getSavedLoans() async {
    final db = await database;
    return db.query('saved_loans', orderBy: 'created_at DESC');
  }

  static Future<void> deleteLoan(int id) async {
    final db = await database;
    await db.delete('saved_loans', where: 'id = ?', whereArgs: [id]);
  }

  // ── Export History ──

  static Future<int> recordExport(Map<String, dynamic> record) async {
    final db = await database;
    return db.insert('export_history', record);
  }

  static Future<List<Map<String, dynamic>>> getExportHistory() async {
    final db = await database;
    return db.query('export_history', orderBy: 'created_at DESC');
  }

  static Future<void> deleteExportRecord(int id) async {
    final db = await database;
    await db.delete('export_history', where: 'id = ?', whereArgs: [id]);
  }
}
