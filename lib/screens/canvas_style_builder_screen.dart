import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/design_system.dart';
import '../models/wardrobe_item.dart';
import '../models/canvas_style.dart';
import '../models/calendar_models.dart';
import '../providers/wardrobe_provider.dart';
import '../services/api_service.dart';
import '../services/image_cache_service.dart';
import '../services/notification_service.dart';
import '../widgets/schedule_canvas_dialog.dart';
import 'saved_styles_screen.dart';
import 'style_story_share_screen.dart';

class CanvasStyleBuilderScreen extends StatefulWidget {
  const CanvasStyleBuilderScreen({super.key, this.initialStyle, this.calendarEvent});
  final CanvasStyle? initialStyle;
  final StyleCalendarEvent? calendarEvent;

  @override
  State<CanvasStyleBuilderScreen> createState() =>
      _CanvasStyleBuilderScreenState();
}

class _PlacedCanvasItem {
  _PlacedCanvasItem({required this.item, required this.x, required this.y});
  final WardrobeItem item;
  double x;
  double y;
  double scale = 1;
  double rotation = 0;
  double _startScale = 1;
  double _startRotation = 0;

  void beginGesture() {
    _startScale = scale;
    _startRotation = rotation;
  }

  void updateGesture(ScaleUpdateDetails details) {
    x += details.focalPointDelta.dx;
    y += details.focalPointDelta.dy;
    scale = (_startScale * details.scale).clamp(.35, 3.5).toDouble();
    rotation = _startRotation + details.rotation;
  }

  void resizeFromHandle(DragUpdateDetails details) {
    final delta = (details.delta.dx + details.delta.dy) / 180;
    scale = (scale + delta).clamp(.35, 3.5).toDouble();
  }

  void rotateFromHandle(DragUpdateDetails details) {
    // At the bottom-left corner, clockwise motion is up (-dy) and left (-dx).
    // In Flutter, positive rotation is clockwise. So we subtract the delta.
    final delta = (details.delta.dx + details.delta.dy) / 100;
    rotation -= delta;
  }

  Map<String, dynamic> toJson() => {
    'item_id': item.id,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
  };
}



enum _CanvasCategory { tops, bottoms, shoes, accessories, hats }

extension _CanvasCategoryPresentation on _CanvasCategory {
  String get title => switch (this) {
    _CanvasCategory.tops => 'Tops',
    _CanvasCategory.bottoms => 'Bottoms',
    _CanvasCategory.shoes => 'Shoes',
    _CanvasCategory.accessories => 'Accessories',
    _CanvasCategory.hats => 'Hats',
  };
}

_CanvasCategory _canvasCategoryFor(WardrobeItem item) {
  final explicitCategory = item.displayCategory.trim().toLowerCase();
  if (explicitCategory.contains("accessor") ||
      explicitCategory.contains("bag") ||
      explicitCategory.contains("jewell") ||
      explicitCategory.contains("watch")) {
    return _CanvasCategory.accessories;
  }
  if (explicitCategory.contains("shoe") ||
      explicitCategory.contains("footwear")) {
    return _CanvasCategory.shoes;
  }
  if (explicitCategory.contains("bottom") ||
      explicitCategory.contains("pant")) {
    return _CanvasCategory.bottoms;
  }
  if (explicitCategory.contains("hat") ||
      explicitCategory.contains("headwear")) {
    return _CanvasCategory.hats;
  }
  if (explicitCategory.contains("top") ||
      explicitCategory.contains("shirt") ||
      explicitCategory.contains("outerwear") ||
      explicitCategory.contains("dress") ||
      explicitCategory.contains("ethnic")) {
    return _CanvasCategory.tops;
  }

  final values = <String>[
    item.aiCategory ?? "",
    item.name,
    ...item.tags,
  ].join(" ").toLowerCase();
  bool hasAny(List<String> words) => words.any(values.contains);

  if (hasAny(const ['hat', 'cap', 'beanie', 'turban', 'headwear'])) {
    return _CanvasCategory.hats;
  }
  if (hasAny(const [
    'shoe',
    'sneaker',
    'trainer',
    'boot',
    'sandal',
    'slipper',
    'heel',
    'loafer',
    'footwear',
    'crocs',
  ])) {
    return _CanvasCategory.shoes;
  }
  if (hasAny(const [
    'pants',
    'pant',
    'trouser',
    'jean',
    'shorts',
    'skirt',
    'bottom',
    'salwar',
    'palazzo',
    'dhoti',
    'legging',
    'jogger',
  ])) {
    return _CanvasCategory.bottoms;
  }
  if (hasAny(const [
    'shirt',
    't-shirt',
    'tshirt',
    'tee',
    'top',
    'blouse',
    'kurta',
    'sweater',
    'hoodie',
    'jacket',
    'outerwear',
    'sweatshirt',
    'dress',
    'saree',
    'lehenga',
    'sherwani',
    'jumpsuit',
  ])) {
    return _CanvasCategory.tops;
  }
  return _CanvasCategory.accessories;
}

