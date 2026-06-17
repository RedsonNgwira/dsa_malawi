import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_state.dart';
import 'manage_contacts_screen.dart';
import 'manage_templates_screen.dart';
import '../features/email/widgets/placeholder_fields.dart';
import '../features/email/widgets/template_picker.dart';
import '../features/email/widgets/email_toolbar.dart';

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
    _bodyCtrl.text = 'Please find the attached document: $_fileName\n\nSent from DSA Malawi';
  }

  @override
  void dispose() { _recipientCtrl.dispose(); _subjectCtrl.dispose(); _bodyCtrl.dispose();
    _clientNameCtrl.dispose(); _loanAmountCtrl.dispose(); super.dispose(); }

  void _applyTemplate(Map<String, dynamic> t) {
    setState(() {
      _subjectCtrl.text = t['subject'] as String? ?? '';
      _bodyCtrl.text = t['body'] as String? ?? '';
      _showPlaceholders = true;
    });
    _replace();
  }

  void _replace() {
    final cn = _clientNameCtrl.text.trim();
    final la = _loanAmountCtrl.text.trim();
    final s = 'DSA Agent';
    _subjectCtrl.text = _subjectCtrl.text.replaceAll('{client_name}', cn.isNotEmpty ? cn : '______')
      .replaceAll('{recipient_name}', '______')
      .replaceAll('{loan_amount}', la.isNotEmpty ? 'MWK $la' : '______')
      .replaceAll('{term}', '______').replaceAll('{sender_name}', s)
      .replaceAll('{submission_date}', '______').replaceAll('{message}', '______');
    _bodyCtrl.text = _bodyCtrl.text.replaceAll('{client_name}', cn.isNotEmpty ? cn : '______')
      .replaceAll('{recipient_name}', '______')
      .replaceAll('{loan_amount}', la.isNotEmpty ? 'MWK $la' : '______')
      .replaceAll('{term}', '______').replaceAll('{sender_name}', s)
      .replaceAll('{submission_date}', '______').replaceAll('{message}', '______');
    if (!_subjectCtrl.text.contains('{') && !_bodyCtrl.text.contains('{')) {
      setState(() => _showPlaceholders = false);
    }
  }

  Future<void> _pickContact() async {
    final r = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(
      builder: (_) => const ManageContactsScreen(pickMode: true),
    ));
    if (r != null) {
      final e = r['email'] as String;
      _recipientCtrl.text = _recipientCtrl.text.isEmpty ? e : '${_recipientCtrl.text}, $e';
    }
  }

  Future<void> _pickTemplate() async {
    final appState = context.read<AppState>();
    if (appState.emailTemplates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No templates yet')));
      return;
    }
    final selected = await TemplatePickerSheet.show(context);
    if (selected != null) _applyTemplate(selected);
  }

  Future<void> _send() async {
    final recipients = _recipientCtrl.text.split(RegExp(r'[,\s;]+')).where((e) => e.isNotEmpty).toList();
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least one recipient')));
      return;
    }
    setState(() => _isSending = true);
    try {
      if (_useShareFallback) {
        await Share.shareXFiles([XFile(widget.file.path)], subject: _subjectCtrl.text, text: _bodyCtrl.text);
      } else {
        await FlutterEmailSender.send(Email(
          recipients: recipients, subject: _subjectCtrl.text, body: _bodyCtrl.text,
          attachmentPaths: [widget.file.path], isHTML: false,
        ));
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email sent successfully')));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _useShareFallback = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open email client: $e'),
          action: SnackBarAction(label: 'Use Share', onPressed: () => Share.shareXFiles(
            [XFile(widget.file.path)], subject: _subjectCtrl.text, text: _bodyCtrl.text,
          )),
        ));
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
            icon: Icon(_useShareFallback ? Icons.share : Icons.email),
            tooltip: _useShareFallback ? 'Using share sheet' : 'Using email',
            onPressed: () => setState(() => _useShareFallback = !_useShareFallback),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: ListTile(
            leading: Icon(_fileName.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.description,
                color: _fileName.endsWith('.pdf') ? Colors.red : const Color(0xFF2B579A), size: 32),
            title: Text(_fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB'),
          )),
          const SizedBox(height: 8),
          EmailToolbar(
            onTemplate: _pickTemplate,
            onContact: _pickContact,
            onManage: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageTemplatesScreen())),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _useShareFallback ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(_useShareFallback ? Icons.share : Icons.email, size: 18,
                  color: _useShareFallback ? Colors.orange : Colors.green),
              const SizedBox(width: 6),
              Text(_useShareFallback ? 'Using share sheet' : 'Using email client',
                  style: TextStyle(fontSize: 12, color: _useShareFallback ? Colors.orange.shade800 : Colors.green.shade800)),
            ]),
          ),
          const SizedBox(height: 12),
          if (_showPlaceholders) ...[
            PlaceholderFields(
              clientNameCtrl: _clientNameCtrl, loanAmountCtrl: _loanAmountCtrl,
              onChanged: _replace, onClose: () => setState(() => _showPlaceholders = false),
            ),
            const SizedBox(height: 12),
          ],
          TextField(controller: _recipientCtrl, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Recipient(s)', hintText: 'email@example.com',
                border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
          const SizedBox(height: 12),
          TextField(controller: _subjectCtrl,
            decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder(), prefixIcon: Icon(Icons.subject))),
          const SizedBox(height: 12),
          TextField(controller: _bodyCtrl, maxLines: 6,
            decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true,
                border: OutlineInputBorder(), prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 100), child: Icon(Icons.message)))),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSending ? null : _send,
            icon: _isSending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_isSending ? 'Sending...' : 'Send Email'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }
}
