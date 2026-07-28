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

class HadithCatalogLoaded extends HadithState {
  final List<HadithCollectionMeta> collections;
  const HadithCatalogLoaded(this.collections);
}

/// [items] is the currently visible *page* of the collection, not
/// necessarily the whole thing — see [HadithCubit.loadMoreInCollection].
/// Large collections (Bukhari has 7000+ entries) are paged in to keep
/// list rendering smooth instead of building thousands of widgets upfront.
class HadithCollectionLoaded extends HadithState {
  final HadithCollectionMeta collection;
  final List<HadithEntity> items;
  final bool hasMore;
  final bool loadingMore;
  const HadithCollectionLoaded(
    this.collection,
    this.items, {
    this.hasMore = false,
    this.loadingMore = false,
  });
}

class HadithSearchLoaded extends HadithState {
  final String query;
  final String? scopedCollectionId;
  final List<HadithSearchResult> results;
  const HadithSearchLoaded({
    required this.query,
    required this.scopedCollectionId,
    required this.results,
  });
}

class HadithError extends HadithState {
  final String message;
  const HadithError(this.message);
}

@injectable
class HadithCubit extends Cubit<HadithState> {
  static const _pageSize = 40;

  final GetHadithCollections _getCollections;
  final GetHadithsByCollection _getHadithsByCollection;
  final SearchHadith _searchHadith;

  /// Full item list for whatever collection is currently open, kept here
  /// (not in state) so pagination can slice it without re-fetching.
  List<HadithEntity> _openCollectionItems = const [];
  HadithCollectionMeta? _openCollection;
  int _visibleCount = 0;

  HadithCubit(this._getCollections, this._getHadithsByCollection, this._searchHadith)
      : super(const HadithInitial());

  Future<void> loadCatalog() async {
    emit(const HadithLoading());
    try {
      final collections = await _getCollections();
      emit(HadithCatalogLoaded(collections));
    } catch (e) {
      emit(HadithError(e.toString()));
    }
  }

  Future<void> openCollection(HadithCollectionMeta collection) async {
    emit(const HadithLoading());
    try {
      final items = await _getHadithsByCollection(collection.collectionId);
      _openCollection = collection;
      _openCollectionItems = items;
      _visibleCount = items.length < _pageSize ? items.length : _pageSize;
      emit(HadithCollectionLoaded(
        collection,
        _openCollectionItems.take(_visibleCount).toList(),
        hasMore: _visibleCount < _openCollectionItems.length,
      ));
    } catch (e) {
      emit(HadithError(e.toString()));
    }
  }

  /// Reveals the next page (40 more) of the currently open collection.
  /// No-op if nothing is open or everything is already visible.
  void loadMoreInCollection() {
    final collection = _openCollection;
    if (collection == null || state is! HadithCollectionLoaded) return;
    if (_visibleCount >= _openCollectionItems.length) return;

    _visibleCount = (_visibleCount + _pageSize) > _openCollectionItems.length
        ? _openCollectionItems.length
        : _visibleCount + _pageSize;

    emit(HadithCollectionLoaded(
      collection,
      _openCollectionItems.take(_visibleCount).toList(),
      hasMore: _visibleCount < _openCollectionItems.length,
    ));
  }

  Future<void> search(String query, {String? collectionId}) async {
    if (query.trim().isEmpty) {
      if (collectionId != null && _openCollection != null) {
        await openCollection(_openCollection!);
      } else {
        await loadCatalog();
      }
      return;
    }
    emit(const HadithLoading());
    try {
      final results = await _searchHadith(query, collectionId: collectionId);
      emit(HadithSearchLoaded(query: query, scopedCollectionId: collectionId, results: results));
    } catch (e) {
      emit(HadithError(e.toString()));
    }
  }
}