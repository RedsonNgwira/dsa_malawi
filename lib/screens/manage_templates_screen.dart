import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

/// Screen to manage email templates for the DSA workflow.
class ManageTemplatesScreen extends StatefulWidget {
  const ManageTemplatesScreen({super.key});

  @override
  State<ManageTemplatesScreen> createState() => _ManageTemplatesScreenState();
}

class _ManageTemplatesScreenState extends State<ManageTemplatesScreen> {
  final Map<String, String> _categoryLabels = {
    'loan-application': 'Loan Applications',
    'agreement': 'Agreements',
    'documents': 'Documents',
    'follow-up': 'Follow Ups',
    'disbursement': 'Disbursements',
    'general': 'General',
  };

  final Map<String, IconData> _categoryIcons = {
    'loan-application': Icons.assignment,
    'agreement': Icons.article,
    'documents': Icons.description,
    'follow-up': Icons.follow_the_signs,
    'disbursement': Icons.payments,
    'general': Icons.email,
  };

  void _showTemplateForm({Map<String, dynamic>? template}) {
    final nameCtrl = TextEditingController(text: template?['name'] ?? '');
    final subjectCtrl = TextEditingController(text: template?['subject'] ?? '');
    final bodyCtrl = TextEditingController(text: template?['body'] ?? '');
    String category = template?['category'] ?? 'general';
    final isNew = template == null;
    final isDefault = template != null && (template['id'] as int) <= 6;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'New Template' : 'Edit Template'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Template Name *', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder(), isDense: true),
                items: _categoryLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: isDefault ? null : (v) => category = v!,
              ),
              const SizedBox(height: 8),
              TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject *', border: OutlineInputBorder(), isDense: true), maxLines: 2),
              const SizedBox(height: 8),
              TextField(controller: bodyCtrl, decoration: const InputDecoration(labelText: 'Body *', border: OutlineInputBorder(), alignLabelWithHint: true), maxLines: 8),
              if (isNew) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Available placeholders: {client_name}, {recipient_name}, {loan_amount}, {term}, {sender_name}, {submission_date}, {message}', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final subject = subjectCtrl.text.trim();
              final body = bodyCtrl.text.trim();
              if (name.isEmpty || subject.isEmpty || body.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name, subject, and body are required')),
                );
                return;
              }
              final data = {'name': name, 'subject': subject, 'body': body, 'category': category};
              final appState = context.read<AppState>();
              if (isNew) {
                appState.addTemplate(data);
              } else {
                appState.updateTemplate(template['id'] as int, data);
              }
              Navigator.pop(ctx);
            },
            child: Text(isNew ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final templates = appState.emailTemplates;

    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final t in templates) {
      final cat = (t['category'] as String?) ?? 'general';
      grouped.putIfAbsent(cat, () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Templates'),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'New template', onPressed: () => _showTemplateForm()),
        ],
      ),
      body: templates.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.email_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No templates yet', style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text('Tap + to create an email template',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: grouped.entries.map((entry) {
                final catLabel = _categoryLabels[entry.key] ?? entry.key;
                final catIcon = _categoryIcons[entry.key] ?? Icons.email;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 6),
                      child: Row(
                        children: [
                          Icon(catIcon, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(catLabel.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                    ...entry.value.map((t) => Card(
                      child: ListTile(
                        title: Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(t['subject'] as String, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showTemplateForm(template: t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete template?'),
                                    content: Text(t['name'] as String),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  appState.removeTemplate(t['id'] as int);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
    );
  }
}
