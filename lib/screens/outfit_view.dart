import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/custom_widgets.dart';
import '../config/design_system.dart';
import '../models/calendar_models.dart';
import '../models/outfit.dart';
import '../models/wardrobe_item.dart';
import '../providers/auth_provider.dart';
import '../providers/mvp_provider.dart';
import 'saved_styles_screen.dart';
import 'stylist_chat_screen.dart';

class DailyOutfitView extends StatefulWidget {
  const DailyOutfitView({
    super.key,
    required this.onOutfitSelfie,
    required this.onOpenHistory,
    required this.onOpenProfile,
    required this.onCreateStyle,
    required this.onAddItem,
  });

  final Future<void> Function() onOutfitSelfie;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenProfile;
  final Future<void> Function() onCreateStyle;
  final Future<void> Function() onAddItem;

  @override
  State<DailyOutfitView> createState() => _DailyOutfitViewState();
}

class _DailyOutfitViewState extends State<DailyOutfitView> {
  bool _bootstrapped = false;
  bool _bootstrapping = true;
  bool _autoRequestScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap({bool refresh = false}) async {
    if (_bootstrapped && !refresh) return;
    _bootstrapped = true;
    _bootstrapping = true;
    try {
      final mvp = context.read<MvpProvider>();
      await Future.wait([
        mvp.loadPreferences(force: refresh),
        mvp.loadTodayEvents(force: refresh),
      ]);
      if (!mounted) return;
      final city = mvp.preferences?.city?.trim() ?? '';
      if (city.isEmpty) return;
      final event = mvp.priorityEvent;
      if (event != null) {
        // Event and everyday looks are independent. Start both together so
        // the slower AI request for one never delays the other.
        await Future.wait([
          mvp.generateEventOutfit(city, event),
          if (refresh || mvp.outfit == null) mvp.generateOutfit(city, 'daily'),
        ]);
      } else if (refresh || mvp.outfit == null) {
        await mvp.generateOutfit(city, 'daily');
      }
      _autoRequestScheduled = true;
    } finally {
      _bootstrapping = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _newLook() async {
    HapticFeedback.selectionClick();
    final mvp = context.read<MvpProvider>();
    final city = mvp.preferences?.city?.trim() ?? '';
    if (city.isEmpty) {
      widget.onOpenProfile();
      return;
    }
    final ok = await mvp.generateOutfit(city, 'daily alternative');
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mvp.error ?? 'Could not create a new look.')),
    );
  }

  Future<void> _newEventLook(StyleCalendarEvent event) async {
    HapticFeedback.selectionClick();
    final mvp = context.read<MvpProvider>();
    final city = mvp.preferences?.city?.trim() ?? '';
    if (city.isEmpty) {
      widget.onOpenProfile();
      return;
    }
    final ok = await mvp.generateEventOutfit(city, event, force: true);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mvp.eventError ?? 'Could not restyle this event.'),
      ),
    );
  }

  Future<void> _showLogSheet(Outfit target, {required String label}) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How would you like to log it?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'A selfie creates your visual outfit history too.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  widget.onOutfitSelfie();
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take an outfit selfie'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final provider = context.read<MvpProvider>();
                  final ok = await provider.markOutfitWorn(target);
                  if (!mounted) return;
                  if (ok) {
                    HapticFeedback.heavyImpact();
                    await _showLoggedSuccess(target, label: label);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.error ?? 'Could not log this outfit.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Yes, I wore this'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLoggedSuccess(
    Outfit target, {
    required String label,
  }) async {
    final items = target.items;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: DesignSystem.success,
          size: 48,
        ),
        title: const Text('Outfit logged'),
        content: Text(
          items.isEmpty
              ? '$label is in your history.'
              : '${items.map((item) => item.name).join(', ')} marked as worn today.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Back to Today'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onOpenHistory();
            },
            child: const Text('View history'),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final mvp = context.watch<MvpProvider>();
    final user = context.watch<AuthProvider>().user;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim().split(' ').first
        : (user?.email?.split('@').first ?? 'there');

    final city = mvp.preferences?.city?.trim() ?? '';
    final priorityEvent = mvp.priorityEvent;
    final canStyle = city.isNotEmpty;
    if (city.isNotEmpty &&
        mvp.outfit == null &&
        !mvp.loadingOutfit &&
        !_bootstrapping &&
        !_autoRequestScheduled) {
      _autoRequestScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await context.read<MvpProvider>().generateOutfit(city, 'daily');
      });
    }

    if (mvp.loadingPreferences && !mvp.preferencesAttempted) {
      return const _TodaySkeleton();
    }

    return RefreshIndicator(
      onRefresh: () => _bootstrap(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: DesignSystem.primary,
              borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
              gradient: const LinearGradient(
                colors: [DesignSystem.primaryDark, DesignSystem.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  priorityEvent == null
                      ? 'STYLE EDIT  /  TODAY'
                      : 'PRIORITY EDIT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: DesignSystem.secondaryLight,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_greeting()}, $name',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  priorityEvent == null
                      ? 'Your strongest look, edited from your own closet.'
                      : 'You have ${priorityEvent.title} today. Let’s dress for it first.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              final city = mvp.preferences?.city?.trim() ?? '';
              if (city.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StylistChatScreen(city: city),
                  ),
                );
              } else {
                widget.onOpenProfile();
              }
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Ask your stylist anything'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onCreateStyle,
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Create Style'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'My Styles',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedStylesScreen()),
                ),
                icon: const Icon(Icons.collections_bookmark_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (priorityEvent != null) ...[
            _EventHeader(
              event: priorityEvent,
              additionalEvents: mvp.todayEvents.length - 1,
            ),
            const SizedBox(height: 14),
            if (canStyle && mvp.loadingEventOutfit && mvp.eventOutfit == null)
              const _EventOutfitSkeleton()
            else if (canStyle && mvp.eventOutfit != null) ...[
              _OutfitBoard(
                items: mvp.eventOutfit!.items,
                title: 'For ${priorityEvent.title}',
              ),
              const SizedBox(height: 14),
              _WhyItWorks(
                reasoning: mvp.eventOutfit!.reasoning,
                title: 'Why this works for ${priorityEvent.title}',
              ),
              const SizedBox(height: 18),
              StyleStackButton(
                label: 'Log This Event Outfit',
                icon: Icons.check_circle_outline,
                onPressed: () => _showLogSheet(
                  mvp.eventOutfit!,
                  label: 'Your ${priorityEvent.title} look',
                ),
              ),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: mvp.loadingEventOutfit
                    ? null
                    : () => _newEventLook(priorityEvent),
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  mvp.loadingEventOutfit
                      ? 'Curating another event look…'
                      : 'Try another event look',
                ),
              ),
              if (mvp.loadingEventOutfit)
                const StyleStackLoadingIndicator(
                  message: 'Refining your event look…',
                  animationAsset: StyleStackMotionAssets.outfitDesigner,
                  animationSize: 150,
                  padding: EdgeInsets.only(top: 8),
                ),
            ] else if (canStyle && mvp.eventError != null)
              _InlineRetry(
                message: mvp.eventError!,
                onRetry: () => _newEventLook(priorityEvent),
              ),
            if (canStyle) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your everyday look',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const Text('For the rest of today'),
                ],
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 6),
          ],
          if ((mvp.preferences?.city?.trim() ?? '').isEmpty)
            _WardrobeGate(
              icon: Icons.location_on_outlined,
              title: 'Start with your wardrobe',
              body:
                  'Add your first pieces to unlock styling. Location is optional and only improves weather-aware suggestions.',
              action: 'Add your first item',
              onPressed: widget.onAddItem,
              secondaryAction: 'Enable location',
              onSecondaryPressed: widget.onOpenProfile,
            )
          else if (mvp.loadingOutfit && mvp.outfit == null)
            const _OutfitSkeleton()
          else if (mvp.outfit == null)
            _WardrobeGate(
              icon: Icons.checkroom_outlined,
              title: 'Build your style library',
              body:
                  'Add pieces from your closet and your stylist will create looks from what you actually own.',
              action: 'Add items',
              onPressed: widget.onAddItem,
              secondaryAction: 'Try again',
              onSecondaryPressed: _newLook,
            )
          else ...[
            _WeatherStrip(outfit: mvp.outfit!),
            const SizedBox(height: 14),
            _OutfitBoard(items: mvp.outfit!.items),
            const SizedBox(height: 14),
            _WhyItWorks(reasoning: mvp.outfit!.reasoning),
            const SizedBox(height: 18),
            _InspirationStrip(images: mvp.outfit!.inspirationImages),
            const SizedBox(height: 18),
            StyleStackButton(
              label: 'Log This Outfit',
              icon: Icons.check_circle_outline,
              onPressed: () =>
                  _showLogSheet(mvp.outfit!, label: 'Today\'s look'),
            ),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: mvp.loadingOutfit ? null : _newLook,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                mvp.loadingOutfit
                    ? 'Curating a new look…'
                    : 'Show me a new look',
              ),
            ),
            if (mvp.loadingOutfit)
              const StyleStackLoadingIndicator(
                message: 'Your stylist is reworking the edit…',
                animationAsset: StyleStackMotionAssets.outfitDesigner,
                animationSize: 150,
                padding: EdgeInsets.only(top: 8),
              ),
          ],
          const SizedBox(height: 24),
          _OutfitSelfieExplainer(onPressed: widget.onOutfitSelfie),
        ],
      ),
    );
  }
}

