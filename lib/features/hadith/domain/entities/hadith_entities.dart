/// Metadata describing a single Hadith collection bundled as a JSON asset
/// under `assets/hadith/`. Any well-formed JSON file dropped into that
/// folder (matching this schema) is picked up automatically — no code
/// changes required. See [HadithLocalDataSourceImpl].
class HadithCollectionMeta {
  final String collectionId; // e.g. "bukhari", "qudsi"
  final String assetPath; // e.g. "assets/hadith/bukhari_ar.json"
  final String lang;
  final int count;
  final String displayTitle; // Latin/English display name
  final String displayTitleAr; // Arabic display name
  final String? attribution;
  final String? license;
  final String? licenseUrl;
  final String? sourceUrl;
  final String? sourceId;

  const HadithCollectionMeta({
    required this.collectionId,
    required this.assetPath,
    required this.lang,
    required this.count,
    required this.displayTitle,
    required this.displayTitleAr,
    this.attribution,
    this.license,
    this.licenseUrl,
    this.sourceUrl,
    this.sourceId,
  });

  /// Picks the display name matching [languageCode] ('ar' -> Arabic name).
  String titleFor(String languageCode) => languageCode == 'ar' ? displayTitleAr : displayTitle;
}

class HadithEntity {
  final String collectionId;
  final int number;
  final int? arabicNumber;
  final int? book;
  final String text;

  const HadithEntity({
    required this.collectionId,
    required this.number,
    required this.text,
    this.arabicNumber,
    this.book,
  });
}

/// A single search hit, carrying the source collection's display title in
/// both languages so global search results can show where each hadith
/// came from, translated to the active UI language.
class HadithSearchResult {
  final HadithEntity hadith;
  final String collectionTitle;
  final String collectionTitleAr;

  const HadithSearchResult({
    required this.hadith,
    required this.collectionTitle,
    required this.collectionTitleAr,
  });

  String titleFor(String languageCode) => languageCode == 'ar' ? collectionTitleAr : collectionTitle;
}