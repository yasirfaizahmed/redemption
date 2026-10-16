import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/domain/app_settings.dart';
import 'package:redemption/domain/dashboard.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_config.dart';
import 'package:redemption/domain/tracker_goal.dart';
import 'package:redemption/domain/tracker_value.dart';

T roundTrip<T>(
  Map<String, dynamic> json,
  T Function(Map<String, dynamic>) decode,
) => decode(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);

void main() {
  test('every value type survives a JSON round trip', () {
    const values = <TrackerValue>[
      BoolValue(true),
      TimeValue(305),
      NumberValue(72.4),
      DurationValue(95),
      ChoiceValue('jamaah'),
      MultiChoiceValue(['a', 'b']),
      TextValue('Oats, eggs'),
      AttachmentsValue([
        Attachment(relativePath: '2026-10/x.jpg', name: 'x.jpg', sizeBytes: 42),
      ]),
    ];
    for (final v in values) {
      expect(
        roundTrip(v.toJson(), TrackerValue.fromJson),
        v,
        reason: v.runtimeType.toString(),
      );
    }
  });

  test('unknown value tags decode to null (forward compatibility)', () {
    expect(TrackerValue.fromJson({'t': 'hologram', 'v': 1}), isNull);
  });

  test('every goal type survives a JSON round trip', () {
    const goals = <TrackerGoal>[
      LoggedGoal(),
      BoolGoal(target: false),
      NumberGoal(comparator: NumberComparator.between, value: 1, upper: 3),
      TimeGoal(
        comparator: TimeComparator.after,
        minutes: 600,
        graceMinutes: 10,
      ),
      ChoiceScoreGoal(),
    ];
    for (final g in goals) {
      expect(roundTrip(g.toJson(), TrackerGoal.fromJson), g);
    }
    expect(TrackerGoal.fromJson(null), const LoggedGoal());
  });

  test('tracker config round trip keeps options and scores', () {
    const config = TrackerConfig(
      unit: 'kg',
      min: 40,
      max: 120,
      step: 0.1,
      inputStyle: NumberInputStyle.slider,
      presets: [70, 72.5],
      ratingStyle: RatingStyle.emoji,
      options: prayerOptions,
      yesLabel: 'Prayed',
    );
    expect(roundTrip(config.toJson(), TrackerConfig.fromJson), config);
  });

  test('dashboard config and settings round trip', () {
    const cfg = DashboardItemConfig(
      trackerIds: [3, 1],
      rangeDays: 7,
      title: 'Salah',
      stat: StatKind.average,
    );
    final decoded = roundTrip(cfg.toJson(), DashboardItemConfig.fromJson);
    expect(decoded.trackerIds, [3, 1]);
    expect(decoded.stat, StatKind.average);

    const s = AppSettings(
      dayStartMinutes: 240,
      successThreshold: 0.9,
      quotePack: QuotePack.faith,
    );
    final back = AppSettings.fromMap(s.toMap());
    expect(back.dayStartMinutes, 240);
    expect(back.successThreshold, 0.9);
    expect(back.quotePack, QuotePack.faith);
  });

  test('templates are internally consistent', () {
    for (final t in Templates.all) {
      final refs = {for (final tt in t.trackers) tt.ref};
      expect(refs.length, t.trackers.length, reason: '${t.id}: duplicate refs');
      for (final w in t.widgets) {
        for (final r in w.refs) {
          expect(
            refs,
            contains(r),
            reason: '${t.id}: widget references unknown "$r"',
          );
        }
      }
    }
    // The Redemption template mirrors the routine it was designed for.
    final names = Templates.redemption.trackers
        .map((t) => t.tracker.name)
        .toList();
    expect(
      names,
      containsAllInOrder([
        'Wake-up time',
        'Fajr',
        'Breakfast on time?',
        'Dhuhr',
        'Lunch on time?',
        'Asr',
        'Maghrib',
        'Workout',
        'Dinner on time?',
        'Isha',
        'Sleep time',
      ]),
    );
  });
}
