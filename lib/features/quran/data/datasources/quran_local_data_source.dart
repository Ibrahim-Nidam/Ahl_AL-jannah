import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'quran_database.dart';

abstract class QuranLocalDataSource {
  Future<List<Surah>> getSurahs();
  Future<List<Ayah>> getAyahsBySurah(int surahId);
  Future<List<Ayah>> searchQuran(String query);
  Future<List<Ayah>> getAyahsByJuz(int juz);
  Future<List<Ayah>> getAyahsByPage(int page);
}

@LazySingleton(as: QuranLocalDataSource)
class QuranLocalDataSourceImpl implements QuranLocalDataSource {
  final QuranDatabase _db;

  QuranLocalDataSourceImpl(this._db);

  @override
  Future<List<Surah>> getSurahs() async {
    return _db.select(_db.surahs).get();
  }

  @override
  Future<List<Ayah>> getAyahsBySurah(int surahId) async {
    return (_db.select(_db.ayahs)
          ..where((tbl) => tbl.surahId.equals(surahId))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.number)]))
        .get();
  }

  @override
  Future<List<Ayah>> searchQuran(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final queryLowerExpr = '%${normalizedQuery.toLowerCase()}%';
    
    // Normalize query for Arabic search
    final cleanQuery = _cleanArabicText(normalizedQuery);
    final arabicQueryExpr = '%$cleanQuery%';

    // 1. Get matching Surah IDs (also normalize Arabic name search!)
    final cleanSurahNameArExpr = CustomExpression<String>('remove_diacritics(name_ar)');
    
    final surahIdsQuery = _db.selectOnly(_db.surahs)
      ..addColumns([_db.surahs.id])
      ..where(cleanSurahNameArExpr.like(arabicQueryExpr) | _db.surahs.nameEn.like(queryLowerExpr));
    
    final rows = await surahIdsQuery.get();
    final surahIds = rows.map((row) => row.read(_db.surahs.id)).whereType<int>().toList();

    // 2. Select matching Ayahs using native SQL query
    final cleanTextArExpr = CustomExpression<String>('remove_diacritics(text_ar)');
    
    final ayahsQuery = _db.select(_db.ayahs)
      ..where((tbl) {
        var baseExpr = cleanTextArExpr.like(arabicQueryExpr) |
            tbl.translationEn.like(queryLowerExpr) |
            tbl.translationFr.like(queryLowerExpr);
        if (surahIds.isNotEmpty) {
          baseExpr = baseExpr | tbl.surahId.isIn(surahIds);
        }
        return baseExpr;
      });

    return ayahsQuery.get();
  }

  String _cleanArabicText(String text) {
    var normalized = text.replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640\u0653-\u0655\u06DF-\u06E8\u06EA-\u06EC]'), '');
    normalized = normalized.replaceAll(RegExp(r'[أإآٱ]'), 'ا');
    normalized = normalized.replaceAll('ة', 'ه');
    return normalized;
  }

  @override
  Future<List<Ayah>> getAyahsByJuz(int juz) async {
    return (_db.select(_db.ayahs)
          ..where((tbl) => tbl.juz.equals(juz))
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.surahId),
            (tbl) => OrderingTerm(expression: tbl.number),
          ]))
        .get();
  }

  @override
  Future<List<Ayah>> getAyahsByPage(int page) async {
    return (_db.select(_db.ayahs)
          ..where((tbl) => tbl.page.equals(page))
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.surahId),
            (tbl) => OrderingTerm(expression: tbl.number),
          ]))
        .get();
  }
}
