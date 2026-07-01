import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/local/database.dart' as db;
import '../providers/provider_manager.dart';
import '../media_shared_widgets.dart';
import '../player/player_service.dart';
import '../providers/app_cache_provider.dart';
import '../../ui/backdrop.dart';

class ParentalScreen extends ConsumerStatefulWidget {
  const ParentalScreen({super.key});

  @override
  ConsumerState<ParentalScreen> createState() => _ParentalScreenState();
}

class _ParentalScreenState extends ConsumerState<ParentalScreen> {
  bool _loading = true;
  List<db.CategoryPreference> _categories = [];
  List<db.Channel> _movies = [];
  List<db.Channel> _series = [];
  List<db.Channel> _live = [];

  final FocusScopeNode _pageFocusNode = FocusScopeNode();
  db.Channel? _focusedChannel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cache = await ref.read(appCacheProvider.future);
    final database = ref.read(databaseProvider);
    
    final allPrefs = cache.prefs;
    final hiddenPrefs = allPrefs.where((p) => p.hidden || p.parentalLocked).toList();
    
    final hiddenChannels = await database.getHiddenOrLockedChannels();

    if (!mounted) return;
    setState(() {
      _categories = hiddenPrefs;
      _movies = hiddenChannels.where((c) => c.streamType == 'vod').toList();
      _series = hiddenChannels.where((c) => c.streamType == 'series').toList();
      _live = hiddenChannels.where((c) => c.streamType == 'live').toList();
      _loading = false;
    });
  }

  void _playChannel(db.Channel ch) async {
    final ps = ref.read(playerServiceProvider);
    await ps.play(
      ch.streamUrl,
      channelId: ch.id,
      channelName: ch.name,
      tvgId: ch.tvgId,
    );
    if (!mounted) return;
    context.push('/player', extra: {
      'streamUrl': ch.streamUrl,
      'channelName': ch.name,
      'channelLogo': ch.tvgLogo,
      'alternativeUrls': <String>[],
      'channels': [
        {
          'id': ch.id,
          'providerId': ch.providerId,
          'name': ch.name,
          'originalName': ch.name,
          'streamUrl': ch.streamUrl,
          'tvgLogo': ch.tvgLogo,
          'tvgId': ch.tvgId,
          'tvgName': ch.tvgName,
          'groupTitle': ch.groupTitle,
          'streamType': ch.streamType,
        }
      ],
      'currentIndex': 0,
    });
  }

  void _hideChannel(db.Channel ch) async {
    await ref.read(databaseProvider).hideChannel(ch.id, false);
    ref.read(appCacheProvider.notifier).updateChannel(ch.copyWith(hidden: false));
    _load();
  }

  void _lockChannel(db.Channel ch) async {
    await ref.read(databaseProvider).setChannelParentalLock(ch.id, false);
    ref.read(appCacheProvider.notifier).updateChannel(ch.copyWith(parentalLocked: false));
    _load();
  }

  Widget _buildChannelRow(String title, List<db.Channel> channels) {
    if (channels.isEmpty) return const SizedBox.shrink();
    final posterHeight = MediaQuery.of(context).size.height * 0.22;
    final posterWidth = posterHeight * 0.67;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(
          height: posterHeight,
          child: ListView.builder(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            scrollDirection: Axis.horizontal,
            itemCount: channels.length,
            itemBuilder: (ctx, i) {
              final ch = channels[i];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: MediaPosterCard(
                  channel: ch,
                  width: posterWidth,
                  height: posterHeight,
                  onTap: () => _playChannel(ch),
                  onHide: () => _hideChannel(ch),
                  onLock: () => _lockChannel(ch),
                  onFocus: (f) {
                    if (f) setState(() => _focusedChannel = ch);
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCategoryRow() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final cardHeight = MediaQuery.of(context).size.height * 0.15;
    final cardWidth = cardHeight * 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Text('Locked Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.builder(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _CategoryCard(
                  category: cat,
                  width: cardWidth,
                  height: cardHeight,
                  onTap: () {
                    context.push('/parental_category', extra: {
                      'providerId': cat.providerId,
                      'groupTitle': cat.groupTitle,
                      'streamType': cat.streamType,
                    });
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    if (_categories.isEmpty && _movies.isEmpty && _series.isEmpty && _live.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Focus(
            autofocus: true,
            child: const Text(
              'No locked or hidden content.\n\nTo lock content, set a PIN in Settings -> Parental Controls.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 18),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          BackdropLayer(imageUrl: _focusedChannel?.tvgLogo),
          Padding(
            padding: const EdgeInsets.only(top: 64),
            child: FocusScope(
              node: _pageFocusNode,
              child: ListView(
                padding: const EdgeInsets.only(top: 32, bottom: 64),
                children: [
                  _buildCategoryRow(),
                  _buildChannelRow('Locked Movies', _movies),
                  _buildChannelRow('Locked Series', _series),
                  _buildChannelRow('Locked Live Channels', _live),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final db.CategoryPreference category;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6C5CE7);
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (f) => setState(() => _focused = f),
      focusColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_special_rounded, color: Colors.white70, size: 32),
              const SizedBox(height: 8),
              Text(
                widget.category.groupTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
