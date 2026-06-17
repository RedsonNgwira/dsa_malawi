import 'package:flutter/material.dart';

/// Toolbar with template, contact, and manage buttons for email composer.
class EmailToolbar extends StatelessWidget {
  final VoidCallback onTemplate;
  final VoidCallback onContact;
  final VoidCallback onManage;

  const EmailToolbar({
    super.key,
    required this.onTemplate,
    required this.onContact,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTemplate,
            icon: const Icon(Icons.email_outlined, size: 18),
            label: const Text('Template', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onContact,
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Contact', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onManage,
            icon: const Icon(Icons.manage_search, size: 18),
            label: const Text('Manage', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
