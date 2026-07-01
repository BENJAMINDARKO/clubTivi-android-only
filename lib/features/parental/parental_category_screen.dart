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

class ParentalCategoryScreen extends ConsumerStatefulWidget {
  final String providerId;
  final String groupTitle;
  final String streamType;

  const ParentalCategoryScreen({
    super.key,
    required this.providerId,
    required this.groupTitle,
    required this.streamType,
  });

  @override
  ConsumerState<ParentalCategoryScreen> createState() => _ParentalCategoryScreenState();
}

class _ParentalCategoryScreenState extends ConsumerState<ParentalCategoryScreen> {
  bool _loading = true;
  List<db.Channel> _channels = [];
  db.Channel? _focusedChannel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final database = ref.read(databaseProvider);
    final channels = await database.getChannelsForCategory(
      providerId: widget.providerId,
      groupTitle: widget.groupTitle,
      streamType: widget.streamType,
    );

    if (!mounted) return;
    setState(() {
      _channels = channels;
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
      'channels': _channels.map((c) => {
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
      'currentIndex': _channels.indexOf(ch),
    });
  }

  void _hideChannel(db.Channel ch) async {
    final newValue = !ch.hidden;
    await ref.read(databaseProvider).hideChannel(ch.id, newValue);
    ref.read(appCacheProvider.notifier).updateChannel(ch.copyWith(hidden: newValue));
    _load();
  }

  void _lockChannel(db.Channel ch) async {
    final newValue = !ch.parentalLocked;
    await ref.read(databaseProvider).setChannelParentalLock(ch.id, newValue);
    ref.read(appCacheProvider.notifier).updateChannel(ch.copyWith(parentalLocked: newValue));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    final posterHeight = MediaQuery.of(context).size.height * 0.25;
    final posterWidth = posterHeight * 0.67;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.groupTitle),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          BackdropLayer(imageUrl: _focusedChannel?.tvgLogo),
          GridView.builder(
            padding: const EdgeInsets.all(32),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: (MediaQuery.of(context).size.width ~/ (posterWidth + 16)).clamp(1, 10),
              childAspectRatio: posterWidth / posterHeight,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _channels.length,
            itemBuilder: (ctx, i) {
              final ch = _channels[i];
              return MediaPosterCard(
                channel: ch,
                width: posterWidth,
                height: posterHeight,
                onTap: () => _playChannel(ch),
                onHide: () => _hideChannel(ch),
                onLock: () => _lockChannel(ch),
                onFocus: (f) {
                  if (f) setState(() => _focusedChannel = ch);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