class _CanvasStyleBuilderScreenState extends State<CanvasStyleBuilderScreen> {
  final _canvasKey = GlobalKey();
  final _api = ApiService();
  final List<_PlacedCanvasItem> _placed = [];
  String? _selectedId;
  bool _saving = false;
  bool _exportingCanvas = false;
  bool _initialStyleRestored = false;
  _PlacedCanvasItem? _gestureTarget;
  _CanvasCategory _activeCategory = _CanvasCategory.tops;
  double _canvasZoom = 1;
  Offset _canvasPan = Offset.zero;
  double _gestureStartZoom = 1;
  Offset _gestureStartPan = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;

  void _clearCanvasSelection() {
    if (_selectedId != null) setState(() => _selectedId = null);
  }



  @override
  void initState() {
    super.initState();
  }

  void _restoreInitialStyle(List<WardrobeItem> items) {
    final style = widget.initialStyle;
    if (!mounted || style == null || _initialStyleRestored) return;
    final byId = {for (final item in items) item.id: item};
    final restored = style.items
        .map((saved) {
          final item = byId[saved.itemId];
          if (item == null) return null;
          return _PlacedCanvasItem(item: item, x: saved.x, y: saved.y)
            ..scale = saved.scale
            ..rotation = saved.rotation;
        })
        .whereType<_PlacedCanvasItem>()
        .toList();
    _initialStyleRestored = true;
    if (restored.isNotEmpty) setState(() => _placed.addAll(restored));
  }

