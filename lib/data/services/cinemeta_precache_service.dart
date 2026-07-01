import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/providers/provider_manager.dart' show databaseProvider;
import '../datasources/local/database.dart' as db;
import '../repositories/cinemeta_scraper.dart';

final cinemetaPrecacheServiceProvider = Provider<CinemetaPrecacheService>((ref) {
  return CinemetaPrecacheService(
    ref.watch(databaseProvider),
    ref.watch(tmdbMetadataScraperProvider),
  );
});

class CinemetaPrecacheService {
  final db.AppDatabase _db;
  final CinemetaMetadataScraper _scraper;
  bool _isRunning = false;

  CinemetaPrecacheService(this._db, this._scraper);

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final channels = await _db.getAllChannels();
      final movies = channels.where((c) => c.streamType == 'movie').toList();
      final series = channels.where((c) => c.streamType == 'series').toList();

      // Precache movies
      for (final m in movies) {
        if (!_isRunning) break;
        await _scraper.fetchMovieMetadata(m.name);
        // Add a tiny delay to not hammer the TMDB API and block event loop
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Precache series
      for (final s in series) {
        if (!_isRunning) break;
        await _scraper.fetchSeriesMetadata(s.name);
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      debugPrint('Precaching failed: $e');
    } finally {
      _isRunning = false;
    }
  }
  
  void stop() {
    _isRunning = false;
  }
}
