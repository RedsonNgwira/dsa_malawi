import '../database/database_helper.dart';

class LoansRepository {
  static Future<int> save(Map<String, dynamic> loan) async {
    final db = await DatabaseHelper.database;
    return db.insert('saved_loans', loan);
  }

  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.database;
    return db.query('saved_loans', orderBy: 'created_at DESC');
  }

  static Future<void> delete(int id) async {
    final db = await DatabaseHelper.database;
    await db.delete('saved_loans', where: 'id = ?', whereArgs: [id]);
  }
}
