import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volume_controller/volume_controller.dart';

import 'player_service.dart';

/// TiviMate-style fullscreen player control bar.
///
/// Two-row layout on a dark semi-transparent background:
/// - Top row: volume, resolution badge, transport controls, action icons
/// - Bottom row: position, seek bar, duration
class PlayerControlBar extends ConsumerStatefulWidget {
  final VoidCallback? onPrevChannel;
  final VoidCallback? onNextChannel;
  final VoidCallback? onBackTap;
  final VoidCallback? onScreenshot;
  final VoidCallback? onFavorite;
  final VoidCallback? onInfo;
  final VoidCallback? onSettings;
  final VoidCallback? onChannelList;
  final VoidCallback? onRename;
  final VoidCallback? onSubtitleToggle;
  final VoidCallback? onSubtitleSelect;
  final VoidCallback? onAudioSelect;
  final bool isFavorite;
  final bool hasSubtitles;
  final bool subtitlesEnabled;
  final int audioTrackCount;
  final double volume;
  final bool visible;

  const PlayerControlBar({
    super.key,
    this.onPrevChannel,
    this.onNextChannel,
    this.onBackTap,
    this.onScreenshot,
    this.onFavorite,
    this.onInfo,
    this.onSettings,
    this.onChannelList,
    this.onRename,
    this.onSubtitleToggle,
    this.onSubtitleSelect,
    this.onAudioSelect,
    this.isFavorite = false,
    this.hasSubtitles = false,
    this.subtitlesEnabled = false,
    this.audioTrackCount = 0,
    required this.volume,
    this.visible = true,
  });

  @override
  ConsumerState<PlayerControlBar> createState() => _PlayerControlBarState();
}

class _PlayerControlBarState extends ConsumerState<PlayerControlBar> {
  // Player state cached from streams
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int? _videoWidth;
  int? _videoHeight;
  bool _isSeeking = false;
  double _seekValue = 0.0;

  final FocusNode _playPauseFocusNode = FocusNode();

  // Mute toggle state
  double _preMuteVolume = 100.0;
  final List<StreamSubscription> _subs = [];
  Timer? _fpsTimer;
  String _fpsLabel = '—';
  String _codecLabel = '';
  bool _isInterlaced = false;
  String _bufferDuration = '—';
  final List<double> _fpsHistory = [];
  final List<double> _bufferHistory = [];
  String _bufferTier = 'normal';

  @override
  void initState() {
    super.initState();
    _subscribeToPlayer();
    _startInfoPolling();
  }

