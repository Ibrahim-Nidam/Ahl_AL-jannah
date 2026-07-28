import 'dart:async';

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/hadith_entities.dart';
import '../bloc/hadith_cubit.dart';
import '../widgets/hadith_item_tile.dart';

/// Reads a single Hadith collection, with a search field scoped to just
/// this collection (as opposed to [HadithPage]'s global search).
///
/// Large collections (Bukhari: 7000+ entries) are paged in 40 at a time
/// as the user scrolls, via [HadithCubit.loadMoreInCollection] — see
/// [_onScroll].
class HadithCollectionPage extends StatefulWidget {
  const HadithCollectionPage({super.key, required this.collection});

  final HadithCollectionMeta collection;

  @override
  State<HadithCollectionPage> createState() => _HadithCollectionPageState();
}

class _HadithCollectionPageState extends State<HadithCollectionPage> {
  late final HadithCubit _cubit;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<HadithCubit>();
    _cubit.openCollection(widget.collection);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_searching) return; // search results aren't paginated
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 600;
    if (_scrollController.position.pixels >= threshold) {
      _cubit.loadMoreInCollection();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _cubit.search(value, collectionId: widget.collection.collectionId);
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _searching = false);
    _cubit.openCollection(widget.collection);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final title = widget.collection.titleFor(Localizations.localeOf(context).languageCode);

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.hadithSearchHint,
                    border: InputBorder.none,
                  ),
                  onChanged: _onQueryChanged,
                )
              : Text(title),
          actions: [
            IconButton(
              icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
              onPressed: () {
                if (_searching) {
                  _closeSearch();
                } else {
                  setState(() => _searching = true);
                }
              },
            ),
          ],
        ),
        body: BlocBuilder<HadithCubit, HadithState>(
          builder: (context, state) {
            if (state is HadithLoading || state is HadithInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is HadithError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error.withAlpha(160)),
                      const SizedBox(height: 12),
                      Text(
                        l10n.commonError(state.message),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              );
            }

            final List<HadithEntity> items;
            final bool hasMore;
            if (state is HadithSearchLoaded) {
              items = state.results.map((r) => r.hadith).toList();
              hasMore = false;
            } else if (state is HadithCollectionLoaded) {
              items = state.items;
              hasMore = state.hasMore;
            } else {
              items = const [];
              hasMore = false;
            }

            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 48, color: colorScheme.onSurfaceVariant.withAlpha(160)),
                      const SizedBox(height: 12),
                      Text(
                        l10n.hadithNoResults,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= items.length) {
                  // Footer spinner shown while more pages of a large
                  // collection (e.g. Bukhari) are being revealed.
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return HadithItemTile(hadith: items[index], isDark: isDark);
              },
            );
          },
        ),
      ),
    );
  }
}