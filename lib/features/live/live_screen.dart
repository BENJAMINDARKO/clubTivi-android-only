import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/remote/cinemeta_client.dart';
import '../../data/repositories/cinemeta_scraper.dart';
import '../../ui/backdrop.dart';
import '../../core/pin_dialog.dart';
import '../../data/datasources/local/database.dart' as db;
import '../../data/services/parental_control_service.dart';
import '../media_shared_widgets.dart';
import '../player/player_service.dart';
import '../providers/provider_manager.dart';
import '../providers/app_cache_provider.dart';

class LiveScreen extends ConsumerStatefulWidget {
  final String? category;
  final String? providerId;
  const LiveScreen({super.key, this.category, this.providerId});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  static const _streamType = 'live';

  bool _loading = true;
  String _selectedProviderId = '';
  List<db.Provider> _providers = [];
  Map<String, List<String>> _providerGroups = {};
  List<db.Channel> _allChannels = [];
  Map<String, db.CategoryPreference> _catPrefs = {};
  
  // Category Navigation
  List<String> _allCategories = [];
  int _currentCategoryIndex = 0;
  bool _isSidebarVisible = false;

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  // Focus & Meta
  final FocusScopeNode _rowFocusNode = FocusScopeNode();
  final FocusScopeNode _sidebarFocusNode = FocusScopeNode();
  final FocusNode _firstItemFocusNode = FocusNode();
  db.Channel? _focusedChannel;
  int _focusedChannelIndex = 0;
  db.EpgProgramme? _focusedEpg;
  bool _fetchingMeta = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LiveScreen oldWidget) {
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
    _rowFocusNode.dispose();
    _sidebarFocusNode.dispose();
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  List<db.Channel> _currentCategoryChannels = [];

  Future<void> _load() async {
    final cache = await ref.read(appCacheProvider.future);
    final database = ref.read(databaseProvider);
    
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
    _allCategories = ['All Channels'];
    
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
    if (category == 'All Channels') {
      channels = await database.getChannelsForProviderType(_selectedProviderId, _streamType);
      channels = channels.where((c) => !c.hidden).toList();
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

  void _onChannelFocus(db.Channel ch, int index) async {
    if (_focusedChannel?.id == ch.id) return;
    setState(() {
      _focusedChannel = ch;
      _focusedChannelIndex = index;
      _focusedEpg = null;
      _fetchingMeta = true;
    });
    
    final database = ref.read(databaseProvider);
    final nowPlaying = await database.getNowPlaying([ch.id]);
    
    if (mounted && _focusedChannel?.id == ch.id) {
      setState(() {
        if (nowPlaying.isNotEmpty) {
          _focusedEpg = nowPlaying.first;
        }
        _fetchingMeta = false;
      });
    }
  }

  void _playChannel(db.Channel ch) async {
    final ps = ref.read(playerServiceProvider);
    await ps.play(
      ch.streamUrl,
      channelId: ch.id,
      channelName: ch.name,
      tvgId: ch.tvgId,
    );
    final channels = _getChannelsForCategory();
    final index = channels.indexWhere((c) => c.id == ch.id);

    if (!mounted) return;
    context.push('/player', extra: {
      'streamUrl': ch.streamUrl,
      'channelName': ch.name,
      'channelLogo': ch.tvgLogo,
      'alternativeUrls': <String>[],
      'channels': channels.map((c) => {
        'id': c.id,
        'providerId': c.providerId,
        'name': c.name,
        'originalName': c.name,
        'streamUrl': c.streamUrl,
        'tvgLogo': c.tvgLogo,
        'tvgId': c.tvgId,
        'tvgName': c.tvgName,
        'groupTitle': c.groupTitle,
        'streamType': c.streamType,
      }).toList(),
      'currentIndex': index >= 0 ? index : 0,
    });
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.live_tv_rounded, size: 64, color: Colors.white24),
              SizedBox(height: 16),
              Text('No live content found',
                  style: TextStyle(fontSize: 18, color: Colors.white60)),
            ],
          ),
        ),
      );
    }

    final currentCategory = _allCategories[_currentCategoryIndex];
    final displayChannels = _getChannelsForCategory();
    
    final backdropUrl = _focusedChannel?.tvgLogo;

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
                                  onTap: () {
                                    if (_currentCategoryIndex == i) return;
                                    setState(() {
                                      _currentCategoryIndex = i;
                                      _searchQuery = '';
                                      _isSidebarVisible = false;
                                    });
                                    _loadChannelsForCurrentCategory();
                                    _rowFocusNode.requestFocus();
                                    _firstItemFocusNode.requestFocus();
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
                
                // Right side: GridView + Search
                Expanded(
                  child: Column(
                    children: [
                      // Top Bar: Search and Metadata
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Metadata for focused item
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_focusedChannel != null)
                                    Text(
                                      CinemetaMetadataScraper.cleanTitle(_focusedChannel!.name),
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (_focusedEpg != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatTime(_focusedEpg!.start)} — ${_formatTime(_focusedEpg!.stop)}: ${_focusedEpg!.title}',
                                      style: const TextStyle(color: Colors.tealAccent, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Grid
                      Expanded(
                        child: FocusScope(
                          node: _rowFocusNode,
                          child: displayChannels.isEmpty
                            ? const Center(child: Text('No items found', style: TextStyle(color: Colors.white54)))
                            : GridView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  childAspectRatio: 1.0,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
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
                                      if (f) _onChannelFocus(ch, i);
                                    },
                                    onEnter: () => _playChannel(ch),
                                  );
                                },
                              ),
                        ),
                      ),
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

  String _formatTime(DateTime time) {
    final hr = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$hr:$min';
  }
}
