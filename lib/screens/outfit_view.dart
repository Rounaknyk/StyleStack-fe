import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/brand_logo.dart';
import '../config/custom_widgets.dart';
import '../config/design_system.dart';
import '../models/calendar_models.dart';
import '../models/outfit.dart';
import '../models/wardrobe_item.dart';
import '../providers/auth_provider.dart';
import '../providers/access_provider.dart';
import '../providers/mvp_provider.dart';
import '../providers/wardrobe_provider.dart';
import '../services/analytics_service.dart';
import '../services/rewarded_ad_service.dart';
import 'saved_styles_screen.dart';
import 'stylist_chat_screen.dart';
import 'app_help_screen.dart';

class DailyOutfitView extends StatefulWidget {
  const DailyOutfitView({
    super.key,
    required this.onOpenHistory,
    required this.onOpenProfile,
    required this.onCreateStyle,
    required this.onAddItem,
  });

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
  final Set<String> _loggingOutfitIds = {};
  final Set<String> _loggedOutfitIds = {};
  bool _loggingAlternateOutfit = false;

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

    final ads = RewardedAdService.instance;
    final user = context.read<AuthProvider>().user;
    final userId = user?.uid ?? 'anonymous';
    var access = await ads.dailyRefreshAccess(userId);
    var bypassAllowance = false;
    if (!mounted) return;
    if (access == DailyRefreshAccess.rewardedAdRequired) {
      final monetization = context.read<AccessProvider>();
      if (user != null) await monetization.syncUser(user, force: true);
      if (!mounted) return;
      if (monetization.bypassAds) {
        bypassAllowance = true;
        await AnalyticsService.instance.event(
          'rewarded_ad_bypassed',
          parameters: {
            'placement': RewardedPlacement.dailyOutfit.name,
            'reason': 'tester',
          },
        );
      }
    }
    if (access == DailyRefreshAccess.rewardedAdRequired && !bypassAllowance) {
      final accepted = await _confirmExtraLookAd();
      if (!mounted || !accepted) return;
      await AnalyticsService.instance.event(
        'rewarded_ad_offer_accepted',
        parameters: {'placement': RewardedPlacement.dailyOutfit.name},
      );
      final outcome = await ads.show(RewardedPlacement.dailyOutfit);
      if (!mounted) return;
      if (outcome == RewardedAdOutcome.dismissed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Finish the rewarded ad to unlock another look.'),
          ),
        );
        return;
      }
      if (outcome == RewardedAdOutcome.earned) {
        await ads.grantBonusRefresh(userId);
        access = DailyRefreshAccess.bonus;
      } else {
        // Invalid credentials, SDK, network, load, or show failures must not
        // punish the user. Only deliberately dismissing a working ad blocks.
        bypassAllowance = true;
        await AnalyticsService.instance.event(
          'rewarded_ad_failed_open',
          parameters: {'placement': RewardedPlacement.dailyOutfit.name},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The ad is unavailable, so we are creating your look anyway.',
              ),
            ),
          );
        }
      }
    }

    final ok = await mvp.generateOutfit(city, 'daily alternative');
    if (ok && !bypassAllowance) await ads.consumeRefresh(userId, access);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mvp.error ?? 'Could not create a new look.')),
    );
  }

  Future<bool> _confirmExtraLookAd() async {
    await AnalyticsService.instance.event(
      'rewarded_ad_offer_viewed',
      parameters: {'placement': RewardedPlacement.dailyOutfit.name},
    );
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.auto_awesome_rounded,
              color: DesignSystem.accent,
            ),
            title: const Text('Unlock one more look'),
            content: const Text(
              'You have used today’s two free outfit refreshes. Watch one rewarded ad to create one additional look. Your current outfit stays available if you skip.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Watch & refresh'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _refreshTodayContext() async {
    final mvp = context.read<MvpProvider>();
    await Future.wait([
      mvp.loadPreferences(force: true),
      mvp.loadTodayEvents(force: true),
    ]);
    if (!mounted) return;
    final city = mvp.preferences?.city?.trim() ?? '';
    final event = mvp.priorityEvent;
    if (city.isNotEmpty && event != null) {
      await mvp.generateEventOutfit(city, event, force: true);
    }
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

  Future<void> _logOutfit(Outfit target, {required String label}) async {
    if (_loggingOutfitIds.contains(target.id) ||
        _loggedOutfitIds.contains(target.id)) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _loggingOutfitIds.add(target.id));
    final provider = context.read<MvpProvider>();
    final ok = await provider.markOutfitWorn(target);
    if (!mounted) return;
    setState(() {
      _loggingOutfitIds.remove(target.id);
      if (ok) _loggedOutfitIds.add(target.id);
    });
    if (ok) {
      HapticFeedback.heavyImpact();
      await _showLoggedSuccess(target, label: label);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Could not log this outfit.')),
      );
    }
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

  Future<void> _logSomethingElse() async {
    if (_loggingAlternateOutfit) return;
    final wardrobe = context.read<WardrobeProvider>();
    final selected = await showModalBottomSheet<List<WardrobeItem>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DesignSystem.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: wardrobe,
        child: const _AlternateOutfitSheet(),
      ),
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    setState(() => _loggingAlternateOutfit = true);
    final ok = await context.read<MvpProvider>().markWardrobeItemsWorn(
      selected,
    );
    if (!mounted) return;
    setState(() => _loggingAlternateOutfit = false);
    if (ok) {
      await _showAlternateLoggedSuccess(selected);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<MvpProvider>().error ?? 'Could not log this outfit.',
          ),
        ),
      );
    }
  }

  Future<void> _showAlternateLoggedSuccess(List<WardrobeItem> items) async {
    HapticFeedback.heavyImpact();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: DesignSystem.success,
          size: 48,
        ),
        title: const Text('Your outfit is logged'),
        content: Text(
          '${items.map((item) => item.name).join(', ')} marked as worn today.',
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
      // Pull-to-refresh updates live context; alternate daily looks must use
      // the visible refresh action so the two-free-refresh rule cannot be
      // bypassed accidentally.
      onRefresh: _refreshTodayContext,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
        children: [
          _EditorialHeader(
            greeting: _greeting(),
            name: name,
            priorityEvent: priorityEvent,
            onHistory: widget.onOpenHistory,
            onProfile: widget.onOpenProfile,
            onHelp: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppHelpScreen()),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('YOUR STYLING STUDIO'),
          const SizedBox(height: 10),
          _StylingTools(
            onAskStylist: () {
              final currentCity = mvp.preferences?.city?.trim() ?? '';
              if (currentCity.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StylistChatScreen(city: currentCity),
                  ),
                );
              } else {
                widget.onOpenProfile();
              }
            },
            onCreateStyle: widget.onCreateStyle,
            onSavedStyles: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedStylesScreen()),
            ),
          ),
          const SizedBox(height: 26),
          if (priorityEvent != null) ...[
            const _SectionHeading(
              eyebrow: 'FIRST PRIORITY',
              title: 'Dress for what matters',
              subtitle: 'Your calendar leads today’s styling edit.',
            ),
            const SizedBox(height: 12),
            _EventHeader(
              event: priorityEvent,
              additionalEvents: mvp.todayEvents.length - 1,
            ),
            const SizedBox(height: 14),
            if (canStyle && mvp.loadingEventOutfit && mvp.eventOutfit == null)
              const _EventOutfitSkeleton()
            else if (canStyle && mvp.eventOutfit != null) ...[
              if (mvp.loadingEventOutfit) ...[
                const _LookGenerationBanner(
                  title: 'Creating another event look',
                  subtitle:
                      'Your stylist is rebuilding the outfit for this event.',
                ),
                const SizedBox(height: 12),
              ],
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
                label: _loggedOutfitIds.contains(mvp.eventOutfit!.id)
                    ? 'Logged'
                    : _loggingOutfitIds.contains(mvp.eventOutfit!.id)
                    ? 'Logging…'
                    : 'Log This Event Outfit',
                icon: _loggedOutfitIds.contains(mvp.eventOutfit!.id)
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline,
                isLoading: _loggingOutfitIds.contains(mvp.eventOutfit!.id),
                onPressed: () => _logOutfit(
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
            ] else if (canStyle && mvp.eventError != null)
              _InlineRetry(
                message: mvp.eventError!,
                onRetry: () => _newEventLook(priorityEvent),
              ),
            if (canStyle) ...[
              const SizedBox(height: 34),
              const _SectionHeading(
                eyebrow: 'DAILY EDIT',
                title: 'For the rest of today',
                subtitle: 'An easy look, composed from your own wardrobe.',
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
            const SizedBox(height: 12),
            if (priorityEvent == null) ...[
              _SectionHeading(
                eyebrow: 'CURATED FOR TODAY',
                title: 'Your daily outfit',
                subtitle:
                    'A complete look using ${mvp.outfit!.items.length} pieces you own.',
                trailing: _RoundIconButton(
                  tooltip: 'Create another look',
                  icon: Icons.refresh_rounded,
                  loading: mvp.loadingOutfit,
                  onPressed: mvp.loadingOutfit ? null : _newLook,
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (mvp.loadingOutfit) ...[
              const _LookGenerationBanner(
                title: 'Creating your next look',
                subtitle:
                    'Your stylist is choosing a fresh combination from your wardrobe.',
              ),
              const SizedBox(height: 12),
            ],
            _OutfitBoard(items: mvp.outfit!.items),
            const SizedBox(height: 14),
            _WhyItWorks(reasoning: mvp.outfit!.reasoning),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignSystem.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      onPressed:
                          _loggingOutfitIds.contains(mvp.outfit!.id) ||
                              _loggedOutfitIds.contains(mvp.outfit!.id)
                          ? null
                          : () =>
                                _logOutfit(mvp.outfit!, label: 'Today\'s look'),
                      icon: _loggingOutfitIds.contains(mvp.outfit!.id)
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _loggedOutfitIds.contains(mvp.outfit!.id)
                                  ? Icons.check_circle_rounded
                                  : Icons.check_circle_outline_rounded,
                            ),
                      label: Text(
                        _loggingOutfitIds.contains(mvp.outfit!.id)
                            ? 'Logging…'
                            : _loggedOutfitIds.contains(mvp.outfit!.id)
                            ? 'Logged'
                            : 'Log this outfit',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                if (mvp.outfit!.inspirationEnabled) ...[
                  const SizedBox(width: 10),
                  _VibeButton(images: mvp.outfit!.inspirationImages),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _loggingAlternateOutfit ? null : _logSomethingElse,
                icon: _loggingAlternateOutfit
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.checkroom_outlined),
                label: Text(
                  _loggingAlternateOutfit
                      ? 'Logging your outfit…'
                      : 'I wore something else',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlternateOutfitSheet extends StatefulWidget {
  const _AlternateOutfitSheet();

  @override
  State<_AlternateOutfitSheet> createState() => _AlternateOutfitSheetState();
}

class _AlternateOutfitSheetState extends State<_AlternateOutfitSheet> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WardrobeProvider>().loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    final items = wardrobe.items.where((item) => !item.isUploading).toList();
    final selected = items
        .where((item) => _selectedIds.contains(item.id))
        .toList(growable: false);
    return FractionallySizedBox(
      heightFactor: .88,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: DesignSystem.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What did you wear?',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose every piece from your wardrobe.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DesignSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: wardrobe.loading || wardrobe.syncing
                          ? const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Opening your wardrobe…'),
                              ],
                            )
                          : const Text(
                              'Add wardrobe pieces before logging another outfit.',
                              textAlign: TextAlign.center,
                            ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isSelected = _selectedIds.contains(item.id);
                      return Material(
                        color: isSelected
                            ? DesignSystem.editorialMint
                            : DesignSystem.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isSelected
                                ? DesignSystem.primary
                                : DesignSystem.border,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) => setState(() {
                            isSelected
                                ? _selectedIds.remove(item.id)
                                : _selectedIds.add(item.id);
                          }),
                          secondary: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ColoredBox(
                              color: Colors.white,
                              child: SizedBox.square(
                                dimension: 58,
                                child: item.gridImageUrl == null
                                    ? const Icon(Icons.checkroom_outlined)
                                    : CachedNetworkImage(
                                        imageUrl: item.gridImageUrl!,
                                        cacheKey: item.gridImageCacheKey,
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ),
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [item.displayCategory, item.displayColor]
                                .whereType<String>()
                                .where((value) => value.trim().isNotEmpty)
                                .join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, selected),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    selected.isEmpty
                        ? 'Select wardrobe items'
                        : 'Log this outfit (${selected.length})',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialHeader extends StatelessWidget {
  const _EditorialHeader({
    required this.greeting,
    required this.name,
    required this.priorityEvent,
    required this.onHistory,
    required this.onProfile,
    required this.onHelp,
  });

  final String greeting;
  final String name;
  final StyleCalendarEvent? priorityEvent;
  final VoidCallback onHistory;
  final VoidCallback onProfile;
  final VoidCallback onHelp;

  String _dateLabel() {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const StyleStackLogo(size: 38),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STYLESTACK',
                  style: TextStyle(
                    color: DesignSystem.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'YOUR PERSONAL EDIT',
                  style: TextStyle(
                    color: DesignSystem.textTertiary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.25,
                  ),
                ),
              ],
            ),
          ),
          _RoundIconButton(
            tooltip: 'How to use StyleStack',
            icon: Icons.help_outline_rounded,
            onPressed: onHelp,
          ),
          const SizedBox(width: 8),
          _RoundIconButton(
            tooltip: 'Style planner',
            icon: Icons.calendar_month_outlined,
            onPressed: onHistory,
          ),
          const SizedBox(width: 8),
          _RoundIconButton(
            tooltip: 'Profile',
            icon: Icons.person_outline_rounded,
            onPressed: onProfile,
            dark: true,
          ),
        ],
      ),
      const SizedBox(height: 28),
      Text(
        '$greeting,',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: DesignSystem.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          color: DesignSystem.primaryDark,
          fontSize: 38,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
        ),
      ),
      const SizedBox(height: 9),
      Row(
        children: [
          Text(
            _dateLabel().toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: DesignSystem.textTertiary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          if (priorityEvent != null) ...[
            const SizedBox(width: 9),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: DesignSystem.cta,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '${priorityEvent!.title} is your style priority',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: DesignSystem.cta,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.dark = false,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool dark;
  final bool loading;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: dark ? DesignSystem.primaryDark : DesignSystem.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 44,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: dark ? Colors.white : DesignSystem.primary,
                  ),
                )
              : Icon(
                  icon,
                  size: 21,
                  color: dark ? Colors.white : DesignSystem.primary,
                ),
        ),
      ),
    ),
  );
}

class _LookGenerationBanner extends StatelessWidget {
  const _LookGenerationBanner({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: '$title. $subtitle',
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignSystem.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DesignSystem.primary.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 38,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: DesignSystem.primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: DesignSystem.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: DesignSystem.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: DesignSystem.textTertiary,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.35,
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(eyebrow),
            const SizedBox(height: 5),
            Text(
              title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: DesignSystem.primaryDark,
                fontWeight: FontWeight.w800,
                letterSpacing: -.7,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ],
  );
}

class _StylingTools extends StatelessWidget {
  const _StylingTools({
    required this.onAskStylist,
    required this.onCreateStyle,
    required this.onSavedStyles,
  });

  final VoidCallback onAskStylist;
  final VoidCallback onCreateStyle;
  final VoidCallback onSavedStyles;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 142,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _ToolCard(
            title: 'Ask your\nstylist',
            caption: 'Personal advice',
            icon: Icons.chat_bubble_outline_rounded,
            background: DesignSystem.primary,
            foreground: Colors.white,
            onTap: onAskStylist,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ToolCard(
            title: 'Build a\nlook',
            caption: 'Outfit canvas',
            icon: Icons.dashboard_customize_outlined,
            background: const Color(0xFFE7DDD2),
            foreground: DesignSystem.primaryDark,
            onTap: onCreateStyle,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: _ToolCard(
            title: 'Saved',
            caption: '',
            icon: Icons.bookmark_border_rounded,
            background: const Color(0xFFDCE9E7),
            foreground: DesignSystem.primaryDark,
            compact: true,
            onTap: onSavedStyles,
          ),
        ),
      ],
    ),
  );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.caption,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final String caption;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: foreground.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: foreground, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foreground,
                height: 1.18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground.withValues(alpha: .72),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE9E7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: const BoxDecoration(
              color: DesignSystem.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wb_cloudy_outlined,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              details.join('  •  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DesignSystem.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Text(
            'COMFORT CHECKED',
            style: TextStyle(
              color: DesignSystem.primary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
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
    final columns = visibleItems.length <= 4 ? 2 : 3;
    final rows = (visibleItems.length / (columns == 0 ? 1 : columns)).ceil();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: DesignSystem.border),
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: DesignSystem.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: DesignSystem.surfaceAlt,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${items.length} PIECES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: DesignSystem.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (visibleItems.isEmpty)
            const Text('No pieces were selected.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 9.0;
                const aspectRatio = .74;
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
  Widget build(BuildContext context) {
    final imageUrl = item.canvasImageUrl;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(8, 9, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: imageUrl == null
                ? const Icon(Icons.checkroom_outlined, size: 34)
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    cacheKey: 'today-outfit-${item.id}-${item.aiTagStatus}',
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.checkroom_outlined),
                  ),
          ),
          const SizedBox(height: 7),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DesignSystem.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyItWorks extends StatelessWidget {
  const _WhyItWorks({required this.reasoning, this.title = 'Why this works'});
  final String reasoning;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFE2E5F5),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: DesignSystem.primaryDark,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: DesignSystem.accent,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: DesignSystem.primaryDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          reasoning,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: DesignSystem.primaryDark,
            height: 1.5,
            fontWeight: FontWeight.w500,
            letterSpacing: -.05,
          ),
        ),
      ],
    ),
  );
}

class _VibeButton extends StatelessWidget {
  const _VibeButton({required this.images});
  final List<Map<String, dynamic>> images;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'See the vibe',
    child: Material(
      color: const Color(0xFFE7DDD2),
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
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
        child: const SizedBox(
          width: 56,
          height: 52,
          child: Icon(
            Icons.auto_awesome_outlined,
            color: DesignSystem.primaryDark,
          ),
        ),
      ),
    ),
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
