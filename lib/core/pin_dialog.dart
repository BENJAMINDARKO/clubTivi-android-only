import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a 4-digit PIN entry dialog. Returns the entered PIN or null if cancelled.
Future<String?> showPinDialog(
  BuildContext context, {
  String title = 'Enter PIN',
  String? subtitle,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PinDialog(title: title, subtitle: subtitle),
  );
}

class _PinDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  const _PinDialog({required this.title, this.subtitle});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _pin = '';
  bool _error = false;

  void _onKey(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = false;
    });
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onSubmit() {
    if (_pin.length == 4) {
      Navigator.of(context).pop(_pin);
    } else {
      setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6C5CE7);
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: Text(widget.title),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.subtitle != null) ...[
              Text(widget.subtitle!,
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 16),
            ],
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? accent : Colors.transparent,
                    border: Border.all(
                      color: _error ? Colors.red : accent,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            if (_error)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Enter all 4 digits',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 24),
            // Numpad
            _Numpad(onDigit: _onKey, onDelete: _onDelete, onSubmit: _onSubmit),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  const _Numpad({
    required this.onDigit,
    required this.onDelete,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6C5CE7);
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['⌫', '0', '✓'],
    ];
    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            final isBackspace = k == '⌫';
            final isSubmit = k == '✓';
            return Padding(
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                width: 64,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSubmit
                        ? accent
                        : const Color(0xFF2D2D44),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isBackspace
                      ? onDelete
                      : isSubmit
                          ? onSubmit
                          : () => onDigit(k),
                  child: Text(k,
                      style: TextStyle(
                          fontSize: isSubmit || isBackspace ? 20 : 22,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
