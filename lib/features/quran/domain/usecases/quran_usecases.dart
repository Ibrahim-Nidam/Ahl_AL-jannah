import 'package:injectable/injectable.dart';
import '../entities/quran_entities.dart';
import '../repositories/quran_repository.dart';

@lazySingleton
class GetSurahsUseCase {
  final QuranRepository _repository;

  GetSurahsUseCase(this._repository);

  Future<List<SurahEntity>> call() async {
    return _repository.getSurahs();
  }
}

@lazySingleton
class GetAyahsBySurahUseCase {
  final QuranRepository _repository;

  GetAyahsBySurahUseCase(this._repository);

  Future<List<AyahEntity>> call(int surahId) async {
    return _repository.getAyahsBySurah(surahId);
  }
}

@lazySingleton
class SearchQuranUseCase {
  final QuranRepository _repository;

  SearchQuranUseCase(this._repository);

  Future<List<AyahEntity>> call(String query) async {
    if (query.trim().isEmpty) return const [];
    return _repository.searchQuran(query);
  }
}

@lazySingleton
class GetAyahsByJuzUseCase {
  final QuranRepository _repository;

  GetAyahsByJuzUseCase(this._repository);

  Future<List<AyahEntity>> call(int juz) async {
    return _repository.getAyahsByJuz(juz);
  }
}

@lazySingleton
class GetAyahsByPageUseCase {
  final QuranRepository _repository;

  GetAyahsByPageUseCase(this._repository);

  Future<List<AyahEntity>> call(int page) async {
    return _repository.getAyahsByPage(page);
  }
}

@lazySingleton
class GetWarshAyahsByPageUseCase {
  final QuranRepository _repository;

  GetWarshAyahsByPageUseCase(this._repository);

  Future<List<AyahEntity>> call(int page) async {
    return _repository.getWarshAyahsByPage(page);
  }
}

@lazySingleton
class GetWarshAyahsBySurahUseCase {
  final QuranRepository _repository;

  GetWarshAyahsBySurahUseCase(this._repository);

  Future<List<AyahEntity>> call(int surahId) async {
    return _repository.getWarshAyahsBySurah(surahId);
  }
}

@lazySingleton
class GetWarshAyahsByJuzUseCase {
  final QuranRepository _repository;

  GetWarshAyahsByJuzUseCase(this._repository);

  Future<List<AyahEntity>> call(int juz) async {
    return _repository.getWarshAyahsByJuz(juz);
  }
}

@lazySingleton
class GetWarshSurahAyahCountsUseCase {
  final QuranRepository _repository;

  GetWarshSurahAyahCountsUseCase(this._repository);

  Future<Map<int, int>> call() async {
    return _repository.getWarshSurahAyahCounts();
  }
}
