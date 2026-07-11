import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wardrobe_provider.dart';

class CameraPreviewScreen extends StatefulWidget {
  const CameraPreviewScreen({super.key, required this.image, required this.onRetake});
  final File image;
  final Future<void> Function() onRetake;

  @override
  State<CameraPreviewScreen> createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  final _name = TextEditingController();
  final _category = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _category.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a name and category.')));
      return;
    }
    final wardrobe = context.read<WardrobeProvider>();
    final saved = await wardrobe.upload(widget.image, _name.text, _category.text);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(wardrobe.error ?? 'Upload failed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploading = context.watch<WardrobeProvider>().uploading;
    return Scaffold(
      appBar: AppBar(title: const Text('Add to wardrobe')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(aspectRatio: 3 / 4, child: Image.file(widget.image, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 20),
            TextField(controller: _name, enabled: !uploading, decoration: const InputDecoration(labelText: 'Item name')),
            const SizedBox(height: 12),
            TextField(controller: _category, enabled: !uploading, decoration: const InputDecoration(labelText: 'Category')),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: uploading ? null : widget.onRetake,
                icon: const Icon(Icons.camera_alt_outlined), label: const Text('Retake'),
              )),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(
                onPressed: uploading ? null : _save,
                icon: uploading
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(uploading ? 'Uploading…' : 'Save'),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}
