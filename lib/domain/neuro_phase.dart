import 'dart:math' as math;

/// The three stages of rewiring a habit, scaled to any journey length.
///
/// Anchored on a 90-day journey: days 1–21, 22–66 and 67–90. The 66-day mark
/// comes from Lally et al. (2010, European Journal of Social Psychology), who
/// found a median of 66 days for a new behaviour to become automatic.
enum NeuroPhaseKind {
  uproot(
    title: 'Uproot',
    tagline: 'Break the old loop',
    description:
        'Old pathways are still the strongest and they fire loudest now. '
        'Cravings and resistance are expected — every time you choose the '
        'hard thing anyway, you weaken the old circuit. Discomfort is the '
        'signal that change is happening.',
  ),
  rewire(
    title: 'Rewire',
    tagline: 'Repetition builds the new road',
    description:
        'Neurons that fire together wire together. Each repetition '
        'strengthens the new pathway (myelination makes it faster). '
        'Consistency beats intensity: research found habits take a median '
        'of 66 days to become automatic. Never miss twice.',
  ),
  redeem(
    title: 'Redeem',
    tagline: 'Become who you practised being',
    description:
        'Automaticity sets in. What once took willpower now takes less '
        'effort — it is becoming who you are. Guard the gains, finish '
        'strong and decide what you will carry beyond the last day.',
  );

  const NeuroPhaseKind({
    required this.title,
    required this.tagline,
    required this.description,
  });

  final String title;
  final String tagline;
  final String description;
}

class NeuroPhase {
  const NeuroPhase({
    required this.kind,
    required this.startDay,
    required this.endDay,
    required this.dayNumber,
  });

  factory NeuroPhase.forDay({required int dayNumber, required int totalDays}) {
    final bounds = boundaries(totalDays);
    final d = dayNumber.clamp(1, math.max(1, totalDays)).toInt();
    if (d <= bounds.$1) {
      return NeuroPhase(
        kind: NeuroPhaseKind.uproot,
        startDay: 1,
        endDay: bounds.$1,
        dayNumber: d,
      );
    }
    if (d <= bounds.$2) {
      return NeuroPhase(
        kind: NeuroPhaseKind.rewire,
        startDay: bounds.$1 + 1,
        endDay: bounds.$2,
        dayNumber: d,
      );
    }
    return NeuroPhase(
      kind: NeuroPhaseKind.redeem,
      startDay: bounds.$2 + 1,
      endDay: math.max(bounds.$2 + 1, totalDays),
      dayNumber: d,
    );
  }

  /// Last day of phase 1 and phase 2 for a journey of [totalDays].
  static (int, int) boundaries(int totalDays) {
    final n = math.max(3, totalDays);
    final p1 = math.max(1, (n * 21 / 90).round());
    final p2 = math.max(p1 + 1, math.min(n - 1, (n * 66 / 90).round()));
    return (p1, p2);
  }

  final NeuroPhaseKind kind;
  final int startDay;
  final int endDay;
  final int dayNumber;

  int get length => endDay - startDay + 1;

  double get progress => ((dayNumber - startDay + 1) / length).clamp(0, 1);

  int get daysToNext => math.max(0, endDay - dayNumber);
}
