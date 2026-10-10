import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// A file stored inside the app's private attachment directory.
@immutable
class Attachment {
  const Attachment({
    required this.relativePath,
    required this.name,
    required this.sizeBytes,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
    relativePath: json['path'] as String,
    name: json['name'] as String? ?? '',
    sizeBytes: json['size'] as int? ?? 0,
  );

  /// Path relative to the attachment root. Absolute paths are never stored:
  /// on iOS the app container path changes between installs/updates.
  final String relativePath;
  final String name;
  final int sizeBytes;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  Map<String, dynamic> toJson() => {
    'path': relativePath,
    'name': name,
    'size': sizeBytes,
  };

  @override
  bool operator ==(Object other) =>
      other is Attachment &&
      other.relativePath == relativePath &&
      other.name == name &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode => Object.hash(relativePath, name, sizeBytes);
}

/// The typed value of one day's entry. Serialised as `{"t": tag, "v": …}`.
@immutable
sealed class TrackerValue {
  const TrackerValue();

  static TrackerValue? fromJson(Map<String, dynamic> json) {
    final v = json['v'];
    return switch (json['t']) {
      'bool' => BoolValue(v as bool),
      'time' => TimeValue(v as int),
      'num' => NumberValue((v as num).toDouble()),
      'dur' => DurationValue(v as int),
      'choice' => ChoiceValue(v as String),
      'multi' => MultiChoiceValue([
        for (final e in v as List<dynamic>) e as String,
      ]),
      'text' => TextValue(v as String),
      'files' => AttachmentsValue([
        for (final e in v as List<dynamic>)
          Attachment.fromJson(e as Map<String, dynamic>),
      ]),
      _ => null,
    };
  }

  Map<String, dynamic> toJson();

  /// An empty value is treated as "not logged".
  bool get isEmpty;
}

final class BoolValue extends TrackerValue {
  const BoolValue(this.value);
  final bool value;
  @override
  bool get isEmpty => false;
  @override
  Map<String, dynamic> toJson() => {'t': 'bool', 'v': value};
  @override
  bool operator ==(Object other) => other is BoolValue && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Minutes since midnight.
final class TimeValue extends TrackerValue {
  const TimeValue(this.minutes);
  final int minutes;
  @override
  bool get isEmpty => false;
  @override
  Map<String, dynamic> toJson() => {'t': 'time', 'v': minutes};
  @override
  bool operator ==(Object other) =>
      other is TimeValue && other.minutes == minutes;
  @override
  int get hashCode => minutes.hashCode;
}

/// Number, decimal, counter and rating values.
final class NumberValue extends TrackerValue {
  const NumberValue(this.value);
  final double value;
  @override
  bool get isEmpty => false;
  @override
  Map<String, dynamic> toJson() => {'t': 'num', 'v': value};
  @override
  bool operator ==(Object other) =>
      other is NumberValue && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

/// Duration in whole minutes.
final class DurationValue extends TrackerValue {
  const DurationValue(this.minutes);
  final int minutes;
  @override
  bool get isEmpty => false;
  @override
  Map<String, dynamic> toJson() => {'t': 'dur', 'v': minutes};
  @override
  bool operator ==(Object other) =>
      other is DurationValue && other.minutes == minutes;
  @override
  int get hashCode => minutes.hashCode;
}

final class ChoiceValue extends TrackerValue {
  const ChoiceValue(this.optionId);
  final String optionId;
  @override
  bool get isEmpty => optionId.isEmpty;
  @override
  Map<String, dynamic> toJson() => {'t': 'choice', 'v': optionId};
  @override
  bool operator ==(Object other) =>
      other is ChoiceValue && other.optionId == optionId;
  @override
  int get hashCode => optionId.hashCode;
}

final class MultiChoiceValue extends TrackerValue {
  const MultiChoiceValue(this.optionIds);
  final List<String> optionIds;
  @override
  bool get isEmpty => optionIds.isEmpty;
  @override
  Map<String, dynamic> toJson() => {'t': 'multi', 'v': optionIds};
  @override
  bool operator ==(Object other) =>
      other is MultiChoiceValue &&
      const ListEquality<String>().equals(other.optionIds, optionIds);
  @override
  int get hashCode => const ListEquality<String>().hash(optionIds);
}

final class TextValue extends TrackerValue {
  const TextValue(this.text);
  final String text;
  @override
  bool get isEmpty => text.trim().isEmpty;
  @override
  Map<String, dynamic> toJson() => {'t': 'text', 'v': text};
  @override
  bool operator ==(Object other) => other is TextValue && other.text == text;
  @override
  int get hashCode => text.hashCode;
}

final class AttachmentsValue extends TrackerValue {
  const AttachmentsValue(this.files);
  final List<Attachment> files;
  @override
  bool get isEmpty => files.isEmpty;
  @override
  Map<String, dynamic> toJson() => {
    't': 'files',
    'v': [for (final f in files) f.toJson()],
  };
  @override
  bool operator ==(Object other) =>
      other is AttachmentsValue &&
      const ListEquality<Attachment>().equals(other.files, files);
  @override
  int get hashCode => const ListEquality<Attachment>().hash(files);
}
