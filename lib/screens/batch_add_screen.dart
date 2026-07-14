import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../models/clothing_analysis.dart';
import '../providers/wardrobe_provider.dart';

const int maxBatchImages = 3;

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
  int? _analyzingIndex;
  int? _uploadingIndex;

  bool get _analyzing => _analyzingIndex != null;
  bool get _uploading => _uploadingIndex != null;

  @override
  void initState() {
    super.initState();
    _drafts = widget.images
        .take(maxBatchImages)
        .map(_BatchItemDraft.new)
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyzeAll());
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _analyzeAll() async {
    for (var index = 0; index < _drafts.length; index++) {
      if (!mounted) return;
      await _analyze(index);
    }
  }

  Future<void> _analyze(int index) async {
    final draft = _drafts[index];
    if (!draft.selected ||
        draft.analysis != null ||
        (_analyzing && _analyzingIndex != index)) {
      return;
    }
    setState(() {
      _analyzingIndex = index;
      draft.error = null;
    });
    final analysis = await context.read<WardrobeProvider>().analyzeImage(
      draft.image,
    );
    if (!mounted) return;
    setState(() {
      _analyzingIndex = null;
      if (analysis == null) {
        draft.error = 'AI analysis failed. You can enter details manually.';
        return;
      }
      draft.apply(analysis);
    });
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

  Future<void> _saveAll() async {
    if (_analyzing || _uploading) return;
    final selected = _drafts.where((draft) => draft.selected).toList();
    final unnamed = selected.indexWhere(
      (draft) => draft.name.text.trim().isEmpty,
    );
    if (unnamed >= 0) {
      final page = _drafts.indexOf(selected[unnamed]);
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add a name for photo ${page + 1}.')),
      );
      return;
    }

    var uploaded = 0;
    for (var index = 0; index < _drafts.length; index++) {
      final draft = _drafts[index];
      if (!draft.selected || draft.uploaded) continue;
      if (!mounted) return;
      setState(() {
        _uploadingIndex = index;
        draft.error = null;
      });
      final created = await context.read<WardrobeProvider>().upload(
        image: draft.image,
        name: draft.name.text,
        category: draft.category.text.trim().isEmpty
            ? 'other'
            : draft.category.text,
        color: draft.color.text,
        season: draft.season,
        formality: draft.formality,
        description: draft.description.text,
        tags: draft.analysis?.tags ?? const [],
        aiAnalysis: draft.analysis,
      );
      if (!mounted) return;
      if (created == null) {
        setState(() {
          draft.error =
              context.read<WardrobeProvider>().error ?? 'Upload failed.';
        });
      } else {
        setState(() => draft.uploaded = true);
        uploaded++;
      }
    }
    if (!mounted) return;
    setState(() => _uploadingIndex = null);
    final remaining = selected.where((draft) => !draft.uploaded).length;
    if (remaining == 0) {
      Navigator.pop(context, uploaded);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$remaining photo(s) failed. Fix and retry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _drafts.where((draft) => draft.selected).length;
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
                          'AI processes one photo at a time • maximum $maxBatchImages per batch',
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
                                  if (draft.uploaded)
                                    const ColoredBox(
                                      color: Color(0x66008050),
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
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
                  analyzing: _analyzingIndex == index,
                  uploading: _uploadingIndex == index,
                  disabled: _uploading,
                  onSelected: (value) => _toggleSelected(index, value),
                  onRetry: () => _analyze(index),
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
                  onPressed: _analyzing || _uploading ? null : _saveAll,
                  icon: _analyzing || _uploading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _analyzing
                        ? 'Analyzing photo ${(_analyzingIndex ?? 0) + 1} of ${_drafts.length}'
                        : _uploading
                        ? 'Uploading photo ${(_uploadingIndex ?? 0) + 1} of ${_drafts.length}'
                        : 'Add $selectedCount ${selectedCount == 1 ? 'item' : 'items'}',
                  ),
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
    required this.analyzing,
    required this.uploading,
    required this.disabled,
    required this.onSelected,
    required this.onRetry,
    required this.onChanged,
  });

  final _BatchItemDraft draft;
  final int index;
  final int total;
  final bool analyzing;
  final bool uploading;
  final bool disabled;
  final ValueChanged<bool> onSelected;
  final VoidCallback onRetry;
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
      if (analyzing || uploading) ...[
        const SizedBox(height: 12),
        LinearProgressIndicator(
          semanticsLabel: analyzing ? 'Analyzing image' : 'Uploading image',
        ),
      ],
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
              if (draft.analysis == null)
                TextButton(onPressed: onRetry, child: const Text('Retry AI')),
            ],
          ),
        ),
      ],
      const SizedBox(height: 18),
      TextField(
        controller: draft.name,
        enabled: !disabled && draft.selected,
        decoration: const InputDecoration(
          labelText: 'Item name *',
          prefixIcon: Icon(Icons.label_outline),
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
      if (draft.analysis?.tags.isNotEmpty == true) ...[
        const SizedBox(height: 14),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: draft.analysis!.tags
              .map((tag) => Chip(label: Text(tag)))
              .toList(),
        ),
      ],
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
  final category = TextEditingController();
  final color = TextEditingController();
  final description = TextEditingController();
  ClothingAnalysis? analysis;
  String? season;
  String? formality;
  String? error;
  bool selected = true;
  bool uploaded = false;

  void apply(ClothingAnalysis value) {
    analysis = value;
    category.text = value.category;
    color.text = value.color;
    description.text = value.description;
    season = value.season;
    formality = value.formality;
    if (name.text.trim().isEmpty) {
      name.text = _BatchDraftPage._title('${value.color} ${value.category}');
    }
  }

  void dispose() {
    name.dispose();
    category.dispose();
    color.dispose();
    description.dispose();
  }
}
