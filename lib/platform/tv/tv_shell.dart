import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pin_dialog.dart';
import '../../data/services/parental_control_service.dart';
/// 10-foot TV UI shell — optimized for remote control navigation.
///
/// Key design principles:
/// - Large text and touch targets (minimum 48dp)
/// - High contrast for viewing distance
/// - D-pad focus navigation (no pointer/mouse needed)
/// - Sidebar navigation with content area
/// - Focus ring visible on all interactive elements
class TvShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const TvShell({super.key, required this.navigationShell});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

class _TvShellState extends ConsumerState<TvShell> {
  final _navScopeNode = FocusScopeNode(debugLabel: 'tv-shell-nav');
  final _contentScopeNode = FocusScopeNode(debugLabel: 'tv-shell-content');

  @override
  void dispose() {
    _navScopeNode.dispose();
    _contentScopeNode.dispose();
    super.dispose();
  }

  static const _navItems = [
    _NavItem(icon: Icons.video_library_rounded, label: 'LIBRARY', route: '/library'),
    _NavItem(icon: Icons.live_tv_rounded, label: 'LIVE TV', route: '/live'),
    _NavItem(icon: Icons.movie_creation_rounded, label: 'MOVIES', route: '/movies'),
    _NavItem(icon: Icons.video_collection_rounded, label: 'SERIES', route: '/series'),
    _NavItem(icon: Icons.security_rounded, label: 'PARENTAL', route: '/parental'),
  ];
  
  int get _selectedNav {
    return widget.navigationShell.currentIndex;
  }

