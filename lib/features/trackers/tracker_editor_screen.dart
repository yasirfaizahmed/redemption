import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/palette.dart';
import '../../core/time/day.dart';
import '../../core/time/time_of_day_x.dart';
import '../../core/widgets/common.dart';
import '../../domain/formatting.dart';
import '../../domain/models.dart';
import '../../domain/tracker_config.dart';
import '../../domain/tracker_goal.dart';
import '../../domain/tracker_type.dart';
import '../../state/providers.dart';
import 'widgets/editor_widgets.dart';

enum _GoalMode {
  logged,
  yes,
  no,
  atLeast,
  atMost,
  between,
  before,
  after,
  choice,
}

class _OptionDraft {
  _OptionDraft({
    required this.id,
    String label = '',
    String emoji = '',
    this.score = 1,
  }) : label = TextEditingController(text: label),
       emoji = TextEditingController(text: emoji);

  factory _OptionDraft.from(ChoiceOption o) =>
      _OptionDraft(id: o.id, label: o.label, emoji: o.emoji, score: o.score);

  final String id;
  final TextEditingController label;
  final TextEditingController emoji;
  double score;

  ChoiceOption toOption() => ChoiceOption(
    id: id,
    label: label.text.trim(),
    emoji: emoji.text.trim(),
    score: score,
  );

  void dispose() {
    label.dispose();
    emoji.dispose();
  }
}

class TrackerEditorScreen extends ConsumerStatefulWidget {
  const TrackerEditorScreen({super.key, this.trackerId});

  /// Null when creating a new tracker.
  final int? trackerId;

  @override
  ConsumerState<TrackerEditorScreen> createState() =>
      _TrackerEditorScreenState();
}

