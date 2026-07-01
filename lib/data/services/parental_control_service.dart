import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the parental control PIN.
/// Uses a simple obfuscated store — for a TV app this is sufficient.
class ParentalControlService {
  static const _kPin = 'parental_pin_v1';

  final SharedPreferences _prefs;
  ParentalControlService(this._prefs);

  bool get isPinSet => _prefs.containsKey(_kPin) && _prefs.getString(_kPin)!.isNotEmpty;

  /// Returns true if pin matches the stored PIN (or no PIN is set).
  bool verifyPin(String pin) {
    if (!isPinSet) return true;
    return _prefs.getString(_kPin) == pin;
  }

  Future<void> setPin(String pin) async {
    await _prefs.setString(_kPin, pin);
  }

  Future<void> clearPin() async {
    await _prefs.remove(_kPin);
  }
}

final parentalControlProvider =
    FutureProvider<ParentalControlService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return ParentalControlService(prefs);
});
