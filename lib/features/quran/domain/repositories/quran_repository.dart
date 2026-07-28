import '../entities/quran_entities.dart';

abstract class QuranRepository {
  Future<List<SurahEntity>> getSurahs();
  Future<List<AyahEntity>> getAyahsBySurah(int surahId);
  Future<List<AyahEntity>> searchQuran(String query);
  Future<List<AyahEntity>> getAyahsByJuz(int juz);
  Future<List<AyahEntity>> getAyahsByPage(int page);
}
