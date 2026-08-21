import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_models.dart';
import '../services/api_service.dart';
import '../config/design_system.dart';
import 'calendar_outfit_collage.dart';

class CustomOutfitCalendar extends StatefulWidget {
  const CustomOutfitCalendar({
    super.key,
    required this.selectedDate,
    required this.events,
    required this.api,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final List<StyleCalendarEvent> events;
  final ApiService api;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<CustomOutfitCalendar> createState() => _CustomOutfitCalendarState();
}

class _CustomOutfitCalendarState extends State<CustomOutfitCalendar> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_displayedMonth.year, _displayedMonth.month);
    final firstDayOffset = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday % 7; // 0 for Sunday
    final totalCells = daysInMonth + firstDayOffset;
    final totalRows = (totalCells / 7).ceil();

    return Column(
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: _previousMonth,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.calendar_today_outlined, size: 20), onPressed: () {}),
                IconButton(icon: const Icon(Icons.view_agenda_outlined, size: 20), onPressed: () {}),
              ],
            )
          ],
        ),
        const SizedBox(height: 16),
        // Weekdays
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map((day) => Text(day, style: TextStyle(color: Colors.grey, fontSize: 13)))
              .toList(),
        ),
        const SizedBox(height: 16),
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalRows * 7,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            childAspectRatio: 0.65, // Taller cells for the collage + text
          ),
          itemBuilder: (context, index) {
            if (index < firstDayOffset || index >= firstDayOffset + daysInMonth) {
              return const SizedBox(); // Empty cell
            }
            final date = DateTime(_displayedMonth.year, _displayedMonth.month, index - firstDayOffset + 1);
            final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
            final isToday = DateUtils.isSameDay(date, DateTime.now());
            
            // Find if there's an outfit event on this day
            final dayEvents = widget.events.where((e) => DateUtils.isSameDay(e.startAt, date)).toList();
            final eventWithOutfit = dayEvents.where((e) => e.outfitId != null).firstOrNull;

            return GestureDetector(
              onTap: () => widget.onDateSelected(date),
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isSelected ? DesignSystem.primary : (isToday ? Colors.black : Colors.transparent),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: (isSelected || isToday) ? Colors.white : Colors.black87,
                        fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (eventWithOutfit != null)
                    CalendarOutfitCollage(
                      outfitId: eventWithOutfit.outfitId!,
                      api: widget.api,
                      size: 40, // Match the visual proportion
                    )
                  else if (dayEvents.isNotEmpty)
                    // If event but no outfit, show a dot
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: DesignSystem.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
