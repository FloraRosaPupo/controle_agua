import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/notification_preferences.dart';
import '../../../data/services/settings_service.dart';
import '../../../core/services/notification_service.dart';

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
    emit(NotificationLoading());
    try {
      final data = await _settingsService.getSettings();
      final prefs = NotificationPreferences.fromJson(data['notificationSettings'] ?? {});
      emit(NotificationLoaded(prefs));
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    if (state is NotificationLoaded) {
      final oldState = state as NotificationLoaded;
      emit(NotificationLoaded(prefs)); // Optimistic update

      try {
        await _settingsService.updateSettings({
          'notifications': prefs.toJson(),
        });
        await _notificationService.scheduleHydrationReminders(prefs);
      } catch (e) {
        emit(oldState);
        emit(NotificationError('Erro ao salvar: $e'));
      }
    }
  }
}
