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
    final dynamic dow = json['daysOfWeek'];
    final List<int> rawDays;
    if (dow is! List || dow.isEmpty) {
      rawDays = [0, 1, 2, 3, 4, 5, 6];
    } else {
      rawDays = dow.map((e) => (e as num).toInt()).toList();
    }

    final List<int> mappedDays = rawDays.map((day) {
      if (day == 0) return 7; // Sunday: 0 -> 7
      return day; // Others stay the same (1=Mon...6=Sat)
    }).toList();

    final dynamic enabledRaw = json['enabled'];
    final bool enabled = enabledRaw is bool
        ? enabledRaw
        : (enabledRaw == null ? true : enabledRaw == 1 || enabledRaw == 'true');

    final rawInterval =
        (json['intervalInMinutes'] as num?)?.toInt() ?? 60;
    return NotificationPreferences(
      intervalMinutes: rawInterval < 30 ? 30 : rawInterval,
      activeDays: mappedDays,
      startTime: json['startTime']?.toString() ?? '08:00',
      endTime: json['endTime']?.toString() ?? '22:00',
      enabled: enabled,
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
