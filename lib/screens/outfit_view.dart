import 'dart:async';

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
import '../providers/wardrobe_provider.dart';
import 'canvas_style_builder_screen.dart';
import 'saved_styles_screen.dart';

class DailyOutfitView extends StatefulWidget {
  const DailyOutfitView({
    super.key,
    required this.onOutfitSelfie,
    required this.onAddItem,
    required this.onOpenHistory,
    required this.onOpenProfile,
  });

  final Future<void> Function() onOutfitSelfie;
  final Future<void> Function() onAddItem;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenProfile;

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
      final wardrobe = context.read<WardrobeProvider>();
      final mvp = context.read<MvpProvider>();
      await Future.wait([
        wardrobe.loadItems(force: refresh),
        mvp.loadPreferences(force: refresh),
        mvp.loadTodayEvents(force: refresh),
      ]);
      if (!mounted || wardrobe.items.length < 5) return;
      final city = mvp.preferences?.city?.trim() ?? '';
      if (city.isEmpty) return;
      final event = mvp.priorityEvent;
      if (event != null) {
        await mvp.generateEventOutfit(city, event);
      }
      if (!mounted) return;
      if (refresh || mvp.outfit == null) {
        _autoRequestScheduled = true;
        await mvp.generateOutfit(city, 'daily');
      }
      if (!mounted) return;
      if (refresh || mvp.tomorrowOutfit == null) {
        unawaited(mvp.generateTomorrowOutfit(city));
      }
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
    final wardrobe = context.watch<WardrobeProvider>();
    final mvp = context.watch<MvpProvider>();
    final user = context.watch<AuthProvider>().user;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim().split(' ').first
        : (user?.email?.split('@').first ?? 'there');

    final city = mvp.preferences?.city?.trim() ?? '';
    final priorityEvent = mvp.priorityEvent;
    final canStyle = wardrobe.items.length >= 5 && city.isNotEmpty;
    if (wardrobe.items.length >= 5 &&
        city.isNotEmpty &&
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

    if ((wardrobe.loading && !wardrobe.loaded) ||
        (mvp.loadingPreferences && !mvp.preferencesAttempted)) {
      return const _TodaySkeleton();
    }

    return RefreshIndicator(
      onRefresh: () => _bootstrap(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
        children: [
          Text(
            '${_greeting()}, $name',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 5),
          Text(
            priorityEvent == null
                ? 'Here is your strongest look today.'
                : 'You have ${priorityEvent.title} today. Let’s dress for it first.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: DesignSystem.textSecondary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CanvasStyleBuilderScreen(),
                    ),
                  ),
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
                icon: mvp.loadingEventOutfit
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('Try another event look'),
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
          if (wardrobe.items.isEmpty)
            _WardrobeGate(
              icon: Icons.checkroom_outlined,
              title: 'Your personal stylist is ready',
              body:
                  'Add your first pieces and StyleStack will build complete looks for you.',
              action: 'Add your first item',
              onPressed: widget.onAddItem,
            )
          else if (wardrobe.items.length < 5)
            _WardrobeGate(
              icon: Icons.auto_awesome,
              title: '${wardrobe.items.length} of 5 pieces added',
              body:
                  'Add ${5 - wardrobe.items.length} more ${5 - wardrobe.items.length == 1 ? 'piece' : 'pieces'} so your stylist has enough variety.',
              action: 'Add another item',
              onPressed: widget.onAddItem,
            )
          else if ((mvp.preferences?.city?.trim() ?? '').isEmpty)
            _WardrobeGate(
              icon: Icons.location_on_outlined,
              title: 'One quick setup step',
              body:
                  'Enable location once so your look is comfortable for today without making weather the main event.',
              action: 'Set up location',
              onPressed: widget.onOpenProfile,
            )
          else if (mvp.loadingOutfit && mvp.outfit == null)
            const _OutfitSkeleton()
          else if (mvp.outfit == null)
            _WardrobeGate(
              icon: Icons.refresh,
              title: 'Your look needs another try',
              body: mvp.error ?? 'We could not style a look right now.',
              action: 'Try again',
              onPressed: _newLook,
            )
          else ...[
            _WeatherStrip(outfit: mvp.outfit!),
            const SizedBox(height: 14),
            _OutfitBoard(items: mvp.outfit!.items),
            const SizedBox(height: 14),
            _WhyItWorks(reasoning: mvp.outfit!.reasoning),
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
              icon: mvp.loadingOutfit
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Show me a new look'),
            ),
            const SizedBox(height: 28),
            _TomorrowPreview(
              outfit: mvp.tomorrowOutfit,
              loading: mvp.loadingTomorrow,
            ),
          ],
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
    height: 245,
    decoration: BoxDecoration(
      color: DesignSystem.surfaceAlt,
      borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
    ),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Styling your event look…'),
        ],
      ),
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

class _TomorrowPreview extends StatelessWidget {
  const _TomorrowPreview({required this.outfit, required this.loading});
  final Outfit? outfit;
  final bool loading;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Tomorrow’s preview',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 4),
      Text(
        'An early style option. Comfort details refresh tomorrow.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 11),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DesignSystem.surfaceAlt,
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        ),
        child: loading && outfit == null
            ? const LinearProgressIndicator()
            : outfit == null
            ? const Text('Your preview will appear here shortly.')
            : Row(
                children: [
                  ...outfit!.items
                      .take(3)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white,
                            backgroundImage: item.imageUrl == null
                                ? null
                                : NetworkImage(item.imageUrl!),
                            child: item.imageUrl == null
                                ? const Icon(Icons.checkroom_outlined)
                                : null,
                          ),
                        ),
                      ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      outfit!.items.map((item) => item.name).join(' + '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ],
  );
}

class _WardrobeGate extends StatelessWidget {
  const _WardrobeGate({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onPressed,
  });
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onPressed;

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
        ],
      ),
    ),
  );
}

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();
  @override
  Widget build(BuildContext context) => const _SkeletonList();
}

class _OutfitSkeleton extends StatelessWidget {
  const _OutfitSkeleton();
  @override
  Widget build(BuildContext context) => const _SkeletonList(compact: true);
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(18),
    children: List.generate(
      compact ? 3 : 5,
      (index) => Container(
        height: index == 1 ? 260 : 56,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: DesignSystem.surfaceAlt,
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        ),
      ),
    ),
  );
}
