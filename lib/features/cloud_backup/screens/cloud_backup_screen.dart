import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/cloud_backup_service.dart';

/// Screen for backing up documents to cloud storage.
/// Uses the system share sheet so users can save to Google Drive,
/// Dropbox, or any cloud app installed on their phone.
class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  int _docCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final backup = context.read<CloudBackupService>();
    final count = await backup.getDocumentCount();
    if (mounted) setState(() => _docCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<CloudBackupService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Backup')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Backup Your Documents',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_docCount document(s) ready to back up',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  if (backup.totalShared > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${backup.totalShared} document(s) shared total',
                        style: TextStyle(color: Colors.green.shade600, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Backup button
          FilledButton.icon(
            onPressed: backup.status == BackupStatus.inProgress
                ? null
                : () async {
                    await backup.shareDocuments();
                    _loadCount();
                  },
            icon: backup.status == BackupStatus.inProgress
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload),
            label: Text(
              backup.status == BackupStatus.inProgress
                  ? 'Preparing...'
                  : 'Share Documents to Cloud',
            ),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),

          // Status messages
          if (backup.status == BackupStatus.success)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '✅ Documents ready — choose Google Drive in the share sheet!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green.shade700),
              ),
            ),

          if (backup.status == BackupStatus.failed && backup.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '❌ ${backup.lastError}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),

          const SizedBox(height: 24),

          // Steps card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 6),
                    Text('How to backup to Google Drive',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                SizedBox(height: 10),
                Text('1. Tap "Share Documents to Cloud"', style: TextStyle(fontSize: 12)),
                SizedBox(height: 4),
                Text('2. Select Google Drive (or Dropbox/OneDrive)', style: TextStyle(fontSize: 12)),
                SizedBox(height: 4),
                Text('3. Choose a folder and tap Save', style: TextStyle(fontSize: 12)),
                SizedBox(height: 8),
                SizedBox(height: 4),
                Text(
                  'Your PDF and DOCX files will be copied to your preferred cloud storage.',
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
