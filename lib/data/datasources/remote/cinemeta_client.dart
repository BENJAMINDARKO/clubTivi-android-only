import 'package:dio/dio.dart';

/// Client for Stremio's Cinemeta API v3
class CinemetaClient {
  final Dio _dio;

  CinemetaClient({
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = 'https://v3-cinemeta.strem.io'
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 15);
  }

  /// Get TV show details including images and external IDs
  Future<CinemetaShowDetail> getTvShow(String cinemetaId) async {
    final response = await _dio.get('/meta/series/$cinemetaId.json');
    return CinemetaShowDetail.fromJson(response.data['meta'] as Map<String, dynamic>);
  }

  /// Get movie details including images and external IDs
  Future<CinemetaShowDetail> getMovie(String cinemetaId) async {
    final response = await _dio.get('/meta/movie/$cinemetaId.json');
    return CinemetaShowDetail.fromJson(response.data['meta'] as Map<String, dynamic>);
  }

  /// Search for TV shows
  Future<List<CinemetaSearchResult>> searchTv(String query) async {
    final response = await _dio.get('/catalog/series/top/search=${Uri.encodeComponent(query)}.json');
    final metas = response.data['metas'] as List?;
    if (metas == null || metas.isEmpty) return [];
    return metas.map((e) => CinemetaSearchResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Search for movies
  Future<List<CinemetaSearchResult>> searchMovie(String query) async {
    final response = await _dio.get('/catalog/movie/top/search=${Uri.encodeComponent(query)}.json');
    final metas = response.data['metas'] as List?;
    if (metas == null || metas.isEmpty) return [];
    return metas.map((e) => CinemetaSearchResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get trending TV shows
  Future<List<CinemetaSearchResult>> getTrendingTv({int skip = 0}) async {
    final response = await _dio.get('/catalog/series/top/skip=$skip.json');
    final metas = response.data['metas'] as List?;
    if (metas == null || metas.isEmpty) return [];
    return metas.map((e) => CinemetaSearchResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get trending movies
  Future<List<CinemetaSearchResult>> getTrendingMovie({int skip = 0}) async {
    final response = await _dio.get('/catalog/movie/top/skip=$skip.json');
    final metas = response.data['metas'] as List?;
    if (metas == null || metas.isEmpty) return [];
    return metas.map((e) => CinemetaSearchResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get popular TV shows (just uses top)
  Future<List<CinemetaSearchResult>> getPopularTv({int skip = 0}) async {
    return getTrendingTv(skip: skip);
  }

  /// Get popular movies (just uses top)
  Future<List<CinemetaSearchResult>> getPopularMovie({int skip = 0}) async {
    return getTrendingMovie(skip: skip);
  }
}

class CinemetaSearchResult {
  final String id;
  final String? name;
  final String? posterUrl;
  final String? backdropUrl;
  final String? overview;
  final double? voteAverage;
  final int? year;
  final String? runtime;

  CinemetaSearchResult({
    required this.id,
    this.name,
    this.posterUrl,
    this.backdropUrl,
    this.overview,
    this.voteAverage,
    this.year,
    this.runtime,
  });

  factory CinemetaSearchResult.fromJson(Map<String, dynamic> json) {
    String parseYear(dynamic releaseInfo) {
      if (releaseInfo == null) return '';
      if (releaseInfo is num) return releaseInfo.toString();
      if (releaseInfo is String) {
        if (releaseInfo.length >= 4) return releaseInfo.substring(0, 4);
      }
      return '';
    }

    final yearStr = parseYear(json['releaseInfo'] ?? json['year']);
    final year = yearStr.isNotEmpty ? int.tryParse(yearStr) : null;
    
    // Parse rating safely
    double? rating;
    if (json['imdbRating'] != null) {
      if (json['imdbRating'] is num) {
        rating = (json['imdbRating'] as num).toDouble();
      } else if (json['imdbRating'] is String) {
        rating = double.tryParse(json['imdbRating'] as String);
      }
    }

    return CinemetaSearchResult(
      id: json['id'] as String,
      name: json['name'] as String?,
      posterUrl: json['poster'] as String?,
      backdropUrl: json['background'] as String?,
      overview: json['description'] as String?,
      voteAverage: rating,
      year: year,
      runtime: json['runtime'] as String?,
    );
  }

  String get displayName => name ?? 'Unknown';
}

class CinemetaShowDetail {
  final String id;
  final String title;
  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
  final double? voteAverage;
  final int? voteCount;
  final int? year;
  final List<String> genres;
  final List<String> cast;
  final String? imdbId;
  final int? numberOfSeasons;
  final String? runtime;

  CinemetaShowDetail({
    required this.id,
    required this.title,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.voteAverage,
    this.voteCount,
    this.year,
    required this.genres,
    required this.cast,
    this.imdbId,
    this.numberOfSeasons,
    this.runtime,
  });

  factory CinemetaShowDetail.fromJson(Map<String, dynamic> json) {
    String parseYear(dynamic releaseInfo) {
      if (releaseInfo == null) return '';
      if (releaseInfo is num) return releaseInfo.toString();
      if (releaseInfo is String) {
        if (releaseInfo.length >= 4) return releaseInfo.substring(0, 4);
      }
      return '';
    }

    final yearStr = parseYear(json['releaseInfo'] ?? json['year']);
    final year = yearStr.isNotEmpty ? int.tryParse(yearStr) : null;
    
    // Parse rating safely
    double? rating;
    if (json['imdbRating'] != null) {
      if (json['imdbRating'] is num) {
        rating = (json['imdbRating'] as num).toDouble();
      } else if (json['imdbRating'] is String) {
        rating = double.tryParse(json['imdbRating'] as String);
      }
    }

    return CinemetaShowDetail(
      id: json['id'] as String,
      imdbId: json['imdb_id'] as String? ?? json['id'] as String,
      title: json['name'] as String? ?? 'Unknown',
      overview: json['description'] as String?,
      posterUrl: json['poster'] as String?,
      backdropUrl: json['background'] as String?,
      voteAverage: rating,
      voteCount: null,
      year: year,
      numberOfSeasons: null,
      genres: (json['genres'] as List?)?.map((g) {
        if (g is String) return g;
        if (g is Map) return g['name'] as String? ?? '';
        return '';
      }).where((g) => g.isNotEmpty).toList() ?? [],
      cast: (json['cast'] as List?)?.take(5).map((c) {
        if (c is String) return c;
        if (c is Map) return c['name'] as String? ?? '';
        return '';
      }).where((c) => c.isNotEmpty).toList() ?? [],
      runtime: json['runtime'] as String?,
    );
  }
}
