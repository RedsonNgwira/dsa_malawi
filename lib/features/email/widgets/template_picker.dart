import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state.dart';

/// Bottom sheet for selecting an email template.
class TemplatePickerSheet extends StatelessWidget {
  const TemplatePickerSheet({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const TemplatePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Choose Template',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Manage'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          SizedBox(
            height: 400,
            child: appState.emailTemplates.isEmpty
                ? const Center(child: Text('No templates yet'))
                : ListView(
                    children: appState.emailTemplates.map((t) {
                      final cat = (t['category'] as String?) ?? 'general';
                      return ListTile(
                        title: Text(t['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${cat.replaceAll('-', ' ').toUpperCase()}  •  ${t['subject']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => Navigator.pop(context, t),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
