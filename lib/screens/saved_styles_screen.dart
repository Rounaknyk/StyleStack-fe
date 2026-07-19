import 'package:flutter/material.dart';

import '../config/design_system.dart';
import '../config/custom_widgets.dart';
import '../models/canvas_style.dart';
import '../services/api_service.dart';
import 'canvas_style_builder_screen.dart';

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Styles')),
    body: FutureBuilder<List<CanvasStyle>>(
      future: _styles,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const StyleStackLoadingIndicator(
            message: 'Opening your saved styles…',
          );
        }
        if (snapshot.hasError)
          return Center(
            child: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          );
        final styles = snapshot.data ?? const <CanvasStyle>[];
        if (styles.isEmpty)
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.dashboard_customize_outlined,
                    size: 54,
                    color: DesignSystem.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No saved styles yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Arrange your wardrobe pieces on a canvas and save your first look.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CanvasStyleBuilderScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create style'),
                  ),
                ],
              ),
            ),
          );
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: styles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: .78,
            ),
            itemBuilder: (context, index) {
              final style = styles[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CanvasStyleBuilderScreen(initialStyle: style),
                      ),
                    );
                    if (context.mounted) _reload();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: style.previewUrl == null
                            ? const Center(
                                child: Icon(Icons.image_outlined, size: 42),
                              )
                            : Image.network(
                                style.previewUrl!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                errorBuilder: (_, _, _) => const Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 4, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                style.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                await _api.deleteCanvasStyle(style.id);
                                if (context.mounted) _reload();
                              },
                              icon: const Icon(Icons.delete_outline, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CanvasStyleBuilderScreen()),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Create style'),
    ),
  );
}
