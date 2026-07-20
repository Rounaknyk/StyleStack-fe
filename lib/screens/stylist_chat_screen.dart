import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../config/custom_widgets.dart';
import '../config/design_system.dart';
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
  static const _starterPrompts = [
    'Interview',
    'Date night',
    'Wedding guest',
    'Casual day out',
  ];

  final _message = TextEditingController();
  final _api = ApiService();
  Outfit? _outfit;
  bool _loading = false;
  String? _error;
  String? _submittedPrompt;

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
      _outfit = null;
      _submittedPrompt = message;
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

  void _useStarterPrompt(String prompt) {
    _message.text = switch (prompt) {
      'Interview' =>
        'I have an interview and want to look polished and confident.',
      'Date night' => 'Style me for a date night. I want to feel confident.',
      'Wedding guest' => 'I need an elegant wedding guest outfit.',
      _ => 'Create a relaxed but intentional outfit for a casual day out.',
    };
    _message.selection = TextSelection.collapsed(offset: _message.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your stylist')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    _StylistGreeting(compact: _loading || _outfit != null),
                    const SizedBox(height: 22),
                    _FocusedStylistPrompt(
                      controller: _message,
                      loading: _loading,
                      starterPrompts: _starterPrompts,
                      onStarterSelected: _useStarterPrompt,
                      onSubmit: _ask,
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 480),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final movement = Tween<Offset>(
                          begin: const Offset(0, 0.045),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: movement,
                            child: child,
                          ),
                        );
                      },
                      child: _resultContent(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultContent() {
    if (_loading) {
      return const StyleStackLoadingIndicator(
        key: ValueKey('stylist-loading'),
        message: 'Your stylist is curating the details…',
        animationAsset: StyleStackMotionAssets.outfitDesigner,
        animationSize: 210,
        padding: EdgeInsets.symmetric(vertical: 8),
      );
    }
    if (_error != null) {
      return _StylistError(
        key: const ValueKey('stylist-error'),
        message: _error!,
        onRetry: _ask,
      );
    }
    if (_outfit != null) {
      return _StylistResult(
        key: ValueKey('stylist-result-${_outfit!.id}'),
        outfit: _outfit!,
        request: _submittedPrompt,
      );
    }
    return const SizedBox(key: ValueKey('stylist-idle'));
  }
}

class _StylistGreeting extends StatelessWidget {
  const _StylistGreeting({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        compact ? 14 : 24,
        24,
        compact ? 14 : 22,
      ),
      decoration: BoxDecoration(
        color: DesignSystem.editorialMint,
        borderRadius: BorderRadius.circular(DesignSystem.radiusXxl),
      ),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            width: compact ? 92 : 142,
            height: compact ? 82 : 130,
            child: Lottie.asset(
              StyleStackMotionAssets.outfitDesigner,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
          SizedBox(height: compact ? 4 : 10),
          Text(
            'Hi, I’m your StyleStack stylist.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: DesignSystem.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tell me where you’re going or how you want to feel. '
            'I’ll create the strongest look from clothes you already own.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DesignSystem.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusedStylistPrompt extends StatelessWidget {
  const _FocusedStylistPrompt({
    required this.controller,
    required this.loading,
    required this.starterPrompts,
    required this.onStarterSelected,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool loading;
  final List<String> starterPrompts;
  final ValueChanged<String> onStarterSelected;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignSystem.surface,
        borderRadius: BorderRadius.circular(DesignSystem.radiusXxl),
        border: Border.all(color: DesignSystem.border),
        boxShadow: DesignSystem.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you dressing for?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Add the occasion, dress code, mood, time, or anything that matters.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DesignSystem.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 7,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText:
                  'Example: I have an interview tomorrow and want to look confident…',
              hintStyle: const TextStyle(color: DesignSystem.textTertiary),
              filled: true,
              fillColor: DesignSystem.background,
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: DesignSystem.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: DesignSystem.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final prompt in starterPrompts) ...[
                  ActionChip(
                    label: Text(prompt),
                    onPressed: loading ? null : () => onStarterSelected(prompt),
                    backgroundColor: DesignSystem.surface,
                    side: const BorderSide(color: DesignSystem.border),
                    shape: const StadiumBorder(),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : onSubmit,
              icon: Icon(
                loading
                    ? Icons.hourglass_top_rounded
                    : Icons.auto_awesome_rounded,
              ),
              label: Text(loading ? 'Curating your look…' : 'Create my look'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StylistResult extends StatelessWidget {
  const _StylistResult({super.key, required this.outfit, this.request});
  final Outfit outfit;
  final String? request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your curated edit',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (request != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      request!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: DesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const StyleStackIconBadge(
              icon: Icons.auto_awesome_rounded,
              foregroundColor: DesignSystem.primary,
              backgroundColor: DesignSystem.editorialMint,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ChatOutfitBoard(outfit: outfit),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: DesignSystem.primary,
            borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: DesignSystem.secondary,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Why this works',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                outfit.reasoning,
                style: const TextStyle(color: Colors.white, height: 1.55),
              ),
            ],
          ),
        ),
      ],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
        border: Border.all(color: DesignSystem.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'FROM YOUR WARDROBE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: DesignSystem.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} pieces',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                mainAxisSpacing: 14,
                childAspectRatio: .76,
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
            borderRadius: BorderRadius.circular(16),
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
        const SizedBox(height: 8),
        Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StylistError extends StatelessWidget {
  const _StylistError({
    super.key,
    required this.message,
    required this.onRetry,
  });
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignSystem.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: DesignSystem.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
