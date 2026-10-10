import 'package:material_ui/material_ui.dart';

/// Every kind of input a tracker can collect.
///
/// The enum `name` is persisted, so never rename existing values.
enum TrackerType {
  checkbox(
    label: 'Yes / No',
    description: 'A single tap. Did it happen today?',
    example: 'Prayed Fajr? Pre-workout meal?',
    icon: Icons.check_circle_outline_rounded,
  ),
  singleChoice(
    label: 'Single choice',
    description: 'Pick one option. Each option can carry its own score.',
    example: 'WFH or office? Prayer in congregation / on time / late',
    icon: Icons.radio_button_checked_rounded,
  ),
  multiChoice(
    label: 'Multiple choice',
    description: 'Pick any number of tags. Add new ones on the fly.',
    example: 'Muscle groups trained, foods eaten',
    icon: Icons.checklist_rounded,
  ),
  time(
    label: 'Time of day',
    description: 'Log a clock time with one tap on “Now” or a wheel.',
    example: 'Wake-up time, left office, sleep time',
    icon: Icons.schedule_rounded,
  ),
  duration(
    label: 'Duration',
    description: 'Hours and minutes with quick presets.',
    example: 'Deep work, workout length, screen time',
    icon: Icons.timer_outlined,
  ),
  counter(
    label: 'Counter',
    description: 'Tap +1 towards a daily target.',
    example: 'Glasses of water, pages read, pages of Qur’an',
    icon: Icons.add_circle_outline_rounded,
  ),
  number(
    label: 'Number',
    description: 'Whole numbers with a stepper or slider.',
    example: 'Steps, push-ups, calories',
    icon: Icons.pin_outlined,
  ),
  decimal(
    label: 'Decimal',
    description: 'Precise values with units.',
    example: 'Body weight (kg), distance (km)',
    icon: Icons.straighten_rounded,
  ),
  rating(
    label: 'Rating',
    description: 'Stars, emoji faces or a 1–10 scale.',
    example: 'Mood, energy, focus, khushu’',
    icon: Icons.star_outline_rounded,
  ),
  text(
    label: 'Short text',
    description: 'One line, with suggestions from your history.',
    example: 'Today’s one win',
    icon: Icons.short_text_rounded,
  ),
  longText(
    label: 'Notes',
    description: 'Free text with tap-to-add suggestion chips.',
    example: 'What I ate for breakfast, what I trained',
    icon: Icons.notes_rounded,
  ),
  image(
    label: 'Photo',
    description: 'Capture or pick photos.',
    example: 'Meal photo, progress picture',
    icon: Icons.photo_camera_outlined,
  ),
  file(
    label: 'File',
    description: 'Attach any document.',
    example: 'Workout plan PDF, lab report',
    icon: Icons.attach_file_rounded,
  );

  const TrackerType({
    required this.label,
    required this.description,
    required this.example,
    required this.icon,
  });

  final String label;
  final String description;
  final String example;
  final IconData icon;

  static TrackerType parse(String name) =>
      TrackerType.values.firstWhere((t) => t.name == name, orElse: () => text);

  /// Types whose value is a plain number (shares numeric goal logic).
  bool get isNumeric =>
      this == number ||
      this == decimal ||
      this == counter ||
      this == rating ||
      this == duration;

  bool get isAttachment => this == image || this == file;

  bool get isTextual => this == text || this == longText;

  /// Types whose single tap in the sheet should save immediately.
  bool get savesInstantly => this == checkbox || this == singleChoice;

  /// Whether a value of this type can be charted as a numeric series.
  bool get isChartable => isNumeric || this == time;
}