  Future<void> _save() async {
    if (_placed.isEmpty || _saving) {
      if (_placed.isEmpty) _message('Add at least one wardrobe item first.');
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(
          text: widget.initialStyle?.name ?? 'My style',
        );
        return AlertDialog(
          title: const Text('Save your style'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Style name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureCleanCanvas();
      final styleId = widget.initialStyle?.id;
      var savedStyleId = styleId;
      if (styleId == null) {
        final created = await _api.createCanvasStyle(
          name: name.trim(),
          items: _placed.map((item) => item.toJson()).toList(),
          previewBytes: bytes,
        );
        savedStyleId = created.id;
      } else {
        await _api.updateCanvasStyle(
          styleId: styleId,
          name: name.trim(),
          items: _placed.map((item) => item.toJson()).toList(),
          previewBytes: bytes,
        );
      }
      
      if (widget.calendarEvent != null && savedStyleId != null) {
        final event = widget.calendarEvent!;
        final createdEvent = await _api.scheduleCanvasStyle(
          styleId: savedStyleId,
          title: event.title,
          startAt: event.startAt,
          eventId: event.id == 'new' ? null : event.id,
        );
        if (createdEvent.outfitId != null) {
          await NotificationService.scheduleOutfitReminder(
            outfitId: createdEvent.outfitId!,
            eventName: event.title,
            eventDate: event.startAt,
          );
        }
        if (!mounted) return;
        _message('Outfit planned!');
        Navigator.pop(context); // Go back to calendar
        return;
      }

      if (!mounted) return;
      _message(
        styleId == null ? 'Style saved to My Styles.' : 'Style updated.',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SavedStylesScreen()),
      );
    } on ApiException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('Could not save this style.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List> _captureCleanCanvas() async {
    final previousSelection = _selectedId;
    setState(() {
      _selectedId = null;
      _exportingCanvas = true;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          _canvasKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw const ApiException('Canvas is not ready yet.');
      }
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw const ApiException('Could not capture the canvas.');
      }
      return bytes.buffer.asUint8List();
    } finally {
      if (mounted) {
        setState(() {
          _selectedId = previousSelection;
          _exportingCanvas = false;
        });
      }
    }
  }

  Future<void> _shareCanvas() async {
    if (_placed.isEmpty) {
      _message('Add an item before sharing your style.');
      return;
    }
    try {
      final bytes = await _captureCleanCanvas();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StyleStoryShareScreen.fromBytes(
            canvasBytes: bytes,
            styleName: widget.initialStyle?.name ?? 'Styled by me',
          ),
        ),
      );
    } catch (_) {
      _message('Could not share this style.');
    }
  }

  void _add(WardrobeItem item) {
    final index = _placed.length;
    setState(() {
      _placed.add(
        _PlacedCanvasItem(
          item: item,
          x: 30 + (index % 3) * 36,
          y: 30 + (index % 3) * 42,
        ),
      );
      _selectedId = item.id;
    });
  }

  void _drop(WardrobeItem item, Offset globalOffset) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    setState(() {
      _placed.add(
        _PlacedCanvasItem(item: item, x: local.dx - 54, y: local.dy - 54),
      );
      _selectedId = item.id;
    });
  }

  Future<void> _scheduleCanvas() async {
    if (widget.initialStyle == null) {
      _message('Please save your style first before scheduling.');
      return;
    }
    await ScheduleCanvasDialog.show(
      context,
      styleId: widget.initialStyle!.id,
      initialTitle: widget.initialStyle!.name,
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    final items = wardrobe.items;

    if (!_initialStyleRestored &&
        widget.initialStyle != null &&
        wardrobe.loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreInitialStyle(items);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialStyle == null ? 'Create Style' : 'Edit Style',
        ),
        actions: [
          IconButton(
            onPressed: _placed.isEmpty ? null : () => setState(_placed.clear),
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear canvas',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: DragTarget<WardrobeItem>(
                onAcceptWithDetails: (details) =>
                    _drop(details.data, details.offset),
                builder: (context, candidates, rejected) => RepaintBoundary(
                  key: _canvasKey,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusLg,
                      ),
                      boxShadow: DesignSystem.shadowSoft,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        DesignSystem.radiusLg,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _clearCanvasSelection,
                            child: Transform.translate(
                              offset: _canvasPan,
                              child: Transform.scale(
                                alignment: Alignment.center,
                                scale: _canvasZoom,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_placed.isEmpty)
                                      const Center(
                                        child: Text(
                                          'Drag wardrobe pieces here',
                                          style: TextStyle(
                                            color: DesignSystem.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ..._placed.map(_placedWidget),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: _Sidebar(
              items: items,
              activeCategory: _activeCategory,
              onCategoryChanged: (category) =>
                  setState(() => _activeCategory = category),
              onAdd: _add,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Outfit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placedWidget(_PlacedCanvasItem placed) {
    final selected = !_exportingCanvas && _selectedId == placed.item.id;
    void beginGesture() {
      // Once a piece is selected, a drag that starts over another overlapping
      // piece still manipulates the selected piece. A simple tap can still
      // change selection via onTap below.
      _gestureTarget = _selectedId == null || selected
          ? placed
          : _placed.firstWhere(
              (candidate) => candidate.item.id == _selectedId,
              orElse: () => placed,
            );
      _gestureTarget!.beginGesture();
    }

    void updateGesture(ScaleUpdateDetails details) {
      final target = _gestureTarget ?? placed;
      setState(() => target.updateGesture(details));
    }

    return Positioned(
      left: placed.x,
      top: placed.y,
      child: GestureDetector(
        onTap: () => setState(() => _selectedId = placed.item.id),
        onScaleStart: (_) => beginGesture(),
        onScaleUpdate: updateGesture,
        onScaleEnd: (_) => _gestureTarget = null,
        child: Transform.rotate(
          angle: placed.rotation,
          child: Transform.scale(
            scale: placed.scale,
            child: SizedBox(
              width: 118,
              height: 118,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: selected
                          ? Border.all(color: DesignSystem.border, width: 1.5)
                          : Border.all(color: Colors.transparent, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: placed.item.canvasImageUrl == null
                        ? const Icon(Icons.checkroom_outlined, size: 38)
                        : CachedNetworkImage(
                            imageUrl: placed.item.canvasImageUrl!,
                            cacheKey:
                                'canvas-${placed.item.id}-${placed.item.aiTagStatus}',
                            cacheManager: StyleStackImageCache.instance,
                            maxWidthDiskCache: 720,
                            memCacheWidth: 360,
                            fadeInDuration: Duration.zero,
                            fit: BoxFit.contain,
                            errorWidget: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                  ),
                  if (selected)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Material(
                        color: Colors.white,
                        elevation: 2,
                        shadowColor: Colors.black26,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() {
                            _placed.remove(placed);
                            _selectedId = null;
                          }),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: DesignSystem.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            setState(() => placed.resizeFromHandle(details)),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.open_in_full_rounded,
                              size: 16,
                              color: DesignSystem.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            setState(() => placed.rotateFromHandle(details)),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.rotate_right_rounded,
                              size: 16,
                              color: DesignSystem.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.activeCategory,
    required this.onCategoryChanged,
    required this.onAdd,
  });

  final List<WardrobeItem> items;
  final _CanvasCategory activeCategory;
  final ValueChanged<_CanvasCategory> onCategoryChanged;
  final ValueChanged<WardrobeItem> onAdd;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items
        .where((item) => _canvasCategoryFor(item) == activeCategory)
        .toList(growable: false);
    final counts = <_CanvasCategory, int>{
      for (final category in _CanvasCategory.values)
        category: items
            .where((item) => _canvasCategoryFor(item) == category)
            .length,
    };

    return Container(
      decoration: const BoxDecoration(
        color: DesignSystem.surfaceAlt,
        border: Border(top: BorderSide(color: DesignSystem.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Add items',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${visibleItems.length} available',
                  style: const TextStyle(
                    color: DesignSystem.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
              itemCount: _CanvasCategory.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final category = _CanvasCategory.values[index];
                final active = category == activeCategory;
                return _CategoryTab(
                  category: category,
                  count: counts[category] ?? 0,
                  active: active,
                  onTap: () => onCategoryChanged(category),
                );
              },
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: DesignSystem.transitionStandard,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(.035, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: visibleItems.isEmpty
                  ? Center(
                      key: ValueKey('empty-${activeCategory.name}'),
                      child: Text(
                        'No ${activeCategory.title.toLowerCase()} yet',
                        style: const TextStyle(
                          color: DesignSystem.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : GridView.builder(
                      key: ValueKey('items-${activeCategory.name}'),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: visibleItems.length,
                      itemBuilder: (context, index) {
                        final item = visibleItems[index];
                        return LongPressDraggable<WardrobeItem>(
                          delay: const Duration(milliseconds: 200),
                          data: item,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: _SidebarTile(item: item),
                            ),
                          ),
                          child: _SidebarTile(
                            item: item,
                            onTap: () => onAdd(item),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.category,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final _CanvasCategory category;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: active,
    label: '${category.title}, $count items',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: DesignSystem.transitionQuick,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? DesignSystem.textPrimary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          category.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active
                ? DesignSystem.textPrimary
                : DesignSystem.textSecondary,
          ),
        ),
      ),
    ),
  );
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, this.onTap});
  final WardrobeItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: DesignSystem.border.withValues(alpha: .5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.gridImageUrl == null
                      ? const Icon(Icons.checkroom_outlined, color: DesignSystem.textSecondary)
                      : CachedNetworkImage(
                          imageUrl: item.gridImageUrl!,
                          cacheKey: item.gridImageCacheKey,
                          cacheManager: StyleStackImageCache.instance,
                          maxWidthDiskCache: 240,
                          memCacheWidth: 120,
                          fadeInDuration: Duration.zero,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: DesignSystem.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
