import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/datasources/remote/cinemeta_client.dart';
import '../../data/datasources/local/database.dart' as db;
import '../../data/repositories/cinemeta_scraper.dart';
import '../../ui/backdrop.dart';
import '../media_shared_widgets.dart';

class IptvMovieDetailScreen extends ConsumerStatefulWidget {
  final db.Channel channel;

  const IptvMovieDetailScreen({
    super.key,
    required this.channel,
  });

  @override
  ConsumerState<IptvMovieDetailScreen> createState() => _IptvMovieDetailScreenState();
}

class _IptvMovieDetailScreenState extends ConsumerState<IptvMovieDetailScreen> {
  CinemetaShowDetail? _movieMeta;
  List<CinemetaSearchResult> _recommendations = [];
  bool _isLoading = true;
  
  final FocusNode _playButtonFocusNode = FocusNode();
  final FocusNode _rowFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  @override
  void dispose() {
    _playButtonFocusNode.dispose();
    _rowFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    final scraper = ref.read(tmdbMetadataScraperProvider);
    final searchResult = await scraper.fetchMovieMetadata(widget.channel.name);
    
    if (searchResult != null) {
      final detail = await scraper.getMovie(searchResult.id);
      final recs = await scraper.getMovieRecommendations(searchResult.id);
      
      if (mounted) {
        setState(() {
          _movieMeta = detail;
          _recommendations = recs;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _playChannel() {
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
          'streamType': widget.channel.streamType,
        }
      ],
      'currentIndex': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final backdropUrl = (_movieMeta?.backdropUrl?.isNotEmpty ?? false) 
        ? _movieMeta!.backdropUrl 
        : widget.channel.tvgLogo;
        
    final posterUrl = (_movieMeta?.posterUrl?.isNotEmpty ?? false)
        ? _movieMeta!.posterUrl
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
                  // Left Column: Details & Actions
                  Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Title
                        Text(
                          _movieMeta?.title ?? CinemetaMetadataScraper.cleanTitle(widget.channel.name),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Metadata Row
                        Row(
                          children: [
                            if (_movieMeta?.year != null) ...[
                              Text(
                                '${_movieMeta!.year}',
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (_movieMeta?.voteAverage != null && _movieMeta!.voteAverage! > 0) ...[
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                _movieMeta!.voteAverage!.toStringAsFixed(1),
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              const SizedBox(width: 16),
                            ],
                            if (_movieMeta?.genres.isNotEmpty == true) ...[
                              Text(
                                _movieMeta!.genres.take(3).join(', '),
                                style: const TextStyle(color: Colors.white54, fontSize: 16),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Summary
                        if (_movieMeta?.overview != null && _movieMeta!.overview!.isNotEmpty)
                          Text(
                            _movieMeta!.overview!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              height: 1.5,
                            ),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          const Text(
                            'No description available.',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                          
                        const SizedBox(height: 40),
                        
                        // Actions
                        Row(
                          children: [
                            ElevatedButton.icon(
                              focusNode: _playButtonFocusNode,
                              autofocus: true,
                              onPressed: _playChannel,
                              icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                              label: const Text('Play Movie', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Right Column: Poster / Recommendations
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: _isLoading 
                      ? const Center(child: CircularProgressIndicator(color: Colors.white24))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (posterUrl != null && posterUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      posterUrl,
                                      width: 200,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                              
                            if (_recommendations.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40.0),
                                child: Text(
                                  'Similar Movies',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
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
                                                    child: const Icon(Icons.movie, color: Colors.white24),
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
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
