import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';

class SfxManager {
  SfxManager._();

  static const List<String> preloadAssets = [
    'sfx_shoot.ogg',
    'sfx_player_hit.ogg',
    'sfx_player_die.ogg',
    'sfx_ultimate.ogg',
    'sfx_assist.ogg',
    'sfx_enemy_spawn.ogg',
    'sfx_enemy_hit.ogg',
    'sfx_enemy_die.ogg',
    'sfx_boss_warning.ogg',
    'sfx_boss_attack.ogg',
    'sfx_coin.ogg',
    'sfx_powerup.ogg',
    'sfx_heal.ogg',
    'sfx_wave_clear.ogg',
    'sfx_button.ogg',
  ];

  static const Map<String, double> _minimumIntervals = {
    'sfx_shoot.ogg': 0.18,
    'sfx_enemy_hit.ogg': 0.30,
    'sfx_enemy_die.ogg': 0.35,
    'sfx_coin.ogg': 0.40,
    'sfx_player_hit.ogg': 0.16,
    'sfx_powerup.ogg': 0.30,
    'sfx_boss_attack.ogg': 0.45,
    'sfx_wave_clear.ogg': 0.50,
    'sfx_assist.ogg': 0.25,
    'sfx_ultimate.ogg': 0.20,
    'sfx_player_die.ogg': 0.80,
    'sfx_button.ogg': 0.08,
  };

  static const Set<String> _optionalGameplaySfx = {
    'sfx_shoot.ogg',
    'sfx_enemy_hit.ogg',
    'sfx_enemy_die.ogg',
    'sfx_coin.ogg',
    'sfx_player_hit.ogg',
    'sfx_heal.ogg',
    'sfx_powerup.ogg',
    'sfx_boss_attack.ogg',
    'sfx_boss_warning.ogg',
    'sfx_wave_clear.ogg',
    'sfx_assist.ogg',
    'sfx_ultimate.ogg',
  };

  static final Map<String, double> _cooldowns = {};
  static final Set<String> _pendingAssets = <String>{};
  static final Map<String, Timer> _pendingCleanupTimers = {};
  static final Set<AudioPlayer> _activePlayers = <AudioPlayer>{};
  static final Map<AudioPlayer, Timer> _activePlayerCleanupTimers =
      <AudioPlayer, Timer>{};
  static bool _preloaded = false;
  static bool _appIsActive = true;
  static int _pendingRequests = 0;
  static int _failureCount = 0;
  static int _skippedCount = 0;
  static DateTime? _suppressedUntil;
  static DateTime? _gameplaySuppressedUntil;

  static int get pendingRequests => _pendingRequests;
  static int get failureCount => _failureCount;
  static int get skippedCount => _skippedCount;
  static bool get gameplaySuppressed {
    final suppressedUntil = _gameplaySuppressedUntil;
    return suppressedUntil != null && suppressedUntil.isAfter(DateTime.now());
  }

  static bool get audioFaulted {
    final suppressedUntil = _suppressedUntil;
    return suppressedUntil != null && suppressedUntil.isAfter(DateTime.now());
  }

  // Like BGM, we do not treat delayed FlameAudio futures as authoritative
  // health signals on Android. We only react to clear immediate errors.

  static Future<void> preloadAllAudio() async {
    if (_preloaded) {
      return;
    }
    await FlameAudio.audioCache.loadAll(preloadAssets);
    _preloaded = true;
  }

  static void update(double dt) {
    if (_cooldowns.isEmpty) {
      return;
    }
    final expired = <String>[];
    _cooldowns.forEach((asset, remaining) {
      final next = remaining - dt;
      if (next <= 0) {
        expired.add(asset);
      } else {
        _cooldowns[asset] = next;
      }
    });
    for (final asset in expired) {
      _cooldowns.remove(asset);
    }
  }

  static void resetGameplaySession() {
    _cooldowns.clear();
    _clearPendingRequests();
    _stopAllActivePlayers();
    _failureCount = 0;
    _skippedCount = 0;
    _gameplaySuppressedUntil = null;
  }

