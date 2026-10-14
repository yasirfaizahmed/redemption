import 'package:material_ui/material_ui.dart';

import '../core/time/day.dart';
import 'dashboard.dart';
import 'models.dart';
import 'tracker_config.dart';
import 'tracker_goal.dart';
import 'tracker_type.dart';

/// A tracker inside a template, referenced by [ref] from dashboard widgets.
class TemplateTracker {
  const TemplateTracker(this.ref, this.tracker);
  final String ref;
  final Tracker tracker;
}

class TemplateWidget {
  const TemplateWidget(
    this.kind, {
    this.size = WidgetSize.full,
    this.refs = const [],
    this.config = const DashboardItemConfig(),
  });
  final DashboardWidgetKind kind;
  final WidgetSize size;
  final List<String> refs;
  final DashboardItemConfig config;
}

class JourneyTemplate {
  const JourneyTemplate({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.suggestedName,
    required this.suggestedIntention,
    required this.trackers,
    required this.widgets,
  });

  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final String suggestedName;
  final String suggestedIntention;
  final List<TemplateTracker> trackers;
  final List<TemplateWidget> widgets;
}

// Placeholder values replaced when a template is instantiated.
const _epoch = Day(2000, 1, 1);

Tracker _t({
  required String name,
  required TrackerType type,
  required String icon,
  required int color,
  String section = '',
  String description = '',
  int? at,
  int weekdays = Weekdays.all,
  bool required = true,
  TrackerConfig config = const TrackerConfig(),
  TrackerGoal goal = const LoggedGoal(),
}) => Tracker(
  id: 0,
  journeyId: 0,
  name: name,
  description: description,
  type: type,
  icon: icon,
  color: color,
  section: section,
  anchorMinutes: at,
  weekdays: weekdays,
  isRequired: required,
  config: config,
  goal: goal,
  activeFrom: _epoch,
);

int _hm(int h, int m) => h * 60 + m;

const prayerOptions = <ChoiceOption>[
  ChoiceOption(id: 'jamaah', label: 'In congregation', emoji: '🕌'),
  ChoiceOption(id: 'ontime', label: 'On time', emoji: '✅'),
  ChoiceOption(id: 'late', label: 'Late / Qada', emoji: '⏳', score: 0.5),
  ChoiceOption(id: 'missed', label: 'Missed', emoji: '❌', score: 0),
];

Tracker _prayer(
  String name,
  String icon,
  int at,
  String section, {
  DayRule? rule,
}) => _t(
  name: name,
  type: TrackerType.singleChoice,
  icon: icon,
  color: 0xFF10B981,
  section: section,
  at: at,
  config: TrackerConfig(options: prayerOptions, dayRule: rule),
  goal: const ChoiceScoreGoal(),
);

/// No masjid at the office: on office days congregation isn't offered as a
/// one-tap option and praying on time earns full marks.
DayRule officeDayRule({String whenRef = 'workmode', int whenTrackerId = 0}) =>
    DayRule(
      whenRef: whenRef,
      whenTrackerId: whenTrackerId,
      whenOptionId: 'office',
      label: 'Office day — no masjid: praying on time earns full marks',
      hideOptionIds: const ['jamaah'],
      credits: const {'ontime': 1},
    );

/// Did you train? A win earns full points; the comment records what you did.
Tracker workoutTracker({required int at, String section = 'Evening'}) => _t(
  name: 'Workout',
  type: TrackerType.checkbox,
  icon: 'gym',
  color: 0xFFEF4444,
  section: section,
  at: at,
  description: 'Did you train today? Add what you did.',
  config: workoutConfig,
  goal: const BoolGoal(),
);

const workoutConfig = TrackerConfig(
  yesLabel: 'Trained',
  noLabel: 'Skipped',
  notePrompt: 'What did you train?',
  placeholder: 'Push day: bench 4×8, OHP 3×10, dips…',
);

