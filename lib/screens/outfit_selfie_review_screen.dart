import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/custom_widgets.dart';
import '../config/design_system.dart';
import '../models/outfit_selfie.dart';
import '../models/wardrobe_item.dart';
import '../providers/wardrobe_provider.dart';
import '../services/api_service.dart';

class OutfitSelfieReviewScreen extends StatefulWidget {
  const OutfitSelfieReviewScreen({
    super.key,
    required this.image,
    required this.onRetake,
  });

  final File image;
  final Future<void> Function() onRetake;

  @override
  State<OutfitSelfieReviewScreen> createState() =>
      _OutfitSelfieReviewScreenState();
}

class _OutfitSelfieReviewScreenState extends State<OutfitSelfieReviewScreen> {
  final _api = ApiService();
  OutfitSelfieAnalysis? _analysis;
  String? _error;
  bool _analyzing = true;
  bool _confirming = false;
  bool _draftClosed = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final result = await _api.analyzeOutfitSelfie(widget.image);
      if (!mounted) return;
      setState(() => _analysis = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not analyze this selfie. Try again.');
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  void _changeMatch(
    OutfitSelfieDetection detection,
    String value,
    List<WardrobeItem> wardrobe,
  ) {
    setState(() {
      if (value == '__none__') {
        detection.wardrobeItemId = null;
        detection.wardrobeItem = null;
      } else {
        detection.wardrobeItemId = value;
        final matches = wardrobe.where((item) => item.id == value);
        detection.wardrobeItem = matches.isEmpty ? null : matches.first;
      }
    });
  }

  Future<void> _confirm() async {
    final analysis = _analysis;
    if (analysis?.selfieId == null || _confirming) return;
    if (!analysis!.detections.any((item) => item.selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one detected item.')),
      );
      return;
    }
    setState(() => _confirming = true);
    try {
      final result = await _api.confirmOutfitSelfie(
        analysis.selfieId!,
        analysis.detections,
      );
      if (!mounted) return;
      await context.read<WardrobeProvider>().loadItems(force: true);
      if (!mounted) return;
      var addMissing = false;
      if (result.unmatchedItems.isNotEmpty) {
        addMissing =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Add missing items?'),
                content: Text(
                  'We logged ${result.loggedItems} matched ${result.loggedItems == 1 ? 'item' : 'items'}. '
                  'These were not found in your wardrobe: ${result.unmatchedItems.join(', ')}. '
                  'Add clear item photos so StyleStack can match them next time.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Add item'),
                  ),
                ],
              ),
            ) ??
            false;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.loggedItems} ${result.loggedItems == 1 ? 'item' : 'items'} logged as worn today.',
            ),
          ),
        );
      }
      setState(() => _draftClosed = true);
      await Future<void>.delayed(Duration.zero);
      if (mounted) Navigator.pop(context, addMissing);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _discardDraft() async {
    final selfieId = _analysis?.selfieId;
    if (_draftClosed) return;
    if (mounted) {
      setState(() => _draftClosed = true);
    } else {
      _draftClosed = true;
    }
    if (selfieId == null) return;
    try {
      await _api.discardOutfitSelfie(selfieId);
    } catch (_) {
      // Cancellation must remain fast; backend cleanup failures are logged.
    }
  }

  Future<void> _retake() async {
    await _discardDraft();
    await widget.onRetake();
  }

  Future<void> _close() async {
    await _discardDraft();
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    final wardrobe = context.watch<WardrobeProvider>().items;
    return PopScope(
      canPop: _draftClosed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _close,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Review your outfit'),
        ),
        body: _analyzing
            ? _AnalyzingView(image: widget.image)
            : _error != null
            ? _RetryView(error: _error!, onRetry: _analyze)
            : analysis == null
            ? _RetryView(error: 'No analysis was returned.', onRetry: _analyze)
            : !analysis.qualityAcceptable
            ? _RetakeView(
                image: widget.image,
                feedback: analysis.qualityFeedback,
                onRetake: _retake,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: Image.file(widget.image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Confirm what you wore',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Text('${analysis.detections.length} detected'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Uncheck anything incorrect or choose a different wardrobe match.',
                  ),
                  const SizedBox(height: 14),
                  ...analysis.detections.map(
                    (detection) => _DetectionCard(
                      detection: detection,
                      wardrobe: wardrobe,
                      onSelected: (selected) =>
                          setState(() => detection.selected = selected),
                      onMatchChanged: (value) =>
                          _changeMatch(detection, value, wardrobe),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: analysis?.qualityAcceptable == true && !_analyzing
            ? SafeArea(
                minimum: const EdgeInsets.all(16),
                child: StyleStackButton(
                  label: 'Log outfit as worn',
                  icon: Icons.check_circle_outline,
                  isLoading: _confirming,
                  onPressed: _confirm,
                ),
              )
            : null,
      ),
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView({required this.image});
  final File image;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.file(image, fit: BoxFit.cover),
      Container(color: Colors.black.withValues(alpha: .55)),
      const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 18),
            Text(
              'Matching your outfit…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Checking colors, shapes and wardrobe details',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({
    required this.detection,
    required this.wardrobe,
    required this.onSelected,
    required this.onMatchChanged,
  });

  final OutfitSelfieDetection detection;
  final List<WardrobeItem> wardrobe;
  final ValueChanged<bool> onSelected;
  final ValueChanged<String> onMatchChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (detection.confidence * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StyleStackCard(
        backgroundColor: detection.selected
            ? DesignSystem.surface
            : DesignSystem.surfaceAlt,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: detection.selected,
                  onChanged: (value) => onSelected(value ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detection.detectedName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        [
                          detection.color,
                          detection.category,
                        ].whereType<String>().join(' • '),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: detection.matched
                        ? DesignSystem.success.withValues(alpha: .12)
                        : DesignSystem.warning.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    detection.matched ? '$percent% match' : 'Not found',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            if (detection.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(detection.description!),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                '${detection.id}-${detection.wardrobeItemId ?? '__none__'}',
              ),
              initialValue: detection.wardrobeItemId ?? '__none__',
              decoration: const InputDecoration(
                labelText: 'Wardrobe match',
                prefixIcon: Icon(Icons.checkroom_outlined),
              ),
              items: [
                const DropdownMenuItem(
                  value: '__none__',
                  child: Text('Not in my wardrobe'),
                ),
                ...wardrobe.map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      '${item.name} • ${item.displayColor ?? item.displayCategory}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: detection.selected
                  ? (value) {
                      if (value != null) onMatchChanged(value);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RetakeView extends StatelessWidget {
  const _RetakeView({
    required this.image,
    required this.feedback,
    required this.onRetake,
  });
  final File image;
  final String feedback;
  final Future<void> Function() onRetake;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(image, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Let’s retake that',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(feedback, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onRetake,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Retake selfie'),
          ),
        ),
      ],
    ),
  );
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.error, required this.onRetry});
  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 54),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
