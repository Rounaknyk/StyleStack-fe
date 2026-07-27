import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ScheduleCanvasDialog extends StatefulWidget {
  const ScheduleCanvasDialog({
    super.key,
    required this.styleId,
    required this.initialTitle,
  });

  final String styleId;
  final String initialTitle;

  static Future<bool?> show(
    BuildContext context, {
    required String styleId,
    required String initialTitle,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ScheduleCanvasDialog(
        styleId: styleId,
        initialTitle: initialTitle,
      ),
    );
  }

  @override
  State<ScheduleCanvasDialog> createState() => _ScheduleCanvasDialogState();
}

class _ScheduleCanvasDialogState extends State<ScheduleCanvasDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _locationController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController();
    _locationController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _schedule() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event title.')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    DateTime startAt = _selectedDate!;
    if (_selectedTime != null) {
      startAt = DateTime(
        startAt.year,
        startAt.month,
        startAt.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    try {
      final api = ApiService();
      await api.scheduleCanvasStyle(
        styleId: widget.styleId,
        title: title,
        description: _descController.text.trim(),
        location: _locationController.text.trim(),
        startAt: startAt,
        allDay: _selectedTime == null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Style scheduled to your Calendar!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Schedule to Calendar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Event Title',
                hintText: 'e.g. Dinner with friends',
              ),
              maxLength: 120,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _selectedDate == null
                          ? 'Select Date'
                          : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_outlined),
                    label: Text(
                      _selectedTime == null
                          ? 'Time (Opt)'
                          : _selectedTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (Optional)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _schedule,
          child: _isLoading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Schedule'),
        ),
      ],
    );
  }
}
