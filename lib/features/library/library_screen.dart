import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/local/database.dart' as db;
import '../media_shared_widgets.dart';
import '../providers/provider_manager.dart';
import '../providers/app_cache_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _loading = true;
  List<db.Channel> _favLive = [];
  List<db.Channel> _favMovies = [];
  List<db.Channel> _favSeries = [];
  List<db.CategoryPreference> _favCategories = [];

  final FocusNode _emptyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final database = ref.read(databaseProvider);
    final allFavs = await database.getFavoriteChannels();
    
    _favLive = allFavs.where((c) => c.streamType == 'live').toList();
    _favMovies = allFavs.where((c) => c.streamType == 'movie').toList();
    _favSeries = allFavs.where((c) => c.streamType == 'series').toList();
    _favCategories = await database.getFavoriteCategories();

    if (mounted) {
      setState(() => _loading = false);
      if (_favLive.isEmpty && _favMovies.isEmpty && _favSeries.isEmpty && _favCategories.isEmpty) {
        // Request focus on the empty state to prevent DPAD getting stuck
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _emptyFocusNode.canRequestFocus) {
            _emptyFocusNode.requestFocus();
          }
        });
      }
    }
  }

  void _playChannel(db.Channel ch) {
    if (ch.streamType == 'live') {
      context.push('/player', extra: {
        'streamUrl': ch.streamUrl,
        'channelName': ch.name,
        'channelLogo': ch.tvgLogo,
        'alternativeUrls': <String>[],
        'channels': _favLive.map((c) => c.toJson()).toList(),
        'currentIndex': _favLive.indexWhere((c) => c.id == ch.id),
      });
    } else if (ch.streamType == 'movie') {
      context.push('/movies/details', extra: ch);
    } else {
      context.push('/series/details', extra: ch);
    }
  }

  Future<void> _toggleChannelFavourite(db.Channel channel) async {
    final database = ref.read(databaseProvider);
    await database.setChannelFavorite(channel.id, !channel.favorite);
    _load();
  }

  Future<void> _toggleCategoryFavourite(db.CategoryPreference pref) async {
    final database = ref.read(databaseProvider);
    await database.setCategoryFavourite(pref.providerId, pref.groupTitle, pref.streamType, !pref.isFavourite);
    _load();
  }

  Widget _buildSection(String title, List<db.Channel> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final ch = items[i];
              return SizedBox(
                width: 150,
                child: MediaPosterCard(
                  channel: ch,
                  onTap: () => _playChannel(ch),
                  onEnter: () => _playChannel(ch),
                  onHide: () {},
                  onLock: () {},
                  onFavourite: () => _toggleChannelFavourite(ch),
                  onFocus: (f) {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    if (_favCategories.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Text('Favourited Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _favCategories.length,
            itemBuilder: (ctx, i) {
              final pref = _favCategories[i];
              return SizedBox(
                width: 250,
                child: CategorySidebarTile(
                  label: pref.groupTitle,
                  selected: false,
                  isFavourite: pref.isFavourite,
                  isLocked: pref.parentalLocked,
                  onTap: () {
                    // Navigate to the respective screen and category
                    if (pref.streamType == 'live') {
                      context.go('/live?category=${Uri.encodeComponent(pref.groupTitle)}&providerId=${Uri.encodeComponent(pref.providerId)}');
                    } else if (pref.streamType == 'movie') {
                      context.go('/movies?category=${Uri.encodeComponent(pref.groupTitle)}&providerId=${Uri.encodeComponent(pref.providerId)}');
                    } else {
                      context.go('/series?category=${Uri.encodeComponent(pref.groupTitle)}&providerId=${Uri.encodeComponent(pref.providerId)}');
                    }
                  },
                  onFavourite: () => _toggleCategoryFavourite(pref),
                  onHide: () {},
                  onLock: () {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppCache>>(appCacheProvider, (previous, next) {
      if (next is AsyncData && !next.isLoading) {
        if (mounted) _load();
      }
    });

    if (_loading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    final isEmpty = _favLive.isEmpty && _favMovies.isEmpty && _favSeries.isEmpty && _favCategories.isEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: isEmpty
          ? Center(
              child: Focus(
                focusNode: _emptyFocusNode,
                autofocus: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.video_library_rounded, size: 64, color: Colors.white24),
                    SizedBox(height: 16),
                    Text('Your library is empty.\nFavourite items to see them here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.white60)),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),
                  _buildSection('Favourited Live TV', _favLive),
                  _buildSection('Favourited Movies', _favMovies),
                  _buildSection('Favourited Series', _favSeries),
                  _buildCategoriesSection(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }
}
