import '../../domain/entities/hadith_entities.dart';

class HadithModel extends HadithEntity {
  const HadithModel({
    required super.collectionId,
    required super.number,
    required super.text,
    super.arabicNumber,
    super.book,
  });

  factory HadithModel.fromJson(Map<String, dynamic> json, String fallbackCollectionId) {
    return HadithModel(
      collectionId: json['collection'] as String? ?? fallbackCollectionId,
      number: _asInt(json['number']) ?? 0,
      arabicNumber: _asInt(json['arabic_number']),
      book: _asInt(json['book']),
      text: (json['text'] as String? ?? '').trim(),
    );
  }

  /// Builds a model from a map produced by [_parseItems] in the data source
  /// isolate helpers (keys already normalized to Dart field names).
  factory HadithModel.fromParsedMap(Map<String, dynamic> map) {
    return HadithModel(
      collectionId: map['collectionId'] as String,
      number: map['number'] as int,
      arabicNumber: map['arabicNumber'] as int?,
      book: map['book'] as int?,
      text: map['text'] as String,
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