import 'clothing_analysis.dart';

class AiAnalysisJob {
  const AiAnalysisJob({
    required this.id,
    required this.status,
    required this.kind,
    required this.itemsAhead,
    required this.estimatedWaitSeconds,
    this.queuePosition,
    this.analysis,
    this.items = const [],
    this.error,
  });

  factory AiAnalysisJob.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    final resultMap = result is Map ? Map<String, dynamic>.from(result) : null;
    final detected = resultMap?['items'];
    return AiAnalysisJob(
      id: json['job_id'] as String,
      status: json['status'] as String? ?? 'queued',
      kind: json['kind'] as String? ?? 'single',
      queuePosition: json['queue_position'] as int?,
      itemsAhead: json['items_ahead'] as int? ?? 0,
      estimatedWaitSeconds: json['estimated_wait_seconds'] as int? ?? 0,
      analysis: resultMap != null && detected == null
          ? ClothingAnalysis.fromJson(resultMap)
          : null,
      items: detected is List
          ? detected
                .whereType<Map>()
                .map(
                  (item) => ClothingAnalysis.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      error: json['error'] as String?,
    );
  }

  final String id;
  final String status;
  final String kind;
  final int? queuePosition;
  final int itemsAhead;
  final int estimatedWaitSeconds;
  final ClothingAnalysis? analysis;
  final List<ClothingAnalysis> items;
  final String? error;

  bool get isTerminal =>
      status == 'completed' || status == 'failed' || status == 'canceled';
}