class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.event, required this.additionalEvents});
  final StyleCalendarEvent event;
  final int additionalEvents;

  String _timeLabel(BuildContext context) {
    if (event.allDay) return 'All day';
    final localizations = MaterialLocalizations.of(context);
    final start = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(event.startAt),
    );
    if (event.endAt == null) return start;
    final end = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(event.endAt!),
    );
    return '$start – $end';
  }

  String _statusLabel() {
    if (event.allDay) return 'Today’s priority';
    final now = DateTime.now();
    if (!event.startAt.isAfter(now)) return 'Happening now';
    final difference = event.startAt.difference(now);
    if (difference.inMinutes < 60) {
      return 'Starts in ${difference.inMinutes.clamp(1, 59)} min';
    }
    if (difference.inHours < 6) return 'Starts in ${difference.inHours} hr';
    return 'Coming up today';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: DesignSystem.accent.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
      border: Border.all(color: DesignSystem.accent.withValues(alpha: .55)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: DesignSystem.primary,
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'EVENT PRIORITY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
            ),
            const Spacer(),
            Text(
              _statusLabel(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DesignSystem.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 7,
          children: [
            _EventDetail(icon: Icons.schedule, label: _timeLabel(context)),
            if ((event.location?.trim() ?? '').isNotEmpty)
              _EventDetail(
                icon: Icons.location_on_outlined,
                label: event.location!.trim(),
              ),
            _EventDetail(
              icon: event.source == 'google'
                  ? Icons.event_available
                  : Icons.edit_calendar_outlined,
              label: event.source == 'google'
                  ? 'Google Calendar'
                  : 'StyleStack',
            ),
          ],
        ),
        if (additionalEvents > 0) ...[
          const SizedBox(height: 10),
          Text(
            '+$additionalEvents more ${additionalEvents == 1 ? 'event' : 'events'} today',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}

class _EventDetail extends StatelessWidget {
  const _EventDetail({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: DesignSystem.textSecondary),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _EventOutfitSkeleton extends StatelessWidget {
  const _EventOutfitSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 300,
    decoration: BoxDecoration(
      color: DesignSystem.surfaceAlt,
      borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
    ),
    child: const StyleStackLoadingIndicator(
      message: 'Curating your event look…',
      animationAsset: StyleStackMotionAssets.outfitDesigner,
      animationSize: 220,
      padding: EdgeInsets.all(12),
    ),
  );
}

class _InlineRetry extends StatelessWidget {
  const _InlineRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StyleStackCard(
    child: Row(
      children: [
        const Icon(Icons.error_outline),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _WeatherStrip extends StatelessWidget {
  const _WeatherStrip({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final temperature = outfit.weather['temperature_c'];
    final description = outfit.weather['description']?.toString();
    final city = outfit.weather['city']?.toString();
    final details = <String>[];
    if (temperature != null) details.add('$temperature°C');
    if (description != null) details.add(description);
    if (city != null) details.add(city);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: DesignSystem.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_cloudy_outlined, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              details.join('  •  '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const Text('Comfort checked', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _OutfitBoard extends StatelessWidget {
  const _OutfitBoard({required this.items, this.title = 'Today’s outfit'});
  final List<WardrobeItem> items;
  final String title;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(6).toList();
    final columns = visibleItems.length <= 2 ? 2 : 3;
    final rows = (visibleItems.length / (columns == 0 ? 1 : columns)).ceil();
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length} pieces',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visibleItems.isEmpty)
            const Text('No pieces were selected.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                const aspectRatio = .72;
                final itemWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                final itemHeight = itemWidth / aspectRatio;
                final gridHeight =
                    itemHeight * rows +
                    spacing * (rows - 1).clamp(0, rows).toDouble();
                return SizedBox(
                  height: gridHeight,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: aspectRatio,
                    ),
                    itemBuilder: (context, index) =>
                        _OutfitPiece(item: visibleItems[index]),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _OutfitPiece extends StatelessWidget {
  const _OutfitPiece({required this.item});
  final WardrobeItem item;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Colors.white,
            child: item.imageUrl == null
                ? const Icon(Icons.checkroom_outlined, size: 34)
                : Image.network(
                    item.imageUrl!,
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
          color: DesignSystem.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _WhyItWorks extends StatelessWidget {
  const _WhyItWorks({required this.reasoning, this.title = 'Why this works'});
  final String reasoning;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [DesignSystem.primary, DesignSystem.primaryLight],
      ),
      borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_outline, color: DesignSystem.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                reasoning,
                style: const TextStyle(color: Colors.white, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InspirationStrip extends StatelessWidget {
  const _InspirationStrip({required this.images});
  final List<Map<String, dynamic>> images;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('See the vibe', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(
        'Open a general style moodboard inspired by this look.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () {
          if (images.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('A style moodboard is unavailable right now.'),
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _VibeMoodboardScreen(images: images),
            ),
          );
        },
        icon: const Icon(Icons.auto_awesome_outlined),
        label: const Text('See the vibe'),
      ),
    ],
  );
}

class _VibeMoodboardScreen extends StatelessWidget {
  const _VibeMoodboardScreen({required this.images});
  final List<Map<String, dynamic>> images;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('The vibe')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DesignSystem.secondary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: DesignSystem.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This is a moodboard, not an exact outfit match. These editorial references use broad colour, occasion and style cues. Use them for the overall energy, silhouette and styling direction; the wardrobe pieces on Today remain your actual recommendation.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...images.map((image) {
          final url = image['image_url']?.toString();
          if (url == null || url.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: CachedNetworkImage(
                  imageUrl: url,
                  cacheKey: 'style-vibe-${image['id'] ?? url}',
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(
                    color: DesignSystem.surfaceAlt,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => const ColoredBox(
                    color: DesignSystem.surfaceAlt,
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ),
  );
}

class _OutfitSelfieExplainer extends StatelessWidget {
  const _OutfitSelfieExplainer({required this.onPressed});
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: DesignSystem.surface,
      borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
      border: Border.all(color: DesignSystem.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DesignSystem.primary.withValues(alpha: .09),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: DesignSystem.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Teach your stylist what you actually wear',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Take one outfit selfie after getting dressed. StyleStack identifies visible pieces, asks you to confirm every match, logs the confirmed items as worn, and builds your private visual outfit history. This helps avoid repetitive suggestions.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Take an outfit selfie'),
        ),
      ],
    ),
  );
}

class _WardrobeGate extends StatelessWidget {
  const _WardrobeGate({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onPressed,
    this.secondaryAction,
    this.onSecondaryPressed,
  });
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onPressed;
  final String? secondaryAction;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) => StyleStackCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: DesignSystem.primary.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: DesignSystem.primary),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(action),
          ),
          if (secondaryAction != null && onSecondaryPressed != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onSecondaryPressed,
              child: Text(secondaryAction!),
            ),
          ],
        ],
      ),
    ),
  );
}

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 28, 18, 120),
    children: const [
      SizedBox(height: 90),
      StyleStackLoadingIndicator(
        message: 'Preparing today’s edit…',
        animationSize: 210,
      ),
    ],
  );
}

class _OutfitSkeleton extends StatelessWidget {
  const _OutfitSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    height: 340,
    decoration: BoxDecoration(
      color: DesignSystem.surface,
      borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
      border: Border.all(color: DesignSystem.border),
    ),
    child: const StyleStackLoadingIndicator(
      message: 'Your stylist is curating a look…',
      animationAsset: StyleStackMotionAssets.outfitDesigner,
      animationSize: 250,
      padding: EdgeInsets.all(12),
    ),
  );
}