class _TrackerEditorScreenState extends ConsumerState<TrackerEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  Tracker? _draft;
  int _entryCount = 0;
  bool _countFromStart = false;
  bool _saving = false;

  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _unit = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _step = TextEditingController();
  final _presets = TextEditingController();
  final _placeholder = TextEditingController();
  final _yes = TextEditingController();
  final _no = TextEditingController();
  final _goalValue = TextEditingController();
  final _goalUpper = TextEditingController();
  final List<_OptionDraft> _options = [];

  _GoalMode _goalMode = _GoalMode.logged;
  int _goalTime = 5 * 60;
  int _grace = 0;

  bool get _isNew => widget.trackerId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) {
      final t = ref.read(trackerByIdProvider(widget.trackerId!));
      if (t != null) _load(t);
      ref.read(trackerRepositoryProvider).entryCount(widget.trackerId!).then((
        c,
      ) {
        if (mounted) setState(() => _entryCount = c);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _desc,
      _unit,
      _min,
      _max,
      _step,
      _presets,
      _placeholder,
      _yes,
      _no,
      _goalValue,
      _goalUpper,
    ]) {
      c.dispose();
    }
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Draft <-> controllers
  // -------------------------------------------------------------------------

  String _num(double? v) =>
      v == null ? '' : Fmt.number(v, decimals: 2).replaceAll(',', '');

  void _load(Tracker t) {
    _draft = t;
    final c = t.config;
    _name.text = t.name;
    _desc.text = t.description;
    _unit.text = c.unit;
    _min.text = _num(c.min);
    _max.text = _num(c.max);
    _step.text = _num(c.step);
    _presets.text = c.presets.map(_num).join(', ');
    _placeholder.text = c.placeholder;
    _yes.text = c.yesLabel;
    _no.text = c.noLabel;
    for (final o in _options) {
      o.dispose();
    }
    _options
      ..clear()
      ..addAll(c.options.map(_OptionDraft.from));
    switch (t.goal) {
      case LoggedGoal():
        _goalMode = _GoalMode.logged;
      case BoolGoal(:final target):
        _goalMode = target ? _GoalMode.yes : _GoalMode.no;
      case ChoiceScoreGoal():
        _goalMode = _GoalMode.choice;
      case NumberGoal(:final comparator, :final value, :final upper):
        _goalMode = switch (comparator) {
          NumberComparator.atLeast => _GoalMode.atLeast,
          NumberComparator.atMost => _GoalMode.atMost,
          NumberComparator.between => _GoalMode.between,
        };
        _goalValue.text = _num(value);
        _goalUpper.text = _num(upper);
      case TimeGoal(:final comparator, :final minutes, :final graceMinutes):
        _goalMode = comparator == TimeComparator.before
            ? _GoalMode.before
            : _GoalMode.after;
        _goalTime = minutes;
        _grace = graceMinutes;
    }
  }

  Tracker _defaults(TrackerType type) {
    final journey = ref.read(activeJourneyProvider).value;
    final count = ref.read(activeTrackersProvider).length;
    final icon = switch (type) {
      TrackerType.checkbox => 'check',
      TrackerType.singleChoice => 'flag',
      TrackerType.multiChoice => 'check',
      TrackerType.time => 'clock',
      TrackerType.duration => 'timer',
      TrackerType.counter => 'water',
      TrackerType.number => 'target',
      TrackerType.decimal => 'weight',
      TrackerType.rating => 'mood',
      TrackerType.text || TrackerType.longText => 'edit',
      TrackerType.image => 'camera',
      TrackerType.file => 'file',
    };
    return Tracker(
      id: 0,
      journeyId: journey?.id ?? 0,
      name: '',
      type: type,
      icon: icon,
      color: Palette.trackerColors[count % Palette.trackerColors.length],
      activeFrom: ref.read(todayProvider),
      config: switch (type) {
        TrackerType.singleChoice => const TrackerConfig(
          options: [
            ChoiceOption(id: 'a', label: 'Option A'),
            ChoiceOption(id: 'b', label: 'Option B', score: 0),
          ],
        ),
        TrackerType.decimal => const TrackerConfig(step: 0.1),
        TrackerType.checkbox => const TrackerConfig(
          yesLabel: 'Done',
          noLabel: 'Skipped',
        ),
        _ => const TrackerConfig(),
      },
      goal: switch (type) {
        TrackerType.checkbox => const BoolGoal(),
        TrackerType.singleChoice => const ChoiceScoreGoal(),
        _ => const LoggedGoal(),
      },
    );
  }

  List<double> _parseList(String s) => [
    for (final part in s.split(RegExp(r'[,\s]+'))) ?double.tryParse(part),
  ];

  double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Tracker _compose() {
    final t = _draft!;
    final type = t.type;
    var config = t.config.copyWith(
      unit: _unit.text.trim(),
      min: () => _parse(_min),
      max: () => _parse(_max),
      step: (_parse(_step) ?? 0) > 0
          ? _parse(_step)
          : (type == TrackerType.decimal ? 0.1 : 1),
      presets: _parseList(_presets.text),
      placeholder: _placeholder.text.trim(),
      yesLabel: _yes.text.trim().isEmpty ? 'Yes' : _yes.text.trim(),
      noLabel: _no.text.trim().isEmpty ? 'No' : _no.text.trim(),
      options: [
        for (final o in _options)
          if (o.label.text.trim().isNotEmpty) o.toOption(),
      ],
    );
    if (type == TrackerType.decimal) {
      final step = config.step.toString();
      final dot = step.indexOf('.');
      config = config.copyWith(
        decimals: dot < 0 || step.endsWith('.0')
            ? 1
            : (step.length - dot - 1).clamp(1, 3),
      );
    }
    final value = _parse(_goalValue) ?? 0;
    final goal = switch (_goalMode) {
      _GoalMode.logged => const LoggedGoal(),
      _GoalMode.yes => const BoolGoal(),
      _GoalMode.no => const BoolGoal(target: false),
      _GoalMode.choice => const ChoiceScoreGoal(),
      _GoalMode.atLeast => NumberGoal(
        comparator: NumberComparator.atLeast,
        value: value,
      ),
      _GoalMode.atMost => NumberGoal(
        comparator: NumberComparator.atMost,
        value: value,
      ),
      _GoalMode.between => NumberGoal(
        comparator: NumberComparator.between,
        value: value,
        upper: _parse(_goalUpper) ?? value,
      ),
      _GoalMode.before => TimeGoal(
        comparator: TimeComparator.before,
        minutes: _goalTime,
        graceMinutes: _grace,
      ),
      _GoalMode.after => TimeGoal(
        comparator: TimeComparator.after,
        minutes: _goalTime,
        graceMinutes: _grace,
      ),
    };
    return t.copyWith(
      name: _name.text.trim(),
      description: _desc.text.trim(),
      config: config,
      goal: goal,
    );
  }

  void _update(Tracker Function(Tracker) f) =>
      setState(() => _draft = f(_draft!));

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final t = _compose();
    if (t.type == TrackerType.singleChoice && t.config.options.length < 2) {
      showSnack(context, 'Add at least two options.');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(trackerRepositoryProvider);
    if (_isNew) {
      final journey = ref.read(activeJourneyProvider).value!;
      final today = ref.read(todayProvider);
      final from = trackerStartDay(
        today: today,
        journeyStart: journey.startDay,
        fromStart: _countFromStart,
      );
      await repo.insert(t.copyWith(journeyId: journey.id, activeFrom: from));
    } else {
      await repo.update(t);
    }
    if (t.reminderEnabled) {
      await ref.read(notificationServiceProvider).requestPermission();
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    final ok = await confirm(
      context,
      title: 'Archive “${_draft!.name}”?',
      message: 'It stops counting from today. Your history stays and you can restore it any time.',
      confirmLabel: 'Archive',
    );
    if (!ok || !mounted) return;
    await ref
        .read(trackerRepositoryProvider)
        .archive(_draft!.id, ref.read(todayProvider));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete “${_draft!.name}”?',
      message:
          'This permanently deletes the tracker and its $_entryCount logged entries. '
          'Consider archiving instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(trackerRepositoryProvider).delete(_draft!.id);
    if (mounted) Navigator.of(context).pop();
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _draft;
    if (draft == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_isNew ? 'New tracker' : 'Edit tracker')),
        body: _isNew
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'What kind of input?',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You can track anything. Pick how you want to log it.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TypePickerGrid(
                    selected: null,
                    onSelected: (t) => setState(() => _load(_defaults(t))),
                  ),
                ],
              )
            : const Center(child: Text('Tracker not found')),
      );
    }

    final journey = ref.watch(activeJourneyProvider).value;
    final today = ref.watch(todayProvider);
    final use24h = ref.watch(settingsValueProvider.select((s) => s.use24h));
    final sections = {
      for (final t in ref.watch(activeTrackersProvider))
        if (t.section.isNotEmpty) t.section,
      if (draft.section.isNotEmpty) draft.section,
    }.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New tracker' : 'Edit tracker'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(72, 40)),
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
          children: [
            // Preview / identity
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Change icon',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () async {
                          final key = await showIconPicker(
                            context,
                            current: draft.icon,
                            color: Color(draft.color),
                          );
                          if (key != null) {
                            _update((t) => t.copyWith(icon: key));
                          }
                        },
                        child: Stack(
                          children: [
                            TrackerAvatar(tracker: draft, size: 60),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: theme.colorScheme.surface,
                                child: const Icon(Icons.edit_rounded, size: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                draft.type.icon,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  draft.type.label,
                                  style: theme.textTheme.labelLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isNew || _entryCount == 0) ...[
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _draft = null),
                                  child: const Text('Change type'),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            draft.type.description,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Fajr, Water, Wake-up time',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Give it a name' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description or reminder text (optional)',
              ),
            ),
            const SizedBox(height: 16),
            Text('Colour', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ColorSwatches(
              selected: draft.color,
              onSelected: (c) => _update((t) => t.copyWith(color: c)),
            ),

            const SectionHeader(
              'When',
              padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Planned time'),
              subtitle: Text(
                draft.anchorMinutes == null
                    ? 'Not set — shown at the end of the day'
                    : Clock.format(draft.anchorMinutes!, use24h: use24h),
              ),
              trailing: draft.anchorMinutes == null
                  ? null
                  : IconButton(
                      tooltip: 'Clear time',
                      onPressed: () =>
                          _update((t) => t.copyWith(anchorMinutes: () => null)),
                      icon: const Icon(Icons.close_rounded),
                    ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: Clock.toTimeOfDay(draft.anchorMinutes ?? 9 * 60),
                );
                if (picked != null) {
                  _update(
                    (t) => t.copyWith(
                      anchorMinutes: () => Clock.fromTimeOfDay(picked),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            Text('Section', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: draft.section.isEmpty,
                  onSelected: (_) => _update((t) => t.copyWith(section: '')),
                ),
                for (final s in sections)
                  ChoiceChip(
                    label: Text(s),
                    selected: draft.section == s,
                    onSelected: (_) => _update((t) => t.copyWith(section: s)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New'),
                  onPressed: () async {
                    final s = await _promptText(
                      context,
                      'New section',
                      'e.g. Morning, Salah, Work',
                    );
                    if (s != null && s.isNotEmpty) {
                      _update((t) => t.copyWith(section: s));
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Repeat on', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            WeekdayPicker(
              mask: draft.weekdays,
              onChanged: (m) => _update((t) => t.copyWith(weekdays: m)),
            ),
            if (_isNew && journey != null && today.isAfter(journey.startDay))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Count from the journey start'),
                subtitle: const Text(
                  'Off: starts counting today. On: earlier days count too (you can back-fill them).',
                ),
                value: _countFromStart,
                onChanged: (v) => setState(() => _countFromStart = v),
              ),

            SectionHeader(
              '${draft.type.label} setup',
              padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
            ),
            ..._typeSetup(draft, theme),

            const SectionHeader(
              'Goal',
              padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
            ),
            ..._goalEditor(draft, theme, use24h),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Counts towards the daily score'),
              subtitle: const Text('Turn off for optional, log-only trackers.'),
              value: draft.isRequired,
              onChanged: (v) => _update((t) => t.copyWith(isRequired: v)),
            ),

            const SectionHeader(
              'Reminder',
              padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Remind me'),
              subtitle: Text(
                draft.reminderEnabled
                    ? 'At ${Clock.format(draft.reminderMinutes ?? draft.anchorMinutes ?? 9 * 60, use24h: use24h)} '
                          'on scheduled days'
                    : 'Off',
              ),
              value: draft.reminderEnabled,
              onChanged: (v) => _update(
                (t) => t.copyWith(
                  reminderEnabled: v,
                  reminderMinutes: () =>
                      t.reminderMinutes ?? t.anchorMinutes ?? 9 * 60,
                ),
              ),
            ),
            if (draft.reminderEnabled)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('Change reminder time'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: Clock.toTimeOfDay(
                        draft.reminderMinutes ?? draft.anchorMinutes ?? 9 * 60,
                      ),
                    );
                    if (picked != null) {
                      _update(
                        (t) => t.copyWith(
                          reminderMinutes: () => Clock.fromTimeOfDay(picked),
                        ),
                      );
                    }
                  },
                ),
              ),

            if (!_isNew) ...[
              const SectionHeader(
                'Danger zone',
                padding: EdgeInsets.fromLTRB(0, 32, 0, 8),
              ),
              if (!draft.isArchived)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('Archive'),
                  subtitle: const Text(
                    'Stop tracking from today, keep history',
                  ),
                  onTap: _archive,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                subtitle: Text('Removes the tracker and $_entryCount entries'),
                onTap: _delete,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _typeSetup(Tracker draft, ThemeData theme) {
    final c = draft.config;
    Widget field(
      TextEditingController ctrl,
      String label, {
      bool number = false,
      String? hint,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
    Widget row(List<Widget> children) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, w) in children.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: w),
        ],
      ],
    );

    switch (draft.type) {
      case TrackerType.checkbox:
        return [
          row([
            field(_yes, '“Yes” label', hint: 'Prayed, Done…'),
            field(_no, '“No” label', hint: 'Missed, Skipped…'),
          ]),
        ];
      case TrackerType.singleChoice || TrackerType.multiChoice:
        final single = draft.type == TrackerType.singleChoice;
        return [
          if (single)
            Text(
              'Each option earns credit towards the daily score — e.g. '
              '“In congregation” 100%, “Late” 50%, “Missed” 0%.',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => setState(() {
              _options.insert(to, _options.removeAt(from));
            }),
            children: [
              for (final (i, o) in _options.indexed)
                Card(
                  key: ObjectKey(o),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_indicator_rounded),
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: TextField(
                                controller: o.emoji,
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  hintText: '🙂',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: o.label,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Option ${i + 1}',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove option',
                              onPressed: () => setState(
                                () => _options.removeAt(i).dispose(),
                              ),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        if (single)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: SegmentedButton<double>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(value: 0, label: Text('0%')),
                                ButtonSegment(value: 0.25, label: Text('25%')),
                                ButtonSegment(value: 0.5, label: Text('50%')),
                                ButtonSegment(value: 0.75, label: Text('75%')),
                                ButtonSegment(value: 1, label: Text('100%')),
                              ],
                              selected: {o.score},
                              onSelectionChanged: (s) =>
                                  setState(() => o.score = s.first),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _options.add(
                  _OptionDraft(
                    id: 'o${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
                  ),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add option'),
            ),
          ),
          if (!single)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow adding options while logging'),
              value: c.allowCustomOptions,
              onChanged: (v) => _update(
                (t) => t.copyWith(
                  config: t.config.copyWith(allowCustomOptions: v),
                ),
              ),
            ),
        ];
      case TrackerType.number || TrackerType.decimal:
        return [
          row([
            field(_unit, 'Unit', hint: 'kg, steps, km'),
            field(
              _step,
              'Step',
              number: true,
              hint: draft.type == TrackerType.decimal ? '0.1' : '1',
            ),
          ]),
          row([
            field(_min, 'Minimum (optional)', number: true),
            field(_max, 'Maximum (optional)', number: true),
          ]),
          field(
            _presets,
            'Quick-pick values (optional)',
            hint: 'e.g. 5000, 8000, 10000',
          ),
          SegmentedButton<NumberInputStyle>(
            segments: const [
              ButtonSegment(
                value: NumberInputStyle.stepper,
                label: Text('Stepper'),
                icon: Icon(Icons.exposure_rounded),
              ),
              ButtonSegment(
                value: NumberInputStyle.slider,
                label: Text('Slider'),
                icon: Icon(Icons.linear_scale_rounded),
              ),
            ],
            selected: {c.inputStyle},
            onSelectionChanged: (s) => _update(
              (t) => t.copyWith(config: t.config.copyWith(inputStyle: s.first)),
            ),
          ),
          if (c.inputStyle == NumberInputStyle.slider)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'The slider needs a minimum and a maximum.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ];
      case TrackerType.time:
        return [
          Text(
            'Nothing to set up — log with one tap on “Now” or scroll the wheel. '
            'Set a target time under Goal.',
            style: theme.textTheme.bodySmall,
          ),
        ];
      case TrackerType.counter:
        return [
          row([
            field(_unit, 'Unit', hint: 'glasses, pages'),
            field(_step, 'Each tap adds', number: true, hint: '1'),
          ]),
        ];
      case TrackerType.duration:
        return [
          field(
            _presets,
            'Quick-pick minutes (optional)',
            hint: 'e.g. 30, 45, 60, 90',
          ),
        ];
      case TrackerType.rating:
        return [
          SegmentedButton<RatingStyle>(
            segments: const [
              ButtonSegment(value: RatingStyle.stars, label: Text('Stars')),
              ButtonSegment(value: RatingStyle.emoji, label: Text('Emoji')),
              ButtonSegment(value: RatingStyle.scale, label: Text('1–10')),
            ],
            selected: {c.ratingStyle},
            onSelectionChanged: (s) => _update(
              (t) => t.copyWith(
                config: t.config.copyWith(
                  ratingStyle: s.first,
                  ratingMax: switch (s.first) {
                    RatingStyle.emoji => 5,
                    RatingStyle.scale => 10,
                    RatingStyle.stars => 5,
                  },
                ),
              ),
            ),
          ),
          if (c.ratingStyle != RatingStyle.emoji) ...[
            const SizedBox(height: 12),
            Text('Maximum: ${c.ratingMax}', style: theme.textTheme.labelLarge),
            Slider(
              value: c.ratingMax.toDouble(),
              min: 3,
              max: 10,
              divisions: 7,
              label: '${c.ratingMax}',
              onChanged: (v) => _update(
                (t) =>
                    t.copyWith(config: t.config.copyWith(ratingMax: v.round())),
              ),
            ),
          ],
        ];
      case TrackerType.text || TrackerType.longText:
        return [
          field(
            _placeholder,
            'Placeholder (optional)',
            hint: 'Oats, eggs, dates…',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Suggest items from history'),
            subtitle: const Text(
              'Shows tap-to-add chips of things you logged before.',
            ),
            value: c.suggestFromHistory,
            onChanged: (v) => _update(
              (t) =>
                  t.copyWith(config: t.config.copyWith(suggestFromHistory: v)),
            ),
          ),
        ];
      case TrackerType.image || TrackerType.file:
        return [
          Text(
            'Up to ${c.maxAttachments} per day',
            style: theme.textTheme.labelLarge,
          ),
          Slider(
            value: c.maxAttachments.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '${c.maxAttachments}',
            onChanged: (v) => _update(
              (t) => t.copyWith(
                config: t.config.copyWith(maxAttachments: v.round()),
              ),
            ),
          ),
        ];
    }
  }

  List<Widget> _goalEditor(Tracker draft, ThemeData theme, bool use24h) {
    final type = draft.type;
    Widget chips(List<(_GoalMode, String)> modes) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (m, label) in modes)
          ChoiceChip(
            label: Text(label),
            selected: _goalMode == m,
            onSelected: (_) => setState(() => _goalMode = m),
          ),
      ],
    );

    switch (type) {
      case TrackerType.checkbox:
        return [
          chips([
            (
              _GoalMode.yes,
              '“${_yes.text.isEmpty ? 'Yes' : _yes.text}” is the win',
            ),
            (
              _GoalMode.no,
              '“${_no.text.isEmpty ? 'No' : _no.text}” is the win (quitting)',
            ),
          ]),
        ];
      case TrackerType.singleChoice:
        return [
          Text(
            'Success comes from the credit of the picked option (set above).',
            style: theme.textTheme.bodySmall,
          ),
        ];
      case TrackerType.time:
        return [
          chips([
            (_GoalMode.logged, 'Just log it'),
            (_GoalMode.before, 'Before…'),
            (_GoalMode.after, 'After…'),
          ]),
          if (_goalMode == _GoalMode.before ||
              _goalMode == _GoalMode.after) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_rounded),
              title: Text(
                '${_goalMode == _GoalMode.before ? 'Before' : 'After'} '
                '${Clock.format(_goalTime, use24h: use24h)}',
              ),
              subtitle: const Text('Tap to change'),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: Clock.toTimeOfDay(_goalTime),
                );
                if (picked != null) {
                  setState(() => _goalTime = Clock.fromTimeOfDay(picked));
                }
              },
            ),
            Text(
              'Grace window (half credit)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final g in const [0, 10, 15, 30, 60])
                  ChoiceChip(
                    label: Text(g == 0 ? 'None' : '${g}m'),
                    selected: _grace == g,
                    onSelected: (_) => setState(() => _grace = g),
                  ),
              ],
            ),
          ],
        ];
      case TrackerType.number ||
          TrackerType.decimal ||
          TrackerType.counter ||
          TrackerType.rating ||
          TrackerType.duration ||
          TrackerType.multiChoice:
        final unit = switch (type) {
          TrackerType.duration => 'minutes',
          TrackerType.multiChoice => 'selected',
          TrackerType.rating => 'of ${draft.config.ratingMax}',
          _ => _unit.text,
        };
        return [
          chips([
            (_GoalMode.logged, 'Just log it'),
            (_GoalMode.atLeast, 'At least'),
            (_GoalMode.atMost, 'At most'),
            (_GoalMode.between, 'Between'),
          ]),
          if (_goalMode
              case _GoalMode.atLeast ||
                  _GoalMode.atMost ||
                  _GoalMode.between) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _goalValue,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _goalMode == _GoalMode.between
                          ? 'From'
                          : 'Target',
                      suffixText: unit,
                    ),
                    validator: (v) =>
                        double.tryParse((v ?? '').replaceAll(',', '.')) == null
                        ? 'Enter a number'
                        : null,
                  ),
                ),
                if (_goalMode == _GoalMode.between) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _goalUpper,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'To',
                        suffixText: unit,
                      ),
                      validator: (v) =>
                          double.tryParse((v ?? '').replaceAll(',', '.')) ==
                              null
                          ? 'Enter a number'
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            if (_goalMode == _GoalMode.atLeast)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Partial credit is earned on the way (e.g. 6 of 8 = 75%).',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ];
      case TrackerType.text ||
          TrackerType.longText ||
          TrackerType.image ||
          TrackerType.file:
        return [
          Text(
            'Logging anything counts as done.',
            style: theme.textTheme.bodyMedium,
          ),
        ];
    }
  }
}

Future<String?> _promptText(
  BuildContext context,
  String title,
  String hint,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// First day a newly created tracker counts on.
Day trackerStartDay({
  required Day today,
  required Day journeyStart,
  required bool fromStart,
}) => fromStart || today.isBefore(journeyStart) ? journeyStart : today;
