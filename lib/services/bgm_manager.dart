import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';

enum BgmTrack { lobby, battle, boss, gameOver }

class BgmManager {
  BgmManager._();

  static const Map<BgmTrack, String> _assetByTrack = {
    BgmTrack.lobby: 'bgm_lobby.mp3',
    BgmTrack.battle: 'bgm_battle.mp3',
    BgmTrack.boss: 'bgm_boss.mp3',
    BgmTrack.gameOver: 'bgm_gameover.mp3',
  };

  static const Map<BgmTrack, double> _volumeByTrack = {
    BgmTrack.lobby: 0.25,
    BgmTrack.battle: 0.25,
    BgmTrack.boss: 0.30,
    BgmTrack.gameOver: 0.40,
  };

  static const List<String> preloadAssets = [
    'bgm_battle.mp3',
    'bgm_boss.mp3',
    'bgm_gameover.mp3',
    'bgm_lobby.mp3',
  ];

  static BgmTrack? _currentTrack;
  static BgmTrack? _requestedTrack;
  static bool _appIsActive = true;
  static bool _preloaded = false;
  static int _commandSerial = 0;
  static bool _stoppedByLifecycle = false;
  static bool _gameplayRestoreArmed = false;
  static Future<void> _pendingCommand = Future<void>.value();
  static Timer? _inactiveStopTimer;
  static const Duration _inactiveStopDelay = Duration(milliseconds: 350);

  static BgmTrack? get currentTrack => _currentTrack;
  static BgmTrack? get requestedTrack => _requestedTrack;
  static bool get isAppActive => _appIsActive;
  static bool get isRecovering => false;

  // We no longer infer backend failure from FlameAudio futures because on some
  // Android devices the playback futures may complete late even while playback
  // is already progressing in MediaPlayer.
  static bool get audioFaulted => false;

  static Future<void> preloadTracks() async {
    if (_preloaded) {
      return;
    }
    await FlameAudio.audioCache.loadAll(preloadAssets);
    _preloaded = true;
  }

  static Future<void> setTrack(
    BgmTrack? track, {
    bool forceRestart = false,
  }) {
    _requestedTrack = track;
    final commandId = ++_commandSerial;
    _cancelRecovery();
    _cancelInactiveStop();

    if (track == null) {
      _currentTrack = null;
      _stoppedByLifecycle = false;
      _gameplayRestoreArmed = false;
      _forceImmediateStop();
      return Future<void>.value();
    }

    return _enqueue(() async {
      if (commandId != _commandSerial || _requestedTrack != track || !_appIsActive) {
        return;
      }

      final shouldReuseCurrent =
          !forceRestart &&
          _currentTrack == track &&
          FlameAudio.bgm.isPlaying;
      if (shouldReuseCurrent) {
        return;
      }

      final previousTrack = _currentTrack;
      _currentTrack = track;
      _stoppedByLifecycle = false;

      if (previousTrack != null || FlameAudio.bgm.isPlaying) {
        _issueStop();

        // Let the backend settle before issuing the next play command.
        await Future<void>.delayed(const Duration(milliseconds: 220));
        if (commandId != _commandSerial || _requestedTrack != track || !_appIsActive) {
          return;
        }
      }

      await preloadTracks();
      _issuePlay(track);
    });
  }

  static Future<void> stop({bool clearRequest = false}) {
    ++_commandSerial;
    _cancelRecovery();
    _cancelInactiveStop();
    _gameplayRestoreArmed = false;
    if (clearRequest) {
      _requestedTrack = null;
    }
    _currentTrack = null;
    _stoppedByLifecycle = false;
    _forceImmediateStop();
    return Future<void>.value();
  }

  static Future<void> handleLifecycleChange(AppLifecycleState state) async {
    debugPrint(
      '[BGM] lifecycle=$state requested=$_requestedTrack current=$_currentTrack active=$_appIsActive stoppedByLifecycle=$_stoppedByLifecycle',
    );
    switch (state) {
      case AppLifecycleState.inactive:
        _appIsActive = false;
        _cancelRecovery();
        _gameplayRestoreArmed = false;
        _scheduleInactiveStop();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _cancelInactiveStop();
        _applyBackgroundStop(state);
        break;
      case AppLifecycleState.resumed:
        _cancelInactiveStop();
        _appIsActive = true;
        final requestedTrack = _requestedTrack;
        if (requestedTrack != null) {
          if (_shouldAutoRestoreOnResume(requestedTrack)) {
            debugPrint(
              '[BGM] resume detected; auto-restoring non-gameplay track $requestedTrack',
            );
            await ensureRequestedTrackPlaying();
            return;
          }
          debugPrint(
            '[BGM] resume detected; waiting for explicit gameplay resume before restoring $requestedTrack',
          );
        }
        break;
      case AppLifecycleState.detached:
        _cancelInactiveStop();
        _appIsActive = false;
        _cancelRecovery();
        _stoppedByLifecycle = false;
        _gameplayRestoreArmed = false;
        break;
    }
  }

