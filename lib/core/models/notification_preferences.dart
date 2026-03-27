import 'package:flutter/material.dart';

class NotificationPreferences {
  final int intervalMinutes; // mins
  final List<int> activeDays; // 1=Mon ... 7=Sun
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final bool enabled;

  NotificationPreferences({
    required this.intervalMinutes,
    required this.activeDays,
    required this.startTime,
    required this.endTime,
    required this.enabled,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    // Backend (Prisma): 0=Dom, 1=Seg...6=Sáb
    // Flutter (DateTime): 1=Seg...7=Dom
    final List<int> rawDays = json['daysOfWeek'] != null 
        ? List<int>.from(json['daysOfWeek']) 
        : [0, 1, 2, 3, 4, 5, 6];

    final List<int> mappedDays = rawDays.map((day) {
      if (day == 0) return 7; // Sunday: 0 -> 7
      return day; // Others stay the same (1=Mon...6=Sat)
    }).toList();

    return NotificationPreferences(
      intervalMinutes: json['intervalInMinutes'] ?? 120,
      activeDays: mappedDays,
      startTime: json['startTime'] ?? '08:00',
      endTime: json['endTime'] ?? '22:00',
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    // Converte de volta para o formato do backend
    final List<int> backendDays = activeDays.map((day) {
      if (day == 7) return 0; // Sunday: 7 -> 0
      return day;
    }).toList();

    return {
      'intervalInMinutes': intervalMinutes,
      'daysOfWeek': backendDays,
      'startTime': startTime,
      'endTime': endTime,
      'enabled': enabled,
    };
  }

  NotificationPreferences copyWith({
    int? intervalMinutes,
    List<int>? activeDays,
    String? startTime,
    String? endTime,
    bool? enabled,
  }) {
    return NotificationPreferences(
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
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