/// "Had it on time?" for a meal; counts towards the daily score.
Tracker mealOnTime(String meal, {required String section, required int at}) =>
    _t(
      name: '$meal on time?',
      type: TrackerType.checkbox,
      icon: 'clock',
      color: 0xFFF97316,
      section: section,
      at: at,
      config: const TrackerConfig(yesLabel: 'On time', noLabel: 'Late'),
      goal: const BoolGoal(),
    );

abstract final class Templates {
  static final redemption = JourneyTemplate(
    id: 'redemption',
    name: 'Redemption — Muslim daily discipline',
    tagline: 'Wake early, 5 prayers on time, clean meals, train, sleep early.',
    icon: Icons.mosque_rounded,
    suggestedName: '90 Days of Redemption',
    suggestedIntention:
        'For the sake of Allah: to guard my prayers, master my nafs and '
        'become the strong believer He loves.',
    trackers: [
      TemplateTracker(
        'wake',
        _t(
          name: 'Wake-up time',
          type: TrackerType.time,
          icon: 'alarm',
          color: 0xFFF59E0B,
          section: 'Morning',
          at: _hm(4, 30),
          goal: TimeGoal(
            comparator: TimeComparator.before,
            minutes: _hm(5, 0),
            graceMinutes: 15,
          ),
        ),
      ),
      TemplateTracker(
        'fajr',
        _prayer('Fajr', 'twilight', _hm(5, 0), 'Morning'),
      ),
      TemplateTracker(
        'breakfast',
        _t(
          name: 'Breakfast',
          type: TrackerType.longText,
          icon: 'breakfast',
          color: 0xFFF97316,
          section: 'Morning',
          at: _hm(7, 30),
          config: const TrackerConfig(placeholder: 'Oats, eggs, dates…'),
        ),
      ),
      TemplateTracker(
        'breakfast_ontime',
        mealOnTime('Breakfast', section: 'Morning', at: _hm(7, 30)),
      ),
      TemplateTracker(
        'workmode',
        _t(
          name: 'WFH or office?',
          type: TrackerType.singleChoice,
          icon: 'home_work',
          color: 0xFF3B82F6,
          section: 'Day',
          at: _hm(9, 0),
          weekdays: Weekdays.workweek,
          config: const TrackerConfig(
            options: [
              ChoiceOption(id: 'wfh', label: 'Work from home', emoji: '🏠'),
              ChoiceOption(id: 'office', label: 'Office', emoji: '🏢'),
              ChoiceOption(id: 'leave', label: 'Leave / holiday', emoji: '🌴'),
            ],
          ),
          goal: const ChoiceScoreGoal(),
        ),
      ),
      TemplateTracker(
        'dhuhr',
        _prayer('Dhuhr', 'sunny', _hm(13, 15), 'Day', rule: officeDayRule()),
      ),
      TemplateTracker(
        'lunch',
        _t(
          name: 'Lunch',
          type: TrackerType.longText,
          icon: 'lunch',
          color: 0xFFF97316,
          section: 'Day',
          at: _hm(13, 45),
          config: const TrackerConfig(placeholder: 'Rice, dal, chicken…'),
        ),
      ),
      TemplateTracker(
        'lunch_ontime',
        mealOnTime('Lunch', section: 'Day', at: _hm(13, 45)),
      ),
      TemplateTracker(
        'leftoffice',
        _t(
          name: 'Left office',
          type: TrackerType.time,
          icon: 'logout',
          color: 0xFF64748B,
          section: 'Day',
          at: _hm(16, 30),
          weekdays: Weekdays.workweek,
        ),
      ),
      TemplateTracker(
        'asr',
        _prayer('Asr', 'sun_low', _hm(16, 45), 'Day', rule: officeDayRule()),
      ),
      TemplateTracker(
        'preworkout',
        _t(
          name: 'Pre-workout meal',
          type: TrackerType.checkbox,
          icon: 'bolt',
          color: 0xFFEAB308,
          section: 'Evening',
          at: _hm(17, 30),
          config: const TrackerConfig(yesLabel: 'Had it', noLabel: 'Skipped'),
          goal: const BoolGoal(),
        ),
      ),
      TemplateTracker(
        'maghrib',
        _prayer(
          'Maghrib',
          'sunset',
          _hm(18, 30),
          'Evening',
          rule: officeDayRule(),
        ),
      ),
      TemplateTracker('workout', workoutTracker(at: _hm(19, 0))),
      TemplateTracker(
        'dinner',
        _t(
          name: 'Post-workout dinner',
          type: TrackerType.longText,
          icon: 'dinner',
          color: 0xFFF97316,
          section: 'Evening',
          at: _hm(20, 15),
          config: const TrackerConfig(placeholder: 'Chicken, rice, salad…'),
        ),
      ),
      TemplateTracker(
        'dinner_ontime',
        mealOnTime('Dinner', section: 'Evening', at: _hm(20, 15)),
      ),
      TemplateTracker('isha', _prayer('Isha', 'moon', _hm(20, 45), 'Night')),
      TemplateTracker(
        'sleep',
        _t(
          name: 'Sleep time',
          type: TrackerType.time,
          icon: 'bed',
          color: 0xFF6366F1,
          section: 'Night',
          at: _hm(22, 0),
          goal: TimeGoal(
            comparator: TimeComparator.before,
            minutes: _hm(22, 30),
            graceMinutes: 30,
          ),
        ),
      ),
    ],
    widgets: const [
      TemplateWidget(DashboardWidgetKind.journeyRing),
      TemplateWidget(DashboardWidgetKind.todayProgress, size: WidgetSize.half),
      TemplateWidget(DashboardWidgetKind.streak, size: WidgetSize.half),
      TemplateWidget(
        DashboardWidgetKind.todayStrip,
        refs: ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'],
        config: DashboardItemConfig(title: 'Salah today'),
      ),
      TemplateWidget(DashboardWidgetKind.nextUp),
      TemplateWidget(
        DashboardWidgetKind.trackerRings,
        refs: [
          'fajr',
          'dhuhr',
          'asr',
          'maghrib',
          'isha',
          'wake',
          'workout',
          'sleep',
        ],
        config: DashboardItemConfig(title: 'Road to 90'),
      ),
      TemplateWidget(DashboardWidgetKind.trend, refs: ['wake']),
      TemplateWidget(DashboardWidgetKind.trend, refs: ['sleep']),
      TemplateWidget(DashboardWidgetKind.heatmap),
      TemplateWidget(DashboardWidgetKind.phase),
      TemplateWidget(DashboardWidgetKind.motto),
    ],
  );

