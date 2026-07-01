import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'provider_manager.dart';

/// Shows the Add Provider dialog.
/// Uses a full-screen page (navigable via D-pad) instead of a bottom sheet.
Future<bool?> showAddProviderDialog(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _AddProviderPage(),
    ),
  );
}

enum _ProviderType { m3u, xtream }

class _AddProviderPage extends ConsumerStatefulWidget {
  const _AddProviderPage();

  @override
  ConsumerState<_AddProviderPage> createState() => _AddProviderPageState();
}

class _AddProviderPageState extends ConsumerState<_AddProviderPage> {
  final _formKey = GlobalKey<FormState>();
  _ProviderType _type = _ProviderType.m3u;

  // M3U fields
  final _m3uName = TextEditingController();
  final _m3uUrl = TextEditingController();

  // Xtream fields
  final _xtreamName = TextEditingController();
  final _xtreamUrl = TextEditingController();
  final _xtreamUser = TextEditingController();
  final _xtreamPass = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _m3uName.dispose();
    _m3uUrl.dispose();
    _xtreamName.dispose();
    _xtreamUrl.dispose();
    _xtreamUser.dispose();
    _xtreamPass.dispose();
    super.dispose();
  }

  String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  String _generateId(String name) {
    final slug = _slugify(name);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${slug.isEmpty ? 'provider' : slug}-$ts';
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (!value.trim().startsWith('http') && !value.trim().startsWith('/')) return 'Must be a valid URL or file path';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == _ProviderType.m3u) {
      await _addProvider(() {
        final manager = ref.read(providerManagerProvider);
        return manager.addM3uProvider(
          id: _generateId(_m3uName.text.trim()),
          name: _m3uName.text.trim(),
          url: _m3uUrl.text.trim(),
        );
      });
    } else {
      await _addProvider(() {
        final manager = ref.read(providerManagerProvider);
        return manager.addXtreamProvider(
          id: _generateId(_xtreamName.text.trim()),
          name: _xtreamName.text.trim(),
          url: _xtreamUrl.text.trim(),
          username: _xtreamUser.text.trim(),
          password: _xtreamPass.text.trim(),
        );
      });
    }
  }

  Future<void> _addProvider(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provider added successfully')),
      );
    } on ProviderLimitException catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Provider Limit Reached'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Error'),
          content: Text('Failed to add provider:\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pasteUrl(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      controller.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          final pf = FocusManager.instance.primaryFocus;
          if (pf?.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
            pf!.unfocus();
            return;
          }
          Future.microtask(() {
            Navigator.of(context).pop();
          });
        },
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Add Provider'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Provider type selection - D-pad friendly
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    autofocus: true,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return const Color(0xFF8C7CFF);
                        }
                        return _type == _ProviderType.m3u ? const Color(0xFF6C5CE7) : const Color(0xFF1A1A2E);
                      }),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                      side: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return const BorderSide(color: Colors.white, width: 3);
                        }
                        return BorderSide.none;
                      }),
                    ),
                    onPressed: () => setState(() => _type = _ProviderType.m3u),
                    child: const Text('M3U Playlist'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return const Color(0xFF8C7CFF);
                        }
                        return _type == _ProviderType.xtream ? const Color(0xFF6C5CE7) : const Color(0xFF1A1A2E);
                      }),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                      side: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return const BorderSide(color: Colors.white, width: 3);
                        }
                        return BorderSide.none;
                      }),
                    ),
                    onPressed: () => setState(() => _type = _ProviderType.xtream),
                    child: const Text('Xtream Codes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Fields change based on type
            if (_type == _ProviderType.m3u) ..._buildM3uFields(),
            if (_type == _ProviderType.xtream) ..._buildXtreamFields(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    ),
    );
  }

  List<Widget> _buildM3uFields() {
    return [
      TvTextField(
        controller: _m3uName,
        decoration: const InputDecoration(
          labelText: 'Provider Name',
          hintText: 'e.g. My IPTV',
        ),
        validator: _validateRequired,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      TvTextField(
        controller: _m3uUrl,
        decoration: const InputDecoration(
          labelText: 'M3U URL',
          hintText: 'http://...',
        ),
        validator: _validateUrl,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.any, // .m3u might not be recognized on all Android versions
              );
              if (result != null && result.files.single.path != null) {
                _m3uUrl.text = result.files.single.path!;
              }
            },
            icon: const Icon(Icons.folder, size: 18),
            label: const Text('Browse File'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _pasteUrl(_m3uUrl),
            icon: const Icon(Icons.paste, size: 18),
            label: const Text('Paste URL'),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildXtreamFields() {
    return [
      TvTextField(
        controller: _xtreamName,
        decoration: const InputDecoration(
          labelText: 'Provider Name',
          hintText: 'e.g. My Xtream',
        ),
        validator: _validateRequired,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      TvTextField(
        controller: _xtreamUrl,
        decoration: const InputDecoration(
          labelText: 'Server URL',
          hintText: 'http://...',
        ),
        validator: _validateUrl,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      TvTextField(
        controller: _xtreamUser,
        decoration: const InputDecoration(
          labelText: 'Username',
        ),
        validator: _validateRequired,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      TvTextField(
        controller: _xtreamPass,
        decoration: const InputDecoration(
          labelText: 'Password',
        ),
        obscureText: true,
        validator: _validateRequired,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
      ),
    ];
  }

  Widget _buildSubmitButton() {
    const accent = Color(0xFF6C5CE7);
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: _loading ? null : _submit,
        style: FilledButton.styleFrom(backgroundColor: accent),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Add Provider', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

class TvTextField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onFieldSubmitted;

  const TvTextField({
    super.key,
    this.controller,
    this.decoration,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onFieldSubmitted,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  bool _isEditing = false;
  bool _hasFocus = false;
  late FocusNode _outerFocusNode;
  late FocusNode _innerFocusNode;
  late FocusNode _disabledFocusNode;

  @override
  void initState() {
    super.initState();
    _outerFocusNode = FocusNode();
    _innerFocusNode = FocusNode();
    _disabledFocusNode = FocusNode(canRequestFocus: false);

    _outerFocusNode.addListener(() {
      setState(() {
        _hasFocus = _outerFocusNode.hasFocus;
      });
    });

    _innerFocusNode.addListener(() {
      if (!_innerFocusNode.hasFocus && _isEditing) {
        setState(() => _isEditing = false);
      }
    });
  }

  @override
  void dispose() {
    _outerFocusNode.dispose();
    _innerFocusNode.dispose();
    _disabledFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextFormField(
        controller: widget.controller,
        focusNode: _innerFocusNode,
        autofocus: true,
        readOnly: false,
        decoration: widget.decoration,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        obscureText: widget.obscureText,
        onFieldSubmitted: (val) {
          setState(() => _isEditing = false);
          _outerFocusNode.requestFocus();
          widget.onFieldSubmitted?.call(val);
        },
      );
    }

    return Focus(
      focusNode: _outerFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          setState(() => _isEditing = true);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => setState(() => _isEditing = true),
        child: Container(
          decoration: BoxDecoration(
            color: _hasFocus ? const Color(0xFF6C5CE7).withValues(alpha: 0.3) : Colors.transparent,
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IgnorePointer(
            child: TextFormField(
              controller: widget.controller,
              focusNode: _disabledFocusNode,
              readOnly: true,
              decoration: widget.decoration?.copyWith(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ) ?? const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: widget.validator,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              obscureText: widget.obscureText,
            ),
          ),
        ),
      ),
    );
  }
}
