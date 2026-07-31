import '../entities/hadith_entities.dart';

abstract class HadithRepository {
  Future<List<HadithAuthorMeta>> getAuthors();
  Future<List<HadithBookMeta>> getBooks(String authorId);
  Future<List<HadithItem>> getHadiths(String authorId, String bookId);
  Future<List<HadithSearchResult>> searchHadiths(String query);
}
