import 'package:flutter/material.dart';

import '../config/design_system.dart';
import '../models/outfit.dart';
import '../services/api_service.dart';

class StylistChatScreen extends StatefulWidget {
  const StylistChatScreen({super.key, required this.city});
  final String city;

  @override
  State<StylistChatScreen> createState() => _StylistChatScreenState();
}

class _StylistChatScreenState extends State<StylistChatScreen> {
  final _message = TextEditingController();
  final _api = ApiService();
  Outfit? _outfit;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final message = _message.text.trim();
    if (message.length < 3 || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.askStylist(message: message, city: widget.city);
      if (mounted) setState(() => _outfit = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach your stylist.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask your stylist')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
          children: [
            Text(
              'Tell me where you are going',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Describe the event, dress code, mood, or anything you want to feel like. I’ll style it from your wardrobe.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: DesignSystem.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _ask(),
              decoration: const InputDecoration(
                hintText: 'I have an interview tomorrow at 11 AM…',
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _ask,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? 'Styling your look…' : 'Suggest my outfit'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: DesignSystem.error)),
            ],
            if (_outfit != null) ...[
              const SizedBox(height: 26),
              Text(
                'Your stylist suggests',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _outfit!.items
                            .map((item) => Chip(label: Text(item.name)))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(_outfit!.reasoning),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
