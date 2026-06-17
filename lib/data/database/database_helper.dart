import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Handles database initialization and migration.
class DatabaseHelper {
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
      version: 2,
      onCreate: (db, v) => _createAll(db),
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) await _createV2(db);
      },
    );
  }

  static Future<void> _createAll(Database db) async {
    await _createV1(db);
    await _createV2(db);
  }

  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE saved_loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT, loan_amount REAL NOT NULL,
        term_months INTEGER NOT NULL, platinum INTEGER NOT NULL DEFAULT 0,
        existing_debt REAL DEFAULT 0, annual_rate REAL NOT NULL,
        admin_fee REAL NOT NULL, monthly_instalment REAL NOT NULL,
        total_repayable REAL NOT NULL, net_pay REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE export_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_name TEXT NOT NULL, file_path TEXT NOT NULL,
        file_type TEXT NOT NULL, page_count INTEGER NOT NULL DEFAULT 0,
        file_size INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)
    ''');
    await db.insert('app_settings', {
      'key': 'interest_rates',
      'value': jsonEncode({
        'term_12_36': 0.475, 'term_42_52': 0.465,
        'term_60': 0.425, 'platinum_60': 0.38,
      }),
    });
    await db.insert('app_settings', {
      'key': 'fee_rates',
      'value': jsonEncode({
        'admin_fee_standard': 0.025, 'admin_fee_platinum': 0.07,
        'monthly_insurance': 0.00125, 'commission_rate': 0.01,
      }),
    });
    await db.insert('app_settings', {'key': 'theme_mode', 'value': 'system'});
  }

  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS email_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, subject TEXT NOT NULL, body TEXT NOT NULL,
        category TEXT DEFAULT 'general',
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, email TEXT NOT NULL, phone TEXT DEFAULT '',
        role TEXT DEFAULT '', bank_office TEXT DEFAULT '',
        notes TEXT DEFAULT '', created_at TEXT NOT NULL
      )
    ''');
    await _seedTemplates(db);
  }

  static Future<void> _seedTemplates(Database db) async {
    final now = DateTime.now().toIso8601String();
    const templates = [
      {'name': 'New Loan Application', 'category': 'loan-application',
        'subject': 'New Loan Application — {client_name}',
        'body': 'Dear {recipient_name},\n\nPlease find attached the loan application documents for {client_name}.\n\nLoan Amount: MWK {loan_amount}\nTerm: {term} months\n\nDocuments attached:\n— Signed application form\n— ID copy\n\nKindly process and advise.\n\nRegards,\n{sender_name}\nDSA Malawi'},
      {'name': 'Signed Agreement', 'category': 'agreement',
        'subject': 'Signed Loan Agreement — {client_name}',
        'body': 'Dear {recipient_name},\n\nPlease find attached the signed loan agreement for {client_name}.\n\nThe client has reviewed and signed all pages. Kindly confirm receipt and proceed with disbursement.\n\nRegards,\n{sender_name}\nDSA Malawi'},
      {'name': 'Client Documents Submission', 'category': 'documents',
        'subject': 'Client Documents — {client_name}',
        'body': 'Dear {recipient_name},\n\nAttached are the scanned documents for client {client_name}.\n\nDocuments:\n— Completed application form\n— Signed terms & conditions\n— Supporting documents\n\nPlease review and let me know if anything else is needed.\n\nRegards,\n{sender_name}\nDSA Malawi'},
      {'name': 'Follow Up on Application', 'category': 'follow-up',
        'subject': 'Follow Up — {client_name} Loan Application',
        'body': 'Dear {recipient_name},\n\nI am following up on the loan application for {client_name} submitted on {submission_date}.\n\nKindly advise on the status and if any additional documents are required.\n\nRegards,\n{sender_name}\nDSA Malawi'},
      {'name': 'Disbursement Confirmation', 'category': 'disbursement',
        'subject': 'Disbursement Confirmation — {client_name}',
        'body': 'Dear {recipient_name},\n\nI confirm that client {client_name} has received the loan disbursement of MWK {loan_amount}.\n\nThe signed disbursement acknowledgment is attached.\n\nRegards,\n{sender_name}\nDSA Malawi'},
      {'name': 'General Enquiry', 'category': 'general',
        'subject': 'Enquiry — {client_name}',
        'body': 'Dear {recipient_name},\n\nI am writing regarding {client_name}.\n\n{message}\n\nRegards,\n{sender_name}\nDSA Malawi'},
    ];
    for (final t in templates) {
      await db.insert('email_templates', {
        ...t, 'created_at': now, 'updated_at': now,
      });
    }
  }
}
