/// Use cases for the Adhkar catalog.
library;

import 'package:injectable/injectable.dart';

import '../entities/adhkar_entities.dart';
import '../repositories/adhkar_repository.dart';

@lazySingleton
class GetAdhkarCategoriesUseCase {
  final AdhkarRepository _repository;
  const GetAdhkarCategoriesUseCase(this._repository);

  Future<List<AdhkarCategory>> call() => _repository.getCategories();
}

@lazySingleton
class GetAdhkarByCategoryUseCase {
  final AdhkarRepository _repository;
  const GetAdhkarByCategoryUseCase(this._repository);

  Future<List<AdhkarItem>> call(String category) =>
      _repository.getAdhkarByCategory(category);
}

@lazySingleton
class SearchAdhkarUseCase {
  final AdhkarRepository _repository;
  const SearchAdhkarUseCase(this._repository);

  Future<List<AdhkarItem>> call(String query, {String? category}) =>
      _repository.searchAdhkar(query, category: category);
}

@lazySingleton
class ToggleFavoriteAdhkarUseCase {
  final AdhkarRepository _repository;
  const ToggleFavoriteAdhkarUseCase(this._repository);

  Future<void> call(String uniqueKey) => _repository.toggleFavorite(uniqueKey);
}

@lazySingleton
class GetFavoriteKeysUseCase {
  final AdhkarRepository _repository;
  const GetFavoriteKeysUseCase(this._repository);

  Future<Set<String>> call() => _repository.getFavoriteKeys();
}

@lazySingleton
class GetAdhkarSettingsUseCase {
  final AdhkarRepository _repository;
  const GetAdhkarSettingsUseCase(this._repository);

  Future<AdhkarSettings> call() => _repository.getSettings();
}

@lazySingleton
class SaveAdhkarSettingsUseCase {
  final AdhkarRepository _repository;
  const SaveAdhkarSettingsUseCase(this._repository);

  Future<void> call(AdhkarSettings settings) =>
      _repository.saveSettings(settings);
}

@lazySingleton
class GetTasbeehStatsUseCase {
  final AdhkarRepository _repository;
  const GetTasbeehStatsUseCase(this._repository);

  Future<TasbeehStats> call() => _repository.getTasbeehStats();
}

@lazySingleton
class RecordTasbeehProgressUseCase {
  final AdhkarRepository _repository;
  const RecordTasbeehProgressUseCase(this._repository);

  Future<TasbeehStats> call({
    required String dhikrText,
    required int repetitions,
    required int durationMs,
    bool countAsCompletedSession = false,
  }) =>
      _repository.recordTasbeehProgress(
        dhikrText: dhikrText,
        repetitions: repetitions,
        durationMs: durationMs,
        countAsCompletedSession: countAsCompletedSession,
      );
}

@lazySingleton
class ClearTasbeehStatsDayUseCase {
  final AdhkarRepository _repository;
  const ClearTasbeehStatsDayUseCase(this._repository);

  Future<TasbeehStats> call(String date) =>
      _repository.clearTasbeehStatsDay(date);
}

@lazySingleton
class ClearAllTasbeehStatsUseCase {
  final AdhkarRepository _repository;
  const ClearAllTasbeehStatsUseCase(this._repository);

  Future<TasbeehStats> call() => _repository.clearAllTasbeehStats();
}

@lazySingleton
class GetSavedTasbeehSessionUseCase {
  final AdhkarRepository _repository;
  const GetSavedTasbeehSessionUseCase(this._repository);

  Future<Map<String, dynamic>?> call() => _repository.getSavedTasbeehSession();
}

@lazySingleton
class SaveTasbeehSessionUseCase {
  final AdhkarRepository _repository;
  const SaveTasbeehSessionUseCase(this._repository);

  Future<void> call(Map<String, dynamic> session) =>
      _repository.saveTasbeehSession(session);
}

@lazySingleton
class GetTasbeehCollectionUseCase {
  final AdhkarRepository _repository;
  const GetTasbeehCollectionUseCase(this._repository);

  Future<List<TasbeehCollectionItem>> call() =>
      _repository.getTasbeehCollection();
}

@lazySingleton
class SaveTasbeehCollectionUseCase {
  final AdhkarRepository _repository;
  const SaveTasbeehCollectionUseCase(this._repository);

  Future<void> call(List<TasbeehCollectionItem> items) =>
      _repository.saveTasbeehCollection(items);
}

@lazySingleton
class GetAllAdhkarUseCase {
  final AdhkarRepository _repository;
  const GetAllAdhkarUseCase(this._repository);

  Future<List<AdhkarItem>> call() => _repository.getAllAdhkar();
}
