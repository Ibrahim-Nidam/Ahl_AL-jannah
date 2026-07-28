enum QuranBookmarkType { page, ayah }

/// A saved reading position in the Quran — either a full-page bookmark or
/// a specific-ayah bookmark, both explicitly created by the user.
///
/// [readingMode] and [scrollOffset] are optional, additive fields used to
/// restore the reading experience (not just the position) more precisely.
/// Both are nullable and default to `null` when absent from persisted
/// JSON, so bookmarks saved before this feature existed keep deserializing
/// exactly as before — nothing about the existing bookmark list format
/// changes.
class QuranBookmark {
  final String id;
  final QuranBookmarkType type;
  final int surahId;
  final String surahName;
  final int page;
  final int? ayahNumber;
  final String previewText;
  final DateTime createdAt;

  /// 'mushaf' or 'study' — the reader mode active when this position was
  /// saved. Null for bookmarks created before this field existed, or when
  /// not meaningful.
  final String? readingMode;

  /// Landscape infinite-scroll pixel offset at save time. Only ever set
  /// for the auto-saved "last position" entry (see
  /// `QuranBookmarkStorage.saveLastPosition`); manual bookmarks rely on
  /// their page/ayah anchor instead, which is already exact.
  final double? scrollOffset;

  const QuranBookmark({
    required this.id,
    required this.type,
    required this.surahId,
    required this.surahName,
    required this.page,
    required this.previewText,
    required this.createdAt,
    this.ayahNumber,
    this.readingMode,
    this.scrollOffset,
  });

  bool get isPageBookmark => type == QuranBookmarkType.page;
  bool get isAyahBookmark => type == QuranBookmarkType.ayah;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'surahId': surahId,
      'surahName': surahName,
      'page': page,
      'ayahNumber': ayahNumber,
      'previewText': previewText,
      'createdAt': createdAt.toIso8601String(),
      'readingMode': readingMode,
      'scrollOffset': scrollOffset,
    };
  }

  factory QuranBookmark.fromJson(Map<String, dynamic> json) {
    return QuranBookmark(
      id: json['id'] as String,
      type: QuranBookmarkType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => QuranBookmarkType.page,
      ),
      surahId: json['surahId'] as int,
      surahName: json['surahName'] as String? ?? '',
      page: json['page'] as int,
      ayahNumber: json['ayahNumber'] as int?,
      previewText: json['previewText'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readingMode: json['readingMode'] as String?,
      scrollOffset: (json['scrollOffset'] as num?)?.toDouble(),
    );
  }
}