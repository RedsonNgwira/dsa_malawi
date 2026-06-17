import '../database/database_helper.dart';

class TemplatesRepository {
  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.database;
    return db.query('email_templates', orderBy: 'category, name');
  }

  static Future<int> save(Map<String, dynamic> template) async {
    final db = await DatabaseHelper.database;
    return db.insert('email_templates', template);
  }

  static Future<void> update(int id, Map<String, dynamic> template) async {
    final db = await DatabaseHelper.database;
    await db.update('email_templates', template, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> delete(int id) async {
    final db = await DatabaseHelper.database;
    await db.delete('email_templates', where: 'id = ?', whereArgs: [id]);
  }
}
