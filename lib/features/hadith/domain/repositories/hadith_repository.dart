import '../entities/hadith_entities.dart';

abstract class HadithRepository {
  Future<List<HadithCollectionMeta>> getCollections();
  Future<List<HadithEntity>> getHadithsByCollection(String collectionId);
  Future<List<HadithSearchResult>> search(String query, {String? collectionId});
}