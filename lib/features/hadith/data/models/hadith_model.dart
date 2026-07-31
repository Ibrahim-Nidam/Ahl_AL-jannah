import '../../domain/entities/hadith_entities.dart';

class HadithModel extends HadithItem {
  const HadithModel({
    required super.authorId,
    required super.id,
    required super.book,
    required super.reference,
    required super.grade,
    required super.arabic,
    required super.english,
  });

  factory HadithModel.fromJson(Map<String, dynamic> json, String fallbackAuthorId) {
    return HadithModel(
      authorId: json['collection'] as String? ?? fallbackAuthorId,
      id: _asInt(json['id']) ?? 0,
      book: (json['book'] as String? ?? '').trim(),
      reference: (json['reference'] as String? ?? '').trim(),
      grade: (json['grade'] as String? ?? '').trim(),
      arabic: (json['arabic'] as String? ?? '').trim(),
      english: (json['english'] as String? ?? '').trim(),
    );
  }

  /// Builds a model from a map produced by the isolate helpers in the data
  /// source (keys already normalized to Dart field names).
  factory HadithModel.fromParsedMap(Map<String, dynamic> map) {
    return HadithModel(
      authorId: map['authorId'] as String,
      id: map['id'] as int,
      book: map['book'] as String,
      reference: map['reference'] as String,
      grade: map['grade'] as String,
      arabic: map['arabic'] as String,
      english: map['english'] as String,
    );
  }

  /// Some source dumps encode integer fields as JSON floats (e.g. `1.0`),
  /// which `dart:convert` decodes as `double`. A plain `as int?` cast then
  /// throws "type 'double' is not a subtype of type 'int?'" — this coerces
  /// any numeric or numeric-string value into an int safely.
  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
