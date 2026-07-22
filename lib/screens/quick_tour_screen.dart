import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/design_system.dart';

/// Shows the short product tour once for each signed-in account on a device.
class QuickTourGate extends StatefulWidget {
  const QuickTourGate({super.key, required this.userId, required this.child});

  final String userId;
  final Widget child;

  @override
  State<QuickTourGate> createState() => _QuickTourGateState();
}

class _QuickTourGateState extends State<QuickTourGate> {
  bool _loading = true;
  bool _completed = false;

  String get _preferenceKey => 'quick_tour_v1_${widget.userId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant QuickTourGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      setState(() {
        _loading = true;
        _completed = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final preferenceKey = _preferenceKey;
    final preferences = await SharedPreferences.getInstance();
    final completed = preferences.getBool(preferenceKey) ?? false;
    if (!mounted || preferenceKey != _preferenceKey) return;
    setState(() {
      _completed = completed;
      _loading = false;
    });
  }

  Future<void> _complete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, true);
    if (mounted) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_completed) return widget.child;
    return QuickTourScreen(onFinished: _complete);
  }
}

class QuickTourScreen extends StatefulWidget {
  const QuickTourScreen({super.key, required this.onFinished});

  final Future<void> Function() onFinished;

  @override
  State<QuickTourScreen> createState() => _QuickTourScreenState();
}

class _QuickTourScreenState extends State<QuickTourScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _slides = [
    _TourSlideData(
      eyebrow: 'BUILD YOUR DIGITAL CLOSET',
      title: 'Start with the clothes you own.',
      body:
          'Photograph one complete item at a time. Crop or rotate it, then leave background preparation and item details to StyleStack.',
      assetPath: 'assets/images/help/item_photo.webp',
      icon: Icons.add_a_photo_outlined,
      color: Color(0xFFF2E3D5),
    ),
    _TourSlideData(
      eyebrow: 'YOUR DAILY STYLE EDIT',
      title: 'Get an outfit without searching.',
      body:
          'Today automatically creates a strong look from your wardrobe and explains why its colour, shape and styling work together.',
      assetPath: 'assets/images/help/todays_outfit.webp',
      icon: Icons.auto_awesome_outlined,
      color: Color(0xFFDCEDEA),
    ),
    _TourSlideData(
      eyebrow: 'DRESS FOR REAL PLANS',
      title: 'Let your calendar lead when it matters.',
      body:
          'Connect Google Calendar for event-aware looks, or ask your stylist directly when you have a specific occasion or mood.',
      assetPath: 'assets/images/help/style_tools.webp',
      icon: Icons.calendar_month_outlined,
      color: Color(0xFFE9E2F2),
    ),
    _TourSlideData(
      eyebrow: 'MAKE IT PERSONAL',
      title: 'Log what you actually wore.',
      body:
          'Logging outfits builds useful history and helps StyleStack avoid recently worn clothes while keeping accessories reusable.',
      assetPath: 'assets/images/help/outfit_log.webp',
      icon: Icons.check_circle_outline_rounded,
      color: Color(0xFFE8E2D6),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await widget.onFinished();
    if (mounted) setState(() => _finishing = false);
  }

  void _previous() {
    if (_page == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Text(
                  'QUICK TOUR  ${_page + 1} OF ${_slides.length}',
                  style: const TextStyle(
                    color: DesignSystem.primary,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _finishing ? null : _finish,
                  child: const Text('Skip'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => _TourSlide(data: _slides[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: index == _page ? 24 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? DesignSystem.primary
                            : DesignSystem.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    SizedBox.square(
                      dimension: 54,
                      child: OutlinedButton(
                        onPressed: _page == 0 ? null : _previous,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _finishing ? null : _next,
                          icon: _finishing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _page == _slides.length - 1
                                      ? Icons.check_rounded
                                      : Icons.arrow_forward_rounded,
                                ),
                          label: Text(
                            _page == _slides.length - 1
                                ? 'Start styling'
                                : 'Next',
                          ),
                          style: FilledButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: DesignSystem.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TourSlide extends StatelessWidget {
  const _TourSlide({required this.data});

  final _TourSlideData data;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Image.asset(
              data.assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .78),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    data.icon,
                    size: 58,
                    color: DesignSystem.primaryDark,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          data.eyebrow,
          style: const TextStyle(
            color: DesignSystem.secondary,
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          data.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          data.body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: DesignSystem.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}

class _TourSlideData {
  const _TourSlideData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.assetPath,
    required this.icon,
    required this.color,
  });

  final String eyebrow;
  final String title;
  final String body;
  final String assetPath;
  final IconData icon;
  final Color color;
}
