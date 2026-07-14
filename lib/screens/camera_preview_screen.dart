import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../config/custom_widgets.dart';
import '../providers/wardrobe_provider.dart';
import 'item_detail_screen.dart';

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
  final _category = TextEditingController();
  final _description = TextEditingController();
  String? _color;
  String? _season;
  String? _formality;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyzeImage());
  }

  Future<void> _analyzeImage() async {
    final wardrobe = context.read<WardrobeProvider>();
    final analysis = await wardrobe.analyzeImage(widget.image);
    if (!mounted) return;
    if (analysis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wardrobe.error ?? 'AI analysis failed.')),
      );
      return;
    }
    setState(() {
      _category.text = analysis.category;
      _color = analysis.color;
      _season = analysis.season;
      _formality = analysis.formality;
      _description.text = analysis.description;
      if (_name.text.trim().isEmpty) {
        final suggestion = '${analysis.color} ${analysis.category}';
        _name.text = suggestion
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add an item name.')));
      return;
    }
    final wardrobe = context.read<WardrobeProvider>();
    final created = await wardrobe.upload(
      image: widget.image,
      name: _name.text,
      category: _category.text.trim().isEmpty ? 'other' : _category.text,
      color: _color ?? '',
      season: _season,
      formality: _formality,
      description: _description.text,
    );
    if (!mounted) return;
    if (created != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: created.id)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wardrobe.error ?? 'Upload failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    final uploading = wardrobe.uploading;
    final analyzing = wardrobe.analyzing;

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
                  child: Image.file(widget.image, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: DesignSystem.spacingXxl),

            // AI analyzing indicator
            if (analyzing) ...[
              Container(
                padding: const EdgeInsets.all(DesignSystem.spacingMd),
                decoration: BoxDecoration(
                  color: DesignSystem.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
                  border: Border.all(
                    color: DesignSystem.secondary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    const LinearProgressIndicator(minHeight: 3),
                    const SizedBox(height: DesignSystem.spacingMd),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: DesignSystem.iconSizeSmall,
                          color: DesignSystem.primary,
                        ),
                        const SizedBox(width: DesignSystem.spacingMd),
                        Expanded(
                          child: Text(
                            'AI is analyzing this item…',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignSystem.spacingXl),
            ],

            // Form section header
            StyleStackSectionHeader(title: 'Item Details'),
            const SizedBox(height: DesignSystem.spacingMd),

            // Item name field
            TextFormField(
              controller: _name,
              enabled: !uploading,
              decoration: const InputDecoration(
                labelText: 'Item name *',
                hintText: 'e.g., Blue Denim Jacket',
                prefixIcon: Icon(Icons.label_outline),
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
                    onPressed: uploading ? null : _save,
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
                    label: Text(uploading ? 'Uploading…' : 'Save item'),
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
