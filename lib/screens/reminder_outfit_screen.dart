import 'package:flutter/material.dart';

import '../config/design_system.dart';
import '../models/outfit.dart';
import '../services/api_service.dart';

class ReminderOutfitScreen extends StatefulWidget {
  const ReminderOutfitScreen({super.key, required this.outfitId, this.title});

  final String outfitId;
  final String? title;

  @override
  State<ReminderOutfitScreen> createState() => _ReminderOutfitScreenState();
}

class _ReminderOutfitScreenState extends State<ReminderOutfitScreen> {
  Outfit? _outfit;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final outfit = await ApiService().fetchOutfit(widget.outfitId);
      if (mounted) setState(() => _outfit = outfit);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title ?? 'Your planned outfit')),
    body: _error != null
        ? Center(child: Text(_error!))
        : _outfit == null
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Wear these together',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(_outfit!.reasoning),
                const SizedBox(height: 18),
                Expanded(child: _ReminderOutfitBoard(outfit: _outfit!)),
              ],
            ),
          ),
  );
}

class _ReminderOutfitBoard extends StatelessWidget {
  const _ReminderOutfitBoard({required this.outfit});
  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final count = outfit.items.length;
    final columns = count <= 2
        ? count
        : count <= 4
        ? 2
        : 3;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8F3), Color(0xFFF0DDD3)],
        ),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
      ),
      child: count == 0
          ? const Center(child: Text('No wardrobe pieces are attached.'))
          : GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
              ),
              itemBuilder: (_, index) {
                final item = outfit.items[index];
                return Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: item.imageUrl == null
                            ? const Icon(Icons.checkroom_outlined, size: 42)
                            : Image.network(
                                item.imageUrl!,
                                fit: BoxFit.contain,
                              ),
                      ),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
