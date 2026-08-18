import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../domain/entities/quran_entities.dart';
import '../../domain/usecases/quran_usecases.dart';

part 'quran_state.dart';

@lazySingleton
class QuranCubit extends Cubit<QuranState> {
  final GetSurahsUseCase _getSurahsUseCase;
  final GetAyahsBySurahUseCase _getAyahsBySurahUseCase;
  final SearchQuranUseCase _searchQuranUseCase;
  final GetAyahsByJuzUseCase _getAyahsByJuzUseCase;
  final GetAyahsByPageUseCase _getAyahsByPageUseCase;
  final GetWarshAyahsByPageUseCase _getWarshAyahsByPageUseCase;
  final GetWarshAyahsBySurahUseCase _getWarshAyahsBySurahUseCase;
  final GetWarshAyahsByJuzUseCase _getWarshAyahsByJuzUseCase;
  final GetWarshSurahAyahCountsUseCase _getWarshSurahAyahCountsUseCase;

  QuranCubit(
    this._getSurahsUseCase,
    this._getAyahsBySurahUseCase,
    this._searchQuranUseCase,
    this._getAyahsByJuzUseCase,
    this._getAyahsByPageUseCase,
    this._getWarshAyahsByPageUseCase,
    this._getWarshAyahsBySurahUseCase,
    this._getWarshAyahsByJuzUseCase,
    this._getWarshSurahAyahCountsUseCase,
  ) : super(QuranInitial());

  Future<void> loadSurahs() async {
    emit(QuranLoadInProgress());
    try {
      final surahs = await _getSurahsUseCase();
      emit(QuranLoadSuccess(surahs: surahs));
    } catch (e) {
      emit(QuranLoadFailure(e.toString()));
    }
  }

  Future<void> search(String query) async {
    final normalizedQuery = query.trim();
    final currentState = state;

    if (currentState is QuranLoadSuccess) {
      if (normalizedQuery.isEmpty) {
        emit(
          currentState.copyWith(
            searchResults: const [],
            searchQuery: '',
            isSearching: false,
            searchError: null,
          ),
        );
        return;
      }
      emit(
        currentState.copyWith(
          isSearching: true,
          searchError: null,
          searchQuery: normalizedQuery,
        ),
      );
      try {
        final results = await _searchQuranUseCase(normalizedQuery);
        final latestState = state;
        if (latestState is QuranLoadSuccess) {
          emit(
            latestState.copyWith(
              searchResults: results,
              isSearching: false,
              searchQuery: normalizedQuery,
            ),
          );
        }
      } catch (e) {
        final latestState = state;
        if (latestState is QuranLoadSuccess) {
          emit(
            latestState.copyWith(
              isSearching: false,
              searchError: e.toString(),
              searchQuery: normalizedQuery,
            ),
          );
        }
      }
    } else {
      emit(QuranLoadInProgress());
      try {
        final results = await _searchQuranUseCase(normalizedQuery);
        emit(
          QuranLoadSuccess(
            surahs: const [],
            searchResults: results,
            searchQuery: normalizedQuery,
          ),
        );
      } catch (e) {
        emit(QuranLoadFailure(e.toString()));
      }
    }
  }

  // Expose these use cases to components
  Future<List<AyahEntity>> getAyahsBySurah(int surahId) =>
      _getAyahsBySurahUseCase(surahId);
  Future<List<AyahEntity>> getAyahsByJuz(int juz) => _getAyahsByJuzUseCase(juz);
  Future<List<AyahEntity>> getAyahsByPage(int page) =>
      _getAyahsByPageUseCase(page);

  // Warsh riwaya
  Future<List<AyahEntity>> getWarshAyahsBySurah(int surahId) =>
      _getWarshAyahsBySurahUseCase(surahId);
  Future<List<AyahEntity>> getWarshAyahsByJuz(int juz) =>
      _getWarshAyahsByJuzUseCase(juz);
  Future<List<AyahEntity>> getWarshAyahsByPage(int page) =>
      _getWarshAyahsByPageUseCase(page);

  Future<Map<int, int>> getWarshSurahAyahCounts() =>
      _getWarshSurahAyahCountsUseCase();
}
