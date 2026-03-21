import 'package:flutter/material.dart';

class NotificationPreferences {
  final int intervalHours; // 1, 2, 3 or 4
  final List<int> activeDays; // 1=Mon ... 7=Sun
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final bool enabled;

  NotificationPreferences({
    required this.intervalHours,
    required this.activeDays,
    required this.startTime,
    required this.endTime,
    required this.enabled,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      intervalHours: json['intervalInMinutes'] != null 
          ? (json['intervalInMinutes'] as int) ~/ 60 
          : 2,
      activeDays: json['daysOfWeek'] != null 
          ? List<int>.from(json['daysOfWeek']) 
          : [1, 2, 3, 4, 5, 6, 7],
      startTime: json['startTime'] ?? '08:00',
      endTime: json['endTime'] ?? '22:00',
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intervalInMinutes': intervalHours * 60,
      'daysOfWeek': activeDays,
      'startTime': startTime,
      'endTime': endTime,
      'enabled': enabled,
    };
  }

  NotificationPreferences copyWith({
    int? intervalHours,
    List<int>? activeDays,
    String? startTime,
    String? endTime,
    bool? enabled,
  }) {
    return NotificationPreferences(
      intervalHours: intervalHours ?? this.intervalHours,
      activeDays: activeDays ?? this.activeDays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      enabled: enabled ?? this.enabled,
    );
  }

  TimeOfDay get startTimeOfDay {
    final parts = startTime.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  TimeOfDay get endTimeOfDay {
    final parts = endTime.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
