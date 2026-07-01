import 'package:go_router/go_router.dart';

import '../core/platform_info.dart';
import '../features/channels/channels_screen.dart';
import '../features/guide/guide_screen.dart';
import '../features/player/player_screen.dart';
import '../features/providers/providers_screen.dart';
import '../features/epg_mapping/epg_mapping_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/debrid_services_screen.dart';
import '../features/shows/shows_screen.dart';
import '../features/shows/show_detail_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/live/live_screen.dart';
import '../features/movies/movies_screen.dart';
import '../features/series/series_screen.dart';
import '../features/search/search_screen.dart';
import '../features/parental/parental_screen.dart';
import '../features/parental/parental_category_screen.dart';
import '../platform/tv/tv_shell.dart';
import '../data/models/show.dart';
import '../data/datasources/local/database.dart' as db;
import '../features/movies/iptv_movie_detail_screen.dart';
import '../features/series/iptv_series_detail_screen.dart';
import '../features/library/library_screen.dart';

GoRouter createRouter() {
  // Routes that live inside the TV sidebar shell
  final tvShellRoute = StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => TvShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const LibraryScreen(),
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/live',
            builder: (context, state) => LiveScreen(
              category: state.uri.queryParameters['category'],
              providerId: state.uri.queryParameters['providerId'],
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/movies',
            builder: (context, state) => MoviesScreen(
              category: state.uri.queryParameters['category'],
              providerId: state.uri.queryParameters['providerId'],
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/series',
            builder: (context, state) => SeriesScreen(
              category: state.uri.queryParameters['category'],
              providerId: state.uri.queryParameters['providerId'],
            ),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/parental',
            builder: (context, state) => const ParentalScreen(),
          ),
        ],
      ),
    ],
  );

  // Non-TV sidebar routes
  final sidebarRoutes = [
    GoRoute(
      path: '/guide',
      builder: (context, state) => const GuideScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/providers',
      builder: (context, state) => const ProvidersScreen(),
    ),
    GoRoute(
      path: '/epg-mapping',
      builder: (context, state) => const EpgMappingScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/debrid-services',
      builder: (context, state) => const DebridServicesScreen(),
    ),
  ];

  // Routes outside the shell (player, shows detail, splash, etc.)
  final standaloneRoutes = [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return PlayerScreen(
          streamUrl: extra['streamUrl'] as String? ?? '',
          channelName: extra['channelName'] as String? ?? '',
          channelLogo: extra['channelLogo'] as String?,
          alternativeUrls:
              (extra['alternativeUrls'] as List<String>?) ?? const [],
          channels:
              (extra['channels'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              const [],
          currentIndex: extra['currentIndex'] as int? ?? 0,
        );
      },
    ),
    GoRoute(
      path: '/shows',
      builder: (context, state) => const ShowsScreen(),
    ),
    GoRoute(
      path: '/shows/:id',
      builder: (context, state) {
        final traktId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final show = state.extra as Show?;
        return ShowDetailScreen(traktId: traktId, initialShow: show);
      },
    ),
    GoRoute(
      path: '/parental_category',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ParentalCategoryScreen(
          providerId: extra['providerId'] as String? ?? '',
          groupTitle: extra['groupTitle'] as String? ?? '',
          streamType: extra['streamType'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/movies/details',
      builder: (context, state) {
        final channel = state.extra as db.Channel;
        return IptvMovieDetailScreen(channel: channel);
      },
    ),
    GoRoute(
      path: '/series/details',
      builder: (context, state) {
        final channel = state.extra as db.Channel;
        return IptvSeriesDetailScreen(channel: channel);
      },
    ),
  ];

  if (PlatformInfo.isTV) {
    return GoRouter(
      initialLocation: '/splash',
      routes: [
        tvShellRoute,
        ...sidebarRoutes,
        ...standaloneRoutes,
      ],
    );
  }

  // Non-TV: flat routes (original behavior)
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/live',
        builder: (context, state) => const LiveScreen(),
      ),
      GoRoute(
        path: '/movies',
        builder: (context, state) => const MoviesScreen(),
      ),
      GoRoute(
        path: '/series',
        builder: (context, state) => const SeriesScreen(),
      ),
      GoRoute(
        path: '/parental',
        builder: (context, state) => const ParentalScreen(),
      ),
      ...sidebarRoutes,
      ...standaloneRoutes,
    ],
  );
}

/// Global router instance — initialized lazily.
late final GoRouter router = createRouter();
