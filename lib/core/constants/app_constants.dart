/// Application-wide constants for DSA Malawi.
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'DSA Malawi';
  static const String appVersion = '2.0.0';
  static const String developer = 'Redson Ngwira';
  static const String githubUrl = 'https://github.com/RedsonNgwira/dsa_malawi';

  // Database
  static const String dbName = 'dsa_malawi.db';
  static const int dbVersion = 2;

  // Loan calculator
  static const List<int> termOptions = [12, 24, 36, 42, 48, 52, 60];
  static const String defaultCurrency = 'MWK';

  // Image processing
  static const int jpegQuality = 90;
  static const int thumbnailQuality = 70;
  static const int maxImageDimension = 2480; // ~A4 at 300 DPI

  // GPS
  static const int gpsTimeoutSeconds = 10;

  // Export
  static const List<String> exportFormats = ['PDF', 'DOCX'];

  // Default contact roles
  static const List<String> contactRoles = [
    'Branch Manager',
    'Loan Officer',
    'Credit Officer',
    'Operations Manager',
    'Bank Teller',
    'Client',
    'Other',
  ];
}
