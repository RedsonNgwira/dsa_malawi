import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/image_processor.dart';
import '../widgets/page_thumbnail.dart';
import '../core/widgets/reorderable_grid.dart';
import '../features/scanner/providers/scanner_controller.dart';
import '../features/scanner/screens/scan_page_model.dart';
import '../features/scanner/widgets/camera_view.dart';

/// Scanner screen — the main interface for capturing and managing documents.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final TextEditingController _searchCtrl;
  bool _showSearch = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(
      parent: _pulseCtrl,
      curve: Curves.easeInOut,
    ));
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ScanPageDto> _filtered(List<ScanPageDto> pages) {
    if (_searchQuery.isEmpty) return pages;
    final q = _searchQuery.toLowerCase();
    return pages.where((p) => p.path.toLowerCase().contains(q)).toList();
  }

  void _showExportDialog(BuildContext context, ScannerController ctrl) {
    final nameCtrl = TextEditingController(
      text: 'Document_${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}',
    );
    bool pdf = true, docx = false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Export'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'File name')),
          const SizedBox(height: 8),
          Text('${ctrl.pages.length} page(s)',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 8),
          CheckboxListTile(title: const Text('PDF'), value: pdf,
              onChanged: (v) => pdf = v!, contentPadding: EdgeInsets.zero),
          CheckboxListTile(title: const Text('Word (.docx)'), value: docx,
              onChanged: (v) => docx = v!, contentPadding: EdgeInsets.zero),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(onPressed: () {
            Navigator.pop(ctx);
            ctrl.export(context, nameCtrl.text.trim(), pdf, docx);
          }, child: const Text('Export')),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, ScannerController ctrl, int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Filter',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: FilterPreset.values.map((f) {
                    final isCurrent = ctrl.pages[index].filter == f;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isCurrent ? Icons.check_circle : Icons.circle_outlined,
                        color: isCurrent ? Theme.of(context).colorScheme.primary : null,
                        size: 20,
                      ),
                      title: Text(_filterLabel(f),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: isCurrent ? FontWeight.w600 : null)),
                      onTap: () {
                        Navigator.pop(ctx);
                        ctrl.applyFilter(index, f);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _filterLabel(FilterPreset f) {
    return f.name[0].toUpperCase() + f.name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ScannerController>();
    final scheme = Theme.of(context).colorScheme;

    if (ctrl.showCamera) return const CameraView();

    return Scaffold(
      appBar: AppBar(
        title: Text(_showSearch ? '' : 'Scanner',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        actions: ctrl.isEmpty
            ? null
            : [
                IconButton(
                  icon: Icon(_showSearch ? Icons.close : Icons.search),
                  onPressed: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _searchQuery = '';
                  }),
                ),
                if (!_showSearch) ...[
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined),
                    tooltip: 'Import',
                    onPressed: ctrl.pickFromGallery,
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share),
                    tooltip: 'Export',
                    onPressed: () => _showExportDialog(context, ctrl),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Clear all',
                    onPressed: ctrl.clearAll,
                  ),
                ],
              ],
      ),
      body: Column(
        children: [
          if (!ctrl.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${ctrl.pages.length} page${ctrl.pages.length > 1 ? 's' : ''}',
                    style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
                  ),
                  const Spacer(),
                  if (_showSearch)
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search pages...',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ctrl.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 90, height: 90,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(Icons.document_scanner_outlined,
                              size: 42, color: scheme.primary.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 16),
                        Text('No pages yet',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                        const SizedBox(height: 6),
                        Text(
                          'Tap the scan button to capture\na document',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.5),
                              height: 1.5),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {},
                    child: ReorderableGridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.72,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onReorder: (o, n) => ctrl.reorderPages(o, n),
                      children: _filtered(ctrl.pages).asMap().entries.map((e) {
                        final i = e.key;
                        final page = e.value;
                        final idx = ctrl.pages.indexOf(page);
                        return PageThumbnail(
                          key: ValueKey(page.path),
                          imagePath: page.path,
                          pageNumber: i + 1,
                          filterLabel: page.filter != FilterPreset.enhanced
                              ? page.filter.name
                              : null,
                          onRecapture: () => ctrl.openCamera(recaptureIndex: idx),
                          onDelete: () => ctrl.deletePage(idx),
                          onFilter: () => _showFilterSheet(context, ctrl, idx),
                          gpsLabel: page.hasGps ? '📍' : null,
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: FloatingActionButton(
              heroTag: 'smart',
              onPressed: ctrl.smartScan,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.auto_fix_high, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'capture',
            onPressed: () => ctrl.openCamera(),
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundColor: scheme.onSurface,
            child: const Icon(Icons.camera_alt_outlined, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'gallery',
            onPressed: ctrl.pickFromGallery,
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundColor: scheme.onSurface,
            child: const Icon(Icons.photo_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}
