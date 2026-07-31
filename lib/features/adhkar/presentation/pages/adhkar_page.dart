import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:ahl_jannah/core/theme/app_colors.dart';
import 'package:ahl_jannah/core/theme/app_text_styles.dart';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

import '../../../../core/di/injection.dart';
import '../../../settings/presentation/bloc/settings_cubit.dart';
import '../../domain/entities/adhkar_entities.dart';
import '../bloc/adhkar_cubit.dart';
import '../widgets/adhkar_category_reader.dart';
import '../widgets/adhkar_category_tile.dart';

/// Adhkar catalog entry point.
///
/// [initialCategory], when provided (e.g. by Morning/Evening reminder
/// notifications), opens that category directly via [AdhkarCubit.selectCategory].
class AdhkarPage extends StatefulWidget {
  final String? initialCategory;

  const AdhkarPage({super.key, this.initialCategory});

  @override
  State<AdhkarPage> createState() => _AdhkarPageState();
}

class _AdhkarPageState extends State<AdhkarPage>
    with AutomaticKeepAliveClientMixin<AdhkarPage> {
  late final AdhkarCubit _cubit;
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  /// When opening a category from search, jump the reader to this item index.
  int _readerInitialIndex = 0;

  static const _morningKey = 'أذكار الصباح';
  static const _eveningKey = 'أذكار المساء';

  @override
  void initState() {
    super.initState();
    _cubit = getIt<AdhkarCubit>();
    _loadAndSelect();
  }

  @override
  void didUpdateWidget(covariant AdhkarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != null &&
        widget.initialCategory != oldWidget.initialCategory) {
      _readerInitialIndex = 0;
      _cubit.selectCategory(widget.initialCategory!);
    }
  }

  Future<void> _loadAndSelect() async {
    await _cubit.loadInitialData();
    if (!mounted) return;
    if (widget.initialCategory != null) {
      _readerInitialIndex = 0;
      await _cubit.selectCategory(widget.initialCategory!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onBackFromCategory() {
    _readerInitialIndex = 0;
    _searchController.clear();
    _cubit.clearCategory();
  }

  Future<void> _openCategory(String category, {int initialIndex = 0}) async {
    setState(() => _readerInitialIndex = initialIndex);
    _searchController.clear();
    await _cubit.search('');
    await _cubit.selectCategory(category);
  }

  Future<void> _openItemFromSearch(AdhkarItem item) async {
    _searchController.clear();
    await _cubit.search('');
    await _cubit.selectCategory(item.category);
    if (!mounted) return;
    final idx = _cubit.state.currentItems.indexWhere(
      (i) => i.uniqueKey == item.uniqueKey,
    );
    setState(() => _readerInitialIndex = idx >= 0 ? idx : 0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;

    return BlocProvider.value(
      value: _cubit,
      child: BlocBuilder<AdhkarCubit, AdhkarState>(
        builder: (context, state) {
          final inCategory = state.selectedCategory != null;
          final title = inCategory
              ? _categoryTitle(state, languageCode)
              : l10n.adhkarPageTitle;

          return Scaffold(
            appBar: AppBar(
              title: Text(title),
              titleTextStyle: AppTextStyles.arabicHeading(fontSize: 20)
                  .copyWith(
                    color: isDark
                        ? AppColors.onSurfaceDark
                        : AppColors.onSurfaceLight,
                  ),
              leading: inCategory
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: _onBackFromCategory,
                    )
                  : null,
              actions: [
                IconButton(
                  tooltip: l10n.tasbeehPageTitle,
                  icon: const Icon(Icons.fingerprint_rounded),
                  onPressed: () => context.pushNamed('tasbeeh'),
                ),
              ],
            ),
            body: _buildBody(context, state, l10n, languageCode, isDark),
          );
        },
      ),
    );
  }

  String _categoryTitle(AdhkarState state, String languageCode) {
    final key = state.selectedCategory!;
    final match = state.categories.where((c) => c.name == key);
    if (match.isNotEmpty) return match.first.displayName(languageCode);
    if (state.currentItems.isNotEmpty) {
      return state.currentItems.first.categoryLabel(languageCode);
    }
    return key;
  }

  Widget _buildBody(
    BuildContext context,
    AdhkarState state,
    AppLocalizations l10n,
    String languageCode,
    bool isDark,
  ) {
    if (state.isLoading && state.categories.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (state.error != null && state.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.error!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          ),
        ),
      );
    }

    final query = state.searchQuery.trim();
    final searching = query.isNotEmpty;

    final settingsState = context.watch<SettingsCubit>().state;
    final arabicFontSize = settingsState is SettingsLoadSuccess
        ? settingsState.settings.arabicFontSize
        : 28.0;

    if (state.selectedCategory != null) {
      final items = state.currentItems;
      final safeIndex = _readerInitialIndex.clamp(
        0,
        items.isEmpty ? 0 : items.length - 1,
      );
      return AdhkarCategoryReader(
        key: ValueKey('${state.selectedCategory}_$safeIndex'),
        items: items,
        isLoading: state.isLoading,
        emptyLabel: l10n.adhkarEmptyCategory,
        arabicFontSize: arabicFontSize,
        initialIndex: safeIndex,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _CatalogSearchField(
            controller: _searchController,
            hint: l10n.adhkarSearchHint,
            isDark: isDark,
            onChanged: _cubit.search,
            onClear: () {
              _searchController.clear();
              _cubit.search('');
            },
          ),
        ),
        Expanded(
          child: searching
              ? _SearchResultsView(
                  items: state.searchResults,
                  emptyLabel: l10n.adhkarNoResults,
                  languageCode: languageCode,
                  onOpenItem: _openItemFromSearch,
                )
              : _CatalogHome(
                  categories: state.categories,
                  languageCode: languageCode,
                  l10n: l10n,
                  isDark: isDark,
                  morningKey: _morningKey,
                  eveningKey: _eveningKey,
                  onOpenCategory: _openCategory,
                ),
        ),
      ],
    );
  }
}

