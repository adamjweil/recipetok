import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'dart:io';

class MediaPreview extends StatelessWidget {
  final List<File> photos;
  final Function(int) onDelete;
  final Function(int, int) onReorder;

  const MediaPreview({
    super.key,
    required this.photos,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: ReorderableGridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: photos.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          return Container(
            key: ValueKey(photos[index].path),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    photos[index],
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      color: Colors.white,
                      onPressed: () => onDelete(index),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (index == 0)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Cover',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // Show full-screen preview
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            insetPadding: EdgeInsets.zero,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  photos[index],
                                  fit: BoxFit.contain,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close),
                                    color: Colors.white,
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 