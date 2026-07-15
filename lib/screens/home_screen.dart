import 'dart:io';

import 'package:flutter/material.dart';
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

  void _selectTab(int value) => setState(() => _tab = value);

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
    await Navigator.push<bool>(
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
  }

  Future<void> _startOutfitSelfie() async {
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
    return Scaffold(
      appBar: _tab == 0 ? null : AppBar(title: Text(titles[_tab])),
      body: SafeArea(
        top: _tab == 0,
        child: IndexedStack(
          index: _tab,
          children: [
            DailyOutfitView(
              onOutfitSelfie: _startOutfitSelfie,
              onAddItem: _chooseImageSource,
              onOpenHistory: () => _selectTab(2),
              onOpenProfile: () => _selectTab(3),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.checkroom_outlined),
            selectedIcon: Icon(Icons.checkroom),
            label: 'Wardrobe',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Outfits',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
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
      return const Center(child: CircularProgressIndicator());
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
        title: 'Build your wardrobe',
        subtitle:
            'Add your first piece and your personal stylist will start learning your style.',
        action: widget.onAddItem,
        actionLabel: 'Add first item',
      );
    }
    final visibleItems = _visibleItems(wardrobe.items);
    return RefreshIndicator(
      onRefresh: () => wardrobe.loadItems(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SearchBar(
                controller: _searchController,
                hintText: 'Search description, category, color, brand',
                leading: const Icon(Icons.search),
                trailing: _searchController.text.isEmpty
                    ? null
                    : [
                        IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _FilterDropdown(
                    label: 'Category',
                    value: _category,
                    values: _categories,
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  _FilterDropdown(
                    label: 'Color',
                    value: _color,
                    values: _colors,
                    onChanged: (value) => setState(() => _color = value),
                  ),
                  _FilterDropdown(
                    label: 'Season',
                    value: _season,
                    values: _seasons,
                    onChanged: (value) => setState(() => _season = value),
                  ),
                  _FilterDropdown(
                    label: 'Formality',
                    value: _formality,
                    values: _formalities,
                    onChanged: (value) => setState(() => _formality = value),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
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
                            '${visibleItems.length} ${visibleItems.length == 1 ? 'item' : 'items'}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        DropdownButton<_WardrobeSort>(
                          value: _sort,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: _WardrobeSort.newest,
                              child: Text('Newest'),
                            ),
                            DropdownMenuItem(
                              value: _WardrobeSort.oldest,
                              child: Text('Oldest'),
                            ),
                            DropdownMenuItem(
                              value: _WardrobeSort.mostWorn,
                              child: Text('Most worn'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _sort = value);
                          },
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
                  childAspectRatio: .72,
                ),
                itemCount: visibleItems.length,
                itemBuilder: (_, index) {
                  final item = visibleItems[index];
                  return StaggeredListAnimation(
                    delay: Duration(milliseconds: index * 50),
                    child: _ItemCard(
                      item: item,
                      selected: _selectedIds.contains(item.id),
                      onLongPress: () => _toggleSelection(item.id),
                      onTap: _selectionMode
                          ? () => _toggleSelection(item.id)
                          : () {
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
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: DesignSystem.spacingSm),
    child: DropdownMenu<String>(
      key: ValueKey('$label-$value'),
      label: Text(label),
      initialSelection: value,
      width: 150,
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignSystem.spacingMd,
          vertical: DesignSystem.spacingSm,
        ),
        filled: true,
        fillColor: DesignSystem.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusSm),
          borderSide: const BorderSide(color: DesignSystem.border),
        ),
      ),
      dropdownMenuEntries: values
          .map((entry) => DropdownMenuEntry(value: entry, label: entry))
          .toList(),
      onSelected: (selected) {
        if (selected != null) onChanged(selected);
      },
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
  Widget build(BuildContext context) => StyleStackCard(
    onTap: onTap,
    onLongPress: onLongPress,
    backgroundColor: selected
        ? DesignSystem.secondary.withOpacity(0.15)
        : DesignSystem.surface,
    borderRadius: DesignSystem.radiusLg,
    padding: EdgeInsets.zero,
    margin: const EdgeInsets.only(bottom: DesignSystem.spacingMd),
    child: Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Keep the image region explicitly constrained. Flex children
            // inside a sliver/Stack can receive loose constraints during the
            // first layout pass and cascade into RenderBox hasSize errors.
            AspectRatio(
              aspectRatio: 1.05,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(DesignSystem.radiusLg),
                    topRight: Radius.circular(DesignSystem.radiusLg),
                  ),
                ),
                child: item.gridImageUrl == null
                    ? const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: DesignSystem.textTertiary,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(DesignSystem.radiusLg),
                          topRight: Radius.circular(DesignSystem.radiusLg),
                        ),
                        child: Image.network(
                          item.gridImageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                        ),
                      ),
              ),
            ),

            // Item details
            Padding(
              padding: const EdgeInsets.all(DesignSystem.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.spacingSm),

                  // Category
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignSystem.spacingSm,
                      vertical: DesignSystem.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusSm,
                      ),
                    ),
                    child: Text(
                      item.displayCategory,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: DesignSystem.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // Color if available
                  if (item.displayColor != null) ...[
                    const SizedBox(height: DesignSystem.spacingSm),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getColorFromString(item.displayColor!),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: DesignSystem.spacingSm),
                        Expanded(
                          child: Text(
                            item.displayColor!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
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
                boxShadow: DesignSystem.shadowMedium,
              ),
              padding: const EdgeInsets.all(DesignSystem.spacingSm),
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
                color: DesignSystem.secondary.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(DesignSystem.spacingSm),
              child: const Icon(Icons.favorite, color: Colors.white, size: 14),
            ),
          ),
      ],
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
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => StyleStackEmptyState(
    icon: icon,
    title: title,
    subtitle: subtitle,
    actionLabel: action != null ? actionLabel : null,
    onAction: action,
  );
}
