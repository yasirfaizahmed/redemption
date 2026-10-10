import 'package:material_ui/material_ui.dart';

enum QuotePack {
  faith('Qur’an & Sunnah'),
  discipline('Discipline & science'),
  both('Both');

  const QuotePack(this.label);
  final String label;
}

/// User preferences, persisted as key/value pairs.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.seedColor = defaultSeed,
    this.useDynamicColor = false,
    this.pureBlack = false,
    this.dayStartMinutes = 180,
    this.successThreshold = 0.8,
    this.haptics = true,
    this.celebrations = true,
    this.use24h = true,
    this.onboardingDone = false,
    this.checkInEnabled = false,
    this.checkInMinutes = 21 * 60 + 30,
    this.quotePack = QuotePack.both,
  });

  factory AppSettings.fromMap(Map<String, String> m) {
    const d = AppSettings();
    int? i(String k) => int.tryParse(m[k] ?? '');
    bool? b(String k) => m[k] == null ? null : m[k] == 'true';
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (t) => t.name == m['themeMode'],
        orElse: () => d.themeMode,
      ),
      seedColor: i('seedColor') ?? d.seedColor,
      useDynamicColor: b('useDynamicColor') ?? d.useDynamicColor,
      pureBlack: b('pureBlack') ?? d.pureBlack,
      dayStartMinutes: i('dayStartMinutes') ?? d.dayStartMinutes,
      successThreshold:
          double.tryParse(m['successThreshold'] ?? '') ?? d.successThreshold,
      haptics: b('haptics') ?? d.haptics,
      celebrations: b('celebrations') ?? d.celebrations,
      use24h: b('use24h') ?? d.use24h,
      onboardingDone: b('onboardingDone') ?? d.onboardingDone,
      checkInEnabled: b('checkInEnabled') ?? d.checkInEnabled,
      checkInMinutes: i('checkInMinutes') ?? d.checkInMinutes,
      quotePack: QuotePack.values.firstWhere(
        (q) => q.name == m['quotePack'],
        orElse: () => d.quotePack,
      ),
    );
  }

  static const defaultSeed = 0xFF0E9F6E;

  final ThemeMode themeMode;
  final int seedColor;
  final bool useDynamicColor;

  /// AMOLED black backgrounds in dark mode.
  final bool pureBlack;

  /// When the logical day rolls over (minutes after midnight).
  final int dayStartMinutes;

  /// Fraction (0–1) of the daily score needed for a day to count as a win.
  final double successThreshold;
  final bool haptics;
  final bool celebrations;
  final bool use24h;
  final bool onboardingDone;
  final bool checkInEnabled;
  final int checkInMinutes;
  final QuotePack quotePack;

  Map<String, String> toMap() => {
    'themeMode': themeMode.name,
    'seedColor': '$seedColor',
    'useDynamicColor': '$useDynamicColor',
    'pureBlack': '$pureBlack',
    'dayStartMinutes': '$dayStartMinutes',
    'successThreshold': '$successThreshold',
    'haptics': '$haptics',
    'celebrations': '$celebrations',
    'use24h': '$use24h',
    'onboardingDone': '$onboardingDone',
    'checkInEnabled': '$checkInEnabled',
    'checkInMinutes': '$checkInMinutes',
    'quotePack': quotePack.name,
  };

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? seedColor,
    bool? useDynamicColor,
    bool? pureBlack,
    int? dayStartMinutes,
    double? successThreshold,
    bool? haptics,
    bool? celebrations,
    bool? use24h,
    bool? onboardingDone,
    bool? checkInEnabled,
    int? checkInMinutes,
    QuotePack? quotePack,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    seedColor: seedColor ?? this.seedColor,
    useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    pureBlack: pureBlack ?? this.pureBlack,
    dayStartMinutes: dayStartMinutes ?? this.dayStartMinutes,
    successThreshold: successThreshold ?? this.successThreshold,
    haptics: haptics ?? this.haptics,
    celebrations: celebrations ?? this.celebrations,
    use24h: use24h ?? this.use24h,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    checkInEnabled: checkInEnabled ?? this.checkInEnabled,
    checkInMinutes: checkInMinutes ?? this.checkInMinutes,
    quotePack: quotePack ?? this.quotePack,
  );
}
