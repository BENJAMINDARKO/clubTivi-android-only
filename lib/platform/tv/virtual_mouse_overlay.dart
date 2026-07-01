import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class VirtualMouseOverlay extends StatefulWidget {
  final Widget child;

  const VirtualMouseOverlay({super.key, required this.child});

  @override
  State<VirtualMouseOverlay> createState() => _VirtualMouseOverlayState();
}

class _VirtualMouseOverlayState extends State<VirtualMouseOverlay> with SingleTickerProviderStateMixin {
  bool _isActive = false;
  Offset _position = const Offset(200, 200);
  
  // Movement tracking
  int _dx = 0;
  int _dy = 0;
  
  late Ticker _ticker;
  double _velocity = 0;
  final double _maxVelocity = 15.0;
  final double _acceleration = 1.2;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_dx == 0 && _dy == 0) {
      _velocity = 0;
      return;
    }

    _velocity = (_velocity + _acceleration).clamp(0.0, _maxVelocity);

    setState(() {
      double newX = _position.dx + (_dx * _velocity);
      double newY = _position.dy + (_dy * _velocity);

      // Clamp to screen bounds
      final size = MediaQuery.of(context).size;
      newX = newX.clamp(0.0, size.width - 24);
      newY = newY.clamp(0.0, size.height - 24);

      _position = Offset(newX, newY);
    });
  }

  bool _handleKey(KeyEvent event) {
    // Toggle on Menu / ContextMenu (hamburger button)
    if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
      if (event is KeyDownEvent) {
        setState(() {
          _isActive = !_isActive;
          if (_isActive) {
            // Start centered
            final size = MediaQuery.of(context).size;
            _position = Offset(size.width / 2, size.height / 2);
          } else {
            _ticker.stop();
            _dx = 0;
            _dy = 0;
          }
        });
      }
      return true; // Consume toggle key
    }

    if (!_isActive) return false;

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _dy = -1;
        if (!_ticker.isActive) _ticker.start();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _dy = 1;
        if (!_ticker.isActive) _ticker.start();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _dx = -1;
        if (!_ticker.isActive) _ticker.start();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _dx = 1;
        if (!_ticker.isActive) _ticker.start();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.select || 
                 event.logicalKey == LogicalKeyboardKey.enter || 
                 event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _simulateTapDown();
        return true;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp && _dy == -1) {
        _dy = 0;
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown && _dy == 1) {
        _dy = 0;
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _dx == -1) {
        _dx = 0;
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight && _dx == 1) {
        _dx = 0;
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.select || 
                 event.logicalKey == LogicalKeyboardKey.enter || 
                 event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _simulateTapUp();
        return true;
      }
    }

    // Trap back button/escape to close the mouse mode instead of exiting app
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      if (event is KeyDownEvent) {
        setState(() {
          _isActive = false;
          _ticker.stop();
          _dx = 0;
          _dy = 0;
        });
      }
      return true;
    }

    // While mouse is active, we trap all navigation keys to prevent background UI changes
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      return true;
    }

    return false;
  }

  void _simulateTapDown() {
    GestureBinding.instance.handlePointerEvent(PointerDownEvent(
      position: _position,
      pointer: 100, // arbitrary unique ID
    ));
  }

  void _simulateTapUp() {
    GestureBinding.instance.handlePointerEvent(PointerUpEvent(
      position: _position,
      pointer: 100,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isActive)
          Positioned(
            left: _position.dx,
            top: _position.dy,
            child: IgnorePointer(
              child: Stack(
                children: [
                  const Icon(
                    Icons.mouse_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  Positioned(
                    top: 1, left: 1,
                    child: Icon(
                      Icons.mouse_outlined,
                      color: Colors.black.withOpacity(0.5),
                      size: 28,
                    ),
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }
}
