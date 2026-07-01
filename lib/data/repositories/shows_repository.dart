import 'package:logger/logger.dart';
import '../datasources/remote/trakt_client.dart';
import '../datasources/remote/cinemeta_client.dart';
import '../datasources/remote/debrid_service.dart';
import '../datasources/remote/torrent_search_client.dart';
import '../models/show.dart';

/// Combines Trakt, TMDB, debrid, and torrent search into a unified shows data source
class ShowsRepository {
  final TraktClient? _trakt;
  final CinemetaClient? _cinemeta;
  final DebridService? _debrid;
  final TorrentSearchClient _torrentSearch;
  final _log = Logger(printer: SimplePrinter());

  ShowsRepository({
    TraktClient? trakt,
    CinemetaClient? tmdb,
    DebridService? debrid,
    TorrentSearchClient? torrentSearch,
  })  : _trakt = trakt,
        _cinemeta = tmdb,
        _debrid = debrid,
        _torrentSearch = torrentSearch ?? TorrentSearchClient();

  bool get hasTrakt => _trakt != null;
  bool get hasCinemeta => true;
  bool get hasDebrid => _debrid != null;

  /// Get trending shows, enriched with TMDB posters
  Future<List<Show>> getTrendingShows({int page = 1, int limit = 20}) async {
    if (_trakt != null) {
      final shows = await _trakt.getTrendingShows(page: page, limit: limit);
      return _enrichWithTmdb(shows);
    }
    if (_cinemeta != null) {
      return _cinemetaResultsToShows(await _cinemeta.getTrendingTv(skip: (page - 1) * 20), ShowType.show);
    }
    return [];
  }

  /// Get popular shows, enriched with TMDB posters
  Future<List<Show>> getPopularShows({int page = 1, int limit = 20}) async {
    if (_trakt != null) {
      final shows = await _trakt.getPopularShows(page: page, limit: limit);
      return _enrichWithTmdb(shows);
    }
    if (_cinemeta != null) {
      return _cinemetaResultsToShows(await _cinemeta.getPopularTv(skip: (page - 1) * 20), ShowType.show);
    }
    return [];
  }

  /// Get trending movies, enriched with TMDB posters
  Future<List<Show>> getTrendingMovies({int page = 1, int limit = 20}) async {
    if (_trakt != null) {
      final shows = await _trakt.getTrendingMovies(page: page, limit: limit);
      return _enrichWithTmdb(shows);
    }
    if (_cinemeta != null) {
      return _cinemetaResultsToShows(await _cinemeta.getTrendingMovie(skip: (page - 1) * 20), ShowType.movie);
    }
    return [];
  }

  /// Get popular movies, enriched with TMDB posters
  Future<List<Show>> getPopularMovies({int page = 1, int limit = 20}) async {
    if (_trakt != null) {
      final shows = await _trakt.getPopularMovies(page: page, limit: limit);
      return _enrichWithTmdb(shows);
    }
    if (_cinemeta != null) {
      return _cinemetaResultsToShows(await _cinemeta.getPopularMovie(skip: (page - 1) * 20), ShowType.movie);
    }
    return [];
  }

  /// Search shows and movies
  Future<List<Show>> search(String query) async {
    if (_trakt != null) {
      final results = await _trakt.search(query);
      return _enrichWithTmdb(results);
    }
    if (_cinemeta != null) {
      final tvResults = await _cinemeta.searchTv(query);
      final movieResults = await _cinemeta.searchMovie(query);
      return [
        ..._cinemetaResultsToShows(tvResults, ShowType.show),
        ..._cinemetaResultsToShows(movieResults, ShowType.movie),
      ];
    }
    return [];
  }

  /// Get full show detail with seasons
  Future<ShowDetail?> getShowDetail(int traktId, {ShowType type = ShowType.show}) async {
    // Trakt-based detail
    if (_trakt != null) {
      final show = type == ShowType.movie
          ? await _trakt.getMovie(traktId)
          : await _trakt.getShow(traktId);
      final enriched = await _enrichSingle(show);

      List<Season> seasons = [];
      if (type == ShowType.show) {
        seasons = await _trakt.getSeasons(traktId);
        seasons = seasons.where((s) => s.number > 0).toList();
        if (_cinemeta != null && enriched.cinemetaId != null) {
          seasons = await _enrichSeasons(enriched.cinemetaId!, seasons);
        }
      }
      return ShowDetail(show: enriched, seasons: seasons);
    }

    // TMDB-only fallback — traktId is actually cinemetaId in this case
    if (_cinemeta != null) {
      return _getShowDetailFromTmdb(traktId.toString(), type: type);
    }

    return null;
  }

