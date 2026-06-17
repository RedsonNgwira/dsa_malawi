import '../data/database/database_helper.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/loans_repository.dart';
import '../data/repositories/exports_repository.dart';
import '../data/repositories/templates_repository.dart';
import '../data/repositories/contacts_repository.dart';

/// Persistent local database for saved loans, export history, app settings,
/// email templates, and saved contacts.
///
/// Delegates to specialized repositories under data/.
class DatabaseService {
  // ── Initialization ──
  static Future<void> init() async => DatabaseHelper.database;

  // ── Settings ──
  static Future<String?> getSetting(String key) => SettingsRepository.get(key);
  static Future<void> setSetting(String key, String value) => SettingsRepository.set(key, value);

  // ── Saved Loans ──
  static Future<int> saveLoan(Map<String, dynamic> loan) => LoansRepository.save(loan);
  static Future<List<Map<String, dynamic>>> getSavedLoans() => LoansRepository.getAll();
  static Future<void> deleteLoan(int id) => LoansRepository.delete(id);

  // ── Export History ──
  static Future<int> recordExport(Map<String, dynamic> record) => ExportsRepository.save(record);
  static Future<List<Map<String, dynamic>>> getExportHistory() => ExportsRepository.getAll();
  static Future<void> deleteExportRecord(int id) => ExportsRepository.delete(id);

  // ── Templates ──
  static Future<List<Map<String, dynamic>>> getTemplates() => TemplatesRepository.getAll();
  static Future<int> saveTemplate(Map<String, dynamic> template) => TemplatesRepository.save(template);
  static Future<void> updateTemplate(int id, Map<String, dynamic> template) => TemplatesRepository.update(id, template);
  static Future<void> deleteTemplate(int id) => TemplatesRepository.delete(id);

  // ── Contacts ──
  static Future<List<Map<String, dynamic>>> getContacts() => ContactsRepository.getAll();
  static Future<List<Map<String, dynamic>>> searchContacts(String query) => ContactsRepository.search(query);
  static Future<int> saveContact(Map<String, dynamic> contact) => ContactsRepository.save(contact);
  static Future<void> updateContact(int id, Map<String, dynamic> contact) => ContactsRepository.update(id, contact);
  static Future<void> deleteContact(int id) => ContactsRepository.delete(id);
}
