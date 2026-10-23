import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/notification_preferences.dart';
import '../../data/settings_service.dart';
import '../../../../core/services/notification_service.dart';

abstract class NotificationState {}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final NotificationPreferences prefs;
  NotificationLoaded(this.prefs);
}

class NotificationError extends NotificationState {
  final String message;
  NotificationError(this.message);
}

class NotificationCubit extends Cubit<NotificationState> {
  final SettingsService _settingsService;
  final NotificationService _notificationService = NotificationService();

  NotificationCubit(this._settingsService) : super(NotificationInitial());

  Future<void> loadPreferences() async {
    // Só mostra loading se não tiver dados ainda
    if (state is! NotificationLoaded) {
      emit(NotificationLoading());
    }

    try {
      final data = await _settingsService.getSettings();
      final prefs = NotificationPreferences.fromJson(
        data['notificationSettings'] ?? {},
      );
      emit(NotificationLoaded(prefs));

      // Agendar notificações logo ao carregar
      if (prefs.enabled) {
        await _notificationService.scheduleHydrationReminders(prefs);
      }
    } catch (e) {
      debugPrint('Erro loadPreferences: $e');
      if (state is! NotificationLoaded) {
        emit(NotificationError(e.toString()));
      }
    }
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    if (state is NotificationLoaded) {
      final oldState = state as NotificationLoaded;
      emit(NotificationLoaded(prefs)); // Optimistic update

      try {
        await _settingsService.updateSettings({
          'notificationSettings': prefs.toJson(),
        });
        await _notificationService.scheduleHydrationReminders(prefs);
      } catch (e) {
        debugPrint('Erro updatePreferences: $e');
        emit(oldState);
      }
    }
  }
}
