import 'package:injectable/injectable.dart';

import '../entities/hadith_entities.dart';
import '../repositories/hadith_repository.dart';

@injectable
class GetHadithCollections {
  final HadithRepository _repository;
  GetHadithCollections(this._repository);
  Future<List<HadithCollectionMeta>> call() => _repository.getCollections();
}

@injectable
class GetHadithsByCollection {
  final HadithRepository _repository;
  GetHadithsByCollection(this._repository);
  Future<List<HadithEntity>> call(String collectionId) => _repository.getHadithsByCollection(collectionId);
}

@injectable
class SearchHadith {
  final HadithRepository _repository;
  SearchHadith(this._repository);
  Future<List<HadithSearchResult>> call(String query, {String? collectionId}) =>
      _repository.search(query, collectionId: collectionId);
}