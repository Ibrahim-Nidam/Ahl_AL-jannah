/// A Hadith collection author (e.g. Sahih al-Bukhari). Bundled as a folder
/// under `assets/hadith/<authorId>/` containing an `_index.json` (book list)
/// plus one JSON file per book. See [HadithLocalDataSourceImpl].
class HadithAuthorMeta {
  final String id; // e.g. "bukhari", "muslim", "forty_nawawi", "forty_qudsi"
  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
  final int bookCount;
  final int hadithCount;

  const HadithAuthorMeta({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    required this.bookCount,
    required this.hadithCount,
  });

  /// Picks the display name matching [languageCode] ('ar' -> Arabic name).
  String titleFor(String languageCode) => languageCode == 'ar' ? titleAr : titleEn;

  String subtitleFor(String languageCode) => languageCode == 'ar' ? subtitleAr : subtitleEn;
}

/// A single book (chapter) within an author's collection.
class HadithBookMeta {
  final String authorId;
  final String id; // asset file stem, e.g. "001_revelation"
  final String titleEn; // e.g. "1 Revelation"
  final String titleAr; // e.g. "كتاب بدء الوحى"
  final int count;

  const HadithBookMeta({
    required this.authorId,
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.count,
  });

  /// Picks the display name matching [languageCode] ('ar' -> Arabic name).
  String titleFor(String languageCode) => languageCode == 'ar' ? titleAr : titleEn;
}

/// A single hadith with both its Arabic text and English translation.
class HadithItem {
  final String authorId;
  final int id;
  final String book;
  final String reference;
  final String grade;
  final String arabic;
  final String english;

  const HadithItem({
    required this.authorId,
    required this.id,
    required this.book,
    required this.reference,
    required this.grade,
    required this.arabic,
    required this.english,
  });
}

/// One match from the global "search everything" query, carrying enough
/// context to open the originating book.
class HadithSearchResult {
  final HadithAuthorMeta author;
  final HadithBookMeta book;
  final HadithItem item;

  const HadithSearchResult({
    required this.author,
    required this.book,
    required this.item,
  });
}
