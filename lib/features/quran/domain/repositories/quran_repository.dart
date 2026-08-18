import '../entities/quran_entities.dart';

abstract class QuranRepository {
  Future<List<SurahEntity>> getSurahs();
  Future<List<AyahEntity>> getAyahsBySurah(int surahId);
  Future<List<AyahEntity>> searchQuran(String query);
  Future<List<AyahEntity>> getAyahsByJuz(int juz);
  Future<List<AyahEntity>> getAyahsByPage(int page);

  /// Warsh riwaya (same 604-page structure as Hafs, different text).
  Future<List<AyahEntity>> getWarshAyahsByPage(int page);
  Future<List<AyahEntity>> getWarshAyahsBySurah(int surahId);
  Future<List<AyahEntity>> getWarshAyahsByJuz(int juz);

  /// Warsh per-surah ayah counts — these differ from Hafs in many surahs.
  Future<Map<int, int>> getWarshSurahAyahCounts();
}
