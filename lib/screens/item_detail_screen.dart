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
  static const _seasonOptions = ['summer', 'winter', 'spring', 'autumn', 'all'];
  static const _formalityOptions = [
    'casual',
    'sporty',
    'semi-formal',
    'formal',
  ];
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();
  final _editSectionKey = GlobalKey();
  String? _color;
  String? _season;
  String? _formality;
  WardrobeItem? _item;
  Timer? _pollTimer;
  bool _saving = false;
  bool _retrying = false;
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
      _season = _normalizedSeason(
        item.seasons.isEmpty ? null : item.seasons.first,
      );
      _formality = _normalizedFormality(item.formality);
      _description.text = item.description ?? '';
      _seeded = true;
    }
    if (_category.text.trim().isEmpty && item.aiCategory != null) {
      _category.text = item.aiCategory!;
    }
    if ((_color == null || _color!.trim().isEmpty) && item.aiColor != null) {
      _color = item.aiColor!;
    }
    if (_season == null && item.aiSeason != null) {
      _season = _normalizedSeason(item.aiSeason);
    }
    if (_formality == null && item.aiFormality != null) {
      _formality = _normalizedFormality(item.aiFormality);
    }
    if (_description.text.trim().isEmpty && item.aiDescription != null) {
      _description.text = item.aiDescription!;
    }
  }

  String? _normalizedSeason(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'fall') return 'autumn';
    return _seasonOptions.contains(normalized) ? normalized : null;
  }

  String? _normalizedFormality(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'smart casual' || normalized == 'smart-casual') {
      return 'semi-formal';
    }
    return _formalityOptions.contains(normalized) ? normalized : null;
  }

  Future<void> _retryAnalysis() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final item = await context.read<WardrobeProvider>().retryItemProcessing(
      widget.itemId,
    );
    if (!mounted) return;
    setState(() {
      _retrying = false;
      if (item != null) _item = item;
    });
    if (item != null) {
      _pollTimer ??= Timer.periodic(const Duration(seconds: 2), (_) => _load());
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<WardrobeProvider>().error ??
              'Could not retry analysis. Enter details manually.',
        ),
      ),
    );
  }

  void _editManually() {
    final editContext = _editSectionKey.currentContext;
    if (editContext == null) return;
    Scrollable.ensureVisible(
      editContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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
        'season': _season == null ? <String>[] : [_season!],
        'formality': _formality,
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
    for (final controller in [_name, _category, _description]) {
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
                      color: Colors.white,
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
                              fit: BoxFit.contain,
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
                _AiResultCard(
                  item: item,
                  retrying: _retrying,
                  onRetry: _retryAnalysis,
                  onEditManually: _editManually,
                ),
                const SizedBox(height: DesignSystem.spacingXxl),

                // Edit section
                KeyedSubtree(
                  key: _editSectionKey,
                  child: const StyleStackSectionHeader(title: 'Edit Details'),
                ),
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
                      child: DropdownButtonFormField<String>(
                        initialValue: _season,
                        items: _seasonOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_titleCase(value)),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _season = value),
                        decoration: const InputDecoration(
                          labelText: 'Season',
                          prefixIcon: Icon(Icons.calendar_month),
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignSystem.spacingMd),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _formality,
                        items: _formalityOptions
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_titleCase(value)),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _formality = value),
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

String _titleCase(String value) => value
    .split(RegExp(r'[- ]'))
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

class _AiResultCard extends StatelessWidget {
  const _AiResultCard({
    required this.item,
    required this.retrying,
    required this.onRetry,
    required this.onEditManually,
  });
  final WardrobeItem item;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback onEditManually;

  @override
  Widget build(BuildContext context) {
    final processing =
        item.aiTagStatus == 'pending' || item.aiTagStatus == 'processing';
    final success = item.aiTagStatus == 'completed';
    final suggestionKeys = <String>{
      for (final value in [
        item.aiCategory,
        item.aiColor,
        item.aiSeason,
        item.aiFormality,
      ])
        if (value != null && value.trim().isNotEmpty)
          value.trim().toLowerCase(),
    };
    final suggestionTags = <String>[];
    for (final tag in item.tags) {
      final trimmedTag = tag.trim();
      if (trimmedTag.isEmpty || !suggestionKeys.add(trimmedTag.toLowerCase())) {
        continue;
      }
      suggestionTags.add(trimmedTag);
    }

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
                for (final tag in suggestionTags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSystem.spacingMd,
                      vertical: DesignSystem.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusSm,
                      ),
                    ),
                    child: Text(
                      tag,
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
          ] else if (!processing) ...[
            const SizedBox(height: DesignSystem.spacingMd),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: retrying ? null : onRetry,
                    icon: retrying
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
                const SizedBox(width: DesignSystem.spacingSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEditManually,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Enter manually'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
