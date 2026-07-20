import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../providers/wardrobe_provider.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({
    super.key,
    required this.image,
    required this.onRetake,
    this.retakeLabel = 'Retake',
  });
  final File image;
  final Future<void> Function() onRetake;
  final String retakeLabel;

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  Future<void> _save() async {
    await context.read<WardrobeProvider>().uploadOptimistically(
      image: widget.image,
      name: 'New wardrobe item',
      category: 'other',
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to wardrobe'), elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(DesignSystem.spacingLg),
          children: [
            // Image preview with rounded corners
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: DesignSystem.surfaceAlt,
                    borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
                    boxShadow: DesignSystem.shadowMedium,
                  ),
                  child: Image.file(widget.image, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: DesignSystem.spacingXl),
            Container(
              padding: const EdgeInsets.all(DesignSystem.spacingLg),
              decoration: BoxDecoration(
                color: DesignSystem.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
                border: Border.all(
                  color: DesignSystem.primary.withValues(alpha: .14),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: DesignSystem.primary),
                  SizedBox(width: DesignSystem.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'From here, we will take care of everything',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: DesignSystem.textPrimary,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'StyleStack will remove the background and automatically fill the name, brand, category, colour, season, formality, description and tags. You can continue using the app while it processes.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignSystem.spacingXl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onRetake,
                    icon: const Icon(Icons.refresh),
                    label: Text(widget.retakeLabel),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: DesignSystem.spacingMd,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DesignSystem.spacingMd),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add now'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: DesignSystem.spacingMd,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignSystem.spacingLg),
          ],
        ),
      ),
    );
  }
}
