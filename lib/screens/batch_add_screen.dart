import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../providers/wardrobe_provider.dart';

const int maxBatchImages = 10;

class BatchAddScreen extends StatefulWidget {
  const BatchAddScreen({super.key, required this.images});

  final List<File> images;

  @override
  State<BatchAddScreen> createState() => _BatchAddScreenState();
}

class _BatchAddScreenState extends State<BatchAddScreen> {
  late final List<_BatchItemDraft> _drafts;
  final _pageController = PageController();
  int _page = 0;
  bool _submitting = false;

  bool get _uploading => _submitting;

  @override
  void initState() {
    super.initState();
    _drafts = widget.images
        .take(maxBatchImages)
        .map(_BatchItemDraft.new)
        .toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _toggleSelected(int index, bool selected) {
    if (_uploading) return;
    if (!selected && _drafts.where((draft) => draft.selected).length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keep at least one photo selected.')),
      );
      return;
    }
    setState(() => _drafts[index].selected = selected);
  }

  void _saveAll() {
    if (_uploading) return;
    final wardrobe = context.read<WardrobeProvider>();
    final selected = _drafts.where((draft) => draft.selected).toList();
    setState(() => _submitting = true);
    for (var index = 0; index < _drafts.length; index++) {
      final draft = _drafts[index];
      if (!draft.selected) continue;
      unawaited(
        wardrobe.uploadOptimistically(
          image: draft.image,
          name: draft.name.text.trim().isEmpty
              ? 'New wardrobe item ${index + 1}'
              : draft.name.text,
          category: draft.category.text.trim().isEmpty
              ? 'other'
              : draft.category.text,
          brand: draft.brand.text,
          color: draft.color.text,
          season: draft.season,
          formality: draft.formality,
          description: draft.description.text,
          tags: const [],
        ),
      );
    }
    Navigator.pop(context, selected.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add multiple items')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Upload up to $maxBatchImages photos. StyleStack processes and tags them in the background.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(_drafts.length, (index) {
                      final draft = _drafts[index];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          ),
                          child: Container(
                            height: 58,
                            margin: EdgeInsets.only(
                              right: index == _drafts.length - 1 ? 0 : 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _page == index
                                    ? DesignSystem.primary
                                    : DesignSystem.border,
                                width: _page == index ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(draft.image, fit: BoxFit.contain),
                                  if (!draft.selected)
                                    ColoredBox(
                                      color: Colors.white.withValues(
                                        alpha: .72,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _drafts.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _BatchDraftPage(
                  draft: _drafts[index],
                  index: index,
                  total: _drafts.length,
                  disabled: _uploading,
                  onSelected: (value) => _toggleSelected(index, value),
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: DesignSystem.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _uploading ? null : _saveAll,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add now'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchDraftPage extends StatelessWidget {
  const _BatchDraftPage({
    required this.draft,
    required this.index,
    required this.total,
    required this.disabled,
    required this.onSelected,
    required this.onChanged,
  });

  final _BatchItemDraft draft;
  final int index;
  final int total;
  final bool disabled;
  final ValueChanged<bool> onSelected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Photo ${index + 1} of $total',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Checkbox(
            value: draft.selected,
            onChanged: disabled
                ? null
                : (value) => onSelected(value ?? draft.selected),
          ),
          const Text('Include'),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        height: 260,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
          border: Border.all(color: DesignSystem.border),
        ),
        child: Image.file(draft.image, fit: BoxFit.contain),
      ),
      if (draft.error != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DesignSystem.error.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: DesignSystem.error),
              const SizedBox(width: 8),
              Expanded(child: Text(draft.error!)),
            ],
          ),
        ),
      ],
      const SizedBox(height: 18),
      TextField(
        controller: draft.name,
        enabled: !disabled && draft.selected,
        decoration: const InputDecoration(
          labelText: 'Item name (optional)',
          prefixIcon: Icon(Icons.label_outline),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: draft.brand,
        enabled: !disabled && draft.selected,
        decoration: const InputDecoration(
          labelText: 'Brand',
          prefixIcon: Icon(Icons.workspace_premium_outlined),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: draft.category,
        enabled: !disabled && draft.selected,
        decoration: const InputDecoration(
          labelText: 'Category',
          prefixIcon: Icon(Icons.checkroom_outlined),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: draft.color,
        enabled: !disabled && draft.selected,
        decoration: const InputDecoration(
          labelText: 'Color',
          prefixIcon: Icon(Icons.palette_outlined),
        ),
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        key: ValueKey('season-${draft.season}'),
        initialValue: draft.season,
        decoration: const InputDecoration(
          labelText: 'Season',
          prefixIcon: Icon(Icons.calendar_month),
        ),
        items: const ['summer', 'winter', 'spring', 'autumn', 'all']
            .map(
              (value) =>
                  DropdownMenuItem(value: value, child: Text(_title(value))),
            )
            .toList(),
        onChanged: disabled || !draft.selected
            ? null
            : (value) {
                draft.season = value;
                onChanged();
              },
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        key: ValueKey('formality-${draft.formality}'),
        initialValue: draft.formality,
        decoration: const InputDecoration(
          labelText: 'Formality',
          prefixIcon: Icon(Icons.event_outlined),
        ),
        items: const ['formal', 'semi-formal', 'casual', 'sporty']
            .map(
              (value) =>
                  DropdownMenuItem(value: value, child: Text(_title(value))),
            )
            .toList(),
        onChanged: disabled || !draft.selected
            ? null
            : (value) {
                draft.formality = value;
                onChanged();
              },
      ),
      const SizedBox(height: 14),
      TextField(
        controller: draft.description,
        enabled: !disabled && draft.selected,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'Description',
          prefixIcon: Icon(Icons.description_outlined),
          alignLabelWithHint: true,
        ),
      ),
    ],
  );

  static String _title(String value) => value
      .split('-')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join('-');
}

class _BatchItemDraft {
  _BatchItemDraft(this.image);

  final File image;
  final name = TextEditingController();
  final brand = TextEditingController();
  final category = TextEditingController();
  final color = TextEditingController();
  final description = TextEditingController();
  String? season;
  String? formality;
  String? error;
  bool selected = true;
  void dispose() {
    name.dispose();
    brand.dispose();
    category.dispose();
    color.dispose();
    description.dispose();
  }
}
