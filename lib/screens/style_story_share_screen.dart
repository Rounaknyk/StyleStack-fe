import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

import '../config/brand_logo.dart';
import '../config/design_system.dart';
import '../models/outfit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/image_cache_service.dart';

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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GET THE APP',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                color: DesignSystem.secondaryLight,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scan to download\nStyleStack free',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                color: Colors.white.withValues(alpha: .9),
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: QrImageView(
                          data: 'https://stylestackai.in/download',
                          version: QrVersions.auto,
                          size: 48.0,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
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
}


class OutfitStoryCard extends StatelessWidget {
  const OutfitStoryCard({
    super.key,
    required this.outfit,
  });

  final Outfit outfit;

  @override
  Widget build(BuildContext context) {
    final items = outfit.items.take(6).toList();
    final columns = items.length <= 4 ? 2 : 3;
    final rows = (items.length / (columns == 0 ? 1 : columns)).ceil();
    
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
                    'DAILY LOOK / OUTFIT',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      color: DesignSystem.secondaryLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    "My StyleStack Outfit",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 9.0;
                          const aspectRatio = .74;
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              childAspectRatio: aspectRatio,
                            ),
                            itemBuilder: (context, index) {
                              final imageUrl = items[index].canvasImageUrl;
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFF0F0F0)),
                                ),
                                child: imageUrl == null
                                    ? const Icon(Icons.checkroom_outlined, size: 34, color: DesignSystem.primaryDark)
                                    : CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        cacheKey: 'canvas-${items[index].id}-${items[index].aiTagStatus}',
                                        cacheManager: StyleStackImageCache.instance,
                                        fadeInDuration: Duration.zero,
                                        filterQuality: FilterQuality.high,
                                        fit: BoxFit.contain,
                                      ),
                              );
                            },
                          );
                        }
                      )
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GET THE APP',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                color: DesignSystem.secondaryLight,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scan to download\nStyleStack free',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                color: Colors.white.withValues(alpha: .9),
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: QrImageView(
                          data: 'https://stylestackai.in/download',
                          version: QrVersions.auto,
                          size: 48.0,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
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
}

class StyleStoryShareScreen extends StatefulWidget {
  const StyleStoryShareScreen({
    super.key,
    this.canvasImage,
    this.styleName = '',
    this.outfit,
  });

  final ImageProvider? canvasImage;
  final String styleName;
  final Outfit? outfit;

  factory StyleStoryShareScreen.fromBytes({
    required Uint8List canvasBytes,
    required String styleName,
  }) => StyleStoryShareScreen(
    canvasImage: MemoryImage(canvasBytes),
    styleName: styleName,
  );

  factory StyleStoryShareScreen.fromOutfit({
    required Outfit outfit,
  }) => StyleStoryShareScreen(
    outfit: outfit,
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
    if (widget.canvasImage != null) {
      precacheImage(widget.canvasImage!, context)
          .then((_) {
            if (mounted) setState(() => _imageReady = true);
          })
          .catchError((Object error) {
            if (mounted) setState(() => _precacheError = error);
          });
    } else {
      _imageReady = true;
    }
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


  Future<void> _downloadStory() async {
    if (!_imageReady || _sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _renderStory();
      if (!mounted) return;
      
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final request = await Gal.requestAccess();
        if (!request) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo library access is required to save images.')),
            );
          }
          return;
        }
      }
      
      await Gal.putImageBytes(bytes, name: 'stylestack-outfit-${DateTime.now().millisecondsSinceEpoch}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to your camera roll!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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
    appBar: AppBar(title: const Text('Export your style')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: _storyKey,
                        child: widget.outfit != null 
                            ? OutfitStoryCard(outfit: widget.outfit!) 
                            : StyleStoryCard(
                                canvasImage: widget.canvasImage!,
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _imageReady && !_sharing
                              ? _downloadStory
                              : null,
                          icon: _sharing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_rounded),
                          label: const Text('Download'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                          label: const Text('Post to socials'),
                        ),
                      ),
                    ],
                  ),
              ],
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