  @override
  void didUpdateWidget(PlayerControlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _playPauseFocusNode.requestFocus();
    }
  }

  void _startInfoPolling() {
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final ps = ref.read(playerServiceProvider);
      final results = await Future.wait([
        ps.getMpvProperty('estimated-vf-fps'),
        ps.getMpvProperty('video-codec'),
        ps.getMpvProperty('video-params/pixelformat'),
        ps.getMpvProperty('demuxer-cache-duration'),
      ]);
      if (!mounted) return;
      final fps = double.tryParse(results[0] ?? '');
      final codec = results[1] ?? '';
      final pixFmt = results[2] ?? '';
      final bufDur = double.tryParse(results[3] ?? '');
      setState(() {
        _bufferDuration = bufDur != null ? bufDur.toStringAsFixed(1) : '—';
        if (bufDur != null) {
          _bufferHistory.add(bufDur);
          if (_bufferHistory.length > 60) _bufferHistory.removeAt(0);
        }
        _bufferTier = ps.bufferManager.currentTier;
        _fpsLabel = fps != null ? fps.toStringAsFixed(1) : '—';
        if (fps != null) {
          _fpsHistory.add(fps);
          if (_fpsHistory.length > 60) _fpsHistory.removeAt(0);
        }
        // Extract short codec name (e.g. "h264" from "h264 (High)")
        _codecLabel = codec.split(' ').first.toUpperCase();
        _isInterlaced = pixFmt.contains('interlaced') || pixFmt.contains('tff') || pixFmt.contains('bff');
      });
    });
  }

  void _subscribeToPlayer() {
    final ps = ref.read(playerServiceProvider);
    final player = ps.player;

    _playing = player.state.playing;
    _position = player.state.position;
    _duration = player.state.duration;
    _videoWidth = player.state.width;
    _videoHeight = player.state.height;

    _subs.add(player.stream.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
    }));
    _subs.add(player.stream.position.listen((p) {
      if (mounted && !_isSeeking) setState(() => _position = p);
    }));
    _subs.add(player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    _subs.add(player.stream.width.listen((w) {
      if (mounted) setState(() => _videoWidth = w);
    }));
    _subs.add(player.stream.height.listen((h) {
      if (mounted) setState(() => _videoHeight = h);
    }));
  }

  // --- Helpers ---

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '00:$m:$s';
  }

  String _resolutionLabel() {
    final h = _videoHeight ?? 0;
    if (h >= 2160) return '4K UHD';
    if (h >= 1080) return '1080 HD';
    if (h >= 720) return '720 HD';
    if (h >= 480) return '480 SD';
    if (h > 0) return '${h}p';
    return '—';
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey.shade800,
      ),
    );
  }

  @override
  void dispose() {
    _playPauseFocusNode.dispose();
    _fpsTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // ── Top row ──
                Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      // Back button
                      _iconBtn(Icons.arrow_back, onTap: widget.onBackTap),

                      const Spacer(),

                      // ── Transport controls (center) ──
                      _iconBtn(Icons.skip_previous, onTap: widget.onPrevChannel),
                      const SizedBox(width: 12),
                      _iconBtn(
                        _playing ? Icons.pause : Icons.play_arrow,
                        size: 32,
                        focusNode: _playPauseFocusNode,
                        onTap: () {
                          final ps = ref.read(playerServiceProvider);
                          _playing ? ps.pause() : ps.resume();

                        },
                      ),
                      const SizedBox(width: 12),
                      _iconBtn(Icons.skip_next, onTap: widget.onNextChannel),

                      const Spacer(),

                      // ── Right side icons ──
                      // CC (subtitle) toggle + long-press picker
                      GestureDetector(
                        onTap: widget.onSubtitleToggle,
                        onLongPress: widget.onSubtitleSelect,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            widget.subtitlesEnabled
                                ? Icons.closed_caption
                                : Icons.closed_caption_disabled,
                            color: widget.subtitlesEnabled
                                ? Colors.white
                                : Colors.white38,
                            size: 20,
                          ),
                        ),
                      ),
                      // Audio track selector (only if > 1 track)
                      if (widget.audioTrackCount > 1)
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: widget.onAudioSelect,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.audiotrack, color: Colors.white, size: 20),
                                Positioned(
                                  right: -6,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6C5CE7),
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                    child: Text(
                                      '${widget.audioTrackCount}',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      _iconBtn(
                        widget.isFavorite ? Icons.star : Icons.star_border,
                        color: widget.isFavorite ? Colors.amber : Colors.white,
                        onTap: widget.onFavorite,
                      ),
                      _iconBtn(Icons.menu,
                          onTap: widget.onChannelList),
                      _badge('EPG', fontSize: 10),
                      const SizedBox(width: 6),
                      Tooltip(
                        richMessage: WidgetSpan(
                          child: _FpsSparkline(history: _fpsHistory),
                        ),
                        waitDuration: const Duration(milliseconds: 300),
                        preferBelow: false,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: _badge('$_fpsLabel fps', fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        richMessage: WidgetSpan(
                          child: _BufferSparkline(history: _bufferHistory, tier: _bufferTier),
                        ),
                        waitDuration: const Duration(milliseconds: 300),
                        preferBelow: false,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: _badge('buf: ${_bufferDuration}s', fontSize: 10),
                      ),
                    ],
                  ),
                ),

                // ── Bottom row: seek bar (only for VOD/Series with known duration) ──
                if (_duration.inMilliseconds > 0)
                  Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(
                              _isSeeking
                                  ? Duration(
                                      milliseconds: _seekValue.round())
                                  : _position),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 10),
                              activeTrackColor: Colors.blue,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.blue,
                            ),
                            child: Slider(
                              value: _isSeeking
                                  ? _seekValue
                                  : _position.inMilliseconds
                                      .toDouble()
                                      .clamp(
                                          0,
                                          _duration.inMilliseconds
                                              .toDouble()
                                              .clamp(1, double.infinity)),
                              min: 0,
                              max: _duration.inMilliseconds
                                  .toDouble()
                                  .clamp(1, double.infinity),
                              onChangeStart: (v) {
                                setState(() {
                                  _isSeeking = true;
                                  _seekValue = v;
                                });
                              },
                              onChanged: (v) {
                                setState(() => _seekValue = v);

                              },
                              onChangeEnd: (v) {
                                ref.read(playerServiceProvider).player.seek(
                                    Duration(milliseconds: v.round()));
                                setState(() => _isSeeking = false);
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
  }

  // ── Small helpers ──

  Widget _iconBtn(IconData icon,
      {VoidCallback? onTap, Color color = Colors.white, double size = 20, FocusNode? focusNode}) {
    return _TvFocusableIcon(
      icon: icon,
      color: color,
      size: size,
      onTap: onTap,
      focusNode: focusNode,
    );
  }

  Widget _badge(String text,
      {Color bgColor = Colors.transparent, double fontSize = 11}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        border: bgColor == Colors.transparent
            ? Border.all(color: Colors.white38)
            : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Sparkline chart for FPS history, shown in tooltip.
class _FpsSparkline extends StatelessWidget {
  final List<double> history;
  const _FpsSparkline({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      final label = history.isNotEmpty
          ? 'FPS: ${history.last.toStringAsFixed(1)}\nCollecting more data…'
          : 'Waiting for FPS data…';
      return SizedBox(
        width: 180, height: 60,
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center)),
      );
    }

    final min = history.reduce((a, b) => a < b ? a : b);
    final max = history.reduce((a, b) => a > b ? a : b);
    final avg = history.reduce((a, b) => a + b) / history.length;
    final actualRange = max - min;
    // When FPS is stable (range < 1), use a fixed window around the avg
    // so the sparkline isn't just a flat line at the edge.
    final displayMin = actualRange < 1.0 ? avg - 5.0 : min;
    final displayRange = actualRange < 1.0 ? 10.0 : actualRange;

    return SizedBox(
      width: 200,
      height: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FPS  min: ${min.toStringAsFixed(1)}  avg: ${avg.toStringAsFixed(1)}  max: ${max.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              size: const Size(200, 50),
              painter: _SparklinePainter(history, displayMin, displayRange),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final double min;
  final double range;

  _SparklinePainter(this.data, this.min, this.range);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final linePaint = Paint()
      ..color = const Color(0xFF6C5CE7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x806C5CE7), Color(0x006C5CE7)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => true;
}

/// Sparkline chart for buffer history, shown in tooltip.
class _BufferSparkline extends StatelessWidget {
  final List<double> history;
  final String tier;
  const _BufferSparkline({required this.history, this.tier = 'normal'});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      final label = history.isNotEmpty
          ? 'Buffer: ${history.last.toStringAsFixed(1)}s  tier: $tier\nCollecting more data…'
          : 'Waiting for buffer data…';
      return SizedBox(
        width: 180, height: 60,
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center)),
      );
    }

    final min = history.reduce((a, b) => a < b ? a : b);
    final max = history.reduce((a, b) => a > b ? a : b);
    final avg = history.reduce((a, b) => a + b) / history.length;
    final actualRange = max - min;
    final displayMin = actualRange < 1.0 ? avg - 5.0 : min;
    final displayRange = actualRange < 1.0 ? 10.0 : actualRange;

    return SizedBox(
      width: 200,
      height: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buffer  min: ${min.toStringAsFixed(1)}  avg: ${avg.toStringAsFixed(1)}  max: ${max.toStringAsFixed(1)}  tier: $tier',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              size: const Size(200, 50),
              painter: _BufferSparklinePainter(history, displayMin, displayRange),
            ),
          ),
        ],
      ),
    );
  }
}

class _BufferSparklinePainter extends CustomPainter {
  final List<double> data;
  final double min;
  final double range;

  _BufferSparklinePainter(this.data, this.min, this.range);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final linePaint = Paint()
      ..color = const Color(0xFF00B894)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x8000B894), Color(0x0000B894)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _BufferSparklinePainter old) => true;
}

/// A D-pad focusable icon button for TV navigation.
/// Shows a white border when focused and handles Select/Enter to invoke onTap.
class _TvFocusableIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  const _TvFocusableIcon({
    required this.icon,
    this.color = Colors.white,
    this.size = 20,
    this.onTap,
    this.focusNode,
  });

  @override
  State<_TvFocusableIcon> createState() => _TvFocusableIconState();
}

class _TvFocusableIconState extends State<_TvFocusableIcon> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _hasFocus = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
            color: _hasFocus ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
          ),
          child: Icon(widget.icon, color: widget.color, size: widget.size),
        ),
      ),
    );
  }
}
