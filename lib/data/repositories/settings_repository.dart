import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class SettingsRepository {
  static Future<String?> get(String key) async {
    final db = await DatabaseHelper.database;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  static Future<void> set(String key, String value) async {
    final db = await DatabaseHelper.database;
    await db.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
