import 'package:flutter/material.dart';

import '../../domain/entities/hadith_entities.dart';
import 'hadith_item_tile.dart';

/// Infinite-scrolling list of hadiths for one book. Owns its [ScrollController]
/// and asks [onLoadMore] to reveal the next page when the user approaches
/// the bottom, showing a footer spinner while more items are pending.
class HadithBookListView extends StatefulWidget {
  const HadithBookListView({
    super.key,
    required this.items,
    required this.hasMore,
    required this.onLoadMore,
  });

  final List<HadithItem> items;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  State<HadithBookListView> createState() => _HadithBookListViewState();
}

class _HadithBookListViewState extends State<HadithBookListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 600;
    if (_scrollController.position.pixels >= threshold) {
      widget.onLoadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final hasMore = widget.hasMore;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return HadithItemTile(hadith: items[index]);
      },
    );
  }
}
