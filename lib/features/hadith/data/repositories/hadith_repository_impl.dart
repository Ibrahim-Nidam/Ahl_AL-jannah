import 'package:injectable/injectable.dart';

import '../../domain/entities/hadith_entities.dart';
import '../../domain/repositories/hadith_repository.dart';
import '../datasources/hadith_local_data_source.dart';

@LazySingleton(as: HadithRepository)
class HadithRepositoryImpl implements HadithRepository {
  final HadithLocalDataSource _localDataSource;

  HadithRepositoryImpl(this._localDataSource);

  @override
  Future<List<HadithCollectionMeta>> getCollections() => _localDataSource.getCollections();

  @override
  Future<List<HadithEntity>> getHadithsByCollection(String collectionId) =>
      _localDataSource.getHadithsByCollection(collectionId);

  @override
  Future<List<HadithSearchResult>> search(String query, {String? collectionId}) =>
      _localDataSource.search(query, collectionId: collectionId);
}