  /// TMDB-only show detail
  Future<ShowDetail?> _getShowDetailFromTmdb(String cinemetaId, {ShowType type = ShowType.show}) async {
    if (_cinemeta == null) return null;
    try {
      final detail = type == ShowType.movie
          ? await _cinemeta.getMovie(cinemetaId)
          : await _cinemeta.getTvShow(cinemetaId);

      _log.i('TMDB detail for $cinemetaId: title=${detail.title}, imdb=${detail.imdbId}, seasons=${detail.numberOfSeasons}');

      final show = Show(
        traktId: 0,
        cinemetaId: cinemetaId,
        imdbId: detail.imdbId,
        title: detail.title,
        posterUrl: (detail.posterUrl?.isNotEmpty ?? false) ? detail.posterUrl : null,
        backdropUrl: (detail.backdropUrl?.isNotEmpty ?? false) ? detail.backdropUrl : null,
        overview: detail.overview,
        rating: detail.voteAverage,
        votes: detail.voteCount,
        year: detail.year,
        genres: detail.genres,
        type: type,
      );

      // For TV shows, build seasons list from TMDB
      List<Season> seasons = [];
      if (type == ShowType.show) {
        final numSeasons = detail.numberOfSeasons ?? 0;
        _log.i('Fetching $numSeasons seasons for ${detail.title}');
        for (int i = 1; i <= numSeasons; i++) {
          try {
            // final tmdbSeason = await _cinemeta.getTvSeason(cinemetaId, i);
            /* seasons.add(Season(
              number: i,
              overview: tmdbSeason.overview,
              episodeCount: tmdbSeason.episodes.length,
              airedEpisodes: tmdbSeason.episodes.length,
              posterUrl: tmdbSeason.posterPath != null
                  ? CinemetaClient.posterUrl(tmdbSeason.posterPath)
                  : null,
            )); */
          } catch (e) {
            _log.w('Failed to fetch season $i for $cinemetaId: $e');
            seasons.add(Season(number: i));
          }
        }
      }

      return ShowDetail(show: show, seasons: seasons);
    } catch (e) {
      _log.e('TMDB detail failed for $cinemetaId: $e');
      return null;
    }
  }

  /// Get episodes for a season
  Future<List<Episode>> getEpisodes(int traktId, int seasonNumber) async {
    // Trakt-based
    if (_trakt != null) {
      final episodes = await _trakt.getEpisodes(traktId, seasonNumber);
      if (_cinemeta != null) {
        try {
          final show = await _trakt.getShow(traktId);
          if (show.cinemetaId != null) {
            return _enrichEpisodesWithTmdb(episodes, show.cinemetaId!, seasonNumber);
          }
        } catch (_) {}
      }
      return episodes;
    }

    // TMDB-only fallback — traktId is actually cinemetaId
    if (_cinemeta != null) {
      return _getEpisodesFromTmdb(traktId.toString(), seasonNumber);
    }

    return [];
  }

  /// Get episodes directly from TMDB
  Future<List<Episode>> _getEpisodesFromTmdb(String cinemetaId, int seasonNumber) async {
    /* if (_cinemeta == null) return [];
    try {
      final tmdbSeason = await _cinemeta.getTvSeason(cinemetaId, seasonNumber);
      return tmdbSeason.episodes.map((e) => Episode(
        season: seasonNumber,
        number: e.episodeNumber,
        title: e.name,
        overview: e.overview,
        rating: e.voteAverage,
        stillUrl: e.stillUrl.isNotEmpty ? e.stillUrl : null,
        cinemetaId: e.episodeNumber,
      )).toList();
    } catch (e) {
      _log.e('TMDB episodes failed for $cinemetaId S$seasonNumber: $e');
      return [];
    } */
    return [];
  }

