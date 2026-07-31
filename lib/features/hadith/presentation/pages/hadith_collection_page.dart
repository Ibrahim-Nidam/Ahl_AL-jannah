import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/hadith_entities.dart';
import '../bloc/hadith_cubit.dart';
import '../widgets/hadith_book_list_view.dart';
import '../widgets/hadith_search_field.dart';

/// Reads the hadiths of a single book with infinite scroll.
///
/// Large books (Muslim's pilgrimage book has 1000+ entries) are paged in
/// 30 at a time as the user scrolls via [HadithCubit.loadMoreInBook] — the
/// list widget handles the scroll trigger. The search field at the top
/// filters the fully-loaded list via [HadithCubit.searchInBook].
class HadithCollectionPage extends StatefulWidget {
  const HadithCollectionPage({
    super.key,
    required this.author,
    required this.book,
  });

  final HadithAuthorMeta author;
  final HadithBookMeta book;

  @override
  State<HadithCollectionPage> createState() => _HadithCollectionPageState();
}

class _HadithCollectionPageState extends State<HadithCollectionPage> {
  late final HadithCubit _cubit;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cubit = getIt<HadithCubit>();
    _cubit.openBook(widget.author, widget.book);
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
      child: Scaffold(
        appBar: AppBar(title: Text(widget.book.titleFor(languageCode))),
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
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: colorScheme.error.withAlpha(160)),
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
            if (state is HadithBookFiltered) {
              return Column(
                children: [
                  HadithSearchField(
                    controller: _searchController,
                    hintText: l10n.hadithInBookSearchHint,
                    onChanged: (value) => _cubit.searchInBook(value),
                    onClear: () => _cubit.searchInBook(''),
                  ),
                  Expanded(
                    child: _buildFilteredResults(context, state, l10n, colorScheme),
                  ),
                ],
              );
            }
            if (state is HadithBookLoaded) {
              return Column(
                children: [
                  HadithSearchField(
                    controller: _searchController,
                    hintText: l10n.hadithInBookSearchHint,
                    onChanged: (value) => _cubit.searchInBook(value),
                    onClear: () => _cubit.searchInBook(''),
                  ),
                  Expanded(
                    child: HadithBookListView(
                      items: state.items,
                      hasMore: state.hasMore,
                      onLoadMore: _cubit.loadMoreInBook,
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildFilteredResults(
    BuildContext context,
    HadithBookFiltered state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    if (state.matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.hadithNoResults,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Text(
            l10n.hadithSearchResultCount(state.matches.length),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: HadithBookListView(
            items: state.matches,
            hasMore: false,
            onLoadMore: _cubit.loadMoreInBook,
          ),
        ),
      ],
    );
  }
}
