// (Fragment kodu z Canvas: add_project_member_screen_v1)
// Zakładamy, że ten model jest zdefiniowany w odpowiednim miejscu, np.:
// lib/features/users/domain/models/wtr_settings.dart

class WtrSettings {
  final String? theme;
  final String? language;
  final bool? notificationsEnabled;
  final int? appColorNumber;

  WtrSettings({
    this.theme,
    this.language,
    this.notificationsEnabled,
    this.appColorNumber,
  });

  /// Zwraca domyślne ustawienia aplikacji.
  static WtrSettings defaultSettings() {
    return WtrSettings(
      theme: 'system', // lub 'light', 'dark'
      language: 'pl_PL', // Domyślny język polski
      notificationsEnabled: true, // Domyślnie włączone
      appColorNumber: 0, // Domyślny kolor aplikacji (np. indeks z palety)
    );
  }

  factory WtrSettings.fromJson(Map<String, dynamic> json) {
    return WtrSettings(
      theme: json['theme'] as String?,
      language: json['language'] as String?,
      notificationsEnabled: json['notificationsEnabled'] as bool?,
      appColorNumber: json['appColorNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'theme': theme,
      'language': language,
      'notificationsEnabled': notificationsEnabled,
      'appColorNumber': appColorNumber,
    };
  }

  WtrSettings copyWith({
    String? theme,
    String? language,
    bool? notificationsEnabled,
    int? appColorNumber,
  }) {
    return WtrSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      appColorNumber: appColorNumber ?? this.appColorNumber,
    );
  }

  @override
  String toString() {
    return 'WtrSettings{theme: $theme, language: $language, notificationsEnabled: $notificationsEnabled, appColorNumber: $appColorNumber}';
  }
}