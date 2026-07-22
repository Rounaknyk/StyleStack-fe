import 'package:flutter/material.dart';

import '../config/design_system.dart';

class AppHelpScreen extends StatelessWidget {
  const AppHelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('StyleStack guide')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
      children: const [
        _GuideHero(),
        SizedBox(height: 26),
        _GuideHeading(
          eyebrow: 'START HERE',
          title: 'Your wardrobe, styled for real life',
          body:
              'Add the clothes you actually own. StyleStack prepares each photo, understands the item, and builds looks from your closet.',
        ),
        SizedBox(height: 18),
        _GuideCard(
          number: '01',
          title: 'Photograph one item clearly',
          assetPath: 'assets/images/help/item_photo.webp',
          icon: Icons.add_a_photo_outlined,
          fallbackColor: Color(0xFFF2E3D5),
          points: [
            'Lay one item flat or hang it against a simple background.',
            'Use bright, even light and keep the complete item in frame.',
            'Avoid hands, clutter, deep shadows and overlapping clothes.',
            'Crop or rotate before adding. Background removal and AI details happen after upload.',
          ],
        ),
        _GuideCard(
          number: '02',
          title: 'Open Today for your daily edit',
          assetPath: 'assets/images/help/todays_outfit.webp',
          icon: Icons.auto_awesome_outlined,
          fallbackColor: Color(0xFFDCEDEA),
          points: [
            'Your strongest everyday look appears automatically.',
            'Calendar events take priority when an event is scheduled today.',
            '“Why this works” explains the colour, silhouette and styling logic.',
            'Weather keeps the outfit practical, but style remains the main decision.',
          ],
        ),
        _GuideCard(
          number: '03',
          title: 'Log what you actually wore',
          assetPath: 'assets/images/help/outfit_log.webp',
          icon: Icons.check_circle_outline_rounded,
          fallbackColor: Color(0xFFE9E2F2),
          points: [
            'Tap “Log this outfit” when you wear the recommendation.',
            'Choose “I wore something else” to select different wardrobe pieces.',
            'Recently worn clothes are avoided for three days; reusable accessories can repeat.',
            'Your history becomes a simple timeline of logged items.',
          ],
        ),
        _GuideCard(
          number: '04',
          title: 'Create, save and share your own style',
          assetPath: 'assets/images/help/style_tools.webp',
          icon: Icons.dashboard_customize_outlined,
          fallbackColor: Color(0xFFE8E2D6),
          points: [
            'Open Create Style and add wardrobe cutouts to the canvas.',
            'Move, resize and rotate each selected piece.',
            'Save the style to your private studio or share it as a branded story.',
            'Ask Your Stylist when you need a look for a specific plan or mood.',
          ],
        ),
        SizedBox(height: 4),
        _QuickHelp(),
      ],
    ),
  );
}

class _GuideHero extends StatelessWidget {
  const _GuideHero();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: DesignSystem.primaryDark,
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.checkroom_rounded, color: Colors.white, size: 34),
        SizedBox(height: 28),
        Text(
          'Meet your everyday stylist.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'Four simple steps are enough to turn your own closet into useful daily outfits.',
          style: TextStyle(color: Colors.white70, height: 1.45),
        ),
      ],
    ),
  );
}

class _GuideHeading extends StatelessWidget {
  const _GuideHeading({
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          color: DesignSystem.secondary,
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 7),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(
        body,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    ],
  );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.number,
    required this.title,
    required this.assetPath,
    required this.icon,
    required this.fallbackColor,
    required this.points,
  });

  final String number;
  final String title;
  final String assetPath;
  final IconData icon;
  final Color fallbackColor;
  final List<String> points;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: DesignSystem.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: fallbackColor,
              child: Center(
                child: Icon(icon, size: 62, color: DesignSystem.primaryDark),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STEP $number',
                style: const TextStyle(
                  color: DesignSystem.secondary,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final point in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 17,
                          color: DesignSystem.primary,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _QuickHelp extends StatelessWidget {
  const _QuickHelp();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: DesignSystem.surfaceAlt,
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More useful features',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 10),
        Text(
          '• Gmail Closet Sync imports eligible confirmed Amazon deliveries.\n• Google Calendar makes today’s real events styling priorities.\n• See the Vibe is optional inspiration, not an exact outfit match.\n• Your wardrobe photos and history stay private to your account.',
          style: TextStyle(height: 1.55),
        ),
      ],
    ),
  );
}
