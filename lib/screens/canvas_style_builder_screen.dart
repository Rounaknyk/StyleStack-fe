import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/design_system.dart';
import '../models/wardrobe_item.dart';
import '../models/canvas_style.dart';
import '../providers/wardrobe_provider.dart';
import '../services/api_service.dart';
import 'saved_styles_screen.dart';

class CanvasStyleBuilderScreen extends StatefulWidget {
  const CanvasStyleBuilderScreen({super.key, this.initialStyle});
  final CanvasStyle? initialStyle;

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

  Map<String, dynamic> toJson() => {
    'item_id': item.id,
    'x': x,
    'y': y,
    'scale': scale,
    'rotation': rotation,
  };
}

class _CanvasGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = DesignSystem.border.withValues(alpha: .42)
      ..strokeWidth = .7;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CanvasStyleBuilderScreenState extends State<CanvasStyleBuilderScreen> {
  final _canvasKey = GlobalKey();
  final _api = ApiService();
  final List<_PlacedCanvasItem> _placed = [];
  String? _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreInitialStyle());
  }

  void _restoreInitialStyle() {
    final style = widget.initialStyle;
    if (!mounted || style == null || _placed.isNotEmpty) return;
    final byId = {
      for (final item in context.read<WardrobeProvider>().items) item.id: item,
    };
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
      final boundary =
          _canvasKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null)
        throw const ApiException('Canvas is not ready yet.');
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null)
        throw const ApiException('Could not capture the canvas.');
      final styleId = widget.initialStyle?.id;
      if (styleId == null) {
        await _api.createCanvasStyle(
          name: name.trim(),
          items: _placed.map((item) => item.toJson()).toList(),
          previewBytes: bytes.buffer.asUint8List(),
        );
      } else {
        await _api.updateCanvasStyle(
          styleId: styleId,
          name: name.trim(),
          items: _placed.map((item) => item.toJson()).toList(),
          previewBytes: bytes.buffer.asUint8List(),
        );
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

  Future<void> _shareCanvas() async {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _placed.isEmpty) {
      _message('Add an item before sharing your style.');
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null)
        throw const ApiException('Could not capture the canvas.');
      await Share.shareXFiles([
        XFile.fromData(
          data.buffer.asUint8List(),
          name: 'stylestack-style.png',
          mimeType: 'image/png',
        ),
      ], text: widget.initialStyle?.name ?? 'My Style on StyleStack');
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

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    final items = wardrobe.items;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialStyle == null ? 'Create Style' : 'Edit Style',
        ),
        actions: [
          IconButton(
            onPressed: _shareCanvas,
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Share style',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedStylesScreen()),
            ),
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: 'My Styles',
          ),
          IconButton(
            onPressed: _placed.isEmpty ? null : () => setState(_placed.clear),
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear canvas',
          ),
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            tooltip: 'Save style',
          ),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: (MediaQuery.sizeOf(context).width * .25).clamp(96.0, 180.0),
            child: _Sidebar(items: items, onAdd: _add),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
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
                      child: CustomPaint(
                        painter: _CanvasGridPainter(),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placedWidget(_PlacedCanvasItem placed) {
    final selected = _selectedId == placed.item.id;
    return Positioned(
      left: placed.x,
      top: placed.y,
      child: GestureDetector(
        onTap: () => setState(() => _selectedId = placed.item.id),
        onScaleStart: (_) => placed.beginGesture(),
        onScaleUpdate: (details) =>
            setState(() => placed.updateGesture(details)),
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
                          ? Border.all(color: DesignSystem.primary, width: 2)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: placed.item.canvasImageUrl == null
                        ? const Icon(Icons.checkroom_outlined, size: 38)
                        : Image.network(
                            placed.item.canvasImageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                  ),
                  if (selected)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Material(
                        color: DesignSystem.error,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() {
                            _placed.remove(placed);
                            _selectedId = null;
                          }),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
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
  const _Sidebar({required this.items, required this.onAdd});
  final List<WardrobeItem> items;
  final ValueChanged<WardrobeItem> onAdd;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: DesignSystem.surfaceAlt,
      border: Border(right: BorderSide(color: DesignSystem.border)),
    ),
    child: ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0)
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Text(
              'Your pieces',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        final item = items[index - 1];
        return LongPressDraggable<WardrobeItem>(
          delay: const Duration(milliseconds: 260),
          data: item,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 90, child: _SidebarTile(item: item)),
          ),
          child: _SidebarTile(item: item, onTap: () => onAdd(item)),
        );
      },
    ),
  );
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({required this.item, this.onTap});
  final WardrobeItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: item.gridImageUrl == null
                  ? const Icon(Icons.checkroom_outlined)
                  : Image.network(item.gridImageUrl!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );
}
