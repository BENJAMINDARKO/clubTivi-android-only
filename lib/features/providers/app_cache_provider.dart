import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database.dart' as db;
import 'provider_manager.dart';

class AppCache {
  final List<db.Provider> providers;
  final List<db.CategoryPreference> prefs;

  const AppCache({
    required this.providers,
    required this.prefs,
  });

  AppCache copyWith({
    List<db.Provider>? providers,
    List<db.CategoryPreference>? prefs,
  }) {
    return AppCache(
      providers: providers ?? this.providers,
      prefs: prefs ?? this.prefs,
    );
  }
}

class AppCacheNotifier extends AsyncNotifier<AppCache> {
  @override
  Future<AppCache> build() async {
    final database = ref.read(databaseProvider);
    final providers = await database.getAllProviders();
    final prefs = await database.getAllCategoryPreferences();
    return AppCache(
      providers: providers,
      prefs: prefs,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  void updateChannel(db.Channel updatedChannel) {
    // channels are now fetched directly from SQLite to save memory
  }

  void updateCategoryPreference(db.CategoryPreference updatedPref) {
    if (!state.hasValue) return;
    final cache = state.value!;
    final newPrefs = cache.prefs.toList();
    final index = newPrefs.indexWhere((p) => 
        p.providerId == updatedPref.providerId && 
        p.groupTitle == updatedPref.groupTitle && 
        p.streamType == updatedPref.streamType);
    if (index != -1) {
      newPrefs[index] = updatedPref;
    } else {
      newPrefs.add(updatedPref);
    }
    state = AsyncData(cache.copyWith(prefs: newPrefs));
  }
}

final appCacheProvider = AsyncNotifierProvider<AppCacheNotifier, AppCache>(() {
  return AppCacheNotifier();
});
