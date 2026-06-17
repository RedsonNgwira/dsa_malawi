import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Status of a backup operation.
enum BackupStatus { idle, inProgress, success, failed }

/// Result of a backup operation.
class BackupResult {
  final bool success;
  final String? error;
  final int filesCount;

  const BackupResult({required this.success, this.error, this.filesCount = 0});
}

/// Service for backing up documents via share/export.
/// Uses the system share sheet so users can save to Google Drive,
/// Dropbox, or any other cloud storage app installed on their device.
class CloudBackupService extends ChangeNotifier {
  BackupStatus _status = BackupStatus.idle;
  String? _lastError;
  int _totalShared = 0;

  BackupStatus get status => _status;
  String? get lastError => _lastError;
  int get totalShared => _totalShared;

  /// Share documents via the system share sheet.
  /// This lets the user choose Google Drive, Dropbox, Email, etc.
  Future<BackupResult> shareDocuments() async {
    _status = BackupStatus.inProgress;
    _lastError = null;
    notifyListeners();

    try {
      final dirs = <Directory>[];
      final ext = await getExternalStorageDirectory();
      final app = await getApplicationDocumentsDirectory();
      if (ext != null) dirs.add(ext);
      dirs.add(app);

      final files = <File>[];
      for (final dir in dirs) {
        if (!dir.existsSync()) continue;
        files.addAll(dir.listSync().whereType<File>()
            .where((f) => f.path.endsWith('.pdf') || f.path.endsWith('.docx')));
      }

      if (files.isEmpty) {
        _status = BackupStatus.success;
        notifyListeners();
        return const BackupResult(success: true, filesCount: 0, error: 'No documents found to share');
      }

      // Share first 10 files (share_plus limit)
      final toShare = files.take(10).map((f) => XFile(f.path)).toList();
      await Share.shareXFiles(toShare, subject: 'DSA Malawi Documents');

      _totalShared += toShare.length;
      _status = BackupStatus.success;
      notifyListeners();

      return BackupResult(success: true, filesCount: toShare.length);
    } catch (e) {
      _status = BackupStatus.failed;
      _lastError = e.toString();
      notifyListeners();
      return BackupResult(success: false, error: e.toString());
    }
  }

  /// Get count of exportable documents.
  Future<int> getDocumentCount() async {
    final dirs = <Directory>[];
    final ext = await getExternalStorageDirectory();
    final app = await getApplicationDocumentsDirectory();
    if (ext != null) dirs.add(ext);
    dirs.add(app);

    int count = 0;
    for (final dir in dirs) {
      if (!dir.existsSync()) continue;
      count += dir.listSync().whereType<File>()
          .where((f) => f.path.endsWith('.pdf') || f.path.endsWith('.docx')).length;
    }
    return count;
  }
}