  static final fitness = JourneyTemplate(
    id: 'fitness',
    name: 'Body recomposition',
    tagline: 'Water, steps, training, protein, sleep and progress photos.',
    icon: Icons.fitness_center_rounded,
    suggestedName: '90-Day Transformation',
    suggestedIntention: 'Build a strong, healthy body I am proud of.',
    trackers: [
      TemplateTracker(
        'wake',
        _t(
          name: 'Wake-up time',
          type: TrackerType.time,
          icon: 'alarm',
          color: 0xFFF59E0B,
          section: 'Morning',
          at: _hm(6, 0),
          goal: TimeGoal(
            comparator: TimeComparator.before,
            minutes: _hm(6, 30),
          ),
        ),
      ),
      TemplateTracker(
        'water',
        _t(
          name: 'Water',
          type: TrackerType.counter,
          icon: 'water',
          color: 0xFF0EA5E9,
          section: 'All day',
          config: const TrackerConfig(unit: 'glasses'),
          goal: const NumberGoal(
            comparator: NumberComparator.atLeast,
            value: 8,
          ),
        ),
      ),
      TemplateTracker(
        'steps',
        _t(
          name: 'Steps',
          type: TrackerType.number,
          icon: 'walk',
          color: 0xFF22C55E,
          section: 'All day',
          config: const TrackerConfig(
            step: 500,
            min: 0,
            max: 30000,
            presets: [5000, 8000, 10000, 12000],
          ),
          goal: const NumberGoal(
            comparator: NumberComparator.atLeast,
            value: 8000,
          ),
        ),
      ),
      TemplateTracker(
        'workout',
        _t(
          name: 'Training',
          type: TrackerType.duration,
          icon: 'gym',
          color: 0xFFEF4444,
          section: 'Evening',
          at: _hm(18, 30),
          weekdays: 0x3F, // Mon–Sat
          config: const TrackerConfig(presets: [30, 45, 60, 75, 90]),
          goal: const NumberGoal(
            comparator: NumberComparator.atLeast,
            value: 45,
          ),
        ),
      ),
      TemplateTracker(
        'protein',
        _t(
          name: 'Protein',
          type: TrackerType.number,
          icon: 'egg',
          color: 0xFFF97316,
          section: 'All day',
          config: const TrackerConfig(
            unit: 'g',
            step: 10,
            min: 0,
            max: 300,
            inputStyle: NumberInputStyle.slider,
            presets: [100, 120, 140, 160],
          ),
          goal: const NumberGoal(
            comparator: NumberComparator.atLeast,
            value: 120,
          ),
        ),
      ),
      TemplateTracker(
        'weight',
        _t(
          name: 'Body weight',
          type: TrackerType.decimal,
          icon: 'weight',
          color: 0xFF8B5CF6,
          section: 'Morning',
          at: _hm(6, 15),
          required: false,
          config: const TrackerConfig(unit: 'kg', step: 0.1),
        ),
      ),
      TemplateTracker(
        'sleep',
        _t(
          name: 'Sleep',
          type: TrackerType.duration,
          icon: 'bed',
          color: 0xFF6366F1,
          section: 'Morning',
          at: _hm(6, 5),
          config: const TrackerConfig(presets: [360, 420, 450, 480]),
          goal: const NumberGoal(
            comparator: NumberComparator.atLeast,
            value: 420,
          ),
        ),
      ),
      TemplateTracker(
        'mood',
        _t(
          name: 'Mood',
          type: TrackerType.rating,
          icon: 'mood',
          color: 0xFFEC4899,
          section: 'Night',
          at: _hm(22, 0),
          required: false,
          config: const TrackerConfig(ratingStyle: RatingStyle.emoji),
        ),
      ),
      TemplateTracker(
        'photo',
        _t(
          name: 'Progress photo',
          type: TrackerType.image,
          icon: 'camera',
          color: 0xFF14B8A6,
          section: 'Morning',
          weekdays: 0x40, // Sundays
          required: false,
        ),
      ),
    ],
    widgets: const [
      TemplateWidget(DashboardWidgetKind.journeyRing),
      TemplateWidget(DashboardWidgetKind.todayProgress, size: WidgetSize.half),
      TemplateWidget(DashboardWidgetKind.streak, size: WidgetSize.half),
      TemplateWidget(DashboardWidgetKind.nextUp),
      TemplateWidget(
        DashboardWidgetKind.trackerRings,
        refs: ['water', 'steps', 'workout', 'protein', 'sleep', 'wake'],
      ),
      TemplateWidget(
        DashboardWidgetKind.trend,
        refs: ['weight'],
        config: DashboardItemConfig(rangeDays: 0),
      ),
      TemplateWidget(
        DashboardWidgetKind.statTile,
        size: WidgetSize.half,
        refs: ['steps'],
        config: DashboardItemConfig(stat: StatKind.average),
      ),
      TemplateWidget(
        DashboardWidgetKind.statTile,
        size: WidgetSize.half,
        refs: ['workout'],
        config: DashboardItemConfig(stat: StatKind.total),
      ),
      TemplateWidget(DashboardWidgetKind.weekBars),
      TemplateWidget(DashboardWidgetKind.heatmap),
      TemplateWidget(DashboardWidgetKind.motto),
    ],
  );