  void _navigateTo(int index) async {
    if (index == _selectedNav) return;
    
    final item = _navItems[index];
    if (item.route == '/parental') {
      final pinSvc = await ref.read(parentalControlProvider.future);
      if (pinSvc.isPinSet) {
        final entered = await showPinDialog(
          context,
          title: 'Enter PIN',
          subtitle: 'This section is protected by Parental Controls',
        );
        if (entered == null || !pinSvc.verifyPin(entered)) {
          // Focus back on current tab
          return;
        }
      }
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  String _formatDate() {
    final now = DateTime.now();
    final months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    final days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    
    final dayStr = days[now.weekday - 1];
    final monthStr = months[now.month - 1];
    return '$dayStr, $monthStr ${now.day}, ${now.year}';
  }

  String _formatTime() {
    final now = DateTime.now();
    var h = now.hour;
    h = h % 12;
    if (h == 0) h = 12;
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatAmPm() {
    final now = DateTime.now();
    return now.hour >= 12 ? 'PM' : 'AM';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Exit App', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            content: const Text('Are you sure you want to exit ClubTivi?', style: TextStyle(color: Colors.white70, fontSize: 18)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('NO', style: TextStyle(color: Colors.white54, fontSize: 18)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('YES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        
        if (shouldPop == true) {
          SystemNavigator.pop();
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          // If up arrow is pressed, check if we can move up within the content first
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (!_navScopeNode.hasFocus) {
              final pf = FocusManager.instance.primaryFocus;
              if (pf != null) {
                final moved = pf.focusInDirection(TraversalDirection.up);
                if (moved) return KeyEventResult.handled;
              }
              // If no widget to the up, jump to the top nav
              _navScopeNode.requestFocus();
              if (FocusManager.instance.primaryFocus == _navScopeNode) {
                _navScopeNode.nextFocus();
              }
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (_navScopeNode.hasFocus) {
              final pf = FocusManager.instance.primaryFocus;
              if (pf != null) {
                final moved = pf.focusInDirection(TraversalDirection.down);
                if (moved) return KeyEventResult.handled;
              }
              // Force focus to content
              _contentScopeNode.requestFocus();
              if (FocusManager.instance.primaryFocus == _contentScopeNode) {
                _contentScopeNode.nextFocus();
              }
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.browserBack) {
            if (!_navScopeNode.hasFocus) {
              _navScopeNode.requestFocus();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Stack(
            children: [
              // Main content area
              Positioned.fill(
                child: FocusScope(
                  node: _contentScopeNode,
                  child: FocusTraversalGroup(
                    child: widget.navigationShell,
                  ),
                ),
              ),
              // Top nav
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: FocusScope(
                    node: _navScopeNode,
                    child: Row(
                      children: [
                        const SizedBox(width: 32),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ...List.generate(_navItems.length, (index) {
                                  final item = _navItems[index];
                                  final selected = _selectedNav == index;
                                  return _TvNavButton(
                                    label: item.label,
                                    selected: selected,
                                    autofocus: index == 0,
                                    onSelect: () => _navigateTo(index),
                                    onFocusChange: (hasFocus) {},
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                        // Search and Settings Icons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TvIconNavButton(
                              icon: Icons.search_rounded,
                              onSelect: () {
                                if (GoRouterState.of(context).uri.path == '/search') return;
                                context.push('/search');
                              },
                              onFocusChange: (hasFocus) {},
                            ),
                            const SizedBox(width: 8),
                            _TvIconNavButton(
                              icon: Icons.settings_rounded,
                              onSelect: () {
                                if (GoRouterState.of(context).uri.path == '/settings') return;
                                context.push('/settings');
                              },
                              onFocusChange: (hasFocus) {},
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),
                        // Clock on the far right
                        Padding(
                          padding: const EdgeInsets.only(right: 32),
                          child: SizedBox(
                            width: 180,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _formatTime().split(':').first + ':',
                                      style: const TextStyle(
                                        color: Colors.cyan,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                    Text(
                                      _formatTime().split(':')[1],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${_formatDate()} • ${_formatAmPm()}',
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}


class _TvNavButton extends StatefulWidget {
  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onSelect;
  final ValueChanged<bool> onFocusChange;

  const _TvNavButton({
    required this.label,
    required this.selected,
    this.autofocus = false,
    required this.onSelect,
    required this.onFocusChange,
  });

  @override
  State<_TvNavButton> createState() => _TvNavButtonState();
}

class _TvNavButtonState extends State<_TvNavButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.selected || _focused;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        setState(() => _focused = hasFocus);
        widget.onFocusChange(hasFocus);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
          final pf = FocusManager.instance.primaryFocus;
          if (pf != null) {
            final moved = pf.focusInDirection(TraversalDirection.up);
            if (moved) return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.selected 
                  ? Colors.white 
                  : (_focused ? Colors.white70 : Colors.white54),
              fontSize: 16,
              fontWeight: _focused ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _TvIconNavButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onSelect;
  final ValueChanged<bool> onFocusChange;

  const _TvIconNavButton({
    required this.icon,
    required this.onSelect,
    required this.onFocusChange,
  });

  @override
  State<_TvIconNavButton> createState() => _TvIconNavButtonState();
}

class _TvIconNavButtonState extends State<_TvIconNavButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _focused = hasFocus);
        widget.onFocusChange(hasFocus);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
          final pf = FocusManager.instance.primaryFocus;
          if (pf != null) {
            final moved = pf.focusInDirection(TraversalDirection.up);
            if (moved) return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _focused ? Colors.white24 : Colors.transparent,
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(
            widget.icon,
            color: _focused ? Colors.white : Colors.white54,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

/// Focus-aware card for TV grid items (channels, VOD, etc.).
/// Shows a highlighted border when focused via D-pad navigation.
class TvFocusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final double width;
  final double height;

  const TvFocusCard({
    super.key,
    required this.child,
    this.onSelect,
    this.width = 200,
    this.height = 120,
  });

  @override
  State<TvFocusCard> createState() => _TvFocusCardState();
}

class _TvFocusCardState extends State<TvFocusCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _focused = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onSelect?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height,
        transform: _focused
            ? (Matrix4.identity()..setEntry(0, 0, 1.05)..setEntry(1, 1, 1.05))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? Colors.white : Colors.transparent,
            width: 2,
          ),
          color: const Color(0xFF1A1A2E),
        ),
        child: widget.child,
      ),
    );
  }
}
