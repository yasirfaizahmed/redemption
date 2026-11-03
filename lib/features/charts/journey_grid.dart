import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/palette.dart';
import '../../core/time/day.dart';
import '../../domain/achievements.dart';
import '../../domain/formatting.dart';
import '../../state/providers.dart';

/// Every day of the journey as a numbered tile coloured by its score
/// (or by one tracker's progress when [trackerId] is set). Journey tiles
/// carry the day's achievements as tiny emojis, explained underneath.
class JourneyGrid extends ConsumerWidget {
  const JourneyGrid({
    super.key,
    this.trackerId,
    this.onDayTap,
    this.rangeDays = 0,
  });

  final int? trackerId;
  final ValueChanged<Day>? onDayTap;

  /// Show only the most recent N days (0 = whole journey).
  final int rangeDays;

  static const _gap = 4.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(activeJourneyProvider).value;
    if (journey == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = ref.watch(todayProvider);
    final stats = ref.watch(journeyStatsProvider);
    final scoring = ref.watch(scoringProvider);
    final index = ref.watch(entryIndexProvider);
    final tracker = trackerId == null
        ? null
        : ref.watch(trackerByIdProvider(trackerId!));
    final achievements = trackerId == null
        ? ref.watch(achievementsProvider)
        : const <Day, List<Achievement>>{};

    var days = Day.range(journey.startDay, journey.endDay).toList();
    if (rangeDays > 0 && days.length > rangeDays) {
      final todayIdx = days.indexOf(today);
      final end = todayIdx < 0
          ? (today.isAfter(journey.endDay) ? days.length : rangeDays)
          : todayIdx + 1;
      final start = (end - rangeDays).clamp(0, days.length);
      days = days.sublist(start, end.clamp(start, days.length));
    }

    double? scoreOf(Day d) {
      if (d.isAfter(today)) return null;
      if (tracker != null) {
        final sameDay = index.forDay(d);
        if (!tracker.isExpectedOn(d, sameDay: sameDay)) return null;
        final e = index.get(tracker.id, d);
        if (e == null && d == today) return null;
        return scoring.progress(tracker, e?.value, sameDay: sameDay);
      }
      final s = stats?.summaryByDay[d];
      if (s == null || s.isRestDay) return null;
      if (d == today && s.logged == 0) return null;
      return s.score;
    }

    // The legend explains the emojis on the tiles shown.
    final legend = <String, String>{};
    for (final d in days) {
      final earned = achievements[d] ?? const [];
      final shown = Achievements.cellEmojis(earned).toSet();
      for (final a in earned) {
        if (!shown.contains(a.emoji)) continue;
        legend.putIfAbsent(
          a.emoji,
          () => a.emoji == Achievements.streakEmoji ? 'Streak' : a.label,
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 10;
        final cell = ((constraints.maxWidth - _gap * (columns - 1)) / columns)
            .clamp(16.0, 44.0);
        final perCell = cell >= 30 ? 3 : (cell >= 22 ? 2 : 1);
        return Semantics(
          label: tracker == null
              ? 'Journey grid, ${stats?.winDays ?? 0} winning days so far'
              : '${tracker.name} grid',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final d in days)
                    _Cell(
                      size: cell,
                      dayNumber: journey.dayNumber(d),
                      score: scoreOf(d),
                      isToday: d == today,
                      isFuture: d.isAfter(today),
                      emojis: Achievements.cellEmojis(
                        achievements[d] ?? const [],
                        max: perCell,
                      ),
                      label: [
                        '${DateFormat('d MMM').format(d.toDateTime())}: '
                            '${scoreOf(d) == null ? 'no data' : Fmt.percent(scoreOf(d)!)}',
                        for (final a
                            in achievements[d] ?? const <Achievement>[])
                          a.label,
                      ].join(', '),
                      color: Palette.forScore(scoreOf(d), scheme),
                      onTap: onDayTap == null || d.isAfter(today)
                          ? null
                          : () => onDayTap!(d),
                    ),
                ],
              ),
              if (legend.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ExcludeSemantics(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        for (final MapEntry(key: emoji, value: label)
                            in legend.entries)
                          Text(
                            '$emoji $label',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.size,
    required this.dayNumber,
    required this.score,
    required this.isToday,
    required this.isFuture,
    required this.label,
    required this.color,
    this.emojis = const [],
    this.onTap,
  });

  final double size;
  final int dayNumber;
  final double? score;
  final bool isToday;
  final bool isFuture;

  /// The day's achievements, drawn tiny under the day number.
  final List<String> emojis;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = score != null;
    final textColor = filled
        ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
              ? Colors.white
              : Colors.black87)
        : scheme.onSurfaceVariant.withValues(alpha: isFuture ? 0.5 : 0.8);
    return Semantics(
      label: label,
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? color
                : isFuture
                ? Colors.transparent
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(size * 0.28),
            border: isToday
                ? Border.all(color: scheme.primary, width: 2.5)
                : isFuture
                ? Border.all(color: scheme.outlineVariant)
                : null,
          ),
          child: switch ((size >= 22, emojis.isNotEmpty)) {
            (true, false) => Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            (true, true) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: size * 0.3,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                _Emojis(emojis, size: size * 0.24, width: size * 0.9),
              ],
            ),
            (false, true) => _Emojis(
              emojis.take(1).toList(),
              size: size * 0.5,
              width: size * 0.9,
            ),
            (false, false) => null,
          },
        ),
      ),
    );
  }
}

/// A row of tiny emojis that always fits its tile.
class _Emojis extends StatelessWidget {
  const _Emojis(this.emojis, {required this.size, required this.width});
  final List<String> emojis;
  final double size;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        emojis.join(),
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: size, height: 1.1),
      ),
    ),
  );
}
