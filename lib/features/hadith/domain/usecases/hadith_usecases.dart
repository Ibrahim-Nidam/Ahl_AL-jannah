import 'package:injectable/injectable.dart';

import '../entities/hadith_entities.dart';
import '../repositories/hadith_repository.dart';

@injectable
class GetHadithAuthors {
  final HadithRepository _repository;
  GetHadithAuthors(this._repository);
  Future<List<HadithAuthorMeta>> call() => _repository.getAuthors();
}

@injectable
class GetHadithBooks {
  final HadithRepository _repository;
  GetHadithBooks(this._repository);
  Future<List<HadithBookMeta>> call(String authorId) => _repository.getBooks(authorId);
}

@injectable
class GetHadithsByBook {
  final HadithRepository _repository;
  GetHadithsByBook(this._repository);
  Future<List<HadithItem>> call(String authorId, String bookId) =>
      _repository.getHadiths(authorId, bookId);
}

@injectable
class SearchHadiths {
  final HadithRepository _repository;
  SearchHadiths(this._repository);
  Future<List<HadithSearchResult>> call(String query) =>
      _repository.searchHadiths(query);
}
