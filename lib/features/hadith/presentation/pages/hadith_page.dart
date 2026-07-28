import 'dart:async';

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/hadith_cubit.dart';
import '../widgets/hadith_collection_tile.dart';
import '../widgets/hadith_item_tile.dart';
import 'hadith_collection_page.dart';

/// Catalog of every bundled Hadith collection, with a search bar that
/// searches **globally** across all collections. Collections are
/// discovered automatically from `assets/hadith/*.json` — see
/// [HadithLocalDataSourceImpl] — so dropping a new correctly-shaped JSON
/// file there is enough for it to appear here without any code change.
class HadithPage extends StatefulWidget {
  const HadithPage({super.key});

  @override
  State<HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<HadithPage> {
  late final HadithCubit _cubit;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<HadithCubit>();
    _cubit.loadCatalog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _cubit.close();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _cubit.search(value);
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _searching = false);
    _cubit.loadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

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
              : Text(l10n.hadithTileTitle),
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
              return _EmptyState(
                icon: Icons.error_outline_rounded,
                message: l10n.commonError(state.message),
                color: colorScheme.error,
              );
            }
            if (state is HadithSearchLoaded) {
              if (state.results.isEmpty) {
                return _EmptyState(
                  icon: Icons.search_off_rounded,
                  message: l10n.hadithNoResults,
                  color: colorScheme.onSurfaceVariant,
                );
              }
              final languageCode = Localizations.localeOf(context).languageCode;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.results.length,
                itemBuilder: (context, index) {
                  final result = state.results[index];
                  return HadithItemTile(
                    hadith: result.hadith,
                    collectionTitle: result.titleFor(languageCode),
                    isDark: isDark,
                  );
                },
              );
            }
            if (state is HadithCatalogLoaded) {
              if (state.collections.isEmpty) {
                return _EmptyState(
                  icon: Icons.library_books_outlined,
                  message: l10n.hadithNoCollections,
                  color: colorScheme.onSurfaceVariant,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.collections.length,
                itemBuilder: (context, index) {
                  final collection = state.collections[index];
                  return HadithCollectionTile(
                    collection: collection,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => HadithCollectionPage(collection: collection),
                        ),
                      );
                    },
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
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