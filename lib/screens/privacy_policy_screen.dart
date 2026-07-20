import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/design_system.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _assetPath = 'PRIVACY_POLICY.md';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy Policy')),
    body: FutureBuilder<String>(
      future: rootBundle.loadString(_assetPath),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'The Privacy Policy could not be loaded. Please contact '
                'rondevelops1904@gmail.com for a copy.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 48),
            children: _buildPolicy(context, snapshot.data!),
          ),
        );
      },
    ),
  );

  List<Widget> _buildPolicy(BuildContext context, String source) {
    final widgets = <Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            _clean(paragraph.join(' ')),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DesignSystem.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      );
      paragraph.clear();
    }

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flushParagraph();
        continue;
      }
      if (line.startsWith('# ')) {
        flushParagraph();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _clean(line.substring(2)),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('## ')) {
        flushParagraph();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              _clean(line.substring(3)),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('### ')) {
        flushParagraph();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              _clean(line.substring(4)),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('- ')) {
        flushParagraph();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: DesignSystem.primary,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: 5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _clean(line.substring(2)),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: DesignSystem.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      paragraph.add(line);
    }
    flushParagraph();
    return widgets;
  }

  String _clean(String value) => value.replaceAll('**', '').replaceAll('`', '');
}
