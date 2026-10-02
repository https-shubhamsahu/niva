import 'dart:convert';

enum AppRole { participant, trainer }

extension AppRoleLabel on AppRole {
  String get label => this == AppRole.trainer ? 'Trainer' : 'Participant';
}

/// Kept separately from hardware endpoints and assessment records.
class ExperiencePreferences {
  final AppRole? role;
  final bool voice;
  final bool chimes;
  final bool haptics;
  final bool reduceMotion;

  const ExperiencePreferences({
    this.role,
    this.voice = true,
    this.chimes = true,
    this.haptics = true,
    this.reduceMotion = false,
  });

  ExperiencePreferences copyWith({
    AppRole? role,
    bool? voice,
    bool? chimes,
    bool? haptics,
    bool? reduceMotion,
  }) =>
      ExperiencePreferences(
        role: role ?? this.role,
        voice: voice ?? this.voice,
        chimes: chimes ?? this.chimes,
        haptics: haptics ?? this.haptics,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  String encode() => jsonEncode({
        'role': role?.name,
        'voice': voice,
        'chimes': chimes,
        'haptics': haptics,
        'reduceMotion': reduceMotion,
      });

  static ExperiencePreferences decode(String? raw) {
    if (raw == null) return const ExperiencePreferences();
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return const ExperiencePreferences();
      return ExperiencePreferences(
        role: switch (map['role']) {
          'trainer' => AppRole.trainer,
          'participant' => AppRole.participant,
          _ => null,
        },
        voice: map['voice'] is bool ? map['voice'] : true,
        chimes: map['chimes'] is bool ? map['chimes'] : true,
        haptics: map['haptics'] is bool ? map['haptics'] : true,
        reduceMotion: map['reduceMotion'] is bool ? map['reduceMotion'] : false,
      );
    } on FormatException {
      return const ExperiencePreferences();
    }
  }
}
