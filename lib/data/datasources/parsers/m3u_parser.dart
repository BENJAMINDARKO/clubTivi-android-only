import '../../models/channel.dart';

/// Parses M3U and M3U Plus playlist formats.
///
/// Supports:
/// - Standard M3U (#EXTM3U / #EXTINF)
/// - M3U Plus extended attributes (tvg-id, tvg-name, tvg-logo, group-title, etc.)
/// - Xtream Codes style attributes (tvg-chno, tvg-shift)
/// - Multiple URL formats (HTTP, HTTPS, RTMP, RTSP, UDP)
class M3uParser {
  /// Parse M3U content from a string.
  M3uResult parse(String content, {required String providerId}) {
    final lines = content.split(RegExp(r'\r?\n'));
    final channels = <Channel>[];
    final errors = <String>[];

    if (lines.isEmpty || !lines.first.trim().startsWith('#EXTM3U')) {
      errors.add('Missing #EXTM3U header');
    }

    String? currentExtInf;
    String? currentExtGrp;
    String? epgUrl;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      if (line.startsWith('#EXTM3U')) {
        final regex = RegExp(r'(?:tvg-url|x-tvg-url)="([^"]*)"');
        final match = regex.firstMatch(line);
        if (match != null) {
          epgUrl = match.group(1);
        }
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        currentExtInf = line;
        // reset extGrp when starting a new channel
        currentExtGrp = null;
        continue;
      }

      if (line.startsWith('#EXTGRP:')) {
        currentExtGrp = line.substring(8).trim();
        continue;
      }

      // Skip other directives
      if (line.startsWith('#')) continue;

      // This should be a URL
      if (currentExtInf != null) {
        try {
          final channel = _parseEntry(currentExtInf, line, currentExtGrp, providerId);
          if (channel != null) channels.add(channel);
        } catch (e) {
          errors.add('Line $i: $e');
        }
        currentExtInf = null;
        currentExtGrp = null;
      }
    }

    return M3uResult(channels: channels, errors: errors, epgUrl: epgUrl);
  }

  Channel? _parseEntry(String extInf, String url, String? extGrp, String providerId) {
    if (url.isEmpty) return null;

    // Parse #EXTINF:-1 tvg-id="..." tvg-name="..." ... , Channel Name
    final attrs = _parseAttributes(extInf);
    final displayName = _parseDisplayName(extInf);

    if (displayName.isEmpty && attrs['tvg-name'] == null) return null;

    final name = displayName.isNotEmpty ? displayName : attrs['tvg-name']!;

    // Generate a stable ID from provider + tvg-id or URL
    final tvgId = attrs['tvg-id'];
    final channelId = tvgId != null && tvgId.isNotEmpty
        ? '${providerId}_$tvgId'
        : '${providerId}_${url.hashCode}';

    // Parse channel number
    int? channelNumber;
    final chnoStr = attrs['tvg-chno'];
    if (chnoStr != null && chnoStr.isNotEmpty) {
      channelNumber = int.tryParse(chnoStr);
    }

    final groupTitle = _emptyToNull(attrs['group-title']) ?? extGrp;

    return Channel(
      id: channelId,
      providerId: providerId,
      name: name,
      tvgId: _emptyToNull(attrs['tvg-id']),
      tvgName: _emptyToNull(attrs['tvg-name']),
      tvgLogo: _emptyToNull(attrs['tvg-logo']),
      groupTitle: groupTitle,
      channelNumber: channelNumber,
      streamUrl: url,
      streamType: _inferStreamType(attrs, url, name, groupTitle),
    );
  }

  /// Parse M3U Plus extended attributes from an #EXTINF line.
  /// Example: #EXTINF:-1 tvg-id="ESPN.us" tvg-name="ESPN HD" group-title="Sports",ESPN HD
  Map<String, String> _parseAttributes(String extInf) {
    final attrs = <String, String>{};

    // Match key="value" or key=value pairs
    final regex = RegExp(r'([\w-]+)=(?:"([^"]*)"|([^"\s,]+))');
    for (final match in regex.allMatches(extInf)) {
      final key = match.group(1)!.toLowerCase();
      final value = match.group(2) ?? match.group(3) ?? '';
      attrs[key] = value;
    }

    return attrs;
  }

  /// Extract the display name (after the last comma in #EXTINF line).
  String _parseDisplayName(String extInf) {
    final commaIndex = extInf.lastIndexOf(',');
    if (commaIndex == -1) return '';
    return extInf.substring(commaIndex + 1).trim();
  }

  StreamType _inferStreamType(Map<String, String> attrs, String url, String name, String? resolvedGroupTitle) {
    // 1. Check explicit tvg-type attribute if present
    final tvgType = (attrs['tvg-type'] ?? '').toLowerCase();
    if (tvgType.contains('movie') || tvgType.contains('vod')) return StreamType.vod;
    if (tvgType.contains('series') || tvgType.contains('tv show')) return StreamType.series;
    if (tvgType.contains('live') || tvgType.contains('tv')) return StreamType.live;

    // 2. Check group-title
    final lowerGroupTitle = (resolvedGroupTitle ?? '').toLowerCase();
    if (lowerGroupTitle.contains('vod') || lowerGroupTitle.contains('movie') || lowerGroupTitle.contains('film')) {
      return StreamType.vod;
    }
    if (lowerGroupTitle.contains('series') || lowerGroupTitle.contains('show')) {
      return StreamType.series;
    }

    // 3. Xtream Codes URL patterns
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('/movie/')) return StreamType.vod;
    if (lowerUrl.contains('/series/')) return StreamType.series;

    // 4. File extension from URL
    final urlPath = lowerUrl.split('?').first;
    if (urlPath.endsWith('.mp4') || 
        urlPath.endsWith('.mkv') || 
        urlPath.endsWith('.avi') || 
        urlPath.endsWith('.mov') ||
        urlPath.endsWith('.wmv')) {
      // If it looks like a movie file, check if the name looks like a series episode
      if (RegExp(r's\d{1,2}\s*e\d{1,2}', caseSensitive: false).hasMatch(name)) {
        return StreamType.series;
      }
      return StreamType.vod;
    }

    // 5. Name patterns for series
    if (RegExp(r's\d{1,2}\s*e\d{1,2}', caseSensitive: false).hasMatch(name)) {
      return StreamType.series;
    }

    // Default fallback
    return StreamType.live;
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

/// Result of parsing an M3U playlist.
class M3uResult {
  final List<Channel> channels;
  final List<String> errors;
  final String? epgUrl;

  const M3uResult({
    required this.channels, 
    this.errors = const [],
    this.epgUrl,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get channelCount => channels.length;
}
