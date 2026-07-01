import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/platform_info.dart';
import 'data/services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  PlatformInfo.setTvOverride(true);
  
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
      ],
      child: const ClubTiviApp(),
    ),
  );
}
