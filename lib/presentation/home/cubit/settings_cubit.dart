import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/services/settings_service.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsState {
  final String name;
  final String email;
  final double dailyGoal;
  final String theme;
  final bool dailyReminder;
  final bool vibration;
  final bool isLoading;

  SettingsState({
    this.name = '',
    this.email = '',
    this.dailyGoal = 2000,
    this.theme = 'system',
    this.dailyReminder = true,
    this.vibration = true,
    this.isLoading = true,
  });

  SettingsState copyWith({
    String? name,
    String? email,
    double? dailyGoal,
    String? theme,
    bool? dailyReminder,
    bool? vibration,
    bool? isLoading,
  }) {
    return SettingsState(
      name: name ?? this.name,
      email: email ?? this.email,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      theme: theme ?? this.theme,
      dailyReminder: dailyReminder ?? this.dailyReminder,
      vibration: vibration ?? this.vibration,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsService _settingsService;

  SettingsCubit(this._settingsService) : super(SettingsState());

  void _applyTheme(String themeString) {
    if (themeString == 'dark') {
      AppTheme.themeMode.value = ThemeMode.dark;
    } else if (themeString == 'light') {
      AppTheme.themeMode.value = ThemeMode.light;
    } else {
      AppTheme.themeMode.value = ThemeMode.system;
    }
  }

  Future<void> loadSettings() async {
    emit(state.copyWith(isLoading: true));
    try {
      final data = await _settingsService.getSettings();
      final themeStr = data['theme'] ?? 'system';
      _applyTheme(themeStr);

      emit(
        state.copyWith(
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          dailyGoal: (data['dailyGoal'] ?? 2000).toDouble(),
          theme: themeStr,
          dailyReminder: data['dailyReminder'] ?? true,
          vibration: data['vibration'] ?? true,
          isLoading: false,
        ),
      );
    } catch (e) {
      debugPrint("Erro loadSettings: \$e");
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    // Optimistic Update
    final oldState = state;
    if (key == 'theme') {
      _applyTheme(value as String);
      emit(state.copyWith(theme: value));
    } else if (key == 'dailyReminder') {
      emit(state.copyWith(dailyReminder: value as bool));
    } else if (key == 'vibration') {
      emit(state.copyWith(vibration: value as bool));
    } else if (key == 'dailyGoal') {
      emit(state.copyWith(dailyGoal: (value as num).toDouble()));
    } else if (key == 'name') {
      emit(state.copyWith(name: value as String));
    }

    try {
      await _settingsService.updateSettings({key: value});
    } catch (e) {
      debugPrint("Erro updateSetting \$key: \$e");
      // Revert optimistic update
      emit(oldState);
      if (key == 'theme') {
        _applyTheme(oldState.theme);
      }
    }
  }
}
