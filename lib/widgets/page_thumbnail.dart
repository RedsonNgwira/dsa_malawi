import 'dart:io';
import 'package:flutter/material.dart';

class PageThumbnail extends StatelessWidget {
  final String imagePath;
  final int pageNumber;
  final VoidCallback onRecapture;
  final VoidCallback onDelete;
  final VoidCallback? onFilter;
  final String? filterLabel;
  final String? gpsLabel;

  const PageThumbnail({
    super.key,
    required this.imagePath,
    required this.pageNumber,
    required this.onRecapture,
    required this.onDelete,
    this.onFilter,
    this.filterLabel,
    this.gpsLabel,
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
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)),
              ),
            ),
          ),
          // Page number badge
          Positioned(
            top: 6, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text('Page $pageNumber', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
          // Filter + GPS badges
          if (filterLabel != null || gpsLabel != null)
            Positioned(
              bottom: 6, left: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filterLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_fix_high, size: 10, color: Colors.green.shade300),
                          const SizedBox(width: 2),
                          Text(filterLabel!, style: TextStyle(color: Colors.green.shade200, fontSize: 9)),
                        ],
                      ),
                    ),
                  if (gpsLabel != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                      child: Text(gpsLabel!, style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),
          // Menu button
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: () => _showOptions(context),
              child: Container(
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
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
            if (onFilter != null)
              ListTile(
                leading: const Icon(Icons.auto_fix_high),
                title: Text('Filter page $pageNumber'),
                onTap: () { Navigator.pop(context); onFilter!(); },
              ),
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
