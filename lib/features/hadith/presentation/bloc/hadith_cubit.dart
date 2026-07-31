import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/hadith_entities.dart';
import '../../domain/usecases/hadith_usecases.dart';

@immutable
abstract class HadithState {
  const HadithState();
}

class HadithInitial extends HadithState {
  const HadithInitial();
}

class HadithLoading extends HadithState {
  const HadithLoading();
}

class HadithAuthorsLoaded extends HadithState {
  final List<HadithAuthorMeta> authors;
  const HadithAuthorsLoaded(this.authors);
}

class HadithBooksLoaded extends HadithState {
  final HadithAuthorMeta author;
  final List<HadithBookMeta> books;
  const HadithBooksLoaded(this.author, this.books);
}

/// [items] is the currently visible *page* of a book, not necessarily the
/// whole thing — see [HadithCubit.loadMoreInBook]. Books can hold hundreds
/// of hadiths (Muslim's pilgrimage book has 1000+), so they are paged in
/// to keep list rendering smooth instead of building all widgets upfront.
class HadithBookLoaded extends HadithState {
  final HadithAuthorMeta author;
  final HadithBookMeta book;
  final List<HadithItem> items;
  final bool hasMore;
  final bool loadingMore;
  const HadithBookLoaded(
    this.author,
    this.book,
    this.items, {
    this.hasMore = false,
    this.loadingMore = false,
  });
}

class HadithError extends HadithState {
  final String message;
  const HadithError(this.message);
}

/// Active global "search everything" query. Once non-empty, the home page
/// swaps its collection list for these results.
class HadithSearchLoaded extends HadithState {
  final List<HadithSearchResult> results;
  final String query;
  final bool searching;
  const HadithSearchLoaded(this.results, this.query, {this.searching = false});
}

/// In-book search is applied over the full loaded list, so the visible
/// items are simply filtered [HadithBookLoaded.items].
class HadithBookFiltered extends HadithState {
  final HadithAuthorMeta author;
  final HadithBookMeta book;
  final List<HadithItem> matches;
  final String query;
  final bool searching;
  const HadithBookFiltered(
    this.author,
    this.book,
    this.matches,
    this.query, {
    this.searching = false,
  });
}

@injectable
class HadithCubit extends Cubit<HadithState> {
  static const _pageSize = 30;

  final GetHadithAuthors _getAuthors;
  final GetHadithBooks _getBooks;
  final GetHadithsByBook _getHadithsByBook;
  final SearchHadiths _searchHadiths;

  /// Full item list for the currently open book, kept here (not in state)
  /// so pagination can slice it without re-fetching.
  List<HadithItem> _openItems = const [];
  HadithBookMeta? _openBook;
  int _visibleCount = 0;

  /// Most recently loaded author list, so the global search page can render
  /// context for results without another round-trip.
  List<HadithAuthorMeta> _authors = const [];

  HadithCubit(this._getAuthors, this._getBooks, this._getHadithsByBook, this._searchHadiths)
      : super(const HadithInitial());

  Future<void> loadAuthors() async {
    emit(const HadithLoading());
    try {
      final authors = await _getAuthors();
      _authors = authors;
      emit(HadithAuthorsLoaded(authors));
    } catch (e) {
      emit(HadithError(e.toString()));
    }
  }

  /// Returns the most recently loaded author list (or loads it once).
  Future<List<HadithAuthorMeta>> ensureAuthors() async {
    if (_authors.isNotEmpty) return _authors;
    await loadAuthors();
    return _authors;
  }

  /// Opens an author. Collections with more than one book show the books
  /// list; single-book collections (e.g. Forty Nawawi) skip straight to
  /// their hadiths.
  Future<void> openAuthor(HadithAuthorMeta author) async {
    emit(const HadithLoading());
    try {
      final books = await _getBooks(author.id);
      if (books.isEmpty) {
        emit(HadithBooksLoaded(author, const []));
        return;
      }
      if (books.length == 1) {
        await _loadBook(author, books.first);
        return;
      }
      emit(HadithBooksLoaded(author, books));
    } catch (e) {
      emit(HadithError(e.toString()));
    }
  }

  Future<void> openBook(HadithAuthorMeta author, HadithBookMeta book) async {
    emit(const HadithLoading());
    await _loadBook(author, book);
  }

  Future<void> _loadBook(HadithAuthorMeta author, HadithBookMeta book) async {
    try {
      final items = await _getHadithsByBook(author.id, book.id);
      _openBook = book;
      _openItems = items;
      _visibleCount = items.length < _pageSize ? items.length : _pageSize;
      emit(HadithBookLoaded(
        author,
        book,
        _openItems.take(_visibleCount).toList(),
        hasMore: _visibleCount < _openItems.length,
      ));
    } catch (e) {
      emit(HadithError(e.toString()));
    }
  }

  /// Reveals the next page (30 more) of the currently open book.
  /// No-op if nothing is open, everything is already visible, or a search
  /// filter is currently active.
  void loadMoreInBook() {
    if (state is HadithBookFiltered) return;
    final book = _openBook;
    if (book == null || state is! HadithBookLoaded) return;
    if (_visibleCount >= _openItems.length) return;

    _visibleCount = (_visibleCount + _pageSize) > _openItems.length
        ? _openItems.length
        : _visibleCount + _pageSize;

    final current = state as HadithBookLoaded;
    emit(HadithBookLoaded(
      current.author,
      book,
      _openItems.take(_visibleCount).toList(),
      hasMore: _visibleCount < _openItems.length,
    ));
  }

  /// Runs a query across every bundled collection. Empty queries clear the
  /// search and fall back to the normal author list.
  Future<void> searchAll(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      if (state is HadithSearchLoaded) {
        emit(HadithAuthorsLoaded(_authors));
      }
      return;
    }

    emit(HadithSearchLoaded(const [], normalized, searching: true));
    try {
      final results = await _searchHadiths(normalized);
      if (!isClosed) emit(HadithSearchLoaded(results, normalized));
    } catch (e) {
      if (!isClosed) emit(HadithError(e.toString()));
    }
  }

  /// Filters the currently open book by [query] (Arabic + English + book
  /// reference). Empty queries restore the paged list.
  void searchInBook(String query) {
    final book = _openBook;
    if (book == null) return;

    final normalized = query.trim();
    if (normalized.isEmpty) {
      if (state is HadithBookFiltered) {
        final current = state as HadithBookFiltered;
        emit(HadithBookLoaded(
          current.author,
          book,
          _openItems.take(_visibleCount).toList(),
          hasMore: _visibleCount < _openItems.length,
        ));
      }
      return;
    }

    final matches = _openItems.where((item) {
      final lower = normalized.toLowerCase();
      return item.arabic.contains(normalized) ||
          item.english.toLowerCase().contains(lower) ||
          item.reference.toLowerCase().contains(lower);
    }).toList();

    final current = state;
    if (current is HadithBookFiltered) {
      emit(HadithBookFiltered(
        current.author,
        book,
        matches,
        normalized,
      ));
    } else if (current is HadithBookLoaded) {
      emit(HadithBookFiltered(
        current.author,
        book,
        matches,
        normalized,
      ));
    }
  }
}
