import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/hadith_entities.dart';
import '../bloc/hadith_cubit.dart';
import '../widgets/hadith_book_list_view.dart';
import '../widgets/hadith_book_tile.dart';
import '../widgets/hadith_search_field.dart';
import 'hadith_collection_page.dart';

/// Books of a single Hadith author, loaded via [HadithCubit.openAuthor].
///
/// Collections with more than one book show a book list with a search field
/// that filters by title; single-book collections (e.g. Forty Nawawi) skip
/// the list and render their hadiths directly here — see [HadithBookLoaded].
class HadithBooksPage extends StatefulWidget {
  const HadithBooksPage({super.key, required this.author});

  final HadithAuthorMeta author;

  @override
  State<HadithBooksPage> createState() => _HadithBooksPageState();
}

class _HadithBooksPageState extends State<HadithBooksPage> {
  late final HadithCubit _cubit;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cubit = getIt<HadithCubit>();
    _cubit.openAuthor(widget.author);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;

    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<HadithCubit, HadithState>(
        builder: (context, state) {
          final String appBarTitle;
          if (state is HadithBookLoaded) {
            appBarTitle = state.book.titleFor(languageCode);
          } else {
            appBarTitle = widget.author.titleFor(languageCode);
          }

          return Scaffold(
            appBar: AppBar(title: Text(appBarTitle)),
            body: _buildBody(context, state, l10n, colorScheme),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    HadithState state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    if (state is HadithLoading || state is HadithInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is HadithError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.commonError(state.message),
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      );
    }
    if (state is HadithBooksLoaded) {
      final filtered = _query.isEmpty
          ? state.books
          : state.books
              .where((book) => _bookMatches(book, _query))
              .toList(growable: false);

      return Column(
        children: [
          HadithSearchField(
            controller: _searchController,
            hintText: l10n.hadithBooksSearchHint,
            onChanged: (value) => setState(() => _query = value.trim()),
            onClear: () => setState(() => _query = ''),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      l10n.hadithNoResults,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final book = filtered[index];
                      return HadithBookTile(
                        book: book,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => HadithCollectionPage(
                                author: state.author,
                                book: book,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      );
    }
    if (state is HadithBookLoaded) {
      return HadithBookListView(
        items: state.items,
        hasMore: state.hasMore,
        onLoadMore: _cubit.loadMoreInBook,
      );
    }
    return const SizedBox.shrink();
  }

  bool _bookMatches(HadithBookMeta book, String query) {
    final lower = query.toLowerCase();
    return book.titleEn.toLowerCase().contains(lower) || book.titleAr.contains(query);
  }
}
