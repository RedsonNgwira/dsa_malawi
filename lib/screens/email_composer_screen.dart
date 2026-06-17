import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_state.dart';
import 'manage_contacts_screen.dart';
import 'manage_templates_screen.dart';

/// Screen for composing and sending an email with an attached document.
/// Supports saved contacts, email templates, and placeholder substitution.
class EmailComposerScreen extends StatefulWidget {
  final File file;
  final String? preselectedTemplate;

  const EmailComposerScreen({super.key, required this.file, this.preselectedTemplate});

  @override
  State<EmailComposerScreen> createState() => _EmailComposerScreenState();
}

class _EmailComposerScreenState extends State<EmailComposerScreen> {
  final _recipientCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _loanAmountCtrl = TextEditingController();
  bool _isSending = false;
  bool _useShareFallback = false;
  bool _showPlaceholders = false;

  String get _fileName => widget.file.uri.pathSegments.last;

  @override
  void initState() {
    super.initState();
    _subjectCtrl.text = _fileName;
    _bodyCtrl.text = 'Please find the attached document: $_fileName\n\n'
        'Sent from DSA Malawi';
  }

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _clientNameCtrl.dispose();
    _loanAmountCtrl.dispose();
    super.dispose();
  }

  /// Apply a template: replace subject and body, insert placeholders.
  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _subjectCtrl.text = template['subject'] as String? ?? '';
      _bodyCtrl.text = template['body'] as String? ?? '';
      _showPlaceholders = true;
    });
    _replacePlaceholders();
  }

  /// Replace {placeholders} in subject and body with field values.
  void _replacePlaceholders() {
    final clientName = _clientNameCtrl.text.trim();
    final loanAmount = _loanAmountCtrl.text.trim();
    final senderName = 'DSA Agent'; // Could be configurable

    String subj = _subjectCtrl.text;
    String body = _bodyCtrl.text;

    subj = _replaceAll(subj, clientName, loanAmount, senderName);
    body = _replaceAll(body, clientName, loanAmount, senderName);

    _subjectCtrl.text = subj;
    _bodyCtrl.text = body;

    // Clear placeholders after replacement
    if (_subjectCtrl.text.contains('{') == false &&
        _bodyCtrl.text.contains('{') == false) {
      setState(() => _showPlaceholders = false);
    }
  }

  String _replaceAll(String text, String clientName, String loanAmount, String senderName) {
    return text
        .replaceAll('{client_name}', clientName.isNotEmpty ? clientName : '______')
        .replaceAll('{recipient_name}', '______')
        .replaceAll('{loan_amount}', loanAmount.isNotEmpty ? 'MWK $loanAmount' : '______')
        .replaceAll('{term}', '______')
        .replaceAll('{sender_name}', senderName)
        .replaceAll('{submission_date}', '______')
        .replaceAll('{message}', '______');
  }

  Future<void> _pickContact() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const ManageContactsScreen(pickMode: true)),
    );
    if (result != null) {
      final email = result['email'] as String;
      if (_recipientCtrl.text.isEmpty) {
        _recipientCtrl.text = email;
      } else {
        _recipientCtrl.text = '${_recipientCtrl.text}, $email';
      }
    }
  }

  Future<void> _pickTemplate() async {
    final appState = context.read<AppState>();
    if (appState.emailTemplates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No templates yet. Create one first!')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Choose Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Manage'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageTemplatesScreen()));
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            SizedBox(
              height: 400,
              child: ListView(
                children: appState.emailTemplates.map((t) {
                  final cat = (t['category'] as String?) ?? 'general';
                  return ListTile(
                    title: Text(t['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${cat.replaceAll('-', ' ').toUpperCase()}  •  ${t['subject']}',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(ctx, t),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      _applyTemplate(selected);
    }
  }

  Future<void> _sendEmail() async {
    final recipients = _recipientCtrl.text
        .split(RegExp(r'[,\s;]+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one recipient')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_useShareFallback) {
        await Share.shareXFiles(
          [XFile(widget.file.path)],
          subject: _subjectCtrl.text,
          text: _bodyCtrl.text,
        );
      } else {
        final email = Email(
          recipients: recipients,
          subject: _subjectCtrl.text,
          body: _bodyCtrl.text,
          attachmentPaths: [widget.file.path],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email sent successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _useShareFallback = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open email client: $e'),
            action: SnackBarAction(
              label: 'Use Share',
              onPressed: () {
                Share.shareXFiles(
                  [XFile(widget.file.path)],
                  subject: _subjectCtrl.text,
                  text: _bodyCtrl.text,
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send via Email'),
        actions: [
          IconButton(
            icon: _useShareFallback
                ? const Icon(Icons.share)
                : const Icon(Icons.email),
            tooltip: _useShareFallback ? 'Using share sheet' : 'Using email',
            onPressed: () => setState(() => _useShareFallback = !_useShareFallback),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Attached file ──
          Card(
            child: ListTile(
              leading: Icon(
                _fileName.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.description,
                color: _fileName.endsWith('.pdf') ? Colors.red : const Color(0xFF2B579A),
                size: 32,
              ),
              title: Text(_fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB'),
            ),
          ),

          const SizedBox(height: 8),

          // ── Toolbar: Templates + Contacts ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTemplate,
                  icon: const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Template', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickContact,
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: const Text('Contact', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageTemplatesScreen()),
                  ),
                  icon: const Icon(Icons.manage_search, size: 18),
                  label: const Text('Manage', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Delivery mode indicator ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _useShareFallback ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _useShareFallback ? Icons.share : Icons.email,
                  size: 18,
                  color: _useShareFallback ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _useShareFallback ? 'Using system share sheet' : 'Using email client',
                  style: TextStyle(fontSize: 13, color: _useShareFallback ? Colors.orange.shade800 : Colors.green.shade800),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Placeholder fields (shown when template is used) ──
          if (_showPlaceholders) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      const Text('Fill in template details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _showPlaceholders = false),
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _clientNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Client Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (_) => _replacePlaceholders(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _loanAmountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Loan Amount (MWK)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _replacePlaceholders(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Recipient ──
          TextField(
            controller: _recipientCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Recipient(s)',
              hintText: 'email@example.com, other@example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),

          const SizedBox(height: 12),

          // ── Subject ──
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.subject),
            ),
          ),

          const SizedBox(height: 12),

          // ── Body ──
          TextField(
            controller: _bodyCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          // ── Send button ──
          FilledButton.icon(
            onPressed: _isSending ? null : _sendEmail,
            icon: _isSending
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: Text(_isSending ? 'Sending...' : 'Send Email'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),

          if (_useShareFallback) ...[
            const SizedBox(height: 8),
            Text(
              'Tip: Tap the email/share toggle in the app bar to switch methods.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
