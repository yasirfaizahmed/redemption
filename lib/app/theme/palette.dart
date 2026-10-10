import 'package:material_ui/material_ui.dart';

import '../../domain/scoring.dart';

/// Brand + semantic colours that stay meaningful in light and dark themes.
abstract final class Palette {
  /// Accent seeds offered in Settings.
  static const seeds = <String, int>{
    'Emerald': 0xFF0E9F6E,
    'Gold': 0xFFC9A227,
    'Ocean': 0xFF0284C7,
    'Indigo': 0xFF4F46E5,
    'Violet': 0xFF7C3AED,
    'Crimson': 0xFFDC2626,
    'Ember': 0xFFEA580C,
    'Slate': 0xFF475569,
  };

  /// Tracker colours (chosen for contrast on both light and dark surfaces).
  static const trackerColors = <int>[
    0xFF10B981, // emerald
    0xFF14B8A6, // teal
    0xFF0EA5E9, // sky
    0xFF3B82F6, // blue
    0xFF6366F1, // indigo
    0xFF8B5CF6, // violet
    0xFFD946EF, // fuchsia
    0xFFEC4899, // pink
    0xFFF43F5E, // rose
    0xFFEF4444, // red
    0xFFF97316, // orange
    0xFFF59E0B, // amber
    0xFFEAB308, // yellow
    0xFF84CC16, // lime
    0xFF22C55E, // green
    0xFF64748B, // slate
  ];

  static const gold = Color(0xFFD4A72C);
  static const success = Color(0xFF22C55E);
  static const partial = Color(0xFFF59E0B);
  static const failure = Color(0xFFEF4444);

  static Color forStatus(EntryStatus status, ColorScheme scheme) =>
      switch (status) {
        EntryStatus.done => success,
        EntryStatus.partial => partial,
        EntryStatus.failed || EntryStatus.missed => failure,
        EntryStatus.pending => scheme.outline,
        EntryStatus.notExpected => scheme.outlineVariant,
      };

  static IconData iconForStatus(EntryStatus status) => switch (status) {
    EntryStatus.done => Icons.check_rounded,
    EntryStatus.partial => Icons.timelapse_rounded,
    EntryStatus.failed => Icons.close_rounded,
    EntryStatus.missed => Icons.priority_high_rounded,
    EntryStatus.pending => Icons.circle_outlined,
    EntryStatus.notExpected => Icons.remove_rounded,
  };

  /// Heat-map colour for a day score in 0–1 (null = no data / future).
  static Color forScore(double? score, ColorScheme scheme) {
    if (score == null) return scheme.surfaceContainerHighest;
    if (score <= 0) return failure.withValues(alpha: 0.55);
    final base = scheme.primary;
    if (score < 0.4) return Color.lerp(failure, partial, score / 0.4)!;
    if (score < 0.8) {
      return Color.lerp(partial, base, (score - 0.4) / 0.4)!;
    }
    return Color.lerp(base, success, (score - 0.8) / 0.2)!;
  }
}
