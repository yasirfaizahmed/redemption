import 'dart:math';

import 'package:flutter/foundation.dart';

/// How hard the sums are that stop the wake-up alarm.
enum MathDifficulty {
  medium('Medium', '47 × 6 + 38'),
  hard('Hard', '38 × 17 + 469'),
  veryHard('Very hard', '248 × 37 − 569');

  const MathDifficulty(this.label, this.example);
  final String label;
  final String example;

  static MathDifficulty parse(String? name) => values.firstWhere(
    (d) => d.name == name,
    orElse: () => MathDifficulty.hard,
  );
}

/// One sum to solve, e.g. "38 × 17 + 469".
@immutable
class MathProblem {
  const MathProblem(this.text, this.answer);

  final String text;
  final int answer;

  /// Whether [typed] (digits) is the answer.
  bool isSolvedBy(String typed) => int.tryParse(typed.trim()) == answer;

  @override
  String toString() => '$text = $answer';
}

/// Sums that need a waking mind: no round numbers, nothing to guess.
abstract final class MathChallenge {
  static const minProblems = 1;
  static const maxProblems = 5;

  /// A whole number in [min]..[max] that isn't round (10, 20…) and, when
  /// [noRepdigit], not 11, 22… either — those make the product too easy.
  static int _awkward(Random rnd, int min, int max, {bool noRepdigit = false}) {
    while (true) {
      final n = min + rnd.nextInt(max - min + 1);
      if (n % 10 == 0) continue;
      if (noRepdigit && n % 11 == 0) continue;
      return n;
    }
  }

  static MathProblem generate(Random rnd, MathDifficulty difficulty) {
    switch (difficulty) {
      case MathDifficulty.medium:
        final a = _awkward(rnd, 12, 99);
        final b = 3 + rnd.nextInt(7); // 3–9
        final c = _awkward(rnd, 11, 99);
        return MathProblem('$a × $b + $c', a * b + c);
      case MathDifficulty.hard:
        final a = _awkward(rnd, 23, 99, noRepdigit: true);
        final b = _awkward(rnd, 12, 29, noRepdigit: true);
        final c = _awkward(rnd, 101, 999);
        return MathProblem('$a × $b + $c', a * b + c);
      case MathDifficulty.veryHard:
        final a = _awkward(rnd, 123, 987);
        final b = _awkward(rnd, 13, 89, noRepdigit: true);
        final c = _awkward(rnd, 101, 999);
        return MathProblem('$a × $b − $c', a * b - c);
    }
  }

  /// [count] different problems.
  static List<MathProblem> generateAll(
    Random rnd,
    MathDifficulty difficulty,
    int count,
  ) {
    final problems = <MathProblem>[];
    while (problems.length < count.clamp(minProblems, maxProblems)) {
      final p = generate(rnd, difficulty);
      if (!problems.any((q) => q.text == p.text)) problems.add(p);
    }
    return problems;
  }
}