  static void handleLifecycleChange(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _appIsActive = false;
        _clearPendingRequests();
        _stopAllActivePlayers();
        break;
      case AppLifecycleState.resumed:
        _appIsActive = true;
        break;
    }
  }

  static void playUi(
    String asset, {
    double volume = 0.5,
    double minInterval = 0.08,
  }) {
    _play(
      asset,
      volume: volume,
      minInterval: minInterval,
      gameplay: false,
      activeEnemies: 0,
      activeProjectiles: 0,
    );
  }

  static bool playGameplay(
    String asset, {
    double volume = 1.0,
    double minInterval = 0.08,
    int activeEnemies = 0,
    int activeProjectiles = 0,
  }) {
    return _play(
      asset,
      volume: volume,
      minInterval: minInterval,
      gameplay: true,
      activeEnemies: activeEnemies,
      activeProjectiles: activeProjectiles,
    );
  }

  static bool _play(
    String asset, {
    required double volume,
    required double minInterval,
    required bool gameplay,
    required int activeEnemies,
    required int activeProjectiles,
  }) {
    if (!_appIsActive) {
      _skippedCount++;
      return false;
    }

    final suppressedUntil = _suppressedUntil;
    if (suppressedUntil != null && suppressedUntil.isAfter(DateTime.now())) {
      _skippedCount++;
      return false;
    }

    if (gameplay && gameplaySuppressed && _optionalGameplaySfx.contains(asset)) {
      _skippedCount++;
      return false;
    }

    final floor = _minimumIntervals[asset] ?? minInterval;
    var effectiveInterval = math.max(minInterval, floor);
    if (gameplay && activeEnemies >= 20) {
      effectiveInterval *= 1.5;
    }
    if (gameplay && activeEnemies >= 35) {
      effectiveInterval *= 1.5;
    }

    final cooldown = _cooldowns[asset] ?? 0;
    if (cooldown > 0) {
      _skippedCount++;
      return false;
    }

    if (_pendingRequests >= 2 || _pendingAssets.contains(asset)) {
      _skippedCount++;
      return false;
    }

    if (gameplay &&
        (activeEnemies >= 12 || activeProjectiles >= 12) &&
        (asset == 'sfx_enemy_hit.ogg' ||
            asset == 'sfx_shoot.ogg' ||
            asset == 'sfx_coin.ogg' ||
            asset == 'sfx_player_hit.ogg')) {
      _skippedCount++;
      return false;
    }

    if (gameplay &&
        (activeEnemies >= 20 || activeProjectiles >= 18) &&
        (asset == 'sfx_enemy_die.ogg' || asset == 'sfx_powerup.ogg')) {
      _skippedCount++;
      return false;
    }

    if (gameplay &&
        (activeEnemies >= 28 || activeProjectiles >= 24) &&
        asset == 'sfx_boss_attack.ogg') {
      _skippedCount++;
      return false;
    }

    _cooldowns[asset] = effectiveInterval;
    _pendingRequests++;
    _pendingAssets.add(asset);
    _armPendingRelease(asset, const Duration(milliseconds: 280));

    unawaited(() async {
      try {
        final player = await FlameAudio.play(asset, volume: volume);
        _trackActivePlayer(player);
      } catch (error, stackTrace) {
        if (error is TimeoutException) {
          debugPrint('[SFX] ignoring late playback timeout for $asset');
          return;
        }

        _failureCount++;
        debugPrint('[SFX] play command reported error for $asset: $error');
        debugPrintStack(stackTrace: stackTrace, maxFrames: 4);
        _suppressedUntil = DateTime.now().add(const Duration(seconds: 2));
        if (gameplay && _optionalGameplaySfx.contains(asset)) {
          _gameplaySuppressedUntil = DateTime.now().add(
            const Duration(seconds: 4),
          );
        }
      }
    }());

    return true;
  }

  static void _armPendingRelease(String asset, Duration delay) {
    _pendingCleanupTimers.remove(asset)?.cancel();
    _pendingCleanupTimers[asset] = Timer(delay, () {
      _pendingCleanupTimers.remove(asset);
      _pendingAssets.remove(asset);
      if (_pendingRequests > 0) {
        _pendingRequests--;
      }
    });
  }

  static void _clearPendingRequests() {
    for (final timer in _pendingCleanupTimers.values) {
      timer.cancel();
    }
    _pendingCleanupTimers.clear();
    _pendingAssets.clear();
    _pendingRequests = 0;
  }

  static void _trackActivePlayer(AudioPlayer player) {
    _activePlayers.add(player);
    _activePlayerCleanupTimers.remove(player)?.cancel();
    _activePlayerCleanupTimers[player] = Timer(const Duration(seconds: 3), () {
      _releasePlayer(player);
    });
  }

  static void _stopAllActivePlayers() {
    if (_activePlayers.isEmpty) {
      return;
    }
    final players = List<AudioPlayer>.from(_activePlayers);
    for (final player in players) {
      unawaited(() async {
        try {
          await player.stop();
        } catch (_) {
          // Background cleanup is best-effort.
        } finally {
          _releasePlayer(player);
        }
      }());
    }
  }

  static void _releasePlayer(AudioPlayer player) {
    _activePlayerCleanupTimers.remove(player)?.cancel();
    _activePlayers.remove(player);
    unawaited(() async {
      try {
        await player.dispose();
      } catch (_) {
        // Short-lived SFX disposal is best-effort.
      }
    }());
  }
}
