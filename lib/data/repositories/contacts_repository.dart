import '../database/database_helper.dart';

class ContactsRepository {
  static Future<List<Map<String, dynamic>>> getAll() async {
    final db = await DatabaseHelper.database;
    return db.query('saved_contacts', orderBy: 'name ASC');
  }

  static Future<List<Map<String, dynamic>>> search(String query) async {
    final db = await DatabaseHelper.database;
    return db.query('saved_contacts',
        where: 'name LIKE ? OR email LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name ASC');
  }

  static Future<int> save(Map<String, dynamic> contact) async {
    final db = await DatabaseHelper.database;
    return db.insert('saved_contacts', contact);
  }

  static Future<void> update(int id, Map<String, dynamic> contact) async {
    final db = await DatabaseHelper.database;
    await db.update('saved_contacts', contact, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> delete(int id) async {
    final db = await DatabaseHelper.database;
    await db.delete('saved_contacts', where: 'id = ?', whereArgs: [id]);
  }
}
