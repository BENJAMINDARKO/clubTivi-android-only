import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/remote/cinemeta_client.dart';
import '../../features/shows/shows_providers.dart';

final tmdbMetadataScraperProvider = Provider<CinemetaMetadataScraper>((ref) {
  final client = CinemetaClient();
  return CinemetaMetadataScraper(client);
});

class CinemetaMetadataScraper {
  final CinemetaClient? _client;
  final Map<String, CinemetaSearchResult?> _cache = {};

  CinemetaMetadataScraper(this._client);

  Future<CinemetaSearchResult?> fetchMovieMetadata(String title) async {
    if (_client == null) return null;
    
    // Clean up title (remove trailing years if any like "Avatar (2009)")
    final cleanedTitle = cleanTitle(title);
    
    if (_cache.containsKey(cleanedTitle)) {
      return _cache[cleanedTitle];
    }

    try {
      final results = await _client.searchMovie(cleanedTitle);
      if (results.isNotEmpty) {
        _cache[cleanedTitle] = results.first;
        return results.first;
      }
      
      // Fallback to TV search if movie search fails (for Series screen)
      final tvResults = await _client.searchTv(cleanedTitle);
      if (tvResults.isNotEmpty) {
        _cache[cleanedTitle] = tvResults.first;
        return tvResults.first;
      }

      _cache[cleanedTitle] = null;
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<CinemetaSearchResult?> fetchSeriesMetadata(String title) async {
    if (_client == null) return null;
    
    final cleanedTitle = cleanTitle(title);
    
    if (_cache.containsKey(cleanedTitle)) {
      return _cache[cleanedTitle];
    }

    try {
      final results = await _client.searchTv(cleanedTitle);
      if (results.isNotEmpty) {
        _cache[cleanedTitle] = results.first;
        return results.first;
      }
      
      // Fallback to movie search if tv search fails
      final movieResults = await _client.searchMovie(cleanedTitle);
      if (movieResults.isNotEmpty) {
        _cache[cleanedTitle] = movieResults.first;
        return movieResults.first;
      }

      _cache[cleanedTitle] = null;
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<CinemetaShowDetail?> getTvShow(String cinemetaId) async {
    if (_client == null) return null;
    try {
      return await _client!.getTvShow(cinemetaId);
    } catch (_) {
      return null;
    }
  }

  Future<CinemetaShowDetail?> getMovie(String cinemetaId) async {
    if (_client == null) return null;
    try {
      return await _client!.getMovie(cinemetaId);
    } catch (_) {
      return null;
    }
  }

  Future<List<CinemetaSearchResult>> getTvRecommendations(String cinemetaId) async {
    return [];
  }

  Future<List<CinemetaSearchResult>> getMovieRecommendations(String cinemetaId) async {
    return [];
  }

  static String cleanTitle(String title) {
    // Strip prefix ending with ' - ' (e.g., "AF-FR - HABIBA")
    var clean = title.replaceFirst(RegExp(r'^.*?\s+-\s+'), '');
    // Replace any subsequent hyphens with spaces
    clean = clean.replaceAll('-', ' ');
    // Remove years in parentheses
    clean = clean.replaceAll(RegExp(r'\(\d{4}\)'), '');
    // Remove bracketed text
    clean = clean.replaceAll(RegExp(r'\[.*?\]'), '');
    // Remove multiple spaces
    clean = clean.replaceAll(RegExp(r'\s+'), ' ');
    return clean.trim();
  }
}
