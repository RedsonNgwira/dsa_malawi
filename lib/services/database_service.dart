import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Persistent local database for saved loans, export history, app settings,
/// email templates, and saved contacts.
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
      version: 2,
      onCreate: (db, version) async => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
        }
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await _createV1Tables(db);
    await _createV2Tables(db);
  }

  static Future<void> _createV1Tables(Database db) async {
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
        'commission_rate': 0.01,
      }),
    });
    await db.insert('app_settings', {
      'key': 'theme_mode',
      'value': 'system',
    });
  }

  static Future<void> _createV2Tables(Database db) async {
    // Email templates
    await db.execute('''
      CREATE TABLE IF NOT EXISTS email_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        subject TEXT NOT NULL,
        body TEXT NOT NULL,
        category TEXT DEFAULT 'general',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Saved contacts
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT DEFAULT '',
        role TEXT DEFAULT '',
        bank_office TEXT DEFAULT '',
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // Seed default templates for DSA Malawi workflow
    final now = DateTime.now().toIso8601String();
    final templates = [
      {
        'name': 'New Loan Application',
        'subject': 'New Loan Application — {client_name}',
        'body': 'Dear {recipient_name},\n\n'
            'Please find attached the loan application documents for {client_name}.\n\n'
            'Loan Amount: MWK {loan_amount}\n'
            'Term: {term} months\n\n'
            'Documents attached:\n'
            '— Signed application form\n'
            '— ID copy\n\n'
            'Kindly process and advise.\n\n'
            'Regards,\n{sender_name}\nDSA Malawi',
        'category': 'loan-application',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Signed Agreement',
        'subject': 'Signed Loan Agreement — {client_name}',
        'body': 'Dear {recipient_name},\n\n'
            'Please find attached the signed loan agreement for {client_name}.\n\n'
            'The client has reviewed and signed all pages. Kindly confirm receipt '
            'and proceed with disbursement.\n\n'
            'Regards,\n{sender_name}\nDSA Malawi',
        'category': 'agreement',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Client Documents Submission',
        'subject': 'Client Documents — {client_name}',
        'body': 'Dear {recipient_name},\n\n'
            'Attached are the scanned documents for client {client_name}.\n\n'
            'Documents:\n'
            '— Completed application form\n'
            '— Signed terms & conditions\n'
            '— Supporting documents\n\n'
            'Please review and let me know if anything else is needed.\n\n'
            'Regards,\n{sender_name}\nDSA Malawi',
        'category': 'documents',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Follow Up on Application',
        'subject': 'Follow Up — {client_name} Loan Application',
        'body': 'Dear {recipient_name},\n\n'
            'I am following up on the loan application for {client_name} '
            'submitted on {submission_date}.\n\n'
            'Kindly advise on the status and if any additional documents are required.\n\n'
            'Regards,\n{sender_name}\nDSA Malawi',
        'category': 'follow-up',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'Disbursement Confirmation',
        'subject': 'Disbursement Confirmation — {client_name}',
        'body': 'Dear {recipient_name},\n\n'
            'I confirm that client {client_name} has received the loan disbursement '
            'of MWK {loan_amount}.\n\n'
            'The signed disbursement acknowledgment is attached.\n\n'
            'Regards,\n{sender_name}\nDSA Malawi',
        'category': 'disbursement',
        'created_at': now,
        'updated_at': now,
      },
      {
        'name': 'General Enquiry',
        'subject': 'Enquiry — {client_name}',
        'body': 'Dear {recipient_name},\n\n'
            'I am writing regarding {client_name}.\n\n'
            '{message}\n\n'
            'Regards,\n{sender_name}\nDSA Malawi',
        'category': 'general',
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (final tpl in templates) {
      await db.insert('email_templates', tpl);
    }
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

  // ── Email Templates ──

  static Future<int> saveTemplate(Map<String, dynamic> template) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    template['created_at'] = now;
    template['updated_at'] = now;
    return db.insert('email_templates', template);
  }

  static Future<List<Map<String, dynamic>>> getTemplates() async {
    final db = await database;
    return db.query('email_templates', orderBy: 'category ASC, name ASC');
  }

  static Future<List<Map<String, dynamic>>> getTemplatesByCategory(String category) async {
    final db = await database;
    return db.query('email_templates',
        where: 'category = ?', whereArgs: [category], orderBy: 'name ASC');
  }

  static Future<void> updateTemplate(int id, Map<String, dynamic> template) async {
    final db = await database;
    template['updated_at'] = DateTime.now().toIso8601String();
    await db.update('email_templates', template, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteTemplate(int id) async {
    final db = await database;
    await db.delete('email_templates', where: 'id = ?', whereArgs: [id]);
  }

  // ── Saved Contacts ──

  static Future<int> saveContact(Map<String, dynamic> contact) async {
    final db = await database;
    contact['created_at'] = DateTime.now().toIso8601String();
    return db.insert('saved_contacts', contact);
  }

  static Future<List<Map<String, dynamic>>> getContacts() async {
    final db = await database;
    return db.query('saved_contacts', orderBy: 'name ASC');
  }

  static Future<List<Map<String, dynamic>>> searchContacts(String query) async {
    final db = await database;
    return db.query('saved_contacts',
        where: 'name LIKE ? OR email LIKE ? OR bank_office LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'name ASC');
  }

  static Future<void> updateContact(int id, Map<String, dynamic> contact) async {
    final db = await database;
    await db.update('saved_contacts', contact, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deleteContact(int id) async {
    final db = await database;
    await db.delete('saved_contacts', where: 'id = ?', whereArgs: [id]);
  }
}