class _CatalogHome extends StatelessWidget {
  final List<AdhkarCategory> categories;
  final String languageCode;
  final AppLocalizations l10n;
  final bool isDark;
  final String morningKey;
  final String eveningKey;
  final Future<void> Function(String category) onOpenCategory;

  const _CatalogHome({
    required this.categories,
    required this.languageCode,
    required this.l10n,
    required this.isDark,
    required this.morningKey,
    required this.eveningKey,
    required this.onOpenCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Center(child: Text(l10n.adhkarNoResults));
    }

    AdhkarCategory? morning;
    AdhkarCategory? evening;
    final rest = <AdhkarCategory>[];

    for (final c in categories) {
      if (c.name == morningKey) {
        morning = c;
      } else if (c.name == eveningKey) {
        evening = c;
      } else {
        rest.add(c);
      }
    }

    return CustomScrollView(
      slivers: [
        if (morning != null || evening != null) ...[
          sliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              l10n.adhkarDailySection,
              style: AppTextStyles.caption.copyWith(
                color: isDark
                    ? AppColors.onSurfaceDarkVariant
                    : AppColors.onSurfaceLightVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (morning != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: AdhkarFeaturedCategoryCard(
                  category: morning,
                  languageCode: languageCode,
                  isEvening: false,
                  onTap: () => onOpenCategory(morning!.name),
                ),
              ),
            ),
          if (evening != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: AdhkarFeaturedCategoryCard(
                  category: evening,
                  languageCode: languageCode,
                  isEvening: true,
                  onTap: () => onOpenCategory(evening!.name),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
              child: Text(
                l10n.adhkarAllCategoriesSection,
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.onSurfaceDarkVariant
                      : AppColors.onSurfaceLightVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
        SliverList.separated(
          itemCount: rest.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 62,
            endIndent: 16,
            color: isDark
                ? AppColors.dividerDark
                : AppColors.divider.withValues(alpha: 0.85),
          ),
          itemBuilder: (context, index) {
            final category = rest[index];
            return AdhkarCategoryTile(
              category: category,
              languageCode: languageCode,
              index: index,
              onTap: () => onOpenCategory(category.name),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  /// Tiny helper so section labels can sit in a sliver without repetition.
  static Widget sliverPadding({
    required EdgeInsets padding,
    required Widget child,
  }) {
    return SliverToBoxAdapter(
      child: Padding(padding: padding, child: child),
    );
  }
}

class _CatalogSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _CatalogSearchField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.primaryGreen,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: onClear,
            );
          },
        ),
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceDarkVariant
            : AppColors.surfaceLightVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _SearchResultsView extends StatelessWidget {
  final List<AdhkarItem> items;
  final String emptyLabel;
  final String languageCode;
  final ValueChanged<AdhkarItem> onOpenItem;

  const _SearchResultsView({
    required this.items,
    required this.emptyLabel,
    required this.languageCode,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyLabel));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: isDark
            ? AppColors.dividerDark
            : AppColors.divider.withValues(alpha: 0.85),
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => onOpenItem(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.categoryLabel(languageCode),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.arabic,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: AppTextStyles.arabicBody(fontSize: 18).copyWith(
                    color: isDark
                        ? AppColors.onSurfaceDark
                        : AppColors.onSurfaceLight,
                  ),
                ),
                if (languageCode == 'en' && item.translation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.translation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.onSurfaceDarkVariant
                          : AppColors.onSurfaceLightVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
