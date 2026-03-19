import 'water_log_model.dart';

class DailyWaterDataModel {
  final int total;
  final int dailyGoal;
  final int remaining;
  final double percent;
  final List<WaterLogModel> logs;

  DailyWaterDataModel({
    required this.total,
    required this.dailyGoal,
    required this.remaining,
    required this.percent,
    required this.logs,
  });

  factory DailyWaterDataModel.fromJson(Map<String, dynamic> json) {
    return DailyWaterDataModel(
      total: json['total'] ?? 0,
      dailyGoal: json['dailyGoal'] ?? 2000,
      remaining: json['remaining'] ?? 0,
      percent: (json['percent'] ?? 0.0).toDouble(),
      logs:
          (json['logs'] as List?)
              ?.map((log) => WaterLogModel.fromJson(log))
              .toList() ??
          [],
    );
  }
}
