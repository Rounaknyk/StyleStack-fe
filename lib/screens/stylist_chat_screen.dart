import 'package:flutter/material.dart';

import '../config/design_system.dart';
import '../config/custom_widgets.dart';
import '../models/outfit.dart';
import '../models/wardrobe_item.dart';
import '../services/api_service.dart';

class StylistChatScreen extends StatefulWidget {
  const StylistChatScreen({super.key, required this.city});
  final String city;

  @override
  State<StylistChatScreen> createState() => _StylistChatScreenState();
}

class _StylistChatScreenState extends State<StylistChatScreen> {
  final _message = TextEditingController();
  final _api = ApiService();
  Outfit? _outfit;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final message = _message.text.trim();
    if (message.length < 3 || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.askStylist(message: message, city: widget.city);
      if (mounted) setState(() => _outfit = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach your stylist.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask your stylist')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
          children: [
            Text(
              'Tell me where you are going',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Describe the event, dress code, mood, or anything you want to feel like. I’ll style it from your wardrobe.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: DesignSystem.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _ask(),
              decoration: const InputDecoration(
                hintText: 'I have an interview tomorrow at 11 AM…',
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _ask,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_loading ? 'Styling your look…' : 'Suggest my outfit'),
            ),
            if (_loading)
              const StyleStackLoadingIndicator(
                message: 'Your stylist is curating options…',
                animationAsset: StyleStackMotionAssets.outfitDesigner,
                animationSize: 220,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: DesignSystem.error)),
            ],
            if (_outfit != null) ...[
              const SizedBox(height: 26),
              Text(
                'Your stylist suggests',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              _ChatOutfitBoard(outfit: _outfit!),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Why this works',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(_outfit!.reasoning),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatOutfitBoard extends StatelessWidget {
  const _ChatOutfitBoard({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final items = outfit.items.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
        border: Border.all(color: DesignSystem.border),
        boxShadow: DesignSystem.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: DesignSystem.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  outfit.occasion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('${items.length} pieces', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text('No wardrobe pieces were selected.')
          else
            GridView.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .72,
              ),
              itemBuilder: (_, index) => _ChatOutfitPiece(item: items[index]),
            ),
        ],
      ),
    );
  }
}

class _ChatOutfitPiece extends StatelessWidget {
  const _ChatOutfitPiece({required this.item});
  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.gridImageUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.white,
              child: imageUrl == null
                  ? const Icon(Icons.checkroom_outlined, size: 34)
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.checkroom_outlined),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
