import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../config/custom_widgets.dart';
import '../models/wardrobe_item.dart';
import '../providers/wardrobe_provider.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _season = TextEditingController();
  final _formality = TextEditingController();
  final _description = TextEditingController();
  String? _color;
  WardrobeItem? _item;
  Timer? _pollTimer;
  bool _saving = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final item = await context.read<WardrobeProvider>().refreshItem(
      widget.itemId,
    );
    if (!mounted || item == null) return;
    setState(() => _item = item);
    _populateEditableFields(item);
    if (item.aiTagStatus == 'pending' || item.aiTagStatus == 'processing') {
      _pollTimer ??= Timer.periodic(const Duration(seconds: 2), (_) => _load());
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  void _populateEditableFields(WardrobeItem item) {
    if (!_seeded) {
      _name.text = item.name;
      _category.text = item.category.toLowerCase() == 'other'
          ? ''
          : item.category;
      _color = item.color;
      _season.text = item.seasons.isEmpty ? '' : item.seasons.first;
      _formality.text = item.formality ?? '';
      _description.text = item.description ?? '';
      _seeded = true;
    }
    if (_category.text.trim().isEmpty && item.aiCategory != null) {
      _category.text = item.aiCategory!;
    }
    if ((_color == null || _color!.trim().isEmpty) && item.aiColor != null) {
      _color = item.aiColor!;
    }
    if (_season.text.trim().isEmpty && item.aiSeason != null) {
      _season.text = item.aiSeason!;
    }
    if (_formality.text.trim().isEmpty && item.aiFormality != null) {
      _formality.text = item.aiFormality!;
    }
    if (_description.text.trim().isEmpty && item.aiDescription != null) {
      _description.text = item.aiDescription!;
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _category.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and category are required.')),
      );
      return;
    }
    setState(() => _saving = true);
    final item = await context.read<WardrobeProvider>().updateItem(
      widget.itemId,
      {
        'name': _name.text.trim(),
        'category': _category.text.trim(),
        'color': _color == null || _color!.trim().isEmpty
            ? null
            : _color!.trim(),
        'season': _season.text.trim().isEmpty
            ? <String>[]
            : [_season.text.trim().toLowerCase()],
        'formality': _formality.text.trim().isEmpty
            ? null
            : _formality.text.trim().toLowerCase(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
      },
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (item != null) _item = item;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null ? 'Could not save changes.' : 'Item updated.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    for (final controller in [
      _name,
      _category,
      _season,
      _formality,
      _description,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item details'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: item == null
          ? const StyleStackLoadingIndicator()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                DesignSystem.spacingLg,
                DesignSystem.spacingSm,
                DesignSystem.spacingLg,
                DesignSystem.spacingXxl,
              ),
              children: [
                // Item image
                ClipRRect(
                  borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      color: DesignSystem.surfaceAlt,
                      child: item.imageUrl == null
                          ? const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: DesignSystem.iconSizeXxl,
                                color: DesignSystem.textTertiary,
                              ),
                            )
                          : Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: DesignSystem.spacingXxl),

                // AI Result Card
                _AiResultCard(item: item),
                const SizedBox(height: DesignSystem.spacingXxl),

                // Edit section
                StyleStackSectionHeader(title: 'Edit Details'),
                const SizedBox(height: DesignSystem.spacingMd),

                // Name field
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: DesignSystem.spacingMd),

                // Category and Color row
                TextFormField(
                  controller: _category,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: Icon(Icons.checkroom_outlined),
                  ),
                ),
                const SizedBox(height: DesignSystem.spacingXl),

                // Color picker
                StyleStackColorPicker(
                  selectedColor: _color,
                  onColorSelected: _saving
                      ? (_) {}
                      : (color) => setState(() => _color = color),
                  enabled: !_saving,
                ),
                const SizedBox(height: DesignSystem.spacingXl),

                // Season and Formality row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _season,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Season',
                          prefixIcon: Icon(Icons.calendar_month),
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignSystem.spacingMd),
                    Expanded(
                      child: TextFormField(
                        controller: _formality,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Formality',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignSystem.spacingMd),

                // Description field
                TextFormField(
                  controller: _description,
                  enabled: !_saving,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
    );
  }
}

class _AiResultCard extends StatelessWidget {
  const _AiResultCard({required this.item});
  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    final processing =
        item.aiTagStatus == 'pending' || item.aiTagStatus == 'processing';
    final success = item.aiTagStatus == 'completed';

    return StyleStackCard(
      backgroundColor: processing
          ? DesignSystem.secondary.withOpacity(0.08)
          : success
          ? DesignSystem.success.withOpacity(0.08)
          : DesignSystem.error.withOpacity(0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignSystem.spacingSm),
                decoration: BoxDecoration(
                  color: processing
                      ? DesignSystem.secondary
                      : success
                      ? DesignSystem.success
                      : DesignSystem.error,
                  borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
                ),
                child: Icon(
                  processing
                      ? Icons.auto_awesome
                      : success
                      ? Icons.check_circle
                      : Icons.error,
                  color: Colors.white,
                  size: DesignSystem.iconSizeMedium,
                ),
              ),
              const SizedBox(width: DesignSystem.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      processing
                          ? 'AI is analyzing…'
                          : success
                          ? 'AI Suggestions'
                          : 'Analysis Failed',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      processing
                          ? 'Identifying item details'
                          : success
                          ? 'Based on AI analysis'
                          : 'Please review manually',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (processing)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),

          // AI Tags
          if (success) ...[
            const SizedBox(height: DesignSystem.spacingMd),
            Wrap(
              spacing: DesignSystem.spacingSm,
              runSpacing: DesignSystem.spacingSm,
              children: [
                if (item.aiCategory != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSystem.spacingMd,
                      vertical: DesignSystem.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusSm,
                      ),
                    ),
                    child: Text(
                      item.aiCategory!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DesignSystem.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (item.aiColor != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSystem.spacingMd,
                      vertical: DesignSystem.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusSm,
                      ),
                    ),
                    child: Text(
                      item.aiColor!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DesignSystem.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (item.aiSeason != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSystem.spacingMd,
                      vertical: DesignSystem.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusSm,
                      ),
                    ),
                    child: Text(
                      item.aiSeason!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DesignSystem.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (item.aiFormality != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSystem.spacingMd,
                      vertical: DesignSystem.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusSm,
                      ),
                    ),
                    child: Text(
                      item.aiFormality!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DesignSystem.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (item.aiDescription != null) ...[
              const SizedBox(height: DesignSystem.spacingMd),
              Text(
                item.aiDescription!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignSystem.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
