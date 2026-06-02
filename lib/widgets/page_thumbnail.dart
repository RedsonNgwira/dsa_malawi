import 'dart:io';
import 'package:flutter/material.dart';

class PageThumbnail extends StatelessWidget {
  final String imagePath;
  final int pageNumber;
  final VoidCallback onRecapture;
  final VoidCallback onDelete;

  const PageThumbnail({
    super.key,
    required this.imagePath,
    required this.pageNumber,
    required this.onRecapture,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Page number badge
          Positioned(
            top: 6, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Page $pageNumber',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          // Action button
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: () => _showOptions(context),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('Recapture page $pageNumber'),
              onTap: () { Navigator.pop(context); onRecapture(); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete page', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); onDelete(); },
            ),
          ],
        ),
      ),
    );
  }
}
