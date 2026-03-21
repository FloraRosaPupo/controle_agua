import 'package:flutter_test/flutter_test.dart';
import 'package:bebeu/core/models/notification_preferences.dart';

void main() {
  group('NotificationPreferences', () {
    test('fromJson should create a valid object', () {
      final json = {
        'intervalInMinutes': 120,
        'daysOfWeek': [1, 2, 3],
        'startTime': '09:00',
        'endTime': '21:00',
        'enabled': true,
      };

      final prefs = NotificationPreferences.fromJson(json);

      expect(prefs.intervalHours, 2);
      expect(prefs.activeDays, [1, 2, 3]);
      expect(prefs.startTime, '09:00');
      expect(prefs.endTime, '21:00');
      expect(prefs.enabled, true);
    });

    test('toJson should create a valid map', () {
      final prefs = NotificationPreferences(
        intervalHours: 3,
        activeDays: [1, 5],
        startTime: '08:30',
        endTime: '22:30',
        enabled: false,
      );

      final json = prefs.toJson();

      expect(json['intervalInMinutes'], 180);
      expect(json['daysOfWeek'], [1, 5]);
      expect(json['startTime'], '08:30');
      expect(json['endTime'], '22:30');
      expect(json['enabled'], false);
    });

    test('copyWith should update fields correctly', () {
      final prefs = NotificationPreferences(
        intervalHours: 1,
        activeDays: [1],
        startTime: '08:00',
        endTime: '20:00',
        enabled: true,
      );

      final updated = prefs.copyWith(intervalHours: 4, enabled: false);

      expect(updated.intervalHours, 4);
      expect(updated.enabled, false);
      expect(updated.activeDays, [1]);
    });
  });
}
