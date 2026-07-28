import 'package:injectable/injectable.dart';
import '../../domain/entities/quran_entities.dart';
import '../../domain/repositories/quran_repository.dart';
import '../datasources/quran_local_data_source.dart';

@LazySingleton(as: QuranRepository)
class QuranRepositoryImpl implements QuranRepository {
  final QuranLocalDataSource _localDataSource;

  QuranRepositoryImpl(this._localDataSource);

  @override
  Future<List<SurahEntity>> getSurahs() async {
    final surahs = await _localDataSource.getSurahs();
    return surahs
        .map((s) => SurahEntity(
              id: s.id,
              nameAr: s.nameAr,
              nameEn: s.nameEn,
              revelation: s.revelation,
              ayahCount: s.ayahCount,
            ))
        .toList();
  }

  @override
  Future<List<AyahEntity>> getAyahsBySurah(int surahId) async {
    final ayahs = await _localDataSource.getAyahsBySurah(surahId);
    return ayahs
        .map((a) => AyahEntity(
              id: a.id,
              surahId: a.surahId,
              number: a.number,
              textAr: a.textAr,
              translationEn: a.translationEn,
              translationFr: a.translationFr,
              juz: a.juz,
              page: a.page,
              hizb: a.hizb,
            ))
        .toList();
  }

  @override
  Future<List<AyahEntity>> searchQuran(String query) async {
    final ayahs = await _localDataSource.searchQuran(query);
    return ayahs
        .map((a) => AyahEntity(
              id: a.id,
              surahId: a.surahId,
              number: a.number,
              textAr: a.textAr,
              translationEn: a.translationEn,
              translationFr: a.translationFr,
              juz: a.juz,
              page: a.page,
              hizb: a.hizb,
            ))
        .toList();
  }

  @override
  Future<List<AyahEntity>> getAyahsByJuz(int juz) async {
    final ayahs = await _localDataSource.getAyahsByJuz(juz);
    return ayahs
        .map((a) => AyahEntity(
              id: a.id,
              surahId: a.surahId,
              number: a.number,
              textAr: a.textAr,
              translationEn: a.translationEn,
              translationFr: a.translationFr,
              juz: a.juz,
              page: a.page,
              hizb: a.hizb,
            ))
        .toList();
  }

  @override
  Future<List<AyahEntity>> getAyahsByPage(int page) async {
    final ayahs = await _localDataSource.getAyahsByPage(page);
    return ayahs
        .map((a) => AyahEntity(
              id: a.id,
              surahId: a.surahId,
              number: a.number,
              textAr: a.textAr,
              translationEn: a.translationEn,
              translationFr: a.translationFr,
              juz: a.juz,
              page: a.page,
              hizb: a.hizb,
            ))
        .toList();
  }
}
