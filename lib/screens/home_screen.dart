import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/animations.dart';
import '../config/design_system.dart';
import '../config/custom_widgets.dart';
import '../models/wardrobe_item.dart';
import '../providers/auth_provider.dart';
import '../providers/wardrobe_provider.dart';
import 'camera_preview_screen.dart';
import 'batch_add_screen.dart';
import 'canvas_style_builder_screen.dart';
import 'item_detail_screen.dart';
import 'outfit_view.dart';
import 'outfit_selfie_review_screen.dart';
import 'outfit_history_screen.dart';
import 'profile_settings_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  int _tab = 0;

  void _selectTab(int value) {
    setState(() => _tab = value);
    if (value == 1) {
      // Wardrobe is deliberately lazy: Today never downloads the full closet.
      context.read<WardrobeProvider>().loadItems();
    }
  }

  Future<void> _openCreateStyle() async {
    await context.read<WardrobeProvider>().loadItems();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CanvasStyleBuilderScreen()),
    );
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add wardrobe item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                subtitle: const Text('Open the camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                subtitle: const Text(
                  'Select up to $maxBatchImages photos for batch adding',
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == ImageSource.gallery) {
      await _pickGalleryBatch();
    } else {
      await _pickImage(source);
    }
  }

  Future<void> _pickGalleryBatch() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1600,
      limit: maxBatchImages,
    );
    if (picked.isEmpty || !mounted) return;
    if (picked.length == 1) {
      await _showPreview(File(picked.first.path), ImageSource.gallery);
      return;
    }
    final uploaded = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => BatchAddScreen(
          images: picked
              .take(maxBatchImages)
              .map((image) => File(image.path))
              .toList(),
        ),
      ),
    );
    if (!mounted || uploaded == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$uploaded ${uploaded == 1 ? 'item' : 'items'} added to your wardrobe.',
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    await _showPreview(File(picked.path), source);
  }

  Future<void> _showPreview(File image, ImageSource source) async {
    final queued = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraPreviewScreen(
          image: image,
          retakeLabel: source == ImageSource.camera ? 'Retake' : 'Choose again',
          onRetake: () async {
            final replacement = await _picker.pickImage(
              source: source,
              imageQuality: 82,
              maxWidth: 1600,
            );
            if (replacement == null || !mounted) return;
            Navigator.pop(context);
            await _showPreview(File(replacement.path), source);
          },
        ),
      ),
    );
    if (queued == true && mounted) _selectTab(1);
  }

  Future<void> _startOutfitSelfie() async {
    // Outfit Selfie review needs local wardrobe matches, so load it only for
    // this flow rather than during Today startup.
    await context.read<WardrobeProvider>().loadItems();
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    await _showOutfitSelfie(File(picked.path));
  }

  Future<void> _showOutfitSelfie(File image) async {
    final addMissing = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitSelfieReviewScreen(
          image: image,
          onRetake: () async {
            final replacement = await _picker.pickImage(
              source: ImageSource.camera,
              preferredCameraDevice: CameraDevice.front,
              imageQuality: 82,
              maxWidth: 1600,
            );
            if (replacement == null || !mounted) return;
            Navigator.pop(context);
            await _showOutfitSelfie(File(replacement.path));
          },
        ),
      ),
    );
    if (addMissing == true && mounted) {
      _selectTab(1);
      await _chooseImageSource();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Today', 'My Wardrobe', 'Outfit History', 'Profile'];
    final wardrobeBusy = context.watch<WardrobeProvider>().items.any(
      (item) =>
          item.isUploading ||
          item.aiTagStatus == 'pending' ||
          item.aiTagStatus == 'processing',
    );
    return Scaffold(
      appBar: _tab == 0
          ? null
          : AppBar(
              title: Text(
                titles[_tab],
                style: _tab == 1
                    ? const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      )
                    : null,
              ),
            ),
      body: SafeArea(
        top: _tab == 0,
        child: IndexedStack(
          index: _tab,
          children: [
            DailyOutfitView(
              onOutfitSelfie: _startOutfitSelfie,
              onOpenHistory: () => _selectTab(2),
              onOpenProfile: () => _selectTab(3),
              onCreateStyle: _openCreateStyle,
              onAddItem: _chooseImageSource,
            ),
            WardrobeView(onAddItem: _chooseImageSource),
            const OutfitHistoryView(),
            const ProfileSettingsView(),
          ],
        ),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _startOutfitSelfie,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Outfit Selfie'),
            )
          : _tab == 1
          ? FloatingActionButton.extended(
              onPressed: _chooseImageSource,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add item'),
            )
          : null,
      bottomNavigationBar: FBottomNavigationBar(
        safeAreaBottom: true,
        index: _tab,
        onChange: _selectTab,
        children: [
          const FBottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_outlined),
            label: Text('Today'),
          ),
          FBottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.checkroom_outlined),
                if (wardrobeBusy)
                  const Positioned(
                    right: -3,
                    top: -3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: DesignSystem.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 8),
                    ),
                  ),
              ],
            ),
            label: const Text('Wardrobe'),
          ),
          const FBottomNavigationBarItem(
            icon: Icon(Icons.photo_library_outlined),
            label: Text('Outfits'),
          ),
          const FBottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: Text('Profile'),
          ),
        ],
      ),
    );
  }
}

