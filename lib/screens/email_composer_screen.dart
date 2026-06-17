import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

/// Screen for composing and sending an email with an attached document.
class EmailComposerScreen extends StatefulWidget {
  final File file;

  const EmailComposerScreen({super.key, required this.file});

  @override
  State<EmailComposerScreen> createState() => _EmailComposerScreenState();
}

class _EmailComposerScreenState extends State<EmailComposerScreen> {
  final _recipientCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isSending = false;
  bool _useShareFallback = false;

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
    super.dispose();
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
        // Fallback: use share sheet which includes email option
        await Share.shareXFiles(
          [XFile(widget.file.path)],
          subject: _subjectCtrl.text,
          text: _bodyCtrl.text,
        );
      } else {
        // Primary: use flutter_email_sender
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
      // If primary method fails, suggest fallback
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
          // Attached file info
          Card(
            child: ListTile(
              leading: Icon(
                _fileName.endsWith('.pdf')
                    ? Icons.picture_as_pdf
                    : Icons.description,
                color: _fileName.endsWith('.pdf') ? Colors.red : const Color(0xFF2B579A),
                size: 32,
              ),
              title: Text(_fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.remove_red_eye),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File attached and ready to send')),
                  );
                },
                tooltip: 'View file info',
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Delivery mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _useShareFallback
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
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
                  _useShareFallback
                      ? 'Using system share sheet'
                      : 'Using email client',
                  style: TextStyle(
                    fontSize: 13,
                    color: _useShareFallback ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Recipient
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

          // Subject
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.subject),
            ),
          ),

          const SizedBox(height: 12),

          // Body
          TextField(
            controller: _bodyCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 100),
                child: Icon(Icons.message),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Send button
          FilledButton.icon(
            onPressed: _isSending ? null : _sendEmail,
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: Text(_isSending ? 'Sending...' : 'Send Email'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
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
