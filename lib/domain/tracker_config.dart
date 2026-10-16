import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// One selectable option of a choice tracker.
@immutable
class ChoiceOption {
  const ChoiceOption({
    required this.id,
    required this.label,
    this.emoji = '',
    this.score = 1,
  });

  factory ChoiceOption.fromJson(Map<String, dynamic> json) => ChoiceOption(
    id: json['id'] as String,
    label: json['label'] as String,
    emoji: json['emoji'] as String? ?? '',
    score: (json['score'] as num?)?.toDouble() ?? 1,
  );

  /// Stable identifier; values reference options by id so renaming a label
  /// never breaks history.
  final String id;
  final String label;
  final String emoji;

  /// Credit (0–1) earned towards the daily score when this option is picked.
  final double score;

  String get display => emoji.isEmpty ? label : '$emoji  $label';

  ChoiceOption copyWith({String? label, String? emoji, double? score}) =>
      ChoiceOption(
        id: id,
        label: label ?? this.label,
        emoji: emoji ?? this.emoji,
        score: score ?? this.score,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (emoji.isNotEmpty) 'emoji': emoji,
    'score': score,
  };

  @override
  bool operator ==(Object other) =>
      other is ChoiceOption &&
      other.id == id &&
      other.label == label &&
      other.emoji == emoji &&
      other.score == score;

  @override
  int get hashCode => Object.hash(id, label, emoji, score);
}

/// Changes a choice tracker on days when another choice tracker has a given
/// answer — e.g. on office days (no masjid) the congregation button is
/// hidden from the one-tap row and "On time" earns full marks.
@immutable
class DayRule {
  const DayRule({
    this.whenTrackerId = 0,
    this.whenRef = '',
    required this.whenOptionId,
    this.label = '',
    this.hideOptionIds = const [],
    this.credits = const {},
  });

