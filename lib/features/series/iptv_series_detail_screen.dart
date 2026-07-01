import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/local/database.dart' as db;
import '../../data/datasources/remote/cinemeta_client.dart';
import '../../data/datasources/remote/xtream_client.dart';
import '../../data/repositories/cinemeta_scraper.dart';
import '../../ui/backdrop.dart';
import '../providers/app_cache_provider.dart';

class IptvSeriesDetailScreen extends ConsumerStatefulWidget {
  final db.Channel channel;

  const IptvSeriesDetailScreen({
    super.key,
    required this.channel,
  });

  @override
  ConsumerState<IptvSeriesDetailScreen> createState() => _IptvSeriesDetailScreenState();
}

class _IptvSeriesDetailScreenState extends ConsumerState<IptvSeriesDetailScreen> {
  CinemetaShowDetail? _showMeta;
  List<CinemetaSearchResult> _recommendations = [];
  bool _isLoading = true;
  
  // Xtream Series data
  XtreamSeriesInfo? _seriesInfo;
  String? _selectedSeason;
  List<String> _seasons = [];
  
  final FocusNode _seasonDropdownFocusNode = FocusNode();
  final FocusNode _episodesListFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  @override
  void dispose() {
    _seasonDropdownFocusNode.dispose();
    _episodesListFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    final scraper = ref.read(tmdbMetadataScraperProvider);
    final searchResult = await scraper.fetchSeriesMetadata(widget.channel.name);
    
    CinemetaShowDetail? detail;
    List<CinemetaSearchResult> recs = [];
    
    if (searchResult != null) {
      detail = await scraper.getTvShow(searchResult.id);
      recs = await scraper.getTvRecommendations(searchResult.id);
    }
    
    // Fetch Xtream series info if it's an Xtream series (empty streamUrl and ID has _series_)
    XtreamSeriesInfo? seriesInfo;
    if (widget.channel.streamUrl.isEmpty && widget.channel.id.contains('_series_')) {
      final cache = await ref.read(appCacheProvider.future);
      final provider = cache.providers.cast<db.Provider?>().firstWhere(
        (p) => p?.id == widget.channel.providerId, 
        orElse: () => null
      );
      
      if (provider != null && provider.type == 'xtream') {
        final client = XtreamClient(
          baseUrl: provider.url!,
          username: provider.username!,
          password: provider.password!,
        );
        try {
          final seriesIdParts = widget.channel.id.split('_series_');
          if (seriesIdParts.length > 1) {
            final seriesId = seriesIdParts.last;
            seriesInfo = await client.getSeriesInfo(seriesId);
          }
        } catch (e) {
          debugPrint('Failed to fetch series info: $e');
        } finally {
          client.dispose();
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _showMeta = detail;
        _recommendations = recs;
        _seriesInfo = seriesInfo;
        
        if (_seriesInfo != null && _seriesInfo!.episodes.isNotEmpty) {
          _seasons = _seriesInfo!.episodes.keys.toList()..sort((a, b) {
            final numA = int.tryParse(a) ?? 0;
            final numB = int.tryParse(b) ?? 0;
            return numA.compareTo(numB);
          });
          if (_seasons.isNotEmpty) {
            _selectedSeason = _seasons.first;
          }
        }
        
        _isLoading = false;
      });
      
      // Auto-focus the episodes list if available, otherwise fallback
      if (_seasons.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && _episodesListFocusNode.canRequestFocus) {
            _episodesListFocusNode.requestFocus();
          }
        });
      }
    }
  }

  void _playEpisode(XtreamEpisode episode) async {
    final cache = await ref.read(appCacheProvider.future);
    final provider = cache.providers.firstWhere(
      (p) => p.id == widget.channel.providerId,
    );
    
    final client = XtreamClient(
      baseUrl: provider.url!,
      username: provider.username!,
      password: provider.password!,
    );
    
    final ext = episode.containerExtension.isNotEmpty ? episode.containerExtension : 'mp4';
    final streamUrl = '${provider.url}/series/${provider.username}/${provider.password}/${episode.id}.$ext';
    
    final List<Map<String, dynamic>> allEpisodes = [];
    int currentIndex = 0;
    
    if (_seriesInfo != null) {
      final sortedSeasons = _seriesInfo!.episodes.keys.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
      for (final season in sortedSeasons) {
        final seasonEps = _seriesInfo!.episodes[season] ?? [];
        for (final ep in seasonEps) {
          if (ep.id == episode.id) {
            currentIndex = allEpisodes.length;
          }
          final epExt = ep.containerExtension.isNotEmpty ? ep.containerExtension : 'mp4';
          final epUrl = '${provider.url}/series/${provider.username}/${provider.password}/${ep.id}.$epExt';
          
          allEpisodes.add({
            'id': '${widget.channel.id}_${ep.id}',
            'providerId': widget.channel.providerId,
            'name': 'S${ep.season} E${ep.episodeNum} - ${ep.title}',
            'originalName': ep.title,
            'streamUrl': epUrl,
            'tvgLogo': widget.channel.tvgLogo,
            'tvgId': widget.channel.tvgId,
            'tvgName': widget.channel.tvgName,
            'groupTitle': 'Season $season',
            'streamType': 'series',
          });
        }
      }
    } else {
      allEpisodes.add({
        'id': '${widget.channel.id}_${episode.id}',
        'providerId': widget.channel.providerId,
        'name': 'S${episode.season} E${episode.episodeNum} - ${episode.title}',
        'originalName': episode.title,
        'streamUrl': streamUrl,
        'tvgLogo': widget.channel.tvgLogo,
        'tvgId': widget.channel.tvgId,
        'tvgName': widget.channel.tvgName,
        'groupTitle': widget.channel.groupTitle,
        'streamType': 'series',
      });
    }

    if (!mounted) return;

    context.push('/player', extra: {
      'streamUrl': streamUrl,
      'channelName': '${widget.channel.name} - S${episode.season} E${episode.episodeNum} - ${episode.title}',
      'channelLogo': widget.channel.tvgLogo,
      'alternativeUrls': <String>[],
      'channels': allEpisodes,
      'currentIndex': currentIndex,
    });
  }
  
  // For standard M3U series where the channel itself is the episode
  void _playStandardChannel() {
    context.push('/player', extra: {
      'streamUrl': widget.channel.streamUrl,
      'channelName': widget.channel.name,
      'channelLogo': widget.channel.tvgLogo,
      'alternativeUrls': <String>[],
      'channels': [
        {
          'id': widget.channel.id,
          'providerId': widget.channel.providerId,
          'name': widget.channel.name,
          'originalName': widget.channel.name,
          'streamUrl': widget.channel.streamUrl,
          'tvgLogo': widget.channel.tvgLogo,
          'tvgId': widget.channel.tvgId,
          'tvgName': widget.channel.tvgName,
          'groupTitle': widget.channel.groupTitle,
          'streamType': 'series',
        }
      ],
      'currentIndex': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final backdropUrl = (_showMeta?.backdropUrl?.isNotEmpty ?? false) 
        ? _showMeta!.backdropUrl 
        : widget.channel.tvgLogo;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          BackdropLayer(imageUrl: backdropUrl),
          
          SafeArea(
            child: SizedBox.expand(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Column: Details & Overview
                  Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                        const SizedBox(height: 16),
                        
                        Text(
                          _showMeta?.title ?? CinemetaMetadataScraper.cleanTitle(widget.channel.name),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            if (_showMeta?.year != null) ...[
                              Text(
                                '${_showMeta!.year}-',
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (_showMeta?.numberOfSeasons != null) ...[
                              Text(
                                '${_showMeta!.numberOfSeasons} Seasons',
                                style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (_showMeta?.voteAverage != null && _showMeta!.voteAverage! > 0) ...[
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                _showMeta!.voteAverage!.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (_showMeta?.genres.isNotEmpty == true) ...[
                              Text(
                                _showMeta!.genres.take(3).join(', '),
                                style: const TextStyle(color: Colors.white54, fontSize: 16),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        if (_showMeta?.overview != null && _showMeta!.overview!.isNotEmpty)
                          Text(
                            _showMeta!.overview!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          const Text(
                            'No description available.',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                          
                        const SizedBox(height: 40),
                        
                        if (_recommendations.isNotEmpty) ...[
                          const Text(
                            'Related Series',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _recommendations.length,
                              itemBuilder: (ctx, i) {
                                final rec = _recommendations[i];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: SizedBox(
                                    width: 120,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: AspectRatio(
                                            aspectRatio: 2 / 3,
                                            child: Image.network(
                                              rec.posterUrl ?? '',
                                              fit: BoxFit.cover,
                                              errorBuilder: (ctx, err, stack) => Container(
                                                color: Colors.grey[900],
                                                child: const Icon(Icons.tv, color: Colors.white24),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          rec.displayName,
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                
                // Right Column: Seasons & Episodes
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: Colors.white24))
                      : _buildEpisodesPanel(),
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEpisodesPanel() {
    // Standard M3U fallback
    if (_seriesInfo == null) {
      if (widget.channel.streamUrl.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.tv, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                autofocus: true,
                onPressed: _playStandardChannel,
                icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                label: const Text('Play Episode', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        );
      } else {
        return const Center(child: Text('No episodes available', style: TextStyle(color: Colors.white54)));
      }
    }
    
    // Xtream Seasons/Episodes
    if (_seasons.isEmpty) {
      return const Center(child: Text('No episodes found', style: TextStyle(color: Colors.white54)));
    }
    
    final currentEpisodes = _seriesInfo!.episodes[_selectedSeason] ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Season Dropdown header
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              focusNode: _seasonDropdownFocusNode,
              dropdownColor: Colors.grey[900],
              value: _selectedSeason,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedSeason = newValue;
                  });
                }
              },
              items: _seasons.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text('Season $value'),
                );
              }).toList(),
            ),
          ),
        ),
        
        // Episodes List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            itemCount: currentEpisodes.length,
            itemBuilder: (ctx, i) {
              final ep = currentEpisodes[i];
              return _EpisodeTile(
                episode: ep,
                autofocus: i == 0,
                onTap: () => _playEpisode(ep),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EpisodeTile extends StatefulWidget {
  final XtreamEpisode episode;
  final bool autofocus;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode,
    this.autofocus = false,
    required this.onTap,
  });

  @override
  State<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<_EpisodeTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        autofocus: widget.autofocus,
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: _isFocused ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Play icon placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow_rounded, color: _isFocused ? Colors.white : Colors.white70),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.episode.episodeNum ?? ''}. ${widget.episode.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.episode.info != null && widget.episode.info!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.episode.info!,
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