  static final deepWork = JourneyTemplate(
    id: 'deepwork',
    name: 'Deep work & learning',
    tagline: 'Focused hours, reading, journaling and fewer distractions.',
    icon: Icons.psychology_rounded,
    suggestedName: '90 Days of Deep Work',
    suggestedIntention: 'Master my craft through daily, focused practice.',
    trackers: [
      TemplateTracker(
        'deep',
        _t(
          name: 'Deep work',
          type: TrackerType.duration,
          icon: 'laptop',
          color: 0xFF6366F1,
          section: 'Work',
          at: _hm(9, 0),
          config: const TrackerConfig(presets: [60, 120, 180, 240]),
          goal: const NumberGoal(
            comparator: NumberComparator.atLeast,
            value: 180,
          ),
        ),
      ),
      TemplateTracker(
        'read',
        _t(
          name: 'Reading',
          type: TrackerType.counter,
          icon: 'book',
          color: 0xFF14B8A6,
          section: 'Evening',
          at: _hm(21, 0),
          config: const TrackerConfig(unit: 'pages', step: 5),
          goal: const NumberGoal(
            comparator: NumberComparator.atLeast,
            value: 20,
          ),
        ),
      ),
      TemplateTracker(
        'nosocial',
        _t(
          name: 'Social-media free',
          type: TrackerType.checkbox,
          icon: 'no_phone',
          color: 0xFFF43F5E,
          section: 'All day',
          config: const TrackerConfig(
            yesLabel: 'Stayed off',
            noLabel: 'Slipped',
          ),
          goal: const BoolGoal(),
        ),
      ),
      TemplateTracker(
        'focus',
        _t(
          name: 'Focus quality',
          type: TrackerType.rating,
          icon: 'target',
          color: 0xFFF59E0B,
          section: 'Work',
          at: _hm(17, 0),
          config: const TrackerConfig(
            ratingMax: 10,
            ratingStyle: RatingStyle.scale,
          ),
          goal: const NumberGoal(
            comparator: NumberComparator.atLeast,
            value: 7,
          ),
        ),
      ),
      TemplateTracker(
        'win',
        _t(
          name: 'One win today',
          type: TrackerType.text,
          icon: 'trophy',
          color: 0xFFEAB308,
          section: 'Evening',
          at: _hm(21, 30),
        ),
      ),
      TemplateTracker(
        'journal',
        _t(
          name: 'Journal',
          type: TrackerType.longText,
          icon: 'edit',
          color: 0xFF8B5CF6,
          section: 'Evening',
          at: _hm(21, 45),
          required: false,
          config: const TrackerConfig(suggestFromHistory: false),
        ),
      ),
    ],
    widgets: const [
      TemplateWidget(DashboardWidgetKind.journeyRing),
      TemplateWidget(DashboardWidgetKind.todayProgress, size: WidgetSize.half),
      TemplateWidget(DashboardWidgetKind.streak, size: WidgetSize.half),
      TemplateWidget(
        DashboardWidgetKind.trackerRings,
        refs: ['deep', 'read', 'nosocial', 'focus'],
      ),
      TemplateWidget(DashboardWidgetKind.trend, refs: ['deep']),
      TemplateWidget(
        DashboardWidgetKind.statTile,
        size: WidgetSize.half,
        refs: ['deep'],
        config: DashboardItemConfig(stat: StatKind.total),
      ),
      TemplateWidget(
        DashboardWidgetKind.statTile,
        size: WidgetSize.half,
        refs: ['read'],
        config: DashboardItemConfig(stat: StatKind.total),
      ),
      TemplateWidget(DashboardWidgetKind.heatmap),
      TemplateWidget(DashboardWidgetKind.phase),
      TemplateWidget(DashboardWidgetKind.motto),
    ],
  );

