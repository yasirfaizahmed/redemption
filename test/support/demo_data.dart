import 'dart:math';

import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/db/database.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/settings_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/domain/app_settings.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_value.dart';

/// Seeds a realistic, deterministic Redemption journey: [pastDays] completed
/// days with steadily improving discipline, plus a half-logged "today".
Future<void> seedDemoJourney(
  AppDatabase db, {
  required Day today,
  required int nowMinutes,
  int pastDays = 23,
  AppSettings settings = const AppSettings(onboardingDone: true),
}) async {
  await SettingsRepository(db).save(settings);
  final start = today.addDays(-pastDays);
  final journeyId = await JourneyRepository(db).createFromTemplate(
    template: Templates.redemption,
    name: Templates.redemption.suggestedName,
    intention: Templates.redemption.suggestedIntention,
    startDay: start,
    durationDays: 90,
  );
  final trackers = await TrackerRepository(db).forJourney(journeyId);
  final entries = EntryRepository(db);
  final rnd = Random(7);

  const breakfasts = [
    'Oats, eggs, dates',
    'Eggs, brown bread, banana',
    'Oats, milk, almonds',
    'Poha, boiled eggs',
    'Eggs, dates, black coffee',
  ];
  const lunches = [
    'Rice, dal, chicken curry',
    'Chapati, paneer, salad',
    'Rice, fish, vegetables',
    'Chicken biryani (half), raita',
  ];
  const workouts = [
    'Push: bench 4×8, OHP 3×10, dips 3×12',
    'Pull: deadlift 3×5, rows 4×10, curls 3×12',
    'Legs: squats 4×8, lunges 3×12, calves',
    'Cardio: 5 km run + core',
  ];
  const dinners = [
    'Chicken breast, rice, salad',
    'Eggs, chapati, dal',
    'Fish, sweet potato, greens',
    'Paneer bhurji, chapati',
  ];

  for (final d in Day.range(start, today)) {
    final i = d.difference(start);
    final isToday = d == today;
    // Discipline improves as the new pathways form.
    final p = (0.55 + 0.4 * i / pastDays).clamp(0.0, 0.97);
    bool hit() => rnd.nextDouble() < p;
    String pick(List<String> l) => l[rnd.nextInt(l.length)];

    String? workMode;
    for (final t in trackers) {
      if (!t.isScheduledOn(d)) continue;
      if (isToday && (t.anchorMinutes ?? 0) > nowMinutes) continue;
      // Occasionally an item goes unlogged.
      if (!isToday && rnd.nextDouble() > 0.97) continue;

      final TrackerValue? value = switch (t.name) {
        'Wake-up time' => TimeValue(
          hit() ? 4 * 60 + 30 + rnd.nextInt(25) : 5 * 60 + 5 + rnd.nextInt(50),
        ),
        'Fajr' || 'Dhuhr' || 'Asr' || 'Maghrib' || 'Isha' => ChoiceValue(
          hit()
              ? (rnd.nextBool() ? 'jamaah' : 'ontime')
              : (rnd.nextDouble() < 0.7 ? 'late' : 'missed'),
        ),
        'Breakfast' => TextValue(pick(breakfasts)),
        'WFH or office?' => ChoiceValue(
          workMode = rnd.nextDouble() < 0.6 ? 'wfh' : 'office',
        ),
        'Lunch' => TextValue(pick(lunches)),
        // Only office days (the time is drawn anyway, keeping the sequence).
        'Left office' => switch (TimeValue(16 * 60 + 15 + rnd.nextInt(55))) {
          final v when workMode == 'office' => v,
          _ => null,
        },
        'Pre-workout meal' => BoolValue(hit()),
        'Workout' => hit() ? TextValue(pick(workouts)) : null,
        'Post-workout dinner' => TextValue(pick(dinners)),
        'Sleep time' => TimeValue(
          hit()
              ? 21 * 60 + 50 + rnd.nextInt(35)
              : 22 * 60 + 40 + rnd.nextInt(70),
        ),
        _ => null,
      };
      if (value == null) continue;
      await entries.upsert(trackerId: t.id, day: d, value: value);
    }
  }
}