  factory DayRule.fromJson(Map<String, dynamic> json) => DayRule(
    whenTrackerId: (json['when'] as num?)?.toInt() ?? 0,
    whenOptionId: json['is'] as String? ?? '',
    label: json['label'] as String? ?? '',
    hideOptionIds: [
      for (final id in json['hide'] as List<dynamic>? ?? const []) '$id',
    ],
    credits: {
      for (final e
          in (json['credits'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: (e.value as num).toDouble().clamp(0, 1).toDouble(),
    },
  );

  /// The tracker whose answer switches the rule on (0 until resolved).
  final int whenTrackerId;

  /// In templates: the template ref of that tracker, resolved to
  /// [whenTrackerId] when a journey is created. Never stored.
  final String whenRef;

  /// The answer of that tracker that switches the rule on.
  final String whenOptionId;

  /// Shown on the tracker on those days, e.g. "Office day — no masjid".
  final String label;

  /// Options left out of the one-tap row (still available in the sheet).
  final List<String> hideOptionIds;

  /// Option id → credit (0–1) on those days, instead of the option's own.
  final Map<String, double> credits;

  bool get isResolved => whenTrackerId > 0;

  // [whenRef] is a template-time detail and not part of a rule's identity.

  DayRule copyWith({
    int? whenTrackerId,
    String? whenOptionId,
    String? label,
    List<String>? hideOptionIds,
    Map<String, double>? credits,
  }) => DayRule(
    whenTrackerId: whenTrackerId ?? this.whenTrackerId,
    whenRef: whenRef,
    whenOptionId: whenOptionId ?? this.whenOptionId,
    label: label ?? this.label,
    hideOptionIds: hideOptionIds ?? this.hideOptionIds,
    credits: credits ?? this.credits,
  );

  Map<String, dynamic> toJson() => {
    'when': whenTrackerId,
    'is': whenOptionId,
    if (label.isNotEmpty) 'label': label,
    if (hideOptionIds.isNotEmpty) 'hide': hideOptionIds,
    if (credits.isNotEmpty) 'credits': credits,
  };

  @override
  bool operator ==(Object other) =>
      other is DayRule &&
      other.whenTrackerId == whenTrackerId &&
      other.whenOptionId == whenOptionId &&
      other.label == label &&
      const ListEquality<String>().equals(other.hideOptionIds, hideOptionIds) &&
      const MapEquality<String, double>().equals(other.credits, credits);

  @override
  int get hashCode => Object.hash(
    whenTrackerId,
    whenOptionId,
    label,
    const ListEquality<String>().hash(hideOptionIds),
    const MapEquality<String, double>().hash(credits),
  );
}

enum NumberInputStyle { stepper, slider }

enum RatingStyle { stars, emoji, scale }

/// Type-specific setup of a tracker. A single flexible, JSON-friendly class:
/// each [TrackerType] reads only the fields that apply to it.
@immutable
class TrackerConfig {
  const TrackerConfig({
    this.unit = '',
    this.min,
    this.max,
    this.step = 1,
    this.decimals = 1,
    this.inputStyle = NumberInputStyle.stepper,
    this.presets = const [],
    this.ratingMax = 5,
    this.ratingStyle = RatingStyle.stars,
    this.options = const [],
    this.allowCustomOptions = true,
    this.suggestFromHistory = true,
    this.placeholder = '',
    this.yesLabel = 'Yes',
    this.noLabel = 'No',
    this.maxAttachments = 4,
    this.dayRule,
    this.notePrompt = '',
    this.noteIsInfoOnly = false,
  });

  factory TrackerConfig.fromJson(Map<String, dynamic> json) => TrackerConfig(
    unit: json['unit'] as String? ?? '',
    min: (json['min'] as num?)?.toDouble(),
    max: (json['max'] as num?)?.toDouble(),
    step: (json['step'] as num?)?.toDouble() ?? 1,
    decimals: json['decimals'] as int? ?? 1,
    inputStyle: NumberInputStyle.values.firstWhere(
      (s) => s.name == json['inputStyle'],
      orElse: () => NumberInputStyle.stepper,
    ),
    presets: [
      for (final p in (json['presets'] as List<dynamic>? ?? const []))
        (p as num).toDouble(),
    ],
    ratingMax: json['ratingMax'] as int? ?? 5,
    ratingStyle: RatingStyle.values.firstWhere(
      (s) => s.name == json['ratingStyle'],
      orElse: () => RatingStyle.stars,
    ),
    options: [
      for (final o in (json['options'] as List<dynamic>? ?? const []))
        ChoiceOption.fromJson(o as Map<String, dynamic>),
    ],
    allowCustomOptions: json['allowCustomOptions'] as bool? ?? true,
    suggestFromHistory: json['suggestFromHistory'] as bool? ?? true,
    placeholder: json['placeholder'] as String? ?? '',
    yesLabel: json['yesLabel'] as String? ?? 'Yes',
    noLabel: json['noLabel'] as String? ?? 'No',
    maxAttachments: json['maxAttachments'] as int? ?? 4,
    dayRule: json['dayRule'] is Map<String, dynamic>
        ? DayRule.fromJson(json['dayRule'] as Map<String, dynamic>)
        : null,
    notePrompt: json['notePrompt'] as String? ?? '',
    noteIsInfoOnly: json['noteInfoOnly'] as bool? ?? false,
  );

  /// Unit suffix for numeric types (kg, km, glasses…).
  final String unit;
  final double? min;
  final double? max;
  final double step;

  /// Display precision for [TrackerType.decimal].
  final int decimals;
  final NumberInputStyle inputStyle;

  /// Quick-pick chips (numbers, or minutes for durations).
  final List<double> presets;

  final int ratingMax;
  final RatingStyle ratingStyle;

  final List<ChoiceOption> options;
  final bool allowCustomOptions;

  /// Offer previously typed items as tap-to-add chips.
  final bool suggestFromHistory;
  final String placeholder;

  final String yesLabel;
  final String noLabel;

  final int maxAttachments;

  /// Choice trackers: how they change on certain days (see [DayRule]).
  final DayRule? dayRule;

  /// When set, the entry sheet opens with a comment box asking this
  /// (e.g. "What did you train?"), and the timeline shows the comment.
  final String notePrompt;

  /// The comment is information only: writing it without picking an answer
  /// earns nothing (meals: only eating on time counts). When false, a
  /// comment on its own counts as the winning answer ("What did you
  /// train?" answered means you trained).
  final bool noteIsInfoOnly;

  ChoiceOption? optionById(String id) =>
      options.firstWhereOrNull((o) => o.id == id);

  TrackerConfig copyWith({
    String? unit,
    double? Function()? min,
    double? Function()? max,
    double? step,
    int? decimals,
    NumberInputStyle? inputStyle,
    List<double>? presets,
    int? ratingMax,
    RatingStyle? ratingStyle,
    List<ChoiceOption>? options,
    bool? allowCustomOptions,
    bool? suggestFromHistory,
    String? placeholder,
    String? yesLabel,
    String? noLabel,
    int? maxAttachments,
    DayRule? Function()? dayRule,
    String? notePrompt,
    bool? noteIsInfoOnly,
  }) => TrackerConfig(
    unit: unit ?? this.unit,
    min: min != null ? min() : this.min,
    max: max != null ? max() : this.max,
    step: step ?? this.step,
    decimals: decimals ?? this.decimals,
    inputStyle: inputStyle ?? this.inputStyle,
    presets: presets ?? this.presets,
    ratingMax: ratingMax ?? this.ratingMax,
    ratingStyle: ratingStyle ?? this.ratingStyle,
    options: options ?? this.options,
    allowCustomOptions: allowCustomOptions ?? this.allowCustomOptions,
    suggestFromHistory: suggestFromHistory ?? this.suggestFromHistory,
    placeholder: placeholder ?? this.placeholder,
    yesLabel: yesLabel ?? this.yesLabel,
    noLabel: noLabel ?? this.noLabel,
    maxAttachments: maxAttachments ?? this.maxAttachments,
    dayRule: dayRule != null ? dayRule() : this.dayRule,
    notePrompt: notePrompt ?? this.notePrompt,
    noteIsInfoOnly: noteIsInfoOnly ?? this.noteIsInfoOnly,
  );

  Map<String, dynamic> toJson() => {
    if (unit.isNotEmpty) 'unit': unit,
    'min': ?min,
    'max': ?max,
    'step': step,
    'decimals': decimals,
    'inputStyle': inputStyle.name,
    if (presets.isNotEmpty) 'presets': presets,
    'ratingMax': ratingMax,
    'ratingStyle': ratingStyle.name,
    if (options.isNotEmpty) 'options': [for (final o in options) o.toJson()],
    'allowCustomOptions': allowCustomOptions,
    'suggestFromHistory': suggestFromHistory,
    if (placeholder.isNotEmpty) 'placeholder': placeholder,
    'yesLabel': yesLabel,
    'noLabel': noLabel,
    'maxAttachments': maxAttachments,
    if (dayRule case final rule? when rule.isResolved) 'dayRule': rule.toJson(),
    if (notePrompt.isNotEmpty) 'notePrompt': notePrompt,
    if (noteIsInfoOnly) 'noteInfoOnly': true,
  };

  @override
  bool operator ==(Object other) =>
      other is TrackerConfig &&
      const DeepCollectionEquality().equals(other.toJson(), toJson());

  @override
  int get hashCode => const DeepCollectionEquality().hash(toJson());
}
