/// Shared UI widgets used across Live, Movies and Series screens.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/datasources/local/database.dart' as db;
import '../../data/repositories/cinemeta_scraper.dart';

class MediaSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hint;

  const MediaSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hint,
  });

  @override
  State<MediaSearchBar> createState() => _MediaSearchBarState();
}

class _MediaSearchBarState extends State<MediaSearchBar> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(MediaSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus && widget.controller.text.isEmpty) {
      setState(() => _isExpanded = false);
    }
  }

  void _expand() {
    setState(() => _isExpanded = true);
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isExpanded
          ? Container(
              key: const ValueKey('expanded'),
              width: 280,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                  suffixIcon: widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white38),
                          onPressed: () {
                            widget.controller.clear();
                            widget.onChanged('');
                            widget.focusNode.requestFocus();
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white38),
                          onPressed: () {
                            widget.focusNode.unfocus();
                            setState(() => _isExpanded = false);
                          },
                        ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onChanged: widget.onChanged,
              ),
            )
          : Focus(
              focusNode: widget.focusNode,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter)) {
                  _expand();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onTap: _expand,
                child: Container(
                  key: const ValueKey('collapsed'),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.search_rounded, color: Colors.white70, size: 24),
                ),
              ),
            ),
    );
  }
}

class MediaSectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const MediaSectionHeader({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class MediaHorizontalScroll extends StatelessWidget {
  final List<db.Channel> channels;
  final void Function(db.Channel) onTap;
  final void Function(db.Channel) onHide;
  final void Function(db.Channel) onLock;
  final void Function(db.Channel)? onFocus;

  const MediaHorizontalScroll({
    super.key,
    required this.channels,
    required this.onTap,
    required this.onHide,
    required this.onLock,
    this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: channels.length,
        itemBuilder: (ctx, i) {
          final ch = channels[i];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: MediaPosterCard(
              channel: ch,
              width: 90,
              height: 140,
              onTap: () => onTap(ch),
              onHide: () => onHide(ch),
              onLock: () => onLock(ch),
              onFocus: onFocus != null ? (f) { if (f) onFocus!(ch); } : null,
            ),
          );
        },
      ),
    );
  }
}

