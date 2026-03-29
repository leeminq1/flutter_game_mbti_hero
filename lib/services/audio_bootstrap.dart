import 'dart:async';

import 'bgm_manager.dart';
import 'sfx_manager.dart';

class AudioBootstrap {
  AudioBootstrap._();

  static Future<void>? _pendingInitialization;

  static Future<void> ensureInitialized() {
    final pendingInitialization = _pendingInitialization;
    if (pendingInitialization != null) {
      return pendingInitialization;
    }

    final initialization = Future.wait<void>([
      SfxManager.preloadAllAudio(),
      BgmManager.preloadTracks(),
    ]);

    _pendingInitialization = initialization;
    return initialization;
  }
}
