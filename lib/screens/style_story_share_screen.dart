import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../config/brand_logo.dart';
import '../config/design_system.dart';

/// A fixed 9:16 branded card used for Instagram Story exports.
///
/// Keeping the design at 360x640 logical pixels and capturing at 3x produces
/// Instagram's preferred 1080x1920 output without depending on device size.
class StyleStoryCard extends StatelessWidget {
  const StyleStoryCard({
    super.key,
    required this.canvasImage,
    required this.styleName,
  });

  final ImageProvider canvasImage;
  final String styleName;

  @override
  Widget build(BuildContext context) {
    final cleanName = styleName.trim().isEmpty
        ? 'My style edit'
        : styleName.trim();
    return SizedBox(
      width: 360,
      height: 640,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D2C28), Color(0xFF174E47)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: -46,
              top: 54,
              child: _StoryOrb(size: 150, color: Color(0x22EBD3BA)),
            ),
            const Positioned(
              left: -56,
              bottom: 80,
              child: _StoryOrb(size: 132, color: Color(0x18FFFFFF)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _StoryBrand(),
                  const Spacer(),
                  const Text(
                    'STYLE EDIT / 01',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      color: DesignSystem.secondaryLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    cleanName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.02,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    flex: 8,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .72),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ColoredBox(
                          color: Colors.white,
                          child: Image(
                            image: canvasImage,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your wardrobe. Your point of view.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create, remix and wear what already feels like you.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: DesignSystem.cta,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'CREATE YOUR LOOK',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_outward_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StyleStoryShareScreen extends StatefulWidget {
  const StyleStoryShareScreen({
    super.key,
    required this.canvasImage,
    required this.styleName,
  });

  final ImageProvider canvasImage;
  final String styleName;

  factory StyleStoryShareScreen.fromBytes({
    required Uint8List canvasBytes,
    required String styleName,
  }) => StyleStoryShareScreen(
    canvasImage: MemoryImage(canvasBytes),
    styleName: styleName,
  );

  @override
  State<StyleStoryShareScreen> createState() => _StyleStoryShareScreenState();
}

class _StyleStoryShareScreenState extends State<StyleStoryShareScreen> {
  final GlobalKey _storyKey = GlobalKey();
  bool _precacheStarted = false;
  bool _imageReady = false;
  bool _sharing = false;
  Object? _precacheError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precacheStarted || _imageReady || _precacheError != null) return;
    _precacheStarted = true;
    precacheImage(widget.canvasImage, context)
        .then((_) {
          if (mounted) setState(() => _imageReady = true);
        })
        .catchError((Object error) {
          if (mounted) setState(() => _precacheError = error);
        });
  }

  Future<Uint8List> _renderStory() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _storyKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('Story preview is not ready.');
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not render the Story image.');
    return bytes.buffer.asUint8List();
  }

  Future<void> _shareStory() async {
    if (!_imageReady || _sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _renderStory();
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'stylestack-instagram-story.png',
            mimeType: 'image/png',
          ),
        ],
        text: 'Built with StyleStack — style your wardrobe your way.',
        subject: widget.styleName,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create your Story image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Share your style')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Story-ready',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your canvas is framed in a 9:16 StyleStack edit, ready to post.',
                    style: TextStyle(
                      color: DesignSystem.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SizedBox(
                      height: constraints.maxHeight.clamp(450, 610).toDouble(),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: RepaintBoundary(
                          key: _storyKey,
                          child: StyleStoryCard(
                            canvasImage: widget.canvasImage,
                            styleName: widget.styleName,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_precacheError != null)
                    const Text(
                      'The saved canvas could not be loaded. Open the style and try again.',
                      style: TextStyle(color: DesignSystem.error),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _imageReady && !_sharing
                            ? _shareStory
                            : null,
                        icon: _sharing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.ios_share_rounded),
                        label: Text(
                          _sharing
                              ? 'Preparing 1080 × 1920…'
                              : 'Share to Instagram Story',
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Choose Instagram from the share sheet, then select Story.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: DesignSystem.textTertiary,
                        fontSize: 12,
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
  );
}

class _StoryBrand extends StatelessWidget {
  const _StoryBrand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(7),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const StyleStackLogo(size: 24),
      ),
      const SizedBox(width: 10),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STYLESTACK',
            style: TextStyle(
              fontFamily: 'Manrope',
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          SizedBox(height: 1),
          Text(
            'BUILT FROM YOUR WARDROBE',
            style: TextStyle(
              fontFamily: 'Manrope',
              color: DesignSystem.secondaryLight,
              fontSize: 7,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.05,
            ),
          ),
        ],
      ),
    ],
  );
}

class _StoryOrb extends StatelessWidget {
  const _StoryOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
