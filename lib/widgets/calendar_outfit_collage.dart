import 'package:flutter/material.dart';
import '../models/outfit.dart';
import '../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CalendarOutfitCollage extends StatefulWidget {
  const CalendarOutfitCollage({
    super.key,
    required this.outfitId,
    required this.api,
    this.size = 48,
  });

  final String outfitId;
  final ApiService api;
  final double size;

  @override
  State<CalendarOutfitCollage> createState() => _CalendarOutfitCollageState();
}

class _CalendarOutfitCollageState extends State<CalendarOutfitCollage> {
  Outfit? _outfit;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOutfit();
  }
  
  @override
  void didUpdateWidget(CalendarOutfitCollage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.outfitId != widget.outfitId) {
      _fetchOutfit();
    }
  }

  Future<void> _fetchOutfit() async {
    setState(() => _loading = true);
    try {
      final outfit = await widget.api.fetchOutfit(widget.outfitId);
      if (mounted) {
        setState(() {
          _outfit = outfit;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _outfit == null || _outfit!.items.isEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: _loading ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : const SizedBox(),
      );
    }

    final items = _outfit!.items.take(4).toList();
    final hasMore = _outfit!.items.length > 4;
    final extraCount = _outfit!.items.length - 4 + 1;

    return Container(
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF5), // Light blueish/grey bg for collage
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.count(
        crossAxisCount: items.length > 1 ? 2 : 1,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(items.length, (i) {
          final isLast = i == 3 && hasMore;
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: items[i].imageUrl ?? '',
                  fit: BoxFit.cover,
                  errorWidget: (c,u,e) => const Icon(Icons.broken_image, size: 12),
                ),
              ),
              if (isLast)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+$extraCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
