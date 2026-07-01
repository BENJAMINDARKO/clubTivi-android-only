import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

enum ViewStyle {
  spotlight,
  grid
}

class PreferencesService extends ChangeNotifier {
  final SharedPreferences _prefs;
  
  PreferencesService(this._prefs);

  static const _viewStyleKey = 'view_style_preference';

  ViewStyle get viewStyle {
    final styleString = _prefs.getString(_viewStyleKey);
    return ViewStyle.values.firstWhere(
      (e) => e.toString() == styleString,
      orElse: () => ViewStyle.spotlight,
    );
  }

  Future<void> setViewStyle(ViewStyle style) async {
    await _prefs.setString(_viewStyleKey, style.toString());
    notifyListeners();
  }
}

final preferencesServiceProvider = ChangeNotifierProvider<PreferencesService>((ref) {
  return PreferencesService(ref.watch(preferencesProvider));
});
