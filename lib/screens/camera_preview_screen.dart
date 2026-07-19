import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../config/custom_widgets.dart';
import '../models/clothing_analysis.dart';
import '../providers/wardrobe_provider.dart';

String _titleCase(String value) => value
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
    .join(' ');

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
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  String? _color;
  String? _season;
  String? _formality;
  ClothingAnalysis? _analysis;
  bool _analyzingImage = true;

  @override
  void initState() {
    super.initState();
    // Analyze immediately when the preview opens so the user can review and
    // edit the detected details before saving the item.
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyzeImage());
  }

  Future<void> _analyzeImage() async {
    final result = await context.read<WardrobeProvider>().analyzeImage(
      widget.image,
    );
    if (!mounted) return;
    if (result != null) {
      _analysis = result;
      if (_name.text.trim().isEmpty) {
        final brand = result.brand == null ? '' : '${result.brand} ';
        _name.text = _titleCase(
          '$brand${result.color} ${result.category}'.trim(),
        );
      }
      if (_brand.text.trim().isEmpty && result.brand != null) {
        _brand.text = result.brand!;
      }
      if (_category.text.trim().isEmpty) _category.text = result.category;
      _color ??= result.color;
      _season ??= result.season;
      _formality ??= result.formality;
      if (_description.text.trim().isEmpty) {
        _description.text = result.description;
      }
    }
    setState(() => _analyzingImage = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final wardrobe = context.read<WardrobeProvider>();
    await wardrobe.uploadOptimistically(
      image: widget.image,
      name: _name.text.trim().isEmpty ? 'New wardrobe item' : _name.text,
      category: _category.text.trim().isEmpty ? 'other' : _category.text,
      brand: _brand.text,
      color: _color ?? '',
      season: _season,
      formality: _formality,
      description: _description.text,
      tags: _analysis?.tags ?? const [],
      aiAnalysis: _analysis,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    final uploading = wardrobe.uploading;

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
            const SizedBox(height: DesignSystem.spacingXxl),

            Container(
              padding: const EdgeInsets.all(DesignSystem.spacingMd),
              decoration: BoxDecoration(
                color: DesignSystem.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: DesignSystem.primary),
                  SizedBox(width: DesignSystem.spacingMd),
                  Expanded(
                    child: Text(
                      _analyzingImage
                          ? 'AI is identifying the item and auto-filling every detail.'
                          : _analysis != null
                          ? 'Details were auto-filled by AI. Review or edit anything before saving.'
                          : 'AI could not auto-fill this photo. You can still enter the details manually.',
                    ),
                  ),
                  if (_analyzingImage)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DesignSystem.spacingXl),

            // Form section header
            StyleStackSectionHeader(title: 'Item Details'),
            const SizedBox(height: DesignSystem.spacingMd),

            // Item name field
            TextFormField(
              controller: _name,
              enabled: !uploading,
              decoration: const InputDecoration(
                labelText: 'Item name (optional)',
                hintText: 'e.g., Blue Denim Jacket',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: DesignSystem.spacingMd),

            TextFormField(
              controller: _brand,
              enabled: !uploading,
              decoration: const InputDecoration(
                labelText: 'Brand (optional)',
                hintText: 'e.g., Crocs',
                prefixIcon: Icon(Icons.workspace_premium_outlined),
              ),
            ),
            const SizedBox(height: DesignSystem.spacingMd),

            // Two-column row for category and color
            TextFormField(
              controller: _category,
              enabled: !uploading,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.checkroom_outlined),
              ),
            ),
            const SizedBox(height: DesignSystem.spacingXl),

            // Color picker
            StyleStackColorPicker(
              selectedColor: _color,
              onColorSelected: uploading
                  ? (_) {}
                  : (color) => setState(() => _color = color),
              enabled: !uploading,
            ),
            const SizedBox(height: DesignSystem.spacingXl),

            // Season dropdown
            DropdownButtonFormField<String>(
              key: ValueKey('season-$_season'),
              initialValue: _season,
              decoration: const InputDecoration(
                labelText: 'Season',
                prefixIcon: Icon(Icons.calendar_month),
              ),
              items: const ['Summer', 'Winter', 'Spring', 'Autumn', 'All']
                  .map(
                    (value) => DropdownMenuItem(
                      value: value.toLowerCase(),
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: uploading
                  ? null
                  : (value) => setState(() => _season = value),
            ),
            const SizedBox(height: DesignSystem.spacingMd),

            // Formality dropdown
            DropdownButtonFormField<String>(
              key: ValueKey('formality-$_formality'),
              initialValue: _formality,
              decoration: const InputDecoration(
                labelText: 'Formality',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              items: const ['Formal', 'Semi-formal', 'Casual', 'Sporty']
                  .map(
                    (value) => DropdownMenuItem(
                      value: value.toLowerCase(),
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: uploading
                  ? null
                  : (value) => setState(() => _formality = value),
            ),
            const SizedBox(height: DesignSystem.spacingMd),

            // Description field
            TextFormField(
              controller: _description,
              enabled: !uploading,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Add any additional notes about this item',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: DesignSystem.spacingXxl),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: uploading ? null : widget.onRetake,
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
                    onPressed: uploading || _analyzingImage ? null : _save,
                    icon: uploading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      _analyzingImage
                          ? 'Auto-filling…'
                          : uploading
                          ? 'Saving…'
                          : 'Save item',
                    ),
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
