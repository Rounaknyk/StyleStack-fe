import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe_item.dart';
import '../providers/auth_provider.dart';
import '../providers/wardrobe_provider.dart';
import 'camera_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<WardrobeProvider>().loadItems());
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 88, maxWidth: 1800);
    if (picked == null || !mounted) return;
    await _showPreview(File(picked.path));
  }

  Future<void> _showPreview(File image) async {
    await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => CameraPreviewScreen(
        image: image,
        onRetake: () async {
          final replacement = await _picker.pickImage(source: ImageSource.camera, imageQuality: 88, maxWidth: 1800);
          if (replacement == null || !mounted) return;
          Navigator.pop(context);
          await _showPreview(File(replacement.path));
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['My Wardrobe', 'Outfits', 'Profile'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: IndexedStack(index: _tab, children: const [WardrobeView(), OutfitsView(), ProfileView()]),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt), label: const Text('Add item'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom), label: 'Wardrobe'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_mosaic_outlined), selectedIcon: Icon(Icons.auto_awesome_mosaic), label: 'Outfits'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class WardrobeView extends StatelessWidget {
  const WardrobeView({super.key});
  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeProvider>();
    if (wardrobe.loading && wardrobe.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (wardrobe.error != null && wardrobe.items.isEmpty) {
      return _Message(icon: Icons.cloud_off, title: wardrobe.error!, action: () => wardrobe.loadItems(force: true));
    }
    if (wardrobe.items.isEmpty) {
      return const _Message(icon: Icons.checkroom_outlined, title: 'Your wardrobe is empty', subtitle: 'Tap “Add item” to photograph your first piece.');
    }
    return RefreshIndicator(
      onRefresh: () => wardrobe.loadItems(force: true),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .72),
        itemCount: wardrobe.items.length,
        itemBuilder: (_, index) => _ItemCard(item: wardrobe.items[index]),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});
  final WardrobeItem item;
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: item.imageUrl == null
              ? const ColoredBox(color: Color(0xFFE8E1DC), child: Center(child: Icon(Icons.image_outlined, size: 42)))
              : Image.network(item.imageUrl!, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image_outlined)))),
          Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(item.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
      );
}

class OutfitsView extends StatelessWidget {
  const OutfitsView({super.key});
  @override
  Widget build(BuildContext context) => const _Message(icon: Icons.auto_awesome_mosaic_outlined, title: 'Outfits coming soon', subtitle: 'Build looks from your wardrobe in the next release.');
}

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
      const SizedBox(height: 16),
      Text(user?.email ?? 'StyleStack user', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 24),
      OutlinedButton.icon(onPressed: () async {
        context.read<WardrobeProvider>().reset();
        await context.read<AuthProvider>().signOut();
      }, icon: const Icon(Icons.logout), label: const Text('Sign out')),
    ])));
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
    const SizedBox(height: 16),
    Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
    if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!, textAlign: TextAlign.center)],
    if (action != null) ...[const SizedBox(height: 20), FilledButton(onPressed: action, child: const Text('Try again'))],
  ])));
}
