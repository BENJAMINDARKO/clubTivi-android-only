import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/local/database.dart' as db;
import '../player/player_service.dart';
import 'search_providers.dart';

/// Cross-tab search screen.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _accent = Color(0xFF6C5CE7);

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Do not immediately request focus on TV so keyboard doesn't pop up unless clicked
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(searchProvider.notifier).setQuery(q);
    });
  }

  void _play(db.Channel ch) {
    final playerService = ref.read(playerServiceProvider);
    playerService.play(ch.streamUrl,
        channelId: ch.id,
        channelName: ch.name,
        epgChannelId: null,
        tvgId: ch.tvgId);
    context.go('/');
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'vod': return Colors.pinkAccent;
      case 'series': return Colors.lightBlueAccent;
      default: return Colors.greenAccent;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'vod': return 'Movie';
      case 'series': return 'Series';
      default: return 'Live';
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    if (_searchController.text != searchState.query) {
      _searchController.value = TextEditingValue(
        text: searchState.query,
        selection: TextSelection.collapsed(offset: searchState.query.length),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (searchState.query.isNotEmpty) {
            _searchController.clear();
            ref.read(searchProvider.notifier).clear();
          } else {
            context.go('/');
          }
        },
      },
      child: Scaffold(
        body: Column(
          children: [
            // Top search bar
            Container(
              color: const Color(0xFF0D0D18),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      final pf = FocusManager.instance.primaryFocus;
                      if (pf != null) {
                        pf.focusInDirection(TraversalDirection.down);
                        return KeyEventResult.handled;
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      final pf = FocusManager.instance.primaryFocus;
                      if (pf != null) {
                        pf.focusInDirection(TraversalDirection.up);
                        return KeyEventResult.handled;
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: false,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Search across all content…',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 18),
                  prefixIcon: const Icon(Icons.search_rounded, color: _accent, size: 28),
                  suffixIcon: searchState.query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white38),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchProvider.notifier).clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
                onChanged: _onQueryChanged,
                ),
              ),
            ),
            // Tab filter
            Container(
              color: const Color(0xFF0D0D18),
              child: Row(
                children: SearchTab.values.map((tab) {
                  final selected = searchState.tab == tab;
                  final labels = {
                    SearchTab.all: 'All',
                    SearchTab.live: 'Live TV',
                    SearchTab.movies: 'Movies',
                    SearchTab.series: 'Series',
                  };
                  return Expanded(
                    child: _SearchTabButton(
                      label: labels[tab]!,
                      selected: selected,
                      onSelect: () {
                        ref.read(searchProvider.notifier).setTab(tab);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            // Results
            Expanded(
              child: searchState.query.isEmpty
                  ? _buildEmpty()
                  : searchState.loading
                      ? const Center(child: CircularProgressIndicator())
                      : searchState.results.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off_rounded,
                                      size: 64, color: Colors.white24),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No results for "${searchState.query}"',
                                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: searchState.results.length,
                              itemBuilder: (ctx, i) {
                                final ch = searchState.results[i];
                                return _SearchResultTile(
                                  channel: ch,
                                  typeLabel: _typeLabel(ch.streamType),
                                  typeColor: _typeColor(ch.streamType),
                                  onTap: () => _play(ch),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 80, color: _accent.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'Search your playlists',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white60),
          ),
          const SizedBox(height: 8),
          const Text(
            'Find live channels, movies and series across all providers',
            style: TextStyle(fontSize: 14, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final db.Channel channel;
  final String typeLabel;
  final Color typeColor;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.channel,
    required this.typeLabel,
    required this.typeColor,
    required this.onTap,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6C5CE7);
    final ch = widget.channel;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          decoration: BoxDecoration(
            color: _focused ? accent.withValues(alpha: 0.2) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 44,
                height: 44,
                child: ch.tvgLogo != null && ch.tvgLogo!.isNotEmpty
                    ? Image.network(
                        ch.tvgLogo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(_typeIcon(ch.streamType), color: Colors.white24),
                      )
                    : Icon(_typeIcon(ch.streamType), color: Colors.white24),
              ),
            ),
            title: Row(
              children: [
                if (ch.parentalLocked)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.lock_rounded, size: 12, color: Colors.orangeAccent),
                  ),
                Expanded(
                  child: Text(
                    ch.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: ch.groupTitle != null
                ? Text(ch.groupTitle!,
                    style: const TextStyle(fontSize: 12, color: Colors.white38),
                    overflow: TextOverflow.ellipsis)
                : null,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: widget.typeColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                widget.typeLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.typeColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'vod': return Icons.movie_rounded;
      case 'series': return Icons.video_library_rounded;
      default: return Icons.live_tv_rounded;
    }
  }
}

class _SearchTabButton extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelect;

  const _SearchTabButton({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_SearchTabButton> createState() => _SearchTabButtonState();
}

class _SearchTabButtonState extends State<_SearchTabButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _focused ? Colors.white12 : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: widget.selected ? const Color(0xFF6C5CE7) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.normal,
              color: widget.selected || _focused ? Colors.white : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }
}
