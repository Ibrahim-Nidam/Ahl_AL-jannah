import 'dart:async';

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/hadith_cubit.dart';
import '../widgets/hadith_author_tile.dart';
import '../widgets/hadith_search_field.dart';
import '../widgets/hadith_search_result_tile.dart';
import 'hadith_books_page.dart';
import 'hadith_collection_page.dart';

/// Lists the bundled Hadith authors (collections). Tapping one opens its
/// books — see [HadithBooksPage]. A search field at the top queries every
/// collection at once via [HadithCubit.searchAll].
class HadithPage extends StatefulWidget {
  const HadithPage({super.key});

  @override
  State<HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<HadithPage> {
  late final HadithCubit _cubit;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<HadithCubit>();
    _cubit.loadAuthors();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _cubit.searchAll(value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _cubit.searchAll('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.hadithPageTitle)),
        body: BlocBuilder<HadithCubit, HadithState>(
          builder: (context, state) {
            if (state is HadithLoading || state is HadithInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is HadithError) {
              return _EmptyState(
                icon: Icons.error_outline_rounded,
                message: l10n.commonError(state.message),
                color: colorScheme.error,
              );
            }
            if (state is HadithSearchLoaded) {
              return Column(
                children: [
                  HadithSearchField(
                    controller: _searchController,
                    hintText: l10n.hadithGlobalSearchHint,
                    onChanged: _onSearchChanged,
                    onClear: _clearSearch,
                  ),
                  Expanded(child: _buildSearchResults(state, l10n, colorScheme, languageCode)),
                ],
              );
            }
            if (state is HadithAuthorsLoaded) {
              return Column(
                children: [
                  HadithSearchField(
                    controller: _searchController,
                    hintText: l10n.hadithGlobalSearchHint,
                    onChanged: _onSearchChanged,
                    onClear: _clearSearch,
                  ),
                  Expanded(
                    child: state.authors.isEmpty
                        ? _EmptyState(
                            icon: Icons.library_books_outlined,
                            message: l10n.hadithNoCollections,
                            color: colorScheme.onSurfaceVariant,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: state.authors.length,
                            itemBuilder: (context, index) {
                              final author = state.authors[index];
                              return HadithAuthorTile(
                                author: author,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => HadithBooksPage(author: author),
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
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    HadithSearchLoaded state,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    String languageCode,
  ) {
    if (state.searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off_rounded,
        message: l10n.hadithNoResults,
        color: colorScheme.onSurfaceVariant,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
          child: Text(
            l10n.hadithSearchResultCount(state.results.length),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: state.results.length,
            itemBuilder: (context, index) {
              final result = state.results[index];
              return HadithSearchResultTile(
                result: result,
                languageCode: languageCode,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => HadithCollectionPage(
                        author: result.author,
                        book: result.book,
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, required this.color});

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color.withAlpha(160)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}
