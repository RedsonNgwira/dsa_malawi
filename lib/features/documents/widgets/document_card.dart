import 'dart:io';
import 'package:flutter/material.dart';

/// Document card with actions: WhatsApp, Email, Share, Delete.
class DocumentCard extends StatelessWidget {
  final File file;
  final VoidCallback onTap, onWhatsApp, onEmail, onShare, onDelete;

  const DocumentCard({super.key, required this.file, required this.onTap, required this.onWhatsApp, required this.onEmail, required this.onShare, required this.onDelete});

  bool get _isPdf => file.path.endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final name = file.uri.pathSegments.last;
    final modified = file.statSync().modified;
    final dateStr = '${modified.day}/${modified.month}/${modified.year}  ${modified.hour}:${modified.minute.toString().padLeft(2, '0')}';
    final size = (file.lengthSync() / 1024).toStringAsFixed(0) + ' KB';
    return Card(
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_isPdf ? Icons.picture_as_pdf : Icons.description, color: _isPdf ? Colors.red : const Color(0xFF2B579A), size: 32),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              Text('$size  •  $dateStr', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: onDelete, tooltip: 'Delete'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _Btn(icon: Icons.whatshot, label: 'WhatsApp', color: const Color(0xFF25D366), onTap: onWhatsApp),
            const SizedBox(width: 8),
            _Btn(icon: Icons.email_outlined, label: 'Email', color: Colors.orange, onTap: onEmail),
            const SizedBox(width: 8),
            _Btn(icon: Icons.share, label: 'Share', color: Colors.blueGrey, onTap: onShare),
          ]),
        ])),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _Btn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 16, color: color),
    label: Text(label, style: TextStyle(fontSize: 12, color: color)), style: OutlinedButton.styleFrom(side: BorderSide(color: color.withValues(alpha: 0.4)))));
}
