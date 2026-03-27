import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bebeu/presentation/home/widgets/alerts_view.dart';
import 'package:bebeu/presentation/home/widgets/notification_settings_view.dart';
import 'package:bebeu/presentation/home/cubit/notification_cubit.dart';
import 'package:bebeu/core/models/notification_preferences.dart';

class MockNotificationCubit extends Mock implements NotificationCubit {}

void main() {
  late MockNotificationCubit mockCubit;

  setUp(() {
    mockCubit = MockNotificationCubit();
    when(() => mockCubit.loadPreferences()).thenAnswer((_) async {});
    when(() => mockCubit.close()).thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest(Widget child) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: BlocProvider<NotificationCubit>(
        create: (context) => mockCubit,
        child: child,
      ),
    );
  }

  testWidgets('AlertsView golden test', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(const AlertsView()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(AlertsView),
      matchesGoldenFile('goldens/alerts_view.png'),
    );
  });

  testWidgets('NotificationSettingsView loaded state golden test', (tester) async {
    final prefs = NotificationPreferences(
      intervalMinutes: 120,
      activeDays: [1, 2, 3, 4, 5],
      startTime: '08:00',
      endTime: '22:00',
      enabled: true,
    );

    when(() => mockCubit.state).thenReturn(NotificationLoaded(prefs));
    when(() => mockCubit.stream).thenAnswer((_) => Stream.value(NotificationLoaded(prefs)));

    await tester.pumpWidget(createWidgetUnderTest(const NotificationSettingsView()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(NotificationSettingsView),
      matchesGoldenFile('goldens/settings_view_loaded.png'),
    );
  });
}
