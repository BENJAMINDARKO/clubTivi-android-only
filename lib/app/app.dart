import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform_info.dart';
import '../data/services/cinemeta_precache_service.dart';
import 'router.dart';
import 'theme.dart';

import '../platform/tv/virtual_mouse_overlay.dart';

class ClubTiviApp extends ConsumerStatefulWidget {
  const ClubTiviApp({super.key});

  @override
  ConsumerState<ClubTiviApp> createState() => _ClubTiviAppState();
}

class _ClubTiviAppState extends ConsumerState<ClubTiviApp> {
  @override
  void initState() {
    super.initState();
    // Start precaching TMDB data in the background
    Future.microtask(() => ref.read(cinemetaPrecacheServiceProvider).start());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'clubTivi',
      debugShowCheckedModeBanner: false,
      theme: ClubTiviTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        // Detect TV mode from the first MediaQuery context
        PlatformInfo.detectFromContext(context);
        
        Widget result = Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
          },
          child: child ?? const SizedBox.shrink(),
        );

        if (PlatformInfo.isTV) {
          result = VirtualMouseOverlay(child: result);
        }

        return result;
      },
    );
  }
}
