part of 'quran_cubit.dart';

abstract class QuranState {
  const QuranState();
}

class QuranInitial extends QuranState {}

class QuranLoadInProgress extends QuranState {}

class QuranLoadSuccess extends QuranState {
  final List<SurahEntity> surahs;
  final List<AyahEntity> searchResults;
  final String searchQuery;
  final bool isSearching;
  final String? searchError;

  const QuranLoadSuccess({
    required this.surahs,
    this.searchResults = const [],
    this.searchQuery = '',
    this.isSearching = false,
    this.searchError,
  });

  QuranLoadSuccess copyWith({
    List<SurahEntity>? surahs,
    List<AyahEntity>? searchResults,
    String? searchQuery,
    bool? isSearching,
    String? searchError,
  }) {
    return QuranLoadSuccess(
      surahs: surahs ?? this.surahs,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      searchError: searchError ?? this.searchError,
    );
  }
}

class QuranLoadFailure extends QuranState {
  final String message;
  const QuranLoadFailure(this.message);
}
