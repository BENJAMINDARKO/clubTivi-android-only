import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/remote/cinemeta_client.dart';
import '../../data/repositories/cinemeta_scraper.dart';
import '../../ui/backdrop.dart';
import '../../data/datasources/local/database.dart' as db;
import '../../data/services/parental_control_service.dart';
import '../media_shared_widgets.dart';
import '../player/player_service.dart';
import '../providers/provider_manager.dart';
import '../providers/app_cache_provider.dart';

class MoviesScreen extends ConsumerStatefulWidget {
  final String? category;
  final String? providerId;
  const MoviesScreen({super.key, this.category, this.providerId});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  static const _streamType = 'vod';

  bool _loading = true;
  String _selectedProviderId = '';
  List<db.Provider> _providers = [];
  Map<String, List<String>> _providerGroups = {};
  List<db.Channel> _allChannels = [];
  Map<String, db.CategoryPreference> _catPrefs = {};
  List<db.Channel> _continueWatching = [];
  List<db.Channel> _latestAdded = [];
  
  // Category Navigation
  List<String> _allCategories = [];
  int _currentCategoryIndex = 0;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  // Sidebar
  bool _isSidebarVisible = false;
  final FocusScopeNode _sidebarFocusNode = FocusScopeNode();

  // Focus & Meta
  final FocusScopeNode _rowFocusNode = FocusScopeNode();
  final FocusNode _firstItemFocusNode = FocusNode();
  db.Channel? _focusedChannel;
  CinemetaSearchResult? _focusedMeta;
  CinemetaShowDetail? _focusedDetail;
  bool _fetchingMeta = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MoviesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.category != oldWidget.category || widget.providerId != oldWidget.providerId) && widget.category != null) {
      if (widget.providerId != null && widget.providerId != _selectedProviderId) {
        setState(() {
          _selectedProviderId = widget.providerId!;
        });
        _buildCategoryList().then((_) {
          _selectCategory(widget.category!);
        });
      } else {
        _selectCategory(widget.category!);
      }
    }
  }

  void _selectCategory(String catName) {
    if (_allCategories.isEmpty) return;
    final index = _allCategories.indexOf(catName);
    if (index != -1 && index != _currentCategoryIndex) {
      setState(() {
        _currentCategoryIndex = index;
        _focusedChannel = null;
        _rowFocusNode.requestFocus();
      });
      _loadChannelsForCurrentCategory();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _sidebarFocusNode.dispose();
    _rowFocusNode.dispose();
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  List<db.Channel> _currentCategoryChannels = [];

  Future<void> _load() async {
    final cache = await ref.read(appCacheProvider.future);
    final database = ref.read(databaseProvider);
    
    final continueWatching = await database.getRecentlyWatched(_streamType);
    final latestAdded = await database.getLatestAdded(_streamType);

    final providers = cache.providers;
    final prefs = cache.prefs;

    final groups = await database.getProviderGroups(_streamType);

    final catPrefsMap = <String, db.CategoryPreference>{};
    for (final p in prefs) {
      if (p.streamType != _streamType) continue;
      final key = '${p.providerId}|${p.groupTitle}|$_streamType';
      catPrefsMap[key] = p;
    }

    if (!mounted) return;
    setState(() {
      _providers = providers.where((p) => groups.containsKey(p.id)).toList();
      _providerGroups = groups;
      _catPrefs = catPrefsMap;
      _continueWatching = continueWatching;
      _latestAdded = latestAdded;

      if (widget.providerId != null && widget.providerId!.isNotEmpty && _providers.any((p) => p.id == widget.providerId)) {
        _selectedProviderId = widget.providerId!;
      } else if (_selectedProviderId.isEmpty && _providers.isNotEmpty) {
        _selectedProviderId = _providers.first.id;
      }
    });
    
    await _buildCategoryList();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _buildCategoryList() async {
    _allCategories = ['All Movies', 'Recently Added'];
    
    final groups = _providerGroups[_selectedProviderId] ?? [];
    for (final g in groups) {
      final pref = _catPrefs['$_selectedProviderId|$g|$_streamType'];
      if (pref == null || !pref.hidden) {
        if (g.isNotEmpty) _allCategories.add(g);
      }
    }
    
    if (_currentCategoryIndex >= _allCategories.length) {
      _currentCategoryIndex = 0;
    }
    
    if (widget.category != null) {
      final idx = _allCategories.indexOf(widget.category!);
      if (idx != -1) {
        _currentCategoryIndex = idx;
      }
    }
    
    await _loadChannelsForCurrentCategory();
  }

  Future<void> _loadChannelsForCurrentCategory() async {
    if (_allCategories.isEmpty) return;
    final category = _allCategories[_currentCategoryIndex];
    final database = ref.read(databaseProvider);
    List<db.Channel> channels;
    if (category == 'All Movies') {
      channels = await database.getChannelsForProviderType(_selectedProviderId, _streamType);
      channels = channels.where((c) => !c.hidden).toList();
    } else if (category == 'Recently Added' || category == 'Latest Added') {
      channels = await database.getChannelsForProviderType(_selectedProviderId, _streamType);
      channels = channels.where((c) => !c.hidden).toList().reversed.take(50).toList();
    } else if (category == 'Continue Watching') {
      channels = _continueWatching;
    } else {
      channels = await database.getChannelsForCategory(
        providerId: _selectedProviderId,
        groupTitle: category,
        streamType: _streamType,
        includeHidden: false,
      );
    }
    if (mounted) setState(() { _currentCategoryChannels = channels; });
  }

  List<db.Channel> _getChannelsForCategory() {
    List<db.Channel> channels = _currentCategoryChannels;
    
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      channels = channels.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    return channels;
  }

  void _onChannelFocus(db.Channel ch) async {
    if (_focusedChannel?.id == ch.id) return;
    setState(() {
      _focusedChannel = ch;
      _focusedMeta = null;
      _focusedDetail = null;
      _fetchingMeta = true;
    });
    
    final scraper = ref.read(tmdbMetadataScraperProvider);
    final meta = await scraper.fetchMovieMetadata(ch.name);
    CinemetaShowDetail? detail;
    if (meta != null) {
        detail = await scraper.getMovie(meta.id);
    }
    
    if (mounted && _focusedChannel?.id == ch.id) {
      setState(() {
        _focusedMeta = meta;
        _focusedDetail = detail;
        _fetchingMeta = false;
      });
    }
  }

  void _playChannel(db.Channel ch) {
    context.push('/movies/details', extra: ch);
  }

  Future<void> _hideChannel(db.Channel channel) async {
    final database = ref.read(databaseProvider);
    await database.hideChannel(channel.id, true);
    _load();
  }

  Future<void> _toggleChannelFavourite(db.Channel channel) async {
    final database = ref.read(databaseProvider);
    await database.setChannelFavorite(channel.id, !channel.favorite);
    _load();
  }

  Future<void> _lockChannel(db.Channel ch) async {
    final newValue = !ch.parentalLocked;
    await ref.read(databaseProvider).setChannelParentalLock(ch.id, newValue);
    ref.read(appCacheProvider.notifier).updateChannel(ch.copyWith(parentalLocked: newValue));
    _load();
  }

  Future<void> _hideCategory(String cat) async {
    final database = ref.read(databaseProvider);
    await database.hideCategory(_selectedProviderId, cat, _streamType, true);
    _load();
  }

  Future<void> _toggleCategoryFavourite(String cat, bool isFavourite) async {
    final database = ref.read(databaseProvider);
    await database.setCategoryFavourite(_selectedProviderId, cat, _streamType, !isFavourite);
    _load();
  }

  Future<void> _lockCategory(String cat, bool isLocked) async {
    final database = ref.read(databaseProvider);
    await database.setCategoryParentalLock(_selectedProviderId, cat, _streamType, !isLocked);
    _load();
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

    if (_providers.isEmpty || _allCategories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: const Text('Movies')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.movie_rounded, size: 64, color: Colors.white24),
              SizedBox(height: 16),
              Text('No movie content found',
                  style: TextStyle(fontSize: 18, color: Colors.white60)),
            ],
          ),
        ),
      );
    }

    final currentCategory = _allCategories[_currentCategoryIndex];
    final displayChannels = _getChannelsForCategory();
    
    final backdropUrl = (_focusedMeta?.backdropUrl?.isNotEmpty ?? false) 
        ? _focusedMeta!.backdropUrl 
        : _focusedChannel?.tvgLogo;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          BackdropLayer(imageUrl: backdropUrl),
          Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Left Sidebar
                SizedBox(
                  width: 250,
                  child: FocusScope(
                    node: _sidebarFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
                        _rowFocusNode.requestFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
                            child: Text('Categories', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          const Divider(color: Colors.white12),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _allCategories.length,
                              itemBuilder: (ctx, i) {
                                final cat = _allCategories[i];
                                final isSelected = i == _currentCategoryIndex;
                                final prefKey = '$_selectedProviderId|$cat|$_streamType';
                                final pref = _catPrefs[prefKey];
                                final isLocked = pref?.parentalLocked ?? false;

                                return CategorySidebarTile(
                                  label: cat,
                                  selected: isSelected,
                                  isFavourite: pref?.isFavourite ?? false,
                                  isLocked: isLocked,
                                  onTap: () async {
                                    setState(() {
                                      _currentCategoryIndex = i;
                                      _isSidebarVisible = false;
                                    });
                                    await _loadChannelsForCurrentCategory();
                                    _rowFocusNode.requestFocus();
                                  },
                                  onFavourite: () => _toggleCategoryFavourite(cat, pref?.isFavourite ?? false),
                                  onHide: () => _hideCategory(cat),
                                  onLock: () => _lockCategory(cat, isLocked),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Center: GridView + Search
                Expanded(
                  child: Column(
                    children: [
                      // Grid
                      Expanded(
                        child: FocusScope(
                          node: _rowFocusNode,
                          child: displayChannels.isEmpty
                            ? const Center(child: Text('No items found', style: TextStyle(color: Colors.white54)))
                            : GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                  childAspectRatio: 2/3,
                                  crossAxisSpacing: 32,
                                  mainAxisSpacing: 48,
                                ),
                                itemCount: displayChannels.length,
                                itemBuilder: (ctx, i) {
                                  final ch = displayChannels[i];
                                  return MediaPosterCard(
                                    focusNode: i == 0 ? _firstItemFocusNode : null,
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                        // Manually attempt to move left. If it fails (we are at the left edge),
                                        // then explicitly request focus on the sidebar.
                                        final moved = node.focusInDirection(TraversalDirection.left);
                                        if (!moved) {
                                          _sidebarFocusNode.requestFocus();
                                        }
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    channel: ch,
                                    autofocus: i == 0,
                                    onTap: () => _playChannel(ch),
                                    onHide: () => _hideChannel(ch),
                                    onLock: () => _lockChannel(ch),
                                    onFavourite: () => _toggleChannelFavourite(ch),
                                    onFocus: (f) {
                                      if (f) _onChannelFocus(ch);
                                    },
                                    onEnter: () => _playChannel(ch),
                                  );                                },
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Right Sidebar: Metadata
                Container(
                  width: 240,
                  color: Colors.black.withOpacity(0.5),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_focusedChannel != null)
                        Text(
                          _focusedMeta?.displayName ?? CinemetaMetadataScraper.cleanTitle(_focusedChannel!.name),
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_focusedMeta != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_focusedMeta!.year != null)
                              Text('${_focusedMeta!.year}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                            if (_focusedDetail?.runtime != null) ...[
                              if (_focusedMeta!.year != null)
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('•', style: TextStyle(color: Colors.white38))),
                              const Icon(Icons.schedule, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text(_focusedDetail!.runtime!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                            ],
                            if ((_focusedDetail?.voteAverage ?? 0) > 0) ...[
                              if (_focusedMeta!.year != null || _focusedDetail?.runtime != null)
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('•', style: TextStyle(color: Colors.white38))),
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(_focusedDetail!.voteAverage!.toStringAsFixed(1), style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_focusedDetail?.overview != null || _focusedMeta!.overview != null)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                _focusedDetail?.overview ?? _focusedMeta!.overview!,
                                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                              ),
                            ),
                          ),
                        if (_focusedDetail?.overview == null && _focusedMeta!.overview == null)
                          const Spacer(),
                      ] else ...[
                        const Spacer(),
                      ],
                                            if (_focusedDetail != null) ...[
                        if (_focusedDetail!.genres.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Genres', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_focusedDetail!.genres.join(', '), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                        if (_focusedDetail!.cast.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Top Cast', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_focusedDetail!.cast.join(', '), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ],

                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
