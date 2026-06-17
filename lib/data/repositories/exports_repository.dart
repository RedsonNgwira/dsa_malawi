import '../database/database_helper.dart';

class ExportsRepository {
  static Future<int> save(Map<String, dynamic> record) async {
    final db = await DatabaseHelper.database;
    return db.insert('export_history', record);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.database;
    return db.query('export_history', orderBy: 'created_at DESC');
  }

  static Future<void> delete(int id) async {
    final db = await DatabaseHelper.database;
    await db.delete('export_history', where: 'id = ?', whereArgs: [id]);
  }
}