  /// Find streams for a show/movie. Returns both cached (instant) and
  /// non-cached torrent sources so the user can pick.
  Future<List<ResolvedStream>> resolveStreams({
    required String imdbId,
    int? season,
    int? episode,
  }) async {
    // Step 1: Search for torrent hashes via Torrentio
    List<TorrentResult> torrents;
    if (season != null && episode != null) {
      torrents = await _torrentSearch.searchEpisode(
        imdbId,
        season: season,
        episode: episode,
      );
    } else {
      torrents = await _torrentSearch.searchMovie(imdbId);
    }

    if (torrents.isEmpty) {
      _log.w('No torrents found for $imdbId');
      return [];
    }

    // Sort by quality (best first)
    torrents.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));

    // Step 2: Check debrid instant availability
    Set<String> cachedHashes = {};
    if (_debrid != null) {
      try {
        final hashes = torrents.map((t) => t.infoHash).toList();
        final available = await _debrid.checkInstantAvailability(hashes);
        cachedHashes = available.keys.toSet();
      } catch (e) {
        _log.w('Debrid availability check failed: $e');
      }
    }

    // Step 3: Build stream list — cached first, then non-cached
    final results = <ResolvedStream>[];
    for (final torrent in torrents) {
      final hashLower = torrent.infoHash.toLowerCase();
      final cached = cachedHashes.contains(hashLower);
      results.add(ResolvedStream(
        url: '', // resolved on-demand when user picks
        filename: torrent.title.isNotEmpty ? torrent.title : torrent.name,
        quality: torrent.quality.isNotEmpty ? torrent.quality : null,
        filesize: null,
        source: cached ? 'real-debrid ⚡' : 'torrent',
        isCached: cached,
        magnetUrl: torrent.magnetUrl,
        seeds: torrent.seeds,
      ));
      if (results.length >= 10) break;
    }

    // Sort: cached first, then by quality
    results.sort((a, b) {
      if (a.isCached != b.isCached) return a.isCached ? -1 : 1;
      return 0;
    });

    return results;
  }

  /// Resolve a specific torrent via Real-Debrid (add magnet → wait → stream URL)
  Future<ResolvedStream?> resolveMagnet(
    String magnetUrl, {
    void Function(String status, int progress)? onProgress,
  }) async {
    if (_debrid == null) {
      throw Exception('No Real-Debrid API key configured');
    }
    return await _debrid.resolveFromMagnet(magnetUrl, onProgress: onProgress);
  }

  /// Enrich a list of shows with TMDB poster/backdrop URLs
  Future<List<Show>> _enrichWithTmdb(List<Show> shows) async {
    if (_cinemeta == null) return shows;

    final enriched = <Show>[];
    for (final show in shows) {
      enriched.add(await _enrichSingle(show));
    }
    return enriched;
  }

  /// Enrich seasons with TMDB posters/overviews
  Future<List<Season>> _enrichSeasons(String cinemetaId, List<Season> seasons) async {
    if (_cinemeta == null) return seasons;
    final result = <Season>[];
    for (final season in seasons) {
      try {
        // final tmdbSeason = await _cinemeta.getTvSeason(cinemetaId, season.number);
        result.add(Season(
          number: season.number,
          title: season.title,
          overview: season.overview,
          episodeCount: season.episodeCount,
          airedEpisodes: season.airedEpisodes,
          rating: season.rating,
          /* posterUrl: tmdbSeason.posterPath != null
              ? CinemetaClient.posterUrl(tmdbSeason.posterPath)
              : null, */
          firstAired: season.firstAired,
          traktId: season.traktId,
          cinemetaId: season.cinemetaId,
        ));
      } catch (_) {
        result.add(season);
      }
    }
    return result;
  }

  /// Enrich Trakt episodes with TMDB stills
  Future<List<Episode>> _enrichEpisodesWithTmdb(
      List<Episode> episodes, String cinemetaId, int seasonNumber) async {
    /* if (_cinemeta == null) return episodes;
    try {
      final tmdbSeason = await _cinemeta.getTvSeason(cinemetaId, seasonNumber);
      final tmdbEpMap = {for (final e in tmdbSeason.episodes) e.episodeNumber: e};
      return episodes.map((ep) {
        final tmdbEp = tmdbEpMap[ep.number];
        if (tmdbEp == null) return ep;
        return Episode(
          season: ep.season,
          number: ep.number,
          title: ep.title ?? tmdbEp.name,
          overview: ep.overview ?? tmdbEp.overview,
          rating: ep.rating,
          votes: ep.votes,
          runtime: ep.runtime,
          firstAired: ep.firstAired,
          stillUrl: tmdbEp.stillUrl.isNotEmpty ? tmdbEp.stillUrl : null,
          traktId: ep.traktId,
          cinemetaId: ep.cinemetaId,
        );
      }).toList();
    } catch (_) {
      return episodes;
    } */
    return episodes;
  }

  /// Enrich a single show with TMDB images and IMDB ID
  Future<Show> _enrichSingle(Show show) async {
    if (_cinemeta == null || show.cinemetaId == null) return show;
    try {
      final detail = show.type == ShowType.movie
          ? await _cinemeta.getMovie(show.cinemetaId!)
          : await _cinemeta.getTvShow(show.cinemetaId!);
      return show.copyWith(
        imdbId: detail.imdbId,
        posterUrl: (detail.posterUrl?.isNotEmpty ?? false) ? detail.posterUrl : null,
        backdropUrl: (detail.backdropUrl?.isNotEmpty ?? false) ? detail.backdropUrl : null,
        overview: show.overview ?? detail.overview,
      );
    } catch (e) {
      _log.w('TMDB enrichment failed for ${show.title}: $e');
      return show;
    }
  }

  /// Convert TMDB search results to Show objects (fallback when Trakt unavailable)
  List<Show> _cinemetaResultsToShows(List<CinemetaSearchResult> results, ShowType type) {
    return results.map((r) => Show(
      traktId: 0,
      cinemetaId: r.id,
      title: r.displayName,
      year: r.year,
      overview: r.overview,
      rating: r.voteAverage,
      posterUrl: (r.posterUrl?.isNotEmpty ?? false) ? r.posterUrl : null,
      backdropUrl: (r.backdropUrl?.isNotEmpty ?? false) ? r.backdropUrl : null,
      type: type,
    )).toList();
  }
}