  static void authorizeGameplayRestore() {
    _gameplayRestoreArmed = true;
  }

  static void revokeGameplayRestore() {
    _gameplayRestoreArmed = false;
  }

  static Future<void> ensureRequestedTrackPlaying() async {
    final requestedTrack = _requestedTrack;
    if (!_appIsActive || requestedTrack == null) {
      return;
    }

    if (_requiresExplicitGameplayRestore(requestedTrack) &&
        !_gameplayRestoreArmed) {
      debugPrint(
        '[BGM] blocked gameplay restore for $requestedTrack because no explicit resume authorization is armed',
      );
      return;
    }

    final shouldRefresh =
        _stoppedByLifecycle ||
        _currentTrack != requestedTrack ||
        !FlameAudio.bgm.isPlaying;
    if (!shouldRefresh) {
      return;
    }

    debugPrint(
      '[BGM] ensure requested track playing for $requestedTrack '
      'current=$_currentTrack active=$_appIsActive stoppedByLifecycle=$_stoppedByLifecycle',
    );
    if (_requiresExplicitGameplayRestore(requestedTrack)) {
      _gameplayRestoreArmed = false;
    }
    _stoppedByLifecycle = false;
    await setTrack(requestedTrack, forceRestart: true);
  }

  static void _cancelRecovery() {
    // No-op: BGM restore now happens only through explicit gameplay resume.
  }

  static void _scheduleInactiveStop() {
    _cancelInactiveStop();
    if (_requestedTrack == null || _stoppedByLifecycle) {
      return;
    }
    _inactiveStopTimer = Timer(_inactiveStopDelay, () {
      _inactiveStopTimer = null;
      if (_appIsActive || _requestedTrack == null || _stoppedByLifecycle) {
        return;
      }
      debugPrint('[BGM] inactive persisted; applying deferred background stop');
      _applyBackgroundStop(AppLifecycleState.inactive);
    });
  }

  static void _cancelInactiveStop() {
    _inactiveStopTimer?.cancel();
    _inactiveStopTimer = null;
  }

  static void _applyBackgroundStop(AppLifecycleState state) {
    final wasActive = _appIsActive;
    _appIsActive = false;
    _cancelRecovery();
    _gameplayRestoreArmed = false;
    if (!wasActive && _stoppedByLifecycle) {
      debugPrint(
        '[BGM] background stop already applied; skipping duplicate stop for $state',
      );
      return;
    }
    if (_requestedTrack != null) {
      _stoppedByLifecycle = true;
      _currentTrack = null;
      ++_commandSerial;
      _forceImmediateStop();
    }
  }

  static void _forceImmediateStop() {
    _pendingCommand = Future<void>.value();
    _issueStop();
  }

  static void _issueStop() {
    unawaited(() async {
      try {
        await FlameAudio.bgm.stop();
      } catch (error, stackTrace) {
        debugPrint('[BGM] stop command reported error: $error');
        debugPrintStack(stackTrace: stackTrace, maxFrames: 4);
      }
    }());
  }

  static void _issuePlay(BgmTrack track) {
    unawaited(() async {
      try {
        await FlameAudio.bgm.play(
          _assetByTrack[track]!,
          volume: _volumeByTrack[track]!,
        );
      } catch (error, stackTrace) {
        debugPrint('[BGM] play command reported error for $track: $error');
        debugPrintStack(stackTrace: stackTrace, maxFrames: 4);
      }
    }());
  }

  static Future<void> _enqueue(Future<void> Function() action) {
    _pendingCommand = _pendingCommand.catchError((_) {}).then((_) => action());
    return _pendingCommand;
  }

  static bool _shouldAutoRestoreOnResume(BgmTrack track) {
    switch (track) {
      case BgmTrack.lobby:
      case BgmTrack.gameOver:
        return true;
      case BgmTrack.battle:
      case BgmTrack.boss:
        return false;
    }
  }

  static bool _requiresExplicitGameplayRestore(BgmTrack track) {
    switch (track) {
      case BgmTrack.battle:
      case BgmTrack.boss:
        return true;
      case BgmTrack.lobby:
      case BgmTrack.gameOver:
        return false;
    }
  }
}
