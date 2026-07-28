/// Cubit managing Adhkar categories, items, and search.
///
/// Kept intentionally small: temporary per-dhikr repetition counters live in
/// the category page widget state so they reset when leaving that page.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/adhkar_entities.dart';
import '../../domain/usecases/adhkar_usecases.dart';

// ── State ──

@immutable
class AdhkarState {
  final bool isLoading;
  final List<AdhkarCategory> categories;
  final String? selectedCategory;
  final List<AdhkarItem> currentItems;
  final Set<String> favoriteKeys;
  final AdhkarSettings settings;
  final String searchQuery;
  final List<AdhkarItem> searchResults;
  final String? error;

  const AdhkarState({
    this.isLoading = true,
    this.categories = const [],
    this.selectedCategory,
    this.currentItems = const [],
    this.favoriteKeys = const {},
    this.settings = const AdhkarSettings(),
    this.searchQuery = '',
    this.searchResults = const [],
    this.error,
  });

  AdhkarState copyWith({
    bool? isLoading,
    List<AdhkarCategory>? categories,
    String? selectedCategory,
    bool clearSelectedCategory = false,
    List<AdhkarItem>? currentItems,
    Set<String>? favoriteKeys,
    AdhkarSettings? settings,
    String? searchQuery,
    List<AdhkarItem>? searchResults,
    String? error,
    bool clearError = false,
  }) {
    return AdhkarState(
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      currentItems: currentItems ?? this.currentItems,
      favoriteKeys: favoriteKeys ?? this.favoriteKeys,
      settings: settings ?? this.settings,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Cubit ──

@lazySingleton
class AdhkarCubit extends Cubit<AdhkarState> {
  final GetAdhkarCategoriesUseCase _getCategories;
  final GetAdhkarByCategoryUseCase _getByCategory;
  final SearchAdhkarUseCase _search;
  final ToggleFavoriteAdhkarUseCase _toggleFavorite;
  final GetFavoriteKeysUseCase _getFavoriteKeys;
  final GetAdhkarSettingsUseCase _getSettings;
  final SaveAdhkarSettingsUseCase _saveSettings;
  final GetAllAdhkarUseCase _getAllAdhkar;

  AdhkarCubit(
    this._getCategories,
    this._getByCategory,
    this._search,
    this._toggleFavorite,
    this._getFavoriteKeys,
    this._getSettings,
    this._saveSettings,
    this._getAllAdhkar,
  ) : super(const AdhkarState());

  /// Load categories, favorites, and settings on first open.
  Future<void> loadInitialData() async {
    try {
      emit(state.copyWith(isLoading: true, clearError: true));
      final results = await Future.wait([
        _getCategories(),
        _getFavoriteKeys(),
        _getSettings(),
      ]);
      emit(state.copyWith(
        isLoading: false,
        categories: results[0] as List<AdhkarCategory>,
        favoriteKeys: results[1] as Set<String>,
        settings: results[2] as AdhkarSettings,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Select a category and load its items (used by UI + deep links).
  Future<void> selectCategory(String category) async {
    emit(state.copyWith(
      isLoading: true,
      selectedCategory: category,
      searchQuery: '',
      searchResults: const [],
    ));
    final items = await _getByCategory(category);
    emit(state.copyWith(isLoading: false, currentItems: items));
  }

  /// Go back to the category list.
  void clearCategory() {
    emit(state.copyWith(
      clearSelectedCategory: true,
      currentItems: const [],
      searchQuery: '',
      searchResults: const [],
    ));
  }

  /// Search across the catalog (optionally scoped to the selected category).
  Future<void> search(String query) async {
    emit(state.copyWith(searchQuery: query));
    if (query.trim().isEmpty) {
      emit(state.copyWith(searchResults: const []));
      return;
    }
    final results = await _search(
      query,
      category: state.selectedCategory,
    );
    emit(state.copyWith(searchResults: results));
  }

  /// Toggle favorite status for a dhikr (API kept for future Favorites UI).
  Future<void> toggleFavorite(String uniqueKey) async {
    await _toggleFavorite(uniqueKey);
    final keys = await _getFavoriteKeys();
    emit(state.copyWith(favoriteKeys: keys));
  }

  /// Get all favorited adhkar items.
  Future<List<AdhkarItem>> getFavoriteItems() async {
    final allItems = await _getAllAdhkar();
    final keys = state.favoriteKeys;
    return allItems.where((i) => keys.contains(i.uniqueKey)).toList();
  }

  /// Update settings and persist.
  Future<void> updateSettings(AdhkarSettings settings) async {
    emit(state.copyWith(settings: settings));
    await _saveSettings(settings);
  }
}
