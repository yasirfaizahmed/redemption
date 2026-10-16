import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redemption/core/time/day.dart';
import 'package:redemption/data/backup/backup_service.dart';
import 'package:redemption/data/db/database.dart';
import 'package:redemption/data/repositories/entry_repository.dart';
import 'package:redemption/data/repositories/journey_repository.dart';
import 'package:redemption/data/repositories/tracker_repository.dart';
import 'package:redemption/data/repositories/upgrade_repository.dart';
import 'package:redemption/data/storage/attachment_store.dart';
import 'package:redemption/domain/journey_upgrades.dart';
import 'package:redemption/domain/models.dart';
import 'package:redemption/domain/scoring.dart';
import 'package:redemption/domain/templates.dart';
import 'package:redemption/domain/tracker_config.dart';
import 'package:redemption/domain/tracker_goal.dart';
import 'package:redemption/domain/tracker_type.dart';
import 'package:redemption/domain/tracker_value.dart';

const day = Day(2026, 10, 12);

Entry entry(int trackerId, TrackerValue v) => Entry(
  id: trackerId,
  trackerId: trackerId,
  day: day,
  value: v,
  updatedAt: DateTime(2026),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const scoring = Scoring(dayStartMinutes: 180);

  const workMode = Tracker(
    id: 1,
    journeyId: 1,
    name: 'WFH or office?',
    type: TrackerType.singleChoice,
    icon: 'home_work',
    color: 0,
    activeFrom: day,
    config: TrackerConfig(
      options: [
        ChoiceOption(id: 'wfh', label: 'WFH'),
        ChoiceOption(id: 'office', label: 'Office'),
      ],
    ),
    goal: ChoiceScoreGoal(),
  );
  // "On time" alone is worth 50% here, except on office days.
  final dhuhr = Tracker(
    id: 2,
    journeyId: 1,
    name: 'Dhuhr',
    type: TrackerType.singleChoice,
    icon: 'sunny',
    color: 0,
    activeFrom: day,
    config: TrackerConfig(
      options: [
        prayerOptions[0],
        prayerOptions[1].copyWith(score: 0.5),
        ...prayerOptions.skip(2),
      ],
      dayRule: officeDayRule(whenTrackerId: 1),
    ),
    goal: const ChoiceScoreGoal(),
  );

  group('DayRule', () {
    test('round-trips through JSON; unresolved template rules are not '
        'stored', () {
      final json = dhuhr.config.toJson();
      final back = TrackerConfig.fromJson(json);
      expect(back.dayRule, dhuhr.config.dayRule);
      expect(back.dayRule!.hideOptionIds, ['jamaah']);
      expect(back.dayRule!.credits, {'ontime': 1.0});
      expect(
        TrackerConfig(dayRule: officeDayRule()).toJson(),
        isNot(contains('dayRule')),
      );
      // Configs from before day rules existed still load.
      expect(TrackerConfig.fromJson(const {}).dayRule, isNull);
    });

    test('applies only on days the condition holds', () {
      final ontime = entry(2, const ChoiceValue('ontime'));
      final office = {1: entry(1, const ChoiceValue('office')), 2: ontime};
      final wfh = {1: entry(1, const ChoiceValue('wfh')), 2: ontime};

      expect(dhuhr.ruleOn(office), isNotNull);
      expect(dhuhr.ruleOn(wfh), isNull);
      expect(dhuhr.ruleOn({2: ontime}), isNull, reason: 'not logged yet');

      expect(scoring.progress(dhuhr, ontime.value, sameDay: office), 1);
      expect(scoring.progress(dhuhr, ontime.value, sameDay: wfh), 0.5);
      expect(scoring.progress(dhuhr, ontime.value), 0.5);
      // Options without an override keep their own credit.
      expect(
        scoring.progress(dhuhr, const ChoiceValue('late'), sameDay: office),
        0.5,
      );
      expect(
        scoring.status(dhuhr, ontime, day, day, sameDay: office),
        EntryStatus.done,
      );
      final summary = scoring.summarize(day, [
        workMode,
        dhuhr,
      ], EntryIndex(office.values));
      expect(summary.earned, 2);
    });
  });

  group('journeys', () {
    late AppDatabase db;
    setUp(
      () => db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      ),
    );
    tearDown(() => db.close());

    Future<List<Tracker>> create() async {
      final id = await JourneyRepository(db).createFromTemplate(
        template: Templates.redemption,
        name: '90',
        intention: '',
        startDay: day,
        durationDays: 90,
      );
      return TrackerRepository(db).forJourney(id);
    }

    test('the Redemption template wires office days to Dhuhr, Asr and '
        'Maghrib and adds meal on-time checks', () async {
      final trackers = await create();
      final work = trackers.firstWhere((t) => t.name == 'WFH or office?');
      for (final name in ['Dhuhr', 'Asr', 'Maghrib']) {
        final rule = trackers.firstWhere((t) => t.name == name).config.dayRule;
        expect(rule?.whenTrackerId, work.id, reason: name);
        expect(rule?.whenOptionId, 'office');
      }
      for (final name in ['Fajr', 'Isha']) {
        expect(
          trackers.firstWhere((t) => t.name == name).config.dayRule,
          isNull,
        );
      }
      final names = trackers.map((t) => t.name).toList();
      // One tracker per meal: on time earns the points, what you ate is
      // information only.
      for (final meal in ['Breakfast', 'Lunch', 'Post-workout dinner']) {
        expect(names, isNot(contains(meal)));
      }
      for (final check in [
        'Breakfast on time?',
        'Lunch on time?',
        'Dinner on time?',
      ]) {
        final t = trackers.firstWhere((t) => t.name == check);
        expect(t.type, TrackerType.checkbox);
        expect(t.goal, const BoolGoal());
        expect(t.isRequired, isTrue);
        expect(t.config.notePrompt, 'What did you eat?');
        expect(t.config.noteIsInfoOnly, isTrue);
        expect(t.config.placeholder, isNotEmpty);
      }
      final workout = trackers.firstWhere((t) => t.name == 'Workout');
      expect(workout.type, TrackerType.checkbox);
      expect(workout.config.notePrompt, 'What did you train?');
      expect(workout.isRequired, isTrue);
      expect(JourneyUpgrade.plan(trackers).isEmpty, isTrue);
      // Removing one of the additions doesn't bring the offer back.
      await TrackerRepository(db)
          .delete(trackers.firstWhere((t) => t.name == 'Dinner on time?').id);
      expect(
        JourneyUpgrade.plan(
          await TrackerRepository(db).forJourney(trackers.first.journeyId),
        ).isEmpty,
        isTrue,
      );
    });

    test('meal texts move into on-time checks that already existed', () async {
      final dir = await Directory.systemTemp.createTemp('meal');
      addTearDown(() => dir.delete(recursive: true));
      await BackupService(db, AttachmentStore(dir)).importBytes(
        await File('test/fixtures/redemption-backup-v1.0.0.zip').readAsBytes(),
      );
      final journey = (await JourneyRepository(db).active())!;
      final start = journey.startDay;
      final repo = TrackerRepository(db);
      final upgrades = UpgradeRepository(db);
      // v1.1 already added the checks from the first day…
      await upgrades.apply(
        JourneyUpgrade.plan(
          await repo.forJourney(journey.id),
          dismissed: const {
            JourneyUpgrade.workoutId,
            JourneyUpgrade.mealCommentsId,
          },
        ),
        journeyId: journey.id,
        today: start,
      );
      var trackers = await repo.forJourney(journey.id);
      final lunchCheck = trackers.firstWhere((t) => t.name == 'Lunch on time?');
      final entries = EntryRepository(db);
      // …and lunch was eaten on time on day 1 (day 2 has no answer).
      await entries.upsert(
        trackerId: lunchCheck.id,
        day: start,
        value: const BoolValue(true),
      );
      const scoring = Scoring(dayStartMinutes: 240);
      final before = scoring.summarize(
        start,
        trackers,
        EntryIndex(await entries.watchForJourney(journey.id).first),
      );

      // v1.3: fold the meal texts into the checks.
      await upgrades.apply(
        JourneyUpgrade.plan(
          trackers,
          dismissed: const {JourneyUpgrade.workoutId},
        ),
        journeyId: journey.id,
        today: start.addDays(5),
      );
      trackers = await repo.forJourney(journey.id);
      final all = EntryIndex(await entries.watchForJourney(journey.id).first);
      final lunchText = trackers.firstWhere((t) => t.name == 'Lunch');
      final day1 = all.get(lunchCheck.id, start)!;
      expect(day1.value, const BoolValue(true));
      expect(
        day1.note,
        (all.get(lunchText.id, start)!.value as TextValue).text.trim(),
      );
      final day2 = all.get(lunchCheck.id, start.addDays(1))!;
      expect(day2.value.isEmpty, isTrue, reason: 'info only, no points');
      expect(day2.note, isNotEmpty);
      expect(lunchText.archivedOn, start.addDays(5));
      expect(
        scoring.summarize(start, trackers, all).score,
        before.score,
        reason: 'past days keep their score',
      );
      expect(JourneyUpgrade.plan(trackers).mealTexts, isEmpty);
    });

    test(
      'a renamed check is found, and a meal reminder carries over',
      () async {
        final dir = await Directory.systemTemp.createTemp('meal2');
        addTearDown(() => dir.delete(recursive: true));
        await BackupService(db, AttachmentStore(dir)).importBytes(
          await File('test/fixtures/redemption-backup-v1.0.0.zip')
              .readAsBytes(),
        );
        final journey = (await JourneyRepository(db).active())!;
        final repo = TrackerRepository(db);
        final upgrades = UpgradeRepository(db);
        await upgrades.apply(
          JourneyUpgrade.plan(
            await repo.forJourney(journey.id),
            dismissed: const {
              JourneyUpgrade.workoutId,
              JourneyUpgrade.mealCommentsId,
            },
          ),
          journeyId: journey.id,
          today: journey.startDay,
        );
        var trackers = await repo.forJourney(journey.id);
        final check = trackers.firstWhere((t) => t.name == 'Lunch on time?');
        await repo.update(check.copyWith(name: 'Had lunch on time?'));
        final lunch = trackers.firstWhere((t) => t.name == 'Lunch');
        await repo.update(
          lunch.copyWith(reminderEnabled: true, reminderMinutes: () => 13 * 60),
        );

        await upgrades.apply(
          JourneyUpgrade.plan(
            await repo.forJourney(journey.id),
            dismissed: const {JourneyUpgrade.workoutId},
          ),
          journeyId: journey.id,
          today: journey.startDay.addDays(3),
        );
        trackers = await repo.forJourney(journey.id);
        expect(
          trackers.where((t) => t.name.contains('unch on time')),
          hasLength(1),
          reason: 'no duplicate check',
        );
        final renamed = trackers.firstWhere((t) => t.id == check.id);
        expect(renamed.name, 'Had lunch on time?');
        expect(renamed.config.notePrompt, 'What did you eat?');
        expect(renamed.reminderEnabled, isTrue);
        expect(renamed.reminderMinutes, 13 * 60);
      },
    );

    test('a description the user wrote survives the workout switch', () {
      const own = Tracker(
        id: 7,
        journeyId: 1,
        name: 'Workout',
        type: TrackerType.longText,
        icon: 'gym',
        color: 0,
        activeFrom: day,
        description: 'PPL split, Mon/Wed/Fri',
      );
      expect(
        JourneyUpgrade.plan([own]).workoutAsYesNo()!.description,
        'PPL split, Mon/Wed/Fri',
      );
      expect(
        JourneyUpgrade.plan([own.copyWith(description: 'What did you train?')])
            .workoutAsYesNo()!
            .description,
        workoutTracker(at: 0).description,
      );
    });

    test('one “Dinner on time?” even with two dinner trackers', () {
      Tracker meal(int id, String name) => Tracker(
        id: id,
        journeyId: 1,
        name: name,
        type: TrackerType.longText,
        icon: 'dinner',
        color: 0,
        activeFrom: day,
      );
      final plan = JourneyUpgrade.plan([
        meal(1, 'Post-workout dinner'),
        meal(2, 'Dinner'),
      ]);
      expect(plan.meals.map((m) => m.$2), ['Dinner']);
    });

    test('copying a journey points rules at the copied tracker', () async {
      final old = await create();
      final newId = await JourneyRepository(db).createFromExisting(
        copyFrom: old.first.journeyId,
        name: 'Round 2',
        intention: '',
        startDay: day.addDays(90),
        durationDays: 90,
      );
      final copied = await TrackerRepository(db).forJourney(newId);
      final work = copied.firstWhere((t) => t.name == 'WFH or office?');
      final asr = copied.firstWhere((t) => t.name == 'Asr');
      expect(asr.config.dayRule?.whenTrackerId, work.id);
    });

    test('a v1.0.0 journey can opt in without changing past days', () async {
      final dir = await Directory.systemTemp.createTemp('upg');
      addTearDown(() => dir.delete(recursive: true));
      await BackupService(db, AttachmentStore(dir)).importBytes(
        await File('test/fixtures/redemption-backup-v1.0.0.zip').readAsBytes(),
      );
      final journey = (await JourneyRepository(db).active())!;
      final repo = TrackerRepository(db);
      var trackers = await repo.forJourney(journey.id);
      final entries = EntryIndex(
        await EntryRepository(db).watchForJourney(journey.id).first,
      );
      final before = (trackers,);

      final upgrade = JourneyUpgrade.plan(trackers);
      expect(upgrade.prayers.map((p) => p.name), ['Dhuhr', 'Asr', 'Maghrib']);
      expect(upgrade.meals.map((m) => m.$2), ['Breakfast', 'Lunch', 'Dinner']);
      expect(upgrade.workout?.name, 'Workout');
      expect(upgrade.ids, {
        JourneyUpgrade.officeAndMealsId,
        JourneyUpgrade.workoutId,
        JourneyUpgrade.mealCommentsId,
      });
      expect(upgrade.mealTexts.map((t) => t.name), [
        'Breakfast',
        'Lunch',
        'Post-workout dinner',
      ]);
      final workoutId = upgrade.workout!.id;
      final oldWorkouts = {
        for (final e in entries.forTracker(workoutId).values)
          e.day: (e.value as TextValue).text,
      };
      expect(oldWorkouts, hasLength(2));

      const today = Day(2026, 10, 12);
      await UpgradeRepository(db)
          .apply(upgrade, journeyId: journey.id, today: today);
      trackers = await repo.forJourney(journey.id);
      expect(JourneyUpgrade.plan(trackers).isEmpty, isTrue);

      // The timeline keeps its order (sort order follows planned times).
      final ordered = [
        for (final t in trackers)
          if (t.anchorMinutes != null) t.anchorMinutes!,
      ];
      expect(ordered, [...ordered]..sort(), reason: 'timeline in time order');
      expect(
        trackers.map((t) => t.sortOrder).toSet(),
        hasLength(trackers.length),
      );

      // Workout is now "Did you train?" and its history became comments.
      final workout = trackers.firstWhere((t) => t.id == workoutId);
      expect(workout.type, TrackerType.checkbox);
      expect(workout.goal, const BoolGoal());
      expect(workout.config.yesLabel, 'Trained');
      expect(workout.config.notePrompt, 'What did you train?');
      final converted = EntryIndex(
        await EntryRepository(db).watchForJourney(journey.id).first,
      ).forTracker(workoutId);
      for (final MapEntry(key: day, value: text) in oldWorkouts.entries) {
        expect(converted[day]!.value, const BoolValue(true));
        expect(converted[day]!.note, startsWith(text));
      }

      // Meals: one on-time check each, asking what was eaten (info only);
      // the text trackers stop counting from today and keep their history.
      for (final (meal, check) in [
        ('Breakfast', 'Breakfast on time?'),
        ('Lunch', 'Lunch on time?'),
        ('Post-workout dinner', 'Dinner on time?'),
      ]) {
        final text = trackers.firstWhere((t) => t.name == meal);
        expect(text.archivedOn, today, reason: meal);
        final c = trackers.firstWhere((t) => t.name == check && !t.isArchived);
        expect(c.config.notePrompt, 'What did you eat?');
        expect(c.config.noteIsInfoOnly, isTrue);
        expect(c.icon, text.icon);
        expect(
          EntryIndex(
            await EntryRepository(db).watchForJourney(journey.id).first,
          ).forTracker(text.id),
          hasLength(2),
          reason: 'history kept on the archived $meal tracker',
        );
      }

      final breakfastCheck = trackers.firstWhere(
        (t) => t.name == 'Breakfast on time?',
      );
      expect(breakfastCheck.activeFrom, today);

      final now = EntryIndex(
        await EntryRepository(db).watchForJourney(journey.id).first,
      );
      for (final d in [journey.startDay, journey.startDay.addDays(1)]) {
        final was = scoring.summarize(d, before.$1, entries);
        final after = scoring.summarize(d, trackers, now);
        expect(after.score, was.score, reason: 'scores unchanged on $d');
        expect(after.expected, was.expected);
      }
    });
  });
}
