import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

/// Screen to manage saved email contacts (bank officers, branch managers, etc.)
class ManageContactsScreen extends StatefulWidget {
  final bool pickMode;
  const ManageContactsScreen({super.key, this.pickMode = false});

  @override
  State<ManageContactsScreen> createState() => _ManageContactsScreenState();
}

class _ManageContactsScreenState extends State<ManageContactsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showContactForm({Map<String, dynamic>? contact}) {
    final nameCtrl = TextEditingController(text: contact?['name'] ?? '');
    final emailCtrl = TextEditingController(text: contact?['email'] ?? '');
    final phoneCtrl = TextEditingController(text: contact?['phone'] ?? '');
    final roleCtrl = TextEditingController(text: contact?['role'] ?? '');
    final bankCtrl = TextEditingController(text: contact?['bank_office'] ?? '');
    final notesCtrl = TextEditingController(text: contact?['notes'] ?? '');
    final isNew = contact == null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'Add Contact' : 'Edit Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: roleCtrl, decoration: const InputDecoration(labelText: 'Role (e.g. Branch Manager)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'Bank / Office', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder(), isDense: true), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              if (name.isEmpty || email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name and email are required')),
                );
                return;
              }
              final data = {'name': name, 'email': email, 'phone': phoneCtrl.text.trim(),
                'role': roleCtrl.text.trim(), 'bank_office': bankCtrl.text.trim(), 'notes': notesCtrl.text.trim()};
              final appState = context.read<AppState>();
              if (isNew) {
                appState.addContact(data);
              } else {
                appState.updateContact(contact['id'] as int, data);
              }
              Navigator.pop(ctx);
            },
            child: Text(isNew ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final query = _searchCtrl.text.toLowerCase();
    final contacts = query.isEmpty
        ? appState.savedContacts
        : appState.savedContacts.where((c) =>
            (c['name'] as String).toLowerCase().contains(query) ||
            (c['email'] as String).toLowerCase().contains(query) ||
            (c['bank_office'] as String).toLowerCase().contains(query)
          ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Contacts'),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Add contact', onPressed: () => _showContactForm()),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(_searchCtrl.text.isEmpty ? 'No contacts yet' : 'No matches',
                            style: TextStyle(color: Colors.grey.shade500)),
                        const SizedBox(height: 4),
                        Text('Tap + to add a bank officer or client',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: contacts.length,
                    itemBuilder: (_, i) {
                      final c = contacts[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              (c['name'] as String)[0].toUpperCase(),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          title: Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${c['email']}${(c['bank_office'] as String).isNotEmpty ? ' • ${c['bank_office']}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.pickMode)
                                IconButton(
                                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                                  tooltip: 'Select',
                                  onPressed: () => Navigator.pop(context, c),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _showContactForm(contact: c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Delete contact?'),
                                      content: Text(c['name'] as String),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    appState.removeContact(c['id'] as int);
                                  }
                                },
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
