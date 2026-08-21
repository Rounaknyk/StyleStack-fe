import 'package:flutter/material.dart';

class CalendarSummaryCards extends StatelessWidget {
  const CalendarSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: 'OOTD',
              content: '40',
              valueColor: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              title: 'Most worn',
              isImage: true,
              imageUrl: 'https://via.placeholder.com/60', // Placeholder
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryCard(
              title: 'Expenses',
              content: '\$999',
              valueColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    this.content,
    this.isImage = false,
    this.imageUrl,
    this.valueColor,
  });

  final String title;
  final String? content;
  final bool isImage;
  final String? imageUrl;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (isImage && imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                imageUrl!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.checkroom),
              ),
            )
          else if (content != null)
            Text(
              content!,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
