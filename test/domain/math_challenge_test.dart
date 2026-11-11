import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/domain/app_settings.dart';
import 'package:redemption/domain/math_challenge.dart';

void main() {
  test('every sum is right, awkward and of the chosen size', () {
    final rnd = Random(7);
    final shape = {
      MathDifficulty.medium: RegExp(r'^(\d{2}) × (\d) \+ (\d{2})$'),
      MathDifficulty.hard: RegExp(r'^(\d{2}) × (\d{2}) \+ (\d{3})$'),
      MathDifficulty.veryHard: RegExp(r'^(\d{3}) × (\d{2}) − (\d{3})$'),
    };
    for (final d in MathDifficulty.values) {
      for (var i = 0; i < 500; i++) {
        final p = MathChallenge.generate(rnd, d);
        final m = shape[d]!.firstMatch(p.text);
        expect(m, isNotNull, reason: '$d: ${p.text}');
        final a = int.parse(m![1]!);
        final b = int.parse(m[2]!);
        final c = int.parse(m[3]!);
        final expected = d == MathDifficulty.veryHard ? a * b - c : a * b + c;
        expect(p.answer, expected, reason: p.text);
        expect(a % 10, isNot(0), reason: 'no round numbers: ${p.text}');
        expect(c % 10, isNot(0), reason: 'no round numbers: ${p.text}');
        expect(p.answer, greaterThan(0));
      }
    }
  });

  test('only the exact answer solves it', () {
    const p = MathProblem('38 × 17 + 469', 1115);
    expect(p.isSolvedBy('1115'), isTrue);
    expect(p.isSolvedBy(' 1115 '), isTrue);
    expect(p.isSolvedBy('1114'), isFalse);
    expect(p.isSolvedBy(''), isFalse);
    expect(p.isSolvedBy('11150'), isFalse);
  });

  test('several sums are all different, and the count is kept in range', () {
    final rnd = Random(1);
    final five = MathChallenge.generateAll(rnd, MathDifficulty.hard, 5);
    expect(five.map((p) => p.text).toSet(), hasLength(5));
    expect(
      MathChallenge.generateAll(rnd, MathDifficulty.hard, 0),
      hasLength(1),
    );
    expect(
      MathChallenge.generateAll(rnd, MathDifficulty.hard, 99),
      hasLength(5),
    );
  });

  test('alarm settings are saved, with safe defaults', () {
    const d = AppSettings();
    expect(d.alarmInApp, isTrue);
    expect(d.alarmMathDifficulty, MathDifficulty.hard);
    expect(d.alarmMathCount, 1);
    final s = d.copyWith(
      alarmInApp: false,
      alarmMathDifficulty: MathDifficulty.veryHard,
      alarmMathCount: 3,
    );
    final back = AppSettings.fromMap(s.toMap());
    expect(back.alarmInApp, isFalse);
    expect(back.alarmMathDifficulty, MathDifficulty.veryHard);
    expect(back.alarmMathCount, 3);
    expect(
      AppSettings.fromMap(const {
        'alarmMath': 'nonsense',
        'alarmMathCount': '40',
      }).alarmMathCount,
      5,
    );
    expect(
      AppSettings.fromMap(const {'alarmMath': 'nonsense'}).alarmMathDifficulty,
      MathDifficulty.hard,
    );
  });
}
