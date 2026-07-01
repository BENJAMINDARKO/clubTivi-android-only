import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database.dart' as db;
import '../../data/datasources/local/database.dart'; // Ensure it's imported
import '../providers/provider_manager.dart';

enum SearchTab { all, live, movies, series }

class SearchState {
  final String query;
  final SearchTab tab;
  final List<db.Channel> results;
  final bool loading;

  const SearchState({
    this.query = '',
    this.tab = SearchTab.all,
    this.results = const [],
    this.loading = false,
  });

  SearchState copyWith({
    String? query,
    SearchTab? tab,
    List<db.Channel>? results,
    bool? loading,
  }) {
    return SearchState(
      query: query ?? this.query,
      tab: tab ?? this.tab,
      results: results ?? this.results,
      loading: loading ?? this.loading,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final db.AppDatabase database;

  SearchNotifier(this.database) : super(const SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _performSearch();
  }

  void setTab(SearchTab tab) {
    state = state.copyWith(tab: tab);
    _performSearch();
  }

  void clear() {
    state = const SearchState();
  }

  Future<void> _performSearch() async {
    final query = state.query.trim();
    if (query.isEmpty) {
      state = state.copyWith(results: [], loading: false);
      return;
    }
    
    state = state.copyWith(loading: true);
    
    final all = await database.getAllChannels();
    final q = query.toLowerCase();

    final filtered = all.where((c) {
      if (c.hidden) return false;
      if (!c.name.toLowerCase().contains(q) &&
          !(c.groupTitle?.toLowerCase().contains(q) ?? false)) return false;
      switch (state.tab) {
        case SearchTab.live:
          return c.streamType == 'live';
        case SearchTab.movies:
          return c.streamType == 'vod';
        case SearchTab.series:
          return c.streamType == 'series';
        case SearchTab.all:
          return true;
      }
    }).toList();

    state = state.copyWith(results: filtered, loading: false);
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final database = ref.watch(databaseProvider);
  return SearchNotifier(database);
});
