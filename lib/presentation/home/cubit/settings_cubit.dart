import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/services/settings_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/notification_service.dart';

class SettingsState {
  final String name;
  final String email;
  final double dailyGoal;
  final double quickAddAmount;
  final String theme;
  final bool dailyReminder;
  final bool vibration;
  final bool isLoading;

  SettingsState({
    this.name = '',
    this.email = '',
    this.dailyGoal = 2000,
    this.quickAddAmount = 200,
    this.theme = 'system',
    this.dailyReminder = true,
    this.vibration = true,
    this.isLoading = true,
  });

  SettingsState copyWith({
    String? name,
    String? email,
    double? dailyGoal,
    double? quickAddAmount,
    String? theme,
    bool? dailyReminder,
    bool? vibration,
    bool? isLoading,
  }) {
    return SettingsState(
      name: name ?? this.name,
      email: email ?? this.email,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      quickAddAmount: quickAddAmount ?? this.quickAddAmount,
      theme: theme ?? this.theme,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      vibration: vibration ?? this.vibration,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}


class SettingsCubit extends Cubit<SettingsState> {
  final SettingsService _settingsService;

  SettingsCubit(this._settingsService)
      : super(SettingsState(theme: AppTheme.currentThemeString));

  static const double _dailyGoalMin = 500;
  static const double _dailyGoalMax = 5000;

  double _clampDailyGoal(double v) =>
      v.clamp(_dailyGoalMin, _dailyGoalMax);

  Future<void> _applyTheme(String themeString, {bool persist = false}) async {
    await AppTheme.setThemeFromString(themeString, persist: persist);
  }

  Future<void> loadSettings() async {
    emit(state.copyWith(isLoading: true));
    try {
      final data = await _settingsService.getSettings();
      final themeStr = data['theme'] ?? AppTheme.currentThemeString;
      await _applyTheme(themeStr, persist: true);

      emit(
        state.copyWith(
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          dailyGoal: _clampDailyGoal((data['dailyGoal'] ?? 2000).toDouble()),
          quickAddAmount: (data['quickAddAmount'] ?? 200).toDouble(),
          theme: themeStr,
          dailyReminder: data['dailyReminder'] ?? true,
          vibration: data['vibration'] ?? true,
          isLoading: false,
        ),
      );
      await NotificationService().setVibrationEnabled(state.vibration);
    } catch (e) {
      debugPrint("Erro loadSettings: \$e");
      emit(state.copyWith(isLoading: false));
    }
  }

  /// Atualiza só o estado local enquanto o usuário arrasta o slider (sem API).
  void slideDailyGoal(double value) {
    emit(state.copyWith(dailyGoal: _clampDailyGoal(value)));
  }

  Future<void> updateSetting(String key, dynamic value) async {
    // Optimistic Update
    final oldState = state;
    if (key == 'theme') {
      await _applyTheme(value as String, persist: true);
      emit(state.copyWith(theme: value));
    } else if (key == 'dailyReminder') {
      emit(state.copyWith(dailyReminder: value as bool));
    } else if (key == 'vibration') {
      emit(state.copyWith(vibration: value as bool));
    } else if (key == 'dailyGoal') {
      emit(state.copyWith(
        dailyGoal: _clampDailyGoal((value as num).toDouble()),
      ));
    } else if (key == 'quickAddAmount') {
      emit(state.copyWith(quickAddAmount: (value as num).toDouble()));
    } else if (key == 'name') {
      emit(state.copyWith(name: value as String));
    }

    try {
      final payloadValue =
          key == 'dailyGoal' ? _clampDailyGoal((value as num).toDouble()) : value;
      await _settingsService.updateSettings({key: payloadValue});
      if (key == 'vibration') {
        await NotificationService().setVibrationEnabled(value as bool);
      }
    } catch (e) {
      debugPrint("Erro updateSetting \$key: \$e");
      // Revert optimistic update
      emit(oldState);
      if (key == 'theme') {
        await _applyTheme(oldState.theme, persist: true);
      }
      if (key == 'vibration') {
        await NotificationService().setVibrationEnabled(oldState.vibration);
      }
    }
  }
}
