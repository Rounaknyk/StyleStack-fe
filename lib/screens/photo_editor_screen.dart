import 'dart:io';
import 'dart:ui' as ui;

import 'package:crop_image/crop_image.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../config/design_system.dart';

/// A lightweight, fully on-device editor used before wardrobe uploads.
/// Cropping and rotation do not consume backend or AI capacity.
class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key, required this.image});

  final File image;

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final CropController _controller = CropController();
  bool _saving = false;

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bitmap = await _controller.croppedBitmap();
      final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      bitmap.dispose();
      if (data == null) throw StateError('Could not export the edited photo.');
      final output = File(
        path.join(
          widget.image.parent.path,
          'stylestack_edit_${DateTime.now().microsecondsSinceEpoch}.png',
        ),
      );
      await output.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.pop(context, output);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this edit. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DesignSystem.primaryDark,
    appBar: AppBar(
      backgroundColor: DesignSystem.primaryDark,
      foregroundColor: Colors.white,
      title: const Text('Adjust photo'),
      actions: [
        TextButton(
          onPressed: _saving ? null : _finish,
          child: Text(
            _saving ? 'Saving…' : 'Done',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CropImage(
                controller: _controller,
                image: Image.file(widget.image),
                gridColor: Colors.white.withValues(alpha: .75),
                gridCornerSize: 24,
                gridThinWidth: 1,
                gridThickWidth: 2,
                scrimColor: Colors.black.withValues(alpha: .58),
                alwaysShowThirdLines: true,
                minimumImageSize: 80,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            color: const Color(0xFF102B29),
            child: Column(
              children: [
                const Text(
                  'Keep the complete item inside the frame. StyleStack removes the background after upload.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _EditorAction(
                      icon: Icons.rotate_left_rounded,
                      label: 'Left',
                      onPressed: _controller.rotateLeft,
                    ),
                    const SizedBox(width: 14),
                    _EditorAction(
                      icon: Icons.rotate_right_rounded,
                      label: 'Right',
                      onPressed: _controller.rotateRight,
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

class _EditorAction extends StatelessWidget {
  const _EditorAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white38),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  );
}
