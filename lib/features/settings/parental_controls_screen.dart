import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pin_dialog.dart';
import '../../data/datasources/local/database.dart' as db;
import '../../data/services/parental_control_service.dart';
import '../providers/provider_manager.dart';

/// Full parental controls management screen.
class ParentalControlsScreen extends ConsumerStatefulWidget {
  const ParentalControlsScreen({super.key});

  @override
  ConsumerState<ParentalControlsScreen> createState() =>
      _ParentalControlsScreenState();
}

class _ParentalControlsScreenState
    extends ConsumerState<ParentalControlsScreen> {
  static const _accent = Color(0xFF6C5CE7);

  List<db.CategoryPreference> _lockedCategories = [];
  List<db.CategoryPreference> _hiddenCategories = [];
  List<db.Channel> _lockedChannels = [];
  List<db.Channel> _hiddenChannels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final database = ref.read(databaseProvider);
    final prefs = await database.getAllCategoryPreferences();
    final channels = await database.getHiddenOrLockedChannels();

    setState(() {
      _lockedCategories = prefs.where((p) => p.parentalLocked).toList();
      _hiddenCategories = prefs.where((p) => p.hidden).toList();
      _lockedChannels = channels.where((c) => c.parentalLocked).toList();
      _hiddenChannels = channels.where((c) => c.hidden).toList();
      _loading = false;
    });
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'vod':
        return 'Movies';
      case 'series':
        return 'Series';
      default:
        return 'Live TV';
    }
  }

  @override
  Widget build(BuildContext context) {
    final svcAsync = ref.watch(parentalControlProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parental Controls'),
        backgroundColor: const Color(0xFF0D0D18),
      ),
      body: svcAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (svc) => _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // PIN Section
                  _Section(
                    title: 'PIN Code',
                    children: [
                      ListTile(
                        leading: Icon(
                          svc.isPinSet
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          color: svc.isPinSet ? _accent : Colors.white38,
                        ),
                        title: Text(svc.isPinSet ? 'PIN is Set' : 'No PIN Set'),
                        subtitle: Text(
                          svc.isPinSet
                              ? 'Locked content requires this PIN'
                              : 'Set a 4-digit PIN to protect locked content',
                        ),
                      ),
                      if (!svc.isPinSet)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: ElevatedButton.icon(
                            onPressed: () => _setPin(svc),
                            icon: const Icon(Icons.lock_rounded),
                            label: const Text('Set PIN'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _accent),
                          ),
                        )
                      else ...[
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _changePin(svc),
                                  icon: const Icon(Icons.edit_rounded),
                                  label: const Text('Change PIN'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _clearPin(svc),
                                  icon: const Icon(Icons.lock_open_rounded,
                                      color: Colors.redAccent),
                                  label: const Text('Remove PIN',
                                      style: TextStyle(
                                          color: Colors.redAccent)),
                                  style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Colors.redAccent)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Locked categories
                  _Section(
                    title:
                        'Locked Categories (${_lockedCategories.length})',
                    children: _lockedCategories.isEmpty
                        ? const [
                            ListTile(
                              leading: Icon(Icons.lock_open_rounded,
                                  color: Colors.white24),
                              title: Text('No categories locked',
                                  style:
                                      TextStyle(color: Colors.white38)),
                            )
                          ]
                        : _lockedCategories.map((pref) {
                            return ListTile(
                              leading: const Icon(Icons.lock_rounded,
                                  color: Colors.orangeAccent),
                              title: Text(pref.groupTitle),
                              subtitle: Text(_typeLabel(pref.streamType)),
                              trailing: IconButton(
                                icon: const Icon(Icons.lock_open_rounded,
                                    color: Colors.white38),
                                tooltip: 'Remove lock',
                                onPressed: () async {
                                  await ref
                                      .read(databaseProvider)
                                      .upsertCategoryPreference(
                                    db.CategoryPreferencesCompanion.insert(
                                      providerId: pref.providerId,
                                      groupTitle: pref.groupTitle,
                                      streamType: pref.streamType,
                                      hidden: Value(pref.hidden),
                                      parentalLocked: const Value(false),
                                      isFavourite: Value(pref.isFavourite),
                                    ),
                                  );
                                  _load();
                                },
                              ),
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Hidden categories
                  _Section(
                    title: 'Hidden Categories (${_hiddenCategories.length})',
                    children: _hiddenCategories.isEmpty
                        ? const [
                            ListTile(
                              leading: Icon(Icons.visibility_rounded,
                                  color: Colors.white24),
                              title: Text('No categories hidden',
                                  style:
                                      TextStyle(color: Colors.white38)),
                            )
                          ]
                        : _hiddenCategories.map((pref) {
                            return ListTile(
                              leading: const Icon(
                                  Icons.visibility_off_rounded,
                                  color: Colors.white54),
                              title: Text(pref.groupTitle),
                              subtitle: Text(_typeLabel(pref.streamType)),
                              trailing: IconButton(
                                icon: const Icon(Icons.visibility_rounded,
                                    color: Colors.white38),
                                tooltip: 'Show category',
                                onPressed: () async {
                                  await ref
                                      .read(databaseProvider)
                                      .upsertCategoryPreference(
                                    db.CategoryPreferencesCompanion.insert(
                                      providerId: pref.providerId,
                                      groupTitle: pref.groupTitle,
                                      streamType: pref.streamType,
                                      hidden: const Value(false),
                                      parentalLocked:
                                          Value(pref.parentalLocked),
                                      isFavourite: Value(pref.isFavourite),
                                    ),
                                  );
                                  _load();
                                },
                              ),
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Locked channels
                  _Section(
                    title: 'Locked Channels (${_lockedChannels.length})',
                    children: _lockedChannels.isEmpty
                        ? const [
                            ListTile(
                              leading: Icon(Icons.lock_open_rounded,
                                  color: Colors.white24),
                              title: Text('No channels locked',
                                  style:
                                      TextStyle(color: Colors.white38)),
                            )
                          ]
                        : _lockedChannels.map((ch) {
                            return ListTile(
                              leading: const Icon(Icons.lock_rounded,
                                  color: Colors.orangeAccent),
                              title: Text(ch.name,
                                  overflow: TextOverflow.ellipsis),
                              subtitle:
                                  Text(ch.groupTitle ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.lock_open_rounded,
                                    color: Colors.white38),
                                onPressed: () async {
                                  await ref
                                      .read(databaseProvider)
                                      .setChannelParentalLock(
                                          ch.id, false);
                                  _load();
                                },
                              ),
                            );
                          }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Hidden channels
                  _Section(
                    title: 'Hidden Channels (${_hiddenChannels.length})',
                    children: _hiddenChannels.isEmpty
                        ? const [
                            ListTile(
                              leading: Icon(Icons.visibility_rounded,
                                  color: Colors.white24),
                              title: Text('No channels hidden',
                                  style:
                                      TextStyle(color: Colors.white38)),
                            )
                          ]
                        : _hiddenChannels.map((ch) {
                            return ListTile(
                              leading: const Icon(
                                  Icons.visibility_off_rounded,
                                  color: Colors.white54),
                              title: Text(ch.name,
                                  overflow: TextOverflow.ellipsis),
                              subtitle:
                                  Text(ch.groupTitle ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.visibility_rounded,
                                    color: Colors.white38),
                                onPressed: () async {
                                  await ref
                                      .read(databaseProvider)
                                      .hideChannel(ch.id, false);
                                  _load();
                                },
                              ),
                            );
                          }).toList(),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _setPin(ParentalControlService svc) async {
    final pin = await showPinDialog(context,
        title: 'Set Parental PIN', subtitle: 'Choose a 4-digit PIN');
    if (pin == null || pin.length != 4) return;
    final confirm = await showPinDialog(context,
        title: 'Confirm PIN', subtitle: 'Enter the PIN again to confirm');
    if (confirm != pin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('PINs do not match'),
            backgroundColor: Colors.red));
      }
      return;
    }
    await svc.setPin(pin);
    if (mounted) setState(() {});
  }

  Future<void> _changePin(ParentalControlService svc) async {
    final old = await showPinDialog(context, title: 'Enter Current PIN');
    if (old == null) return;
    if (!svc.verifyPin(old)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Incorrect PIN'), backgroundColor: Colors.red));
      }
      return;
    }
    await _setPin(svc);
  }

  Future<void> _clearPin(ParentalControlService svc) async {
    final pin = await showPinDialog(context, title: 'Enter PIN to Remove');
    if (pin == null) return;
    if (!svc.verifyPin(pin)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Incorrect PIN'), backgroundColor: Colors.red));
      }
      return;
    }
    await svc.clearPin();
    if (mounted) setState(() {});
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                  letterSpacing: 0.8),
            ),
          ),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
