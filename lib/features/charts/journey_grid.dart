import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/palette.dart';
import '../../core/time/day.dart';
import '../../domain/formatting.dart';
import '../../state/providers.dart';

/// Every day of the journey as a numbered tile coloured by its score
/// (or by one tracker's progress when [trackerId] is set).
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
        if (!tracker.isExpectedOn(d)) return null;
        final e = index.get(tracker.id, d);
        if (e == null && d == today) return null;
        return scoring.progress(tracker, e?.value);
      }
      final s = stats?.summaryByDay[d];
      if (s == null || s.isRestDay) return null;
      if (d == today && s.logged == 0) return null;
      return s.score;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 10;
        final cell = ((constraints.maxWidth - _gap * (columns - 1)) / columns)
            .clamp(16.0, 44.0);
        return Semantics(
          label: tracker == null
              ? 'Journey grid, ${stats?.winDays ?? 0} winning days so far'
              : '${tracker.name} grid',
          child: Wrap(
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
                  label:
                      '${DateFormat('d MMM').format(d.toDateTime())}: '
                      '${scoreOf(d) == null ? 'no data' : Fmt.percent(scoreOf(d)!)}',
                  color: Palette.forScore(scoreOf(d), scheme),
                  onTap: onDayTap == null || d.isAfter(today)
                      ? null
                      : () => onDayTap!(d),
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
    this.onTap,
  });

  final double size;
  final int dayNumber;
  final double? score;
  final bool isToday;
  final bool isFuture;
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
          child: size >= 22
              ? Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
