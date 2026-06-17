/// Currency and number formatting utilities.
class FormatUtils {
  /// Format a number with commas as thousands separator.
  /// Example: 1000000 → "1,000,000"
  static String formatNumber(double value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  /// Format as MWK currency.
  /// Example: 1000000 → "MWK 1,000,000.00"
  static String mwk(double value, {int decimals = 2}) {
    return 'MWK ${formatNumber(value, decimals: decimals)}';
  }

  /// Alias for mwk.
  static String currency(double value, {int decimals = 2}) => mwk(value, decimals: decimals);

  /// Format file size in human-readable form.
  static String fileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Format date to short string.
  static String shortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format date with time.
  static String dateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year}  '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
