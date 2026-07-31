import 'package:injectable/injectable.dart';

import '../../domain/entities/hadith_entities.dart';
import '../../domain/repositories/hadith_repository.dart';
import '../datasources/hadith_local_data_source.dart';

@LazySingleton(as: HadithRepository)
class HadithRepositoryImpl implements HadithRepository {
  final HadithLocalDataSource _localDataSource;

  HadithRepositoryImpl(this._localDataSource);

  @override
  Future<List<HadithAuthorMeta>> getAuthors() => _localDataSource.getAuthors();

  @override
  Future<List<HadithBookMeta>> getBooks(String authorId) =>
      _localDataSource.getBooks(authorId);

  @override
  Future<List<HadithItem>> getHadiths(String authorId, String bookId) =>
      _localDataSource.getHadiths(authorId, bookId);

  @override
  Future<List<HadithSearchResult>> searchHadiths(String query) =>
      _localDataSource.searchHadiths(query);
}