  static final quit = JourneyTemplate(
    id: 'quit',
    name: 'Break a bad habit',
    tagline: 'Stay clean, understand your triggers, replace the urge.',
    icon: Icons.shield_rounded,
    suggestedName: '90 Days Clean',
    suggestedIntention: 'I am not my urges. Every clean day makes me free.',
    trackers: [
      TemplateTracker(
        'clean',
        _t(
          name: 'Stayed clean today',
          type: TrackerType.checkbox,
          icon: 'shield',
          color: 0xFF10B981,
          section: 'Night',
          at: _hm(22, 0),
          config: const TrackerConfig(
            yesLabel: 'Stayed clean',
            noLabel: 'Relapsed',
          ),
          goal: const BoolGoal(),
        ),
      ),
      TemplateTracker(
        'urges',
        _t(
          name: 'Urges resisted',
          type: TrackerType.counter,
          icon: 'flame',
          color: 0xFFF97316,
          section: 'All day',
          required: false,
        ),
      ),
      TemplateTracker(
        'strength',
        _t(
          name: 'Urge strength',
          type: TrackerType.rating,
          icon: 'bolt',
          color: 0xFFF43F5E,
          section: 'All day',
          required: false,
          config: const TrackerConfig(
            ratingMax: 10,
            ratingStyle: RatingStyle.scale,
          ),
        ),
      ),
      TemplateTracker(
        'triggers',
        _t(
          name: 'Triggers',
          type: TrackerType.multiChoice,
          icon: 'visibility_off',
          color: 0xFF8B5CF6,
          section: 'All day',
          required: false,
          config: const TrackerConfig(
            options: [
              ChoiceOption(id: 'bored', label: 'Boredom', emoji: '😐'),
              ChoiceOption(id: 'stress', label: 'Stress', emoji: '😣'),
              ChoiceOption(id: 'lonely', label: 'Loneliness', emoji: '🫥'),
              ChoiceOption(id: 'late', label: 'Up late', emoji: '🌙'),
              ChoiceOption(id: 'phone', label: 'Phone in bed', emoji: '📱'),
              ChoiceOption(id: 'social', label: 'Social media', emoji: '🔁'),
            ],
          ),
        ),
      ),
      TemplateTracker(
        'replace',
        _t(
          name: 'Replacement action',
          type: TrackerType.checkbox,
          icon: 'run',
          color: 0xFF22C55E,
          section: 'All day',
          description:
              'Did you redirect at least one urge (walk, wudu, pray, call)?',
          config: const TrackerConfig(yesLabel: 'Did it', noLabel: 'Not today'),
          goal: const BoolGoal(),
        ),
      ),
      TemplateTracker(
        'reflect',
        _t(
          name: 'What helped today',
          type: TrackerType.longText,
          icon: 'lightbulb',
          color: 0xFFEAB308,
          section: 'Night',
          at: _hm(22, 5),
          required: false,
        ),
      ),
    ],
    widgets: const [
      TemplateWidget(DashboardWidgetKind.journeyRing),
      TemplateWidget(DashboardWidgetKind.streak, size: WidgetSize.half),
      TemplateWidget(
        DashboardWidgetKind.statTile,
        size: WidgetSize.half,
        refs: ['urges'],
        config: DashboardItemConfig(stat: StatKind.total),
      ),
      TemplateWidget(DashboardWidgetKind.phase),
      TemplateWidget(DashboardWidgetKind.heatmap),
      TemplateWidget(
        DashboardWidgetKind.trackerRings,
        refs: ['clean', 'replace'],
      ),
      TemplateWidget(DashboardWidgetKind.motto),
    ],
  );

  static const blank = JourneyTemplate(
    id: 'blank',
    name: 'Start from scratch',
    tagline: 'An empty journey. Build every tracker yourself.',
    icon: Icons.add_rounded,
    suggestedName: 'My 90-day journey',
    suggestedIntention: '',
    trackers: [],
    widgets: [
      TemplateWidget(DashboardWidgetKind.journeyRing),
      TemplateWidget(DashboardWidgetKind.todayProgress, size: WidgetSize.half),
      TemplateWidget(DashboardWidgetKind.streak, size: WidgetSize.half),
      TemplateWidget(DashboardWidgetKind.nextUp),
      TemplateWidget(DashboardWidgetKind.heatmap),
      TemplateWidget(DashboardWidgetKind.phase),
      TemplateWidget(DashboardWidgetKind.motto),
    ],
  );

  static final all = [redemption, fitness, deepWork, quit, blank];

  static JourneyTemplate byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => blank);
}
