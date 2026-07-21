import 'package:flutter/material.dart';

import '../config/custom_widgets.dart';
import '../config/design_system.dart';
import '../models/canvas_style.dart';
import '../services/api_service.dart';
import 'canvas_style_builder_screen.dart';
import 'style_story_share_screen.dart';

class SavedStylesScreen extends StatefulWidget {
  const SavedStylesScreen({super.key});

  @override
  State<SavedStylesScreen> createState() => _SavedStylesScreenState();
}

class _SavedStylesScreenState extends State<SavedStylesScreen> {
  final _api = ApiService();
  late Future<List<CanvasStyle>> _styles;

  @override
  void initState() {
    super.initState();
    _styles = _api.fetchCanvasStyles();
  }

  void _reload() => setState(() => _styles = _api.fetchCanvasStyles());

  Future<void> _openBuilder([CanvasStyle? style]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CanvasStyleBuilderScreen(initialStyle: style),
      ),
    );
    if (mounted) _reload();
  }

  void _share(CanvasStyle style) {
    final previewUrl = style.previewUrl;
    if (previewUrl == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StyleStoryShareScreen(
          canvasImage: NetworkImage(previewUrl),
          styleName: style.name,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CanvasStyle style) async {
    final shouldDelete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: DesignSystem.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignSystem.radiusXxl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete this style?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '“${style.name}” will be removed from your studio. Your wardrobe items will stay untouched.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DesignSystem.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep style'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: DesignSystem.error,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldDelete != true) return;

    try {
      await _api.deleteCanvasStyle(style.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Style removed from your studio.')),
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this style. Try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My Styles'),
      actions: [
        IconButton(
          onPressed: _reload,
          tooltip: 'Refresh styles',
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: FutureBuilder<List<CanvasStyle>>(
      future: _styles,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const StyleStackLoadingIndicator(
            message: 'Opening your style studio…',
          );
        }
        if (snapshot.hasError) return _StylesError(onRetry: _reload);

        final styles = snapshot.data ?? const <CanvasStyle>[];
        if (styles.isEmpty) {
          return _EmptyStyles(onCreate: () => _openBuilder());
        }

        return RefreshIndicator(
          color: DesignSystem.primary,
          onRefresh: () async => _reload(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _StudioHero(
                  count: styles.length,
                  onCreate: () => _openBuilder(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Saved edits',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${styles.length} ${styles.length == 1 ? 'look' : 'looks'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: DesignSystem.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 116),
                sliver: SliverGrid.builder(
                  itemCount: styles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                    childAspectRatio: .71,
                  ),
                  itemBuilder: (context, index) {
                    final style = styles[index];
                    return _StylePortfolioCard(
                      key: ValueKey(style.id),
                      style: style,
                      onOpen: () => _openBuilder(style),
                      onShare: style.previewUrl == null
                          ? null
                          : () => _share(style),
                      onDelete: () => _confirmDelete(style),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openBuilder(),
      backgroundColor: DesignSystem.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Create style'),
    ),
  );
}

class _StudioHero extends StatelessWidget {
  const _StudioHero({required this.count, required this.onCreate});

  final int count;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: DesignSystem.primaryDark,
        borderRadius: BorderRadius.circular(DesignSystem.radiusXxl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _EditorialLabel(label: 'YOUR PRIVATE STUDIO'),
                const SizedBox(height: 14),
                Text(
                  'Looks worth\nremembering.',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$count saved ${count == 1 ? 'composition' : 'compositions'} from your wardrobe.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .72),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onCreate,
              tooltip: 'Create a new style',
              icon: const Icon(
                Icons.add_rounded,
                color: DesignSystem.primaryDark,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EditorialLabel extends StatelessWidget {
  const _EditorialLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: DesignSystem.secondaryLight,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.65,
    ),
  );
}

enum _StyleAction { edit, share, delete }

class _StylePortfolioCard extends StatelessWidget {
  const _StylePortfolioCard({
    super.key,
    required this.style,
    required this.onOpen,
    required this.onDelete,
    this.onShare,
  });

  final CanvasStyle style;
  final VoidCallback onOpen;
  final VoidCallback? onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DesignSystem.radiusXl);
    return Material(
      color: DesignSystem.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: DesignSystem.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.white,
                      child: _StylePreview(url: style.previewUrl),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: PopupMenuButton<_StyleAction>(
                        tooltip: 'Style options',
                        color: DesignSystem.surface,
                        surfaceTintColor: Colors.transparent,
                        position: PopupMenuPosition.under,
                        onSelected: (action) {
                          switch (action) {
                            case _StyleAction.edit:
                              onOpen();
                            case _StyleAction.share:
                              onShare?.call();
                            case _StyleAction.delete:
                              onDelete();
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: _StyleAction.edit,
                            child: _MenuLabel(
                              icon: Icons.edit_outlined,
                              label: 'Edit style',
                            ),
                          ),
                          PopupMenuItem(
                            value: _StyleAction.share,
                            enabled: onShare != null,
                            child: const _MenuLabel(
                              icon: Icons.ios_share_outlined,
                              label: 'Share story',
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: _StyleAction.delete,
                            child: _MenuLabel(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              color: DesignSystem.error,
                            ),
                          ),
                        ],
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .94),
                            shape: BoxShape.circle,
                            border: Border.all(color: DesignSystem.border),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            size: 20,
                            color: DesignSystem.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.layers_outlined,
                          size: 14,
                          color: DesignSystem.textTertiary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${style.items.length} ${style.items.length == 1 ? 'piece' : 'pieces'}  ·  ${_shortDate(style.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: DesignSystem.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}

class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const Center(
        child: StyleStackIconBadge(
          icon: Icons.grid_view_rounded,
          size: 56,
          backgroundColor: DesignSystem.editorialMint,
          foregroundColor: DesignSystem.primary,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(7),
      child: Image.network(
        url!,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: DesignSystem.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: color ?? DesignSystem.textPrimary),
      const SizedBox(width: 11),
      Text(label, style: TextStyle(color: color)),
    ],
  );
}

class _EmptyStyles extends StatelessWidget {
  const _EmptyStyles({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: DesignSystem.editorialMint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.dashboard_customize_outlined,
              size: 48,
              color: DesignSystem.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Your studio is ready.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Arrange pieces from your own wardrobe into a look you can revisit, refine, and share.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DesignSystem.textSecondary,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create your first style'),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    ),
  );
}

class _StylesError extends StatelessWidget {
  const _StylesError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StyleStackIconBadge(
            icon: Icons.cloud_off_outlined,
            size: 64,
            backgroundColor: DesignSystem.editorialSand,
            foregroundColor: DesignSystem.cta,
          ),
          const SizedBox(height: 20),
          Text(
            'Your studio did not open',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your saved styles are safe. Check your connection and try once more.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DesignSystem.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
