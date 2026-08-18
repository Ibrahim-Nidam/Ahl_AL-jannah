import 'package:injectable/injectable.dart';

import '../../domain/entities/quran_entities.dart';
import 'quran_warsh_database.dart';

/// Read-only Warsh-riwaya access, parallel to [QuranLocalDataSource] but
/// backed by the standalone `quran_warsh.db` bundle. Returns the same
/// [AyahEntity] shape as the Hafs source (with null translations) so the
/// reader can consume either riwaya through one entity type.
abstract class WarshQuranDataSource {
  Future<List<AyahEntity>> getAyahsByPage(int page);
  Future<List<AyahEntity>> getAyahsBySurah(int surahId);
  Future<List<AyahEntity>> getAyahsByJuz(int juz);
  Future<Map<int, int>> getSurahAyahCounts();
}

@LazySingleton(as: WarshQuranDataSource)
class WarshQuranDataSourceImpl implements WarshQuranDataSource {
  final WarshQuranDatabase _db;

  WarshQuranDataSourceImpl(this._db);

  @override
  Future<List<AyahEntity>> getAyahsByPage(int page) async {
    final rows = await _db.getAyahsByPage(page);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<AyahEntity>> getAyahsBySurah(int surahId) async {
    final rows = await _db.getAyahsBySurah(surahId);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<AyahEntity>> getAyahsByJuz(int juz) async {
    final rows = await _db.getAyahsByJuz(juz);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<Map<int, int>> getSurahAyahCounts() => _db.getSurahAyahCounts();

  AyahEntity _toEntity(WarshAyahRow row) {
    return AyahEntity(
      id: row.id,
      surahId: row.surahId,
      number: row.number,
      textAr: row.textAr,
      translationEn: null,
      translationFr: null,
      juz: row.juz,
      page: row.page,
      hizb: row.hizb,
    );
  }
}