enum _WardrobeSort { newest, oldest, mostWorn }

class WardrobeView extends StatefulWidget {
  const WardrobeView({super.key, required this.onAddItem});
  final Future<void> Function() onAddItem;

  @override
  State<WardrobeView> createState() => _WardrobeViewState();
}

class _WardrobeViewState extends State<WardrobeView> {
  static const _categories = [
    'All',
    'Shirts',
    'Pants',
    'Dresses',
    'Jackets',
    'Shoes',
    'Accessories',
    'Kurtas',
    'Sarees',
    'Lehengas',
    'Sherwanis',
    'Salwar Suits',
    'Dhotis',
    'Dupattas',
    'Blouses',
    'Anarkalis',
    'Ethnic Sets',
    'Other',
  ];
  static const _colors = [
    'All',
    'Black',
    'White',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Purple',
    'Pink',
    'Brown',
    'Grey',
    'Orange',
    'Beige',
    'Multicolor',
  ];
  static const _seasons = ['All', 'Summer', 'Winter', 'Spring', 'Autumn'];
  static const _formalities = [
    'All',
    'Formal',
    'Semi-formal',
    'Casual',
    'Sporty',
  ];

  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  String _category = 'All';
  String _color = 'All';
  String _season = 'All';
  String _formality = 'All';
  _WardrobeSort _sort = _WardrobeSort.newest;

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'shirts') return 'shirt';
    if (normalized == 'dresses') return 'dress';
    if (normalized == 'jackets') return 'jacket';
    if (normalized == 'accessories') return 'accessory';
    if (normalized == 'kurtas') return 'kurta';
    if (normalized == 'sarees') return 'saree';
    if (normalized == 'lehengas') return 'lehenga';
    if (normalized == 'sherwanis') return 'sherwani';
    if (normalized == 'salwar suits') return 'salwar';
    if (normalized == 'dhotis') return 'dhoti';
    if (normalized == 'dupattas') return 'dupatta';
    if (normalized == 'blouses') return 'blouse';
    if (normalized == 'anarkalis') return 'anarkali';
    if (normalized == 'ethnic sets') return 'ethnic_set';
    if (normalized == 'shoes') return 'shoes';
    return normalized;
  }

  bool _matchesCategory(WardrobeItem item) {
    if (_category == 'All') return true;
    final selected = _normalize(_category);
    final itemCategories = [
      item.category,
      item.aiCategory,
    ].whereType<String>().map(_normalize).toSet();
    if (selected == 'jacket') {
      const jacketAliases = {
        'jacket',
        'outerwear',
        'hoodie',
        'sweatshirt',
        'coat',
        'blazer',
      };
      return itemCategories.any(jacketAliases.contains);
    }
    return itemCategories.contains(selected);
  }

  List<WardrobeItem> _visibleItems(List<WardrobeItem> items) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = items.where((item) {
      final colors = [
        item.color,
        item.aiColor,
      ].whereType<String>().map(_normalize);
      final seasons = [
        ...item.seasons,
        if (item.aiSeason != null) item.aiSeason!,
      ].map(_normalize);
      final matchesSearch =
          query.isEmpty ||
          [
            item.aiDescription,
            item.description,
            item.category,
            item.aiCategory,
            item.color,
            item.aiColor,
            item.brand,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(query),
          );
      return matchesSearch &&
          _matchesCategory(item) &&
          (_color == 'All' || colors.contains(_normalize(_color))) &&
          (_season == 'All' || seasons.contains(_normalize(_season))) &&
          (_formality == 'All' ||
              [item.formality, item.aiFormality]
                  .whereType<String>()
                  .map(_normalize)
                  .contains(_normalize(_formality)));
    }).toList();

    visible.sort(
      (a, b) => switch (_sort) {
        _WardrobeSort.newest => b.createdAt.compareTo(a.createdAt),
        _WardrobeSort.oldest => a.createdAt.compareTo(b.createdAt),
        _WardrobeSort.mostWorn => b.wearCount.compareTo(a.wearCount),
      },
    );
    return visible;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _category = 'All';
      _color = 'All';
      _season = 'All';
      _formality = 'All';
    });
  }

  void _toggleSelection(String itemId) {
    setState(() {
      _selectedIds.contains(itemId)
          ? _selectedIds.remove(itemId)
          : _selectedIds.add(itemId);
    });
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} items?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final wardrobe = context.read<WardrobeProvider>();
    final deleted = await wardrobe.deleteItems(Set.of(_selectedIds));
    if (!mounted) return;
    if (deleted) {
      setState(_selectedIds.clear);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wardrobe.error ?? 'Delete failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    if (wardrobe.loading && wardrobe.items.isEmpty) {
      return const StyleStackLoadingIndicator(
        message: 'Opening your wardrobe…',
      );
    }
    if (wardrobe.error != null && wardrobe.items.isEmpty) {
      return _Message(
        icon: Icons.cloud_off,
        title: wardrobe.error!,
        action: () => wardrobe.loadItems(force: true),
      );
    }
    if (wardrobe.items.isEmpty) {
      return _Message(
        icon: Icons.checkroom_outlined,
        animationAsset: StyleStackMotionAssets.emptyCloset,
        title: 'Build your wardrobe',
        subtitle:
            'Add your first piece and your personal stylist will start learning your style.',
        action: widget.onAddItem,
        actionLabel: 'Add first item',
      );
    }
    final visibleItems = _visibleItems(wardrobe.items);
    final processingItems = wardrobe.items
        .where(
          (item) =>
              item.isUploading ||
              item.aiTagStatus == 'pending' ||
              item.aiTagStatus == 'processing',
        )
        .toList();
    final content = RefreshIndicator(
      onRefresh: () => wardrobe.loadItems(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (wardrobe.syncing && wardrobe.items.isNotEmpty)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                minHeight: 2,
                semanticsLabel: 'Refreshing wardrobe',
              ),
            ),
          if (processingItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DesignSystem.primary.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: DesignSystem.primary.withValues(alpha: .16),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Preparing ${processingItems.length} ${processingItems.length == 1 ? 'item' : 'items'} in the background. You can keep using StyleStack.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: FTextField(
                control: FTextFieldControl.managed(
                  controller: _searchController,
                  onChange: (_) => setState(() {}),
                ),
                hint: 'Search your wardrobe',
                prefixBuilder: (context, style, variants) =>
                    FTextField.prefixIconBuilder(
                      context,
                      style,
                      variants,
                      const Icon(Icons.search_rounded, size: 20),
                    ),
                clearable: (value) => value.text.isNotEmpty,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _FilterPill(
                    label: 'Category',
                    value: _category,
                    values: _categories,
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  _FilterPill(
                    label: 'Color',
                    value: _color,
                    values: _colors,
                    onChanged: (value) => setState(() => _color = value),
                  ),
                  _FilterPill(
                    label: 'Season',
                    value: _season,
                    values: _seasons,
                    onChanged: (value) => setState(() => _season = value),
                  ),
                  _FilterPill(
                    label: 'Formality',
                    value: _formality,
                    values: _formalities,
                    onChanged: (value) => setState(() => _formality = value),
                  ),
                ],
              ),
            ),
          ),
          if (wardrobe.error != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                decoration: BoxDecoration(
                  color: DesignSystem.error.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: DesignSystem.error.withValues(alpha: .18),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: DesignSystem.error,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${wardrobe.error} The local wardrobe is still available.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      onPressed: wardrobe.clearError,
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: _selectionMode
                  ? Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedIds.length} selected',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(_selectedIds.clear),
                          child: const Text('Cancel'),
                        ),
                        IconButton(
                          onPressed: wardrobe.deleting ? null : _deleteSelected,
                          icon: wardrobe.deleting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                          tooltip: 'Delete selected',
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${visibleItems.length} ${visibleItems.length == 1 ? 'piece' : 'pieces'}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: DesignSystem.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        _SortPill(
                          value: _sort,
                          onChanged: (value) => setState(() => _sort = value),
                        ),
                      ],
                    ),
            ),
          ),
          if (visibleItems.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _Message(
                icon: Icons.filter_alt_off_outlined,
                title: 'No matching items',
                subtitle: 'Try changing your search or filters.',
                action: _clearFilters,
                actionLabel: 'Clear filters',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .73,
                ),
                itemCount: visibleItems.length,
                itemBuilder: (_, index) {
                  final item = visibleItems[index];
                  return StaggeredListAnimation(
                    delay: Duration(milliseconds: index * 50),
                    child: _ItemCard(
                      item: item,
                      selected: _selectedIds.contains(item.id),
                      onLongPress: item.isUploading
                          ? null
                          : () => _toggleSelection(item.id),
                      onTap: _selectionMode
                          ? () => _toggleSelection(item.id)
                          : () {
                              if (item.isUploading) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This item is still syncing. It will be editable in a moment.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                StyleStackAnimations.fadeSlideTransition(
                                  ItemDetailScreen(itemId: item.id),
                                ),
                              );
                            },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );

    return content;
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final active = value != 'All';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        initialValue: value,
        onSelected: onChanged,
        color: DesignSystem.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (context) => values
            .map(
              (entry) => PopupMenuItem<String>(
                value: entry,
                child: Row(
                  children: [
                    Expanded(child: Text(entry)),
                    if (entry == value)
                      const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: DesignSystem.primary,
                      ),
                  ],
                ),
              ),
            )
            .toList(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active
                ? DesignSystem.primary.withValues(alpha: 0.08)
                : DesignSystem.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? DesignSystem.primary.withValues(alpha: 0.35)
                  : DesignSystem.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                active ? value : label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active
                      ? DesignSystem.primary
                      : DesignSystem.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active
                    ? DesignSystem.primary
                    : DesignSystem.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({required this.value, required this.onChanged});

  final _WardrobeSort value;
  final ValueChanged<_WardrobeSort> onChanged;

  String _label(_WardrobeSort sort) => switch (sort) {
    _WardrobeSort.newest => 'Newest',
    _WardrobeSort.oldest => 'Oldest',
    _WardrobeSort.mostWorn => 'Most worn',
  };

  @override
  Widget build(BuildContext context) => PopupMenuButton<_WardrobeSort>(
    initialValue: value,
    onSelected: onChanged,
    color: DesignSystem.surface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    itemBuilder: (context) => _WardrobeSort.values
        .map(
          (sort) => PopupMenuItem<_WardrobeSort>(
            value: sort,
            child: Text(_label(sort)),
          ),
        )
        .toList(),
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: DesignSystem.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DesignSystem.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _label(value),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: DesignSystem.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        ],
      ),
    ),
  );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.selected,
    this.onTap,
    this.onLongPress,
  });
  final WardrobeItem item;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: Material(
      color: DesignSystem.surface,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? DesignSystem.primary : DesignSystem.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(19),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: item.localImagePath != null
                          ? Image.file(
                              File(item.localImagePath!),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                            )
                          : item.gridImageUrl == null
                          ? const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: DesignSystem.textTertiary,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: item.gridImageUrl!,
                              cacheKey: 'wardrobe-${item.id}',
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                            ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.displayCategory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: DesignSystem.textSecondary,
                                  height: 1.2,
                                ),
                          ),
                        ),
                        if (item.displayColor != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '·',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: DesignSystem.textTertiary,
                                    height: 1.2,
                                  ),
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getColorFromString(item.displayColor!),
                              shape: BoxShape.circle,
                              border:
                                  item.displayColor!.toLowerCase() == 'white'
                                  ? Border.all(color: DesignSystem.border)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              item.displayColor!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: DesignSystem.textSecondary,
                                    height: 1.2,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (item.isUploading)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DesignSystem.primary.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Syncing',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!item.isUploading &&
              (item.aiTagStatus == 'pending' ||
                  item.aiTagStatus == 'processing'))
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DesignSystem.primary.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        item.aiTagStatus == 'processing'
                            ? 'AI analyzing'
                            : 'In queue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Selection indicator
          if (selected)
            Positioned(
              top: DesignSystem.spacingMd,
              right: DesignSystem.spacingMd,
              child: Container(
                decoration: BoxDecoration(
                  color: DesignSystem.primary,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(7),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
            ),

          // Favorite indicator
          if (item.isFavorite)
            Positioned(
              top: DesignSystem.spacingMd,
              left: DesignSystem.spacingMd,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  shape: BoxShape.circle,
                  border: Border.all(color: DesignSystem.border),
                ),
                padding: const EdgeInsets.all(7),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: DesignSystem.error,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Color _getColorFromString(String colorName) {
    final name = colorName.toLowerCase().trim();
    return switch (name) {
      'black' => Colors.black,
      'white' => Colors.grey.shade100,
      'red' => Colors.red.shade400,
      'blue' => Colors.blue.shade400,
      'green' => Colors.green.shade400,
      'yellow' => Colors.amber.shade400,
      'purple' => Colors.purple.shade400,
      'pink' => Colors.pink.shade400,
      'brown' => Colors.brown.shade400,
      'grey' => Colors.grey.shade400,
      'orange' => Colors.orange.shade400,
      'beige' => const Color(0xFFD4A574),
      _ => DesignSystem.secondary,
    };
  }
}

class OutfitsView extends StatelessWidget {
  const OutfitsView({super.key});

  @override
  Widget build(BuildContext context) => StyleStackEmptyState(
    icon: Icons.auto_awesome_mosaic_outlined,
    title: 'Outfits Coming Soon',
    subtitle:
        'Build stunning looks from your wardrobe in the next release. We\'re crafting something special for you!',
    actionLabel: 'Learn More',
    onAction: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Outfit combinations feature coming soon!'),
        ),
      );
    },
  );
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return ListView(
      padding: const EdgeInsets.all(DesignSystem.spacingLg),
      children: [
        // Profile header
        StyleStackCard(
          backgroundColor: DesignSystem.secondary.withOpacity(0.1),
          padding: const EdgeInsets.all(DesignSystem.spacingXl),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(DesignSystem.spacingMd),
                decoration: BoxDecoration(
                  color: DesignSystem.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  size: 48,
                  color: DesignSystem.primary,
                ),
              ),
              const SizedBox(height: DesignSystem.spacingLg),
              Text(
                user?.email ?? 'StyleStack User',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: DesignSystem.spacingSm),
              Text(
                'Your Digital Wardrobe',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignSystem.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignSystem.spacingXxl),

        // Info sections
        StyleStackSectionHeader(title: 'About StyleStack'),
        const SizedBox(height: DesignSystem.spacingMd),

        StyleStackCard(
          padding: const EdgeInsets.all(DesignSystem.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DesignSystem.spacingMd),
                    decoration: BoxDecoration(
                      color: DesignSystem.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusMd,
                      ),
                    ),
                    child: const Icon(
                      Icons.style_outlined,
                      color: DesignSystem.primary,
                    ),
                  ),
                  const SizedBox(width: DesignSystem.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Wardrobe',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'AI-powered clothing organization',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: DesignSystem.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: DesignSystem.spacingXl),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(DesignSystem.spacingMd),
                    decoration: BoxDecoration(
                      color: DesignSystem.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusMd,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      color: DesignSystem.primary,
                    ),
                  ),
                  const SizedBox(width: DesignSystem.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Tagging',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Automatic item identification',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: DesignSystem.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignSystem.spacingXxl),

        // Sign out button
        FilledButton.icon(
          onPressed: () async {
            context.read<WardrobeProvider>().reset();
            await context.read<AuthProvider>().signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: FilledButton.styleFrom(backgroundColor: DesignSystem.error),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel = 'Try again',
    this.animationAsset,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? action;
  final String actionLabel;
  final String? animationAsset;

  @override
  Widget build(BuildContext context) => StyleStackEmptyState(
    icon: icon,
    title: title,
    subtitle: subtitle,
    actionLabel: action != null ? actionLabel : null,
    onAction: action,
    animationAsset: animationAsset,
  );
}