class MediaPosterCard extends StatefulWidget {
  final db.Channel channel;
  final VoidCallback onTap;
  final VoidCallback onHide;
  final VoidCallback onLock;
  final VoidCallback? onFavourite;
  final VoidCallback? onEnter;
  final ValueChanged<bool>? onFocus;
  final double? width;
  final double? height;
  final bool autofocus;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const MediaPosterCard({
    super.key,
    required this.channel,
    required this.onTap,
    required this.onHide,
    required this.onLock,
    this.onFavourite,
    this.onEnter,
    this.onFocus,
    this.width,
    this.height,
    this.autofocus = false,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<MediaPosterCard> createState() => _MediaPosterCardState();
}

class _MediaPosterCardState extends State<MediaPosterCard> {
  bool _focused = false;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  bool _sawKeyDown = false;
  DateTime? _focusTime;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() {
          _focused = f;
          if (f) {
            _focusTime = DateTime.now();
          }
        });
        if (widget.onFocus != null) widget.onFocus!(f);
      },
      onKeyEvent: (node, event) {
        if (widget.onKeyEvent != null) {
          final result = widget.onKeyEvent!(node, event);
          if (result != KeyEventResult.ignored) return result;
        }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          if (event is KeyDownEvent) {
            _sawKeyDown = true;
            if (_longPressTimer == null) {
              _longPressTriggered = false;
              _longPressTimer = Timer(const Duration(milliseconds: 500), () {
                _longPressTriggered = true;
                _showMenu(context);
              });
            }
            return KeyEventResult.handled;
          } else if (event is KeyUpEvent) {
            if (!_sawKeyDown) return KeyEventResult.ignored;
            _sawKeyDown = false;
            _longPressTimer?.cancel();
            _longPressTimer = null;
            if (!_longPressTriggered) {
              widget.onTap();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          // Debounce taps immediately after receiving focus (prevents synthetic D-pad center taps)
          if (_focusTime != null && DateTime.now().difference(_focusTime!) < const Duration(milliseconds: 300)) {
            return;
          }
          widget.onTap();
        },
        onLongPress: () => _showMenu(context),
        child: AnimatedScale(
          scale: _focused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: widget.width,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _focused ? Colors.white : Colors.transparent,
                      width: _focused ? 3 : 0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_focused ? 9 : 12),
                    child: ch.tvgLogo != null && ch.tvgLogo!.isNotEmpty
                        ? Image.network(
                            ch.tvgLogo!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF1A1A2E),
                              child: const Center(
                                child: Icon(Icons.movie_rounded,
                                    size: 40, color: Colors.white24),
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF1A1A2E),
                            child: const Center(
                                child: Icon(Icons.movie_rounded,
                                    size: 40, color: Colors.white24)),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                CinemetaMetadataScraper.cleanTitle(ch.name),
                style: TextStyle(
                  color: _focused ? Colors.white : Colors.white70,
                  fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                  child: Text(
                    CinemetaMetadataScraper.cleanTitle(widget.channel.name),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                _DialogOption(
                  icon: widget.channel.favorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                  iconColor: widget.channel.favorite ? Colors.red : Colors.white,
                  label: widget.channel.favorite ? 'Unfavourite' : 'Favourite',
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onFavourite?.call();
                  },
                ),
                _DialogOption(
                  autofocus: false,
                  icon: widget.channel.parentalLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  iconColor: Colors.orangeAccent,
                  label: widget.channel.parentalLocked ? 'Remove Lock' : 'Parental Lock',
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onLock();
                  },
                ),
                _DialogOption(
                  icon: Icons.visibility_off_rounded,
                  iconColor: Colors.white54,
                  label: 'Remove from View',
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onHide();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategorySidebarTile extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool isFavourite;
  final bool isLocked;
  final VoidCallback? onTap;
  final VoidCallback? onFavourite;
  final VoidCallback? onHide;
  final VoidCallback? onLock;

  const CategorySidebarTile({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.isFavourite,
    required this.isLocked,
    required this.onTap,
    required this.onFavourite,
    required this.onHide,
    required this.onLock,
  });

  @override
  State<CategorySidebarTile> createState() => _CategorySidebarTileState();
}

class _CategorySidebarTileState extends State<CategorySidebarTile> {
  bool _focused = false;
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  bool _sawKeyDown = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6C5CE7);
    final isHighlighted = widget.selected || _focused;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA) {
          if (event is KeyDownEvent) {
            _sawKeyDown = true;
            if (_longPressTimer == null) {
              _longPressTriggered = false;
              _longPressTimer = Timer(const Duration(milliseconds: 500), () {
                _longPressTriggered = true;
                if (widget.onFavourite != null) _showMenu(context);
              });
            }
            return KeyEventResult.handled;
          } else if (event is KeyUpEvent) {
            if (!_sawKeyDown) return KeyEventResult.ignored;
            _sawKeyDown = false;
            _longPressTimer?.cancel();
            _longPressTimer = null;
            if (!_longPressTriggered) {
              if (widget.onTap != null) widget.onTap!();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress:
            widget.onFavourite != null ? () => _showMenu(context) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isHighlighted
                ? accent.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              if (widget.icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(widget.icon, size: 16, color: Colors.white54),
                ),
              if (widget.isLocked)
                const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.lock_rounded,
                        size: 13, color: Colors.orangeAccent)),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isHighlighted ? Colors.white : Colors.white70,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isFavourite)
                const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                  child: Text(
                    widget.label,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (widget.onFavourite != null)
                  _DialogOption(
                    autofocus: true,
                    icon: widget.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                    iconColor: Colors.amber,
                    label: widget.isFavourite ? 'Remove Favourite' : 'Add to Favourites',
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onFavourite?.call();
                    },
                  ),
                if (widget.onLock != null)
                  _DialogOption(
                    autofocus: widget.onFavourite == null,
                    icon: widget.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    iconColor: Colors.orangeAccent,
                    label: widget.isLocked ? 'Remove Lock' : 'Parental Lock',
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onLock?.call();
                    },
                  ),
                if (widget.onHide != null)
                  _DialogOption(
                    autofocus: widget.onFavourite == null && widget.onLock == null,
                    icon: Icons.visibility_off_rounded,
                    iconColor: Colors.white54,
                    label: 'Hide Category',
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onHide?.call();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DialogOption extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  const _DialogOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_DialogOption> createState() => _DialogOptionState();
}

class _DialogOptionState extends State<_DialogOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && 
            (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _focused ? Colors.white12 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
