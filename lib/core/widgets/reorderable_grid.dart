import 'package:flutter/material.dart';

/// A grid view with drag-to-reorder support.
class ReorderableGridView extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final ReorderCallback onReorder;
  final List<Widget> children;

  const ReorderableGridView.count({
    super.key,
    this.padding = EdgeInsets.zero,
    required this.crossAxisCount,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
    required this.onReorder,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.length <= 1) {
      return GridView.count(
        padding: padding,
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      );
    }

    // Use ReorderableListView wrapped in a grid layout
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return LongPressDraggable<int>(
          key: children[index].key,
          data: index,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 120,
              height: 160,
              child: Opacity(opacity: 0.8, child: children[index]),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.4, child: children[index]),
          onDragEnd: (_) {},
          child: DragTarget<int>(
            onAcceptWithDetails: (details) => onReorder(details.data, index),
            builder: (_, __, ___) => children[index],
          ),
        );
      },
    );
  }
}
