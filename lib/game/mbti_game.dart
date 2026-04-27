import 'dart:async';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/enemies/base_enemy.dart';
import 'components/player.dart';
import 'components/projectiles/base_projectile.dart';
import 'config/character_data.dart';
import 'config/mbti_compatibility.dart';
import 'managers/enemy_spawner.dart';
import 'managers/game_state.dart';
import '../services/bgm_manager.dart';
import '../services/debug_logger.dart';
import '../services/save_manager.dart';
import '../services/sfx_manager.dart';

/// MBTI 히어로: 직장인 생존기 - 메인 게임 클래스
class MbtiGame extends FlameGame with HasCollisionDetection, KeyboardEvents {
  static const double _webMobileBreakpoint = 700;
  static const double _webMobileCameraZoom = 1.35;

  // 게임 상태 (Flutter UI 연동)
  final GameState gameState = GameState();

  // 맵 크기 (512 단위 타일에 맞추어 4x4 배열)
  final Vector2 mapSize = Vector2(2048, 2048);

  // 플레이어
  late Player player;

  // 적 스포너
  late EnemySpawner enemySpawner;

  // 조이스틱 방향 (Flutter 오버레이에서 입력)
  Vector2 _joystickDirection = Vector2.zero();
  Vector2 get joystickDirection => _joystickDirection;

  // 로비 복귀 콜백
  VoidCallback? onReturnToLobby;

  // 세이브 매니저
  final SaveManager? saveManager;
  final SaveData? loadedSave;

  // [성능] 활성 적 캐시 (매 프레임 world.children 순회 대신 사용)
  final List<BaseEnemy> activeEnemies = [];
  final List<Projectile> activeProjectiles = [];

  // [성능] 동시 스킬 텍스트 제한
  int _activeSkillTextCount = 0;
  static const int _maxSkillTextCount = 5;
  static const int _maxProjectileCount = 48;
  static const int _maxTransientEffects = 18;
  static const int _maxActiveEnemies = 20;
  static const double _maxFrameDt = 1 / 20;

  // [성능] 사격 사운드 쿨타임 (초당 12회 이하로 제한)
  double _shootSoundCooldown = 0;
  static const double _shootSoundMinInterval = 0.18;
  double _debugStatsTimer = 0;
  double _wavePerfLogCooldown = 0;
  int _effectBudgetSkips = 0;
  bool _staticWorldInitialized = false;
  final List<Component> _staticWorldComponents = [];
  PositionComponent? _activeCompanionVisual;
  double _activeCompanionLifetime = 0;
  int _activeTransientEffects = 0;
  bool _pausedByAppLifecycle = false;
  bool _resumeAfterAppLifecycle = false;
  bool _enginePausedByAppLifecycle = false;
  bool _appLifecycleActive = true;
  bool _awaitingResumeConfirmation = false;
  bool _countdownResumeAuthorized = false;
  AppLifecycleState? _lastObservedLifecycleState;
  int _resumePromptToken = 0;

  MbtiGame({this.saveManager, this.loadedSave});

  bool get isAppLifecycleActive => _appLifecycleActive;
  bool get isAwaitingResumeConfirmation => _awaitingResumeConfirmation;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _applyResponsiveCameraZoom(size);
  }

  void _applyResponsiveCameraZoom(Vector2 viewportSize) {
    camera.viewfinder.zoom =
        kIsWeb && viewportSize.x <= _webMobileBreakpoint
            ? _webMobileCameraZoom
            : 1.0;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 오디오는 Splash의 AudioBootstrap에서 한 번만 준비한다.
    // 여기서는 필요한 트랙만 요청한다.
    unawaited(setBgmTrack(BgmTrack.battle));

    // 프리로드: 모든 캐릭터의 스프라이트를 미리 캐싱합니다 (어시스트 시 지연 방지)
    for (final char in MbtiCharacters.all) {
      await images.load(char.assetPath);
    }

    // 새 게임/이어하기 시작 시의 상태는 HomeScreen에서 이미 주입한다.
    // 여기서 전역 강화 레벨을 다시 읽어오면 삭제된 예전 플레이의
    // HP/ATK/SPD 레벨이 새 게임에 되살아날 수 있으므로 재주입하지 않는다.
    // 맵 배경 (어두운 사무실 색상)
    await _ensureStaticWorld();

    // 바닥 그리드 패턴 (AI 리소스 타일링)

    // 장애물 배치

    // 플레이어 생성
    final characterData = MbtiCharacters.getByType(gameState.selectedCharacter);
    player = Player(
      characterData: characterData,
      restoredHp: loadedSave?.hp,
      restoredMaxHp: loadedSave?.maxHp,
      restoredSpeed: loadedSave?.speed,
      restoredAttack: loadedSave?.attackPower,
      restoredMultiShot: loadedSave?.multiShotCount,
      restoredAttackInterval: loadedSave?.attackInterval,
    );
    player.position = mapSize / 2; // 맵 중앙에서 시작
    world.add(player);

    // 카메라가 플레이어 추적 (시작 시 스냅핑하여 줌인/팬 효과 방지)
    camera.follow(player, snap: true);
    _applyResponsiveCameraZoom(size);

    // 게임 상태 초기화
    gameState.reset();
    gameState.initHp(characterData.maxHp);
    gameState.initUltCooldown(characterData.ultCooldown);
    gameState.initAssistCooldown();

    // 적 스포너 생성 및 시작
    enemySpawner = EnemySpawner();
    add(enemySpawner);
    activeProjectiles.clear();
    _activeSkillTextCount = 0;
    _effectBudgetSkips = 0;
    _debugStatsTimer = 0;
    activeEnemies.clear(); // 캐시 초기화

    // 세이브 데이터 복원
    if (loadedSave != null) {
      gameState.setWave(loadedSave!.wave);
      gameState.syncHp(current: loadedSave!.hp, max: loadedSave!.maxHp);
      gameState.syncUltCooldown(loadedSave!.ultCooldownCurrent);
      gameState.syncAssistCooldown(loadedSave!.assistCooldownCurrent);
      gameState.syncUltTickets(loadedSave!.ultTicketCount);
      gameState.syncAssistTickets(loadedSave!.assistTicketCount);
      // 해당 웨이브부터 시작
      enemySpawner.startWave(loadedSave!.wave - 1);
    } else {
      // 새 게임: 웨이브 1 시작 (인덱스 0)
      enemySpawner.startWave(0);
    }
  }

  @override
  void onMount() {
    super.onMount();
    // 3, 2, 1 카운트다운 오버레이를 표시하고 엔진 일시정지 (몬스터/캐릭터 정지)
    _awaitingResumeConfirmation = false;
    overlays.remove('ResumePrompt');
    _countdownResumeAuthorized = true;
    pauseEngine();
    overlays.add('Countdown');
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
        if (gameState.isAssistReady) {
          performAssist();
        }
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
        if (gameState.isUltReady) {
          player.useUltimate();
        }
        return KeyEventResult.handled;
      }
    }
    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void update(double dt) {
    if (!_appLifecycleActive) {
      return;
    }

    final frameDt = dt.clamp(0, _maxFrameDt).toDouble();

    super.update(frameDt);
    if (_shootSoundCooldown > 0) {
      _shootSoundCooldown = max(0, _shootSoundCooldown - frameDt);
    }
    if (_wavePerfLogCooldown > 0) {
      _wavePerfLogCooldown = max(0, _wavePerfLogCooldown - frameDt);
    }
    SfxManager.update(frameDt);
    if (_activeCompanionVisual != null) {
      if (_activeCompanionVisual!.isRemoved) {
        _activeCompanionVisual = null;
        _activeCompanionLifetime = 0;
      } else if (_activeCompanionLifetime > 0) {
        _activeCompanionLifetime = max(0, _activeCompanionLifetime - frameDt);
        if (_activeCompanionLifetime <= 0) {
          _removeActiveCompanionVisual();
        }
      }
    }

    if (!kDebugMode) {
      return;
    }

    _debugStatsTimer += frameDt;
    if (_debugStatsTimer >= 15) {
      _debugStatsTimer = 0;
      debugLogState('heartbeat');
    }

    final inHotWave = gameState.currentWave >= 5;
    final underPressure =
        activeProjectiles.length >= 18 ||
        activeEnemies.length >= 16 ||
        world.children.length >= 62;
    if (inHotWave && underPressure && _wavePerfLogCooldown <= 0) {
      _wavePerfLogCooldown = 4;
      debugLogState('wave_hotspot');
    }
  }

  Future<void> setBgmTrack(BgmTrack track, {bool forceRestart = false}) async {
    await BgmManager.setTrack(track, forceRestart: forceRestart);
  }

  void tryPlayShootSfx() {
    if (_shootSoundCooldown > 0) {
      return;
    }
    _shootSoundCooldown = _shootSoundMinInterval;
    final played = SfxManager.playGameplay(
      'sfx_shoot.ogg',
      volume: 0.3,
      minInterval: _shootSoundMinInterval,
      activeEnemies: activeEnemies.length,
      activeProjectiles: activeProjectiles.length,
    );
    if (!played) {
      _effectBudgetSkips++;
    }
  }

  void playThrottledSfx(
    String asset, {
    double volume = 1.0,
    double minInterval = 0.08,
  }) {
    final played = SfxManager.playGameplay(
      asset,
      volume: volume,
      minInterval: minInterval,
      activeEnemies: activeEnemies.length,
      activeProjectiles: activeProjectiles.length,
    );
    if (!played) {
      _effectBudgetSkips++;
    }
  }

  void spawnProjectile(Projectile projectile) {
    if (activeProjectiles.length >= _maxProjectileCount) {
      _effectBudgetSkips++;
      return;
    }
    world.add(projectile);
  }

  void registerEnemy(BaseEnemy enemy) {
    if (!activeEnemies.contains(enemy)) {
      activeEnemies.add(enemy);
    }
  }

  void unregisterEnemy(BaseEnemy enemy) {
    activeEnemies.remove(enemy);
  }

  void registerProjectile(Projectile projectile) {
    if (activeProjectiles.contains(projectile)) {
      return;
    }
    if (activeProjectiles.length >= _maxProjectileCount) {
      _effectBudgetSkips++;
      projectile.removeFromParent();
      return;
    }
    activeProjectiles.add(projectile);
  }

  void unregisterProjectile(Projectile projectile) {
    activeProjectiles.remove(projectile);
  }

  int get maxActiveEnemies => _maxActiveEnemies;

  void handleAppLifecycleState(AppLifecycleState state) {
    if (_lastObservedLifecycleState == state) {
      return;
    }
    _lastObservedLifecycleState = state;
    unawaited(BgmManager.handleLifecycleChange(state));
    SfxManager.handleLifecycleChange(state);
    debugLog(
      '[APP] game lifecycle=$state paused=$paused gamePaused=${gameState.isPaused} gameOver=${gameState.isGameOver} victory=${gameState.isVictory}',
    );
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _appLifecycleActive = false;
        _joystickDirection = Vector2.zero();
        _awaitingResumeConfirmation = false;
        _countdownResumeAuthorized = false;
        _resumePromptToken++;
        BgmManager.revokeGameplayRestore();
        overlays.remove('ResumePrompt');
        overlays.remove('Countdown');
        if (!_pausedByAppLifecycle) {
          _resumeAfterAppLifecycle =
              !paused &&
              !gameState.isPaused &&
              !gameState.isGameOver &&
              !gameState.isVictory;
          _pausedByAppLifecycle = true;
          _enginePausedByAppLifecycle = !paused;
          if (_enginePausedByAppLifecycle) {
            pauseEngine();
          }
        }
        break;
      case AppLifecycleState.resumed:
        _appLifecycleActive = true;
        final shouldResume =
            _pausedByAppLifecycle &&
            _resumeAfterAppLifecycle &&
            _enginePausedByAppLifecycle &&
            !gameState.isPaused &&
            !gameState.isGameOver &&
            !gameState.isVictory;
        _pausedByAppLifecycle = false;
        _resumeAfterAppLifecycle = false;
        _enginePausedByAppLifecycle = false;
        if (shouldResume && paused) {
          overlays.remove('Countdown');
          _countdownResumeAuthorized = false;
          _awaitingResumeConfirmation = true;
          _showResumePromptDeferred();
          if (!overlays.isActive('ResumePrompt')) {
            overlays.add('ResumePrompt');
          }
        } else {
          _resumePromptToken++;
          BgmManager.revokeGameplayRestore();
        }
        break;
      case AppLifecycleState.detached:
        _appLifecycleActive = false;
        _joystickDirection = Vector2.zero();
        _awaitingResumeConfirmation = false;
        _countdownResumeAuthorized = false;
        _resumePromptToken++;
        BgmManager.revokeGameplayRestore();
        overlays.remove('ResumePrompt');
        overlays.remove('Countdown');
        _pausedByAppLifecycle = true;
        _resumeAfterAppLifecycle = false;
        _enginePausedByAppLifecycle = !paused;
        if (!paused) {
          pauseEngine();
        }
        break;
    }
  }

  void resumeGameplayIfAllowed({
    String reason = 'unknown',
    bool consumeCountdownAuthorization = false,
  }) {
    if (!_appLifecycleActive ||
        _pausedByAppLifecycle ||
        _awaitingResumeConfirmation) {
      debugLog(
        '[APP] blocked resume from $reason appActive=$_appLifecycleActive lifecyclePaused=$_pausedByAppLifecycle awaitingConfirm=$_awaitingResumeConfirmation',
      );
      return;
    }

    if (consumeCountdownAuthorization &&
        !_consumeCountdownResumeAuthorization()) {
      debugLog(
        '[APP] blocked resume from $reason because countdown authorization was missing',
      );
      return;
    }

    if (paused) {
      resumeEngine();
    }
    BgmManager.authorizeGameplayRestore();
    unawaited(BgmManager.ensureRequestedTrackPlaying());
  }

  void confirmLifecycleResume() {
    if (!_awaitingResumeConfirmation) {
      return;
    }
    _resumePromptToken++;
    _awaitingResumeConfirmation = false;
    overlays.remove('ResumePrompt');
    overlays.remove('Countdown');
    _countdownResumeAuthorized = true;
    overlays.add('Countdown');
  }

  void cancelLifecycleResume({bool returnToLobby = false}) {
    _awaitingResumeConfirmation = false;
    _countdownResumeAuthorized = false;
    _resumePromptToken++;
    BgmManager.revokeGameplayRestore();
    overlays.remove('ResumePrompt');
    overlays.remove('Countdown');
    if (returnToLobby) {
      unawaited(this.returnToLobby());
    }
  }

  bool _consumeCountdownResumeAuthorization() {
    if (!_countdownResumeAuthorized) {
      return false;
    }
    _countdownResumeAuthorized = false;
    return true;
  }

  void startCountdownResume({String reason = 'unknown'}) {
    if (!_appLifecycleActive ||
        _pausedByAppLifecycle ||
        _awaitingResumeConfirmation ||
        gameState.isGameOver ||
        gameState.isVictory) {
      debugLog(
        '[APP] blocked countdown resume from $reason '
        'appActive=$_appLifecycleActive lifecyclePaused=$_pausedByAppLifecycle '
        'awaitingConfirm=$_awaitingResumeConfirmation gameOver=${gameState.isGameOver} '
        'victory=${gameState.isVictory}',
      );
      return;
    }

    _resumePromptToken++;
    _countdownResumeAuthorized = true;
    overlays.remove('ResumePrompt');
    overlays.remove('Countdown');
    pauseEngine();
    overlays.add('Countdown');
  }

  void _showResumePromptDeferred() {
    final token = ++_resumePromptToken;
    unawaited(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (_resumePromptToken != token) {
        return;
      }
      if (!_appLifecycleActive ||
          !_awaitingResumeConfirmation ||
          gameState.isPaused ||
          gameState.isGameOver ||
          gameState.isVictory) {
        return;
      }
      if (!overlays.isActive('ResumePrompt')) {
        overlays.add('ResumePrompt');
      }
    }());
  }

  bool canSpawnTransientEffect() {
    final canSpawn = _activeTransientEffects < _maxTransientEffects;
    if (!canSpawn) {
      _effectBudgetSkips++;
    }
    return canSpawn;
  }

  int _countTransientWorldEffects() {
    return _activeTransientEffects;
  }

  void debugLogState(String reason) {
    if (!kDebugMode) {
      return;
    }
    debugLog(
      '[PERF][$reason] enemies=${activeEnemies.length} '
      'projectiles=${activeProjectiles.length} '
      'effects=${_countTransientWorldEffects()} '
      'world=${world.children.length} '
      'bgmCurrent=${BgmManager.currentTrack} '
      'bgmRequested=${BgmManager.requestedTrack} '
      'bgmFaulted=${BgmManager.audioFaulted} '
      'pendingSfx=${SfxManager.pendingRequests} '
      'sfxFailures=${SfxManager.failureCount} '
      'sfxSuppressed=${SfxManager.gameplaySuppressed} '
      'sfxFaulted=${SfxManager.audioFaulted} '
      'skipped=$_effectBudgetSkips',
    );
  }

  Future<void> _ensureStaticWorld() async {
    if (_staticWorldInitialized) {
      return;
    }

    final background = RectangleComponent(
      size: mapSize,
      paint: Paint()..color = const Color(0xFF1A1A2E),
      priority: -10,
    );
    _addStaticWorldComponent(background);
    await _addGridPattern();
    await _addObstacles();
    _staticWorldInitialized = true;
  }

  void _addStaticWorldComponent(Component component) {
    _staticWorldComponents.add(component);
    world.add(component);
  }

  void _clearDynamicWorld() {
    _removeActiveCompanionVisual();
    final dynamicWorldChildren = world.children
        .where((child) => !_staticWorldComponents.contains(child))
        .toList();
    if (dynamicWorldChildren.isNotEmpty) {
      world.removeAll(dynamicWorldChildren);
    }

    final runtimeChildren = children
        .where((child) => child is EnemySpawner || child is TimerComponent)
        .toList();
    if (runtimeChildren.isNotEmpty) {
      removeAll(runtimeChildren);
    }

    activeEnemies.clear();
    activeProjectiles.clear();
    _activeSkillTextCount = 0;
    _shootSoundCooldown = 0;
    _effectBudgetSkips = 0;
    _activeTransientEffects = 0;
    SfxManager.resetGameplaySession();
    debugLogState('clear_dynamic_world');
  }

  void _removeActiveCompanionVisual() {
    _activeCompanionVisual?.removeFromParent();
    _activeCompanionVisual = null;
    _activeCompanionLifetime = 0;
  }

  void addTimedWorldComponent(
    PositionComponent component, {
    required double lifetime,
    bool countsAsTransient = true,
  }) {
    if (countsAsTransient) {
      if (!canSpawnTransientEffect()) {
        return;
      }
      _activeTransientEffects++;
    }
    component.add(
      TimerComponent(
        period: lifetime,
        removeOnFinish: true,
        onTick: () {
          if (countsAsTransient && _activeTransientEffects > 0) {
            _activeTransientEffects--;
          }
          component.removeFromParent();
        },
      ),
    );
    world.add(component);
  }

  /// 바닥 타일 추가
  Future<void> _addGridPattern() async {
    try {
      final bgSprite = await images.load('maps/bg_tile.png');
      const tileSize = 512.0;

      for (double x = 0; x < mapSize.x; x += tileSize) {
        for (double y = 0; y < mapSize.y; y += tileSize) {
          _addStaticWorldComponent(
            SpriteComponent(
              sprite: Sprite(bgSprite),
              position: Vector2(x, y),
              size: Vector2(tileSize, tileSize),
              priority: -9,
            ),
          );
        }
      }
    } catch (e) {
      debugLogError('Error loading map tile: ', e);
    }
  }

  /// 맵 장애물 10개 랜덤 배치
  Future<void> _addObstacles() async {
    try {
      final obsSprite = await images.load('maps/obstacles/obstacle_0.png');
      final rand = Random();

      for (int i = 0; i < 15; i++) {
        final x = rand.nextDouble() * (mapSize.x - 200) + 100;
        final y = rand.nextDouble() * (mapSize.y - 200) + 100;

        final obstacle = SpriteComponent(
          sprite: Sprite(obsSprite),
          position: Vector2(x, y),
          size: Vector2(96, 96), // 적당한 크기
          anchor: Anchor.center,
          priority: -5,
        );
        _addStaticWorldComponent(obstacle);
      }
    } catch (e) {
      debugLogError('Error loading obstacle: ', e);
    }
  }

  /// 조이스틱 방향 업데이트 (Flutter 오버레이에서 호출)
  void updateJoystick(Vector2 direction) {
    _joystickDirection = direction;
  }

  // ══════════════════════════════════════════
  // ═══ 자동 공격 패턴 ═══
  // ══════════════════════════════════════════
  /// 플레이어 자동 공격 공통 헬퍼 (다중 발사 지원)
  bool _fireMultiProjectiles({
    required Player p,
    required List<BaseEnemy> enemies,
    required double speed,
    required double damageRatio,
    required double radius,
    required String emoji,
    bool isSplash = false,
    double splashRadius = 30,
    double lifetime = 3.0,
  }) {
    final baseDir = _resolveAutoAttackDirection(p, enemies);
    final count = p.multiShotCount;
    final spreadAngle = 0.15; // 투사체 간 각도 차이

    final startAngle = -spreadAngle * (count - 1) / 2;

    for (int i = 0; i < count; i++) {
      final angle = startAngle + (i * spreadAngle);
      final dir = baseDir.clone()..rotate(angle);

      spawnProjectile(
        Projectile(
          position: p.position.clone(),
          direction: dir,
          speed: speed,
          damage: p.attackPower * damageRatio,
          color: p.characterData.color,
          radius: radius,
          emoji: emoji,
          isSplash: isSplash,
          splashRadius: splashRadius,
          knockbackPower: p.characterData.knockbackPower,
          pierceCount: p.characterData.pierceCount,
          lifetime: lifetime,
        ),
      );
    }
    return true;
  }

  bool performAutoAttack(Player attackingPlayer) {
    final enemies = activeEnemies; // [성능] O(1) 캐시 접근

    switch (attackingPlayer.characterData.attackType) {
      case AttackType.wave:
        return _attackWave(attackingPlayer, enemies);
      case AttackType.homing:
        return _attackHoming(attackingPlayer, enemies);
      case AttackType.summon:
        return _attackSummon(attackingPlayer, enemies);
      case AttackType.straight:
        return _attackStraight(attackingPlayer, enemies);
      case AttackType.aura:
        return _attackAura(attackingPlayer, enemies);
      case AttackType.blink:
        return _attackBlink(attackingPlayer, enemies);
      case AttackType.rapid:
        return _attackRapid(attackingPlayer, enemies);
      case AttackType.shield:
        return _attackShield(attackingPlayer, enemies);
    }
  }

  /// ESTJ: 로 돌진하는 방패 (파란색 잔상) 🛡️
  bool _attackWave(Player p, List<BaseEnemy> enemies) {
    return _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 300,
      damageRatio: 1.0,
      radius: 12,
      emoji: p.characterData.projectileEmoji,
      isSplash: true,
      splashRadius: 30,
      lifetime: 0.4, // 근거리 파동망
    );
  }

  /// ENTP: 팩트 폭격 - 전구 발사 💡
  bool _attackHoming(Player p, List<BaseEnemy> enemies) {
    return _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 250,
      damageRatio: 1.0,
      radius: 10,
      emoji: p.characterData.projectileEmoji,
      isSplash: true,
      splashRadius: 30,
    );
  }

  /// INFP: 내면의 친구 - 정령 소환 (꽃잎 치유 광선 🌸)
  bool _attackSummon(Player p, List<BaseEnemy> enemies) {
    return _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 180,
      damageRatio: 1.0,
      radius: 10,
      emoji: p.characterData.projectileEmoji,
      lifetime: 2.0, // 원거리 투사체
    );
  }

  /// ISTP: 나사 던지기 - 전방 직선 스패너 투척 🔧
  bool _attackStraight(Player p, List<BaseEnemy> enemies) {
    return _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 350,
      damageRatio: 1.0,
      radius: 10,
      emoji: p.characterData.projectileEmoji,
      lifetime: 2.5, // 긴 사거리
    );
  }

  /// ENFJ: 리더십 오라 - 깃발 휘두르기 🚩
  bool _attackAura(Player p, List<BaseEnemy> enemies) {
    return _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 200,
      damageRatio: 1.0,
      radius: 12,
      emoji: p.characterData.projectileEmoji,
      lifetime: 1.0, // 중거리 오라
    );
  }

  /// INTJ: 순간이동 슬래시 - 가장 가까운 적 위치로 순간이동 후 범위 공격
  bool _attackBlink(Player attackingPlayer, List<BaseEnemy> enemies) {
    return _fireMultiProjectiles(
      p: attackingPlayer,
      enemies: enemies,
      speed: 320,
      damageRatio: 1.0,
      radius: 10,
      emoji: attackingPlayer.characterData.projectileEmoji,
      isSplash: true,
      splashRadius: 36,
      lifetime: 2.8,
    );
  }

  /// ESFP: 빠른 연타 - 마이크 음파 🎤
  bool _attackRapid(Player p, List<BaseEnemy> enemies) {
    // 멀티샷 갯수에 약간의 패널티(원래 2발 발사하므로 계수 보정)
    return _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 280,
      damageRatio: 0.7,
      radius: 10,
      emoji: p.characterData.projectileEmoji,
    );
  }

  /// ISFJ: 냄비 뚜껑 방어 투사체 🍲
  bool _attackShield(Player p, List<BaseEnemy> enemies) {
    final fired = _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 200,
      damageRatio: 1.0,
      radius: 12,
      emoji: p.characterData.projectileEmoji,
    );

    // 20% + 멀티샷 비례 확률로 약간 회복
    final healChance = 0.2 + (p.multiShotCount * 0.05);
    if (Random().nextDouble() < healChance) {
      p.heal(p.maxHp * 0.02, playEffectSound: false);
    }
    return fired;
  }

  // ══════════════════════════════════════════
  // ═══ 유틸리티 ═══
  // ══════════════════════════════════════════
  BaseEnemy? _findClosestEnemy(Vector2 from, List<BaseEnemy> enemies) {
    BaseEnemy? closest;
    double closestDist = double.infinity;
    for (final enemy in enemies) {
      final dist = from.distanceTo(enemy.position);
      if (dist < closestDist) {
        closestDist = dist;
        closest = enemy;
      }
    }
    return closest;
  }

  Vector2 _resolveAutoAttackDirection(Player player, List<BaseEnemy> enemies) {
    final closest = _findClosestEnemy(player.position, enemies);
    if (closest != null) {
      final toEnemy = closest.position - player.position;
      if (toEnemy.length2 > 0) {
        return toEnemy.normalized();
      }
    }

    final fallback = player.attackFacingDirection;
    if (fallback.length2 > 0) {
      return fallback.normalized();
    }

    return Vector2(1, 0);
  }

  void _dealDamageInRadius(Vector2 center, double radius, double damage) {
    final activeEnemies = List<BaseEnemy>.from(this.activeEnemies);
    for (final enemy in activeEnemies) {
      // [성능] 캐시 사용
      if (center.distanceTo(enemy.position) <= radius + enemy.radius) {
        enemy.takeDamage(damage);
      }
    }
  }

  void showSkillText(String text, Color color, Vector2 pos) {
    // [성능] 동시 스킬 텍스트 최대 5개로 제한
    if (_activeSkillTextCount >= _maxSkillTextCount ||
        !canSpawnTransientEffect()) {
      return;
    }
    _activeSkillTextCount++;

    final textComp = TextComponent(
      text: text,
      position: pos.clone()..y -= 60,
      anchor: Anchor.center,
      priority: 20,
      textRenderer: TextPaint(
        style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
    );

    textComp.add(
      TimerComponent(
        period: 1.5,
        removeOnFinish: true,
        onTick: () {
          _activeSkillTextCount--;
          if (_activeTransientEffects > 0) {
            _activeTransientEffects--;
          }
          textComp.removeFromParent();
        },
      ),
    );
    _activeTransientEffects++;
    world.add(textComp);
  }

  // ══════════════════════════════════════════
  // ═══ 필살기 패턴 ═══
  // ══════════════════════════════════════════
  void performUltimate(Player attackingPlayer) {
    // 필살기 효과 발동 (기존 스위치문 대체 -> 내부 함수는 여전히 호출)
    switch (attackingPlayer.characterData.attackType) {
      case AttackType.wave:
        _ultWave(attackingPlayer);
        break;
      case AttackType.homing:
        _ultHoming(attackingPlayer);
        break;
      case AttackType.summon:
        _ultSummon(attackingPlayer);
        break;
      case AttackType.straight:
        _ultStraight(attackingPlayer);
        break;
      case AttackType.aura:
        _ultAura(attackingPlayer);
        break;
      case AttackType.blink:
        _ultBlink(attackingPlayer);
        break;
      case AttackType.rapid:
        _ultRapid(attackingPlayer);
        break;
      case AttackType.shield:
        _ultShield(attackingPlayer);
        break;
    }

    // 텍스트 출력. "[동료] MBTI: " 부분 제거
    String ultText = attackingPlayer.characterData.assistText;
    ultText = ultText.replaceAll('[동료] ', '');
    ultText = ultText.replaceAll('${attackingPlayer.characterData.mbti}: ', '');

    showSkillText(
      ultText,
      attackingPlayer.characterData.color,
      attackingPlayer.position,
    );
    playThrottledSfx('sfx_ultimate.ogg', volume: 0.7, minInterval: 0.12);
  }

  /// ESTJ 필살기: "철벽 방어" - 전신 보호막 🛡️ + 범위 데미지
  void _ultWave(Player p) {
    _dealDamageInRadius(p.position, 180, p.attackPower * 4.0);
    final balancedWave = CircleComponent(
      radius: 180,
      position: p.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = p.characterData.color.withValues(alpha: 0.4),
    );
    addTimedWorldComponent(balancedWave, lifetime: 0.65);
    p.isInvincible = true;
    final shieldVisual = TextComponent(
      text: p.characterData.effectEmoji,
      position: Vector2(p.size.x / 2, -20),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: TextStyle(fontSize: 30)),
    );
    p.add(shieldVisual);
    add(
      TimerComponent(
        period: 3.5,
        removeOnFinish: true,
        onTick: () {
          p.isInvincible = false;
          shieldVisual.removeFromParent();
        },
      ),
    );
    _addPulseRingEffect(
      center: p.position,
      radius: 180,
      color: p.characterData.color,
      lifetime: 0.65,
    );
    _addRadialEmojiEffect(
      center: p.position,
      emojis: characterEffectBurst(p.characterData, 4),
      radius: 115,
      fontSize: 28,
      color: p.characterData.color,
      lifetime: 0.65,
    );
  }

  /// ENTP 필살기: "브레인스토밍 폭발" - 광역 폭발 💥
  void _ultHoming(Player p) {
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final dir = Vector2(cos(angle), sin(angle));
      final offset = dir * 30.0;
      spawnProjectile(
        Projectile(
          position: p.position.clone()..add(offset),
          direction: dir,
          speed: 320,
          damage: p.attackPower * 2.4,
          color: p.characterData.color,
          radius: 20,
          emoji: p.characterData.projectileEmoji,
          isSplash: true,
          splashRadius: 55,
        ),
      );
    }
    _addPulseRingEffect(
      center: p.position,
      radius: 120,
      color: p.characterData.color,
      lifetime: 0.55,
      alpha: 0.28,
    );
    _addRadialEmojiEffect(
      center: p.position,
      emojis: characterEffectBurst(p.characterData, 8),
      radius: 95,
      fontSize: 24,
      color: p.characterData.color,
      lifetime: 0.55,
    );
  }

  /// INFP 필살기: "힐링 서클" - 장판형 회복 🌿
  void _ultSummon(Player p) {
    p.heal(p.maxHp * 0.45);
    p.isInvincible = true;

    final sanctuary = CircleComponent(
      radius: 140,
      position: p.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.3),
    );
    sanctuary.add(
      TextComponent(
        text: p.characterData.effectEmoji,
        position: Vector2(140, 140),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: 40)),
      ),
    );
    addTimedWorldComponent(sanctuary, lifetime: 3.5);
    add(
      TimerComponent(
        period: 3.5,
        removeOnFinish: true,
        onTick: () {
          p.isInvincible = false;
          sanctuary.removeFromParent();
        },
      ),
    );
    _addPulseRingEffect(
      center: p.position,
      radius: 140,
      color: const Color(0xFF6DDC8B),
      lifetime: 0.8,
      alpha: 0.30,
    );
    _addRadialEmojiEffect(
      center: p.position,
      emojis: characterEffectBurst(p.characterData, 6),
      radius: 90,
      fontSize: 26,
      color: const Color(0xFF6DDC8B),
      lifetime: 0.8,
    );
  }

  /// ISTP 필살기: "기계 장치 폭발" - 부품 파편 ⚙️
  void _ultStraight(Player p) {
    var burstDir = _joystickDirection.clone();
    if (burstDir == Vector2.zero()) burstDir = Vector2(1, 0);
    burstDir.normalize();
    spawnProjectile(
      Projectile(
        position: p.position.clone(),
        direction: burstDir,
        speed: 500,
        damage: p.attackPower * 6.0,
        color: p.characterData.color,
        radius: 24,
        emoji: p.characterData.projectileEmoji,
        isSplash: true,
        splashRadius: 75,
      ),
    );
    _addPulseRingEffect(
      center: p.position,
      radius: 95,
      color: p.characterData.color,
      lifetime: 0.45,
      alpha: 0.28,
    );
    _addRadialEmojiEffect(
      center: p.position,
      emojis: characterEffectBurst(p.characterData, 4),
      radius: 70,
      fontSize: 24,
      color: p.characterData.color,
      lifetime: 0.45,
    );
  }

  /// ENFJ 필살기: "사기 진작 오라" - 황금빛 왕관 ✨
  void _ultAura(Player p) {
    final originalAtk = p.attackPower;
    p.attackPower *= 2;
    _dealDamageInRadius(p.position, 160, p.attackPower * 1.8);

    final auraEffect = CircleComponent(
      radius: 160,
      position: p.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.25),
    );
    auraEffect.add(
      TextComponent(
        text: p.characterData.effectEmoji,
        position: Vector2(160, 60),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: 50)),
      ),
    );
    auraEffect.add(
      TimerComponent(
        period: 5.0,
        removeOnFinish: true,
        onTick: () => p.attackPower = originalAtk,
      ),
    );
    addTimedWorldComponent(auraEffect, lifetime: 5.0);
    _addRadialEmojiEffect(
      center: p.position,
      emojis: characterEffectBurst(p.characterData, 6),
      radius: 110,
      fontSize: 26,
      color: const Color(0xFFFFD54F),
      lifetime: 0.8,
    );
  }

  /// INTJ 필살기: "단검 기습" - 날카로운 일격 🗡️ (맵 전체)
  void _ultBlink(Player p) {
    final closest = _findClosestEnemy(p.position, activeEnemies);
    final burstCenter = closest?.position.clone() ?? p.position.clone();
    _dealDamageInRadius(burstCenter, 170, p.attackPower * 4.0);

    final flash = CircleComponent(
      radius: 170,
      position: burstCenter,
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xFF00BCD4).withValues(alpha: 0.32),
      priority: 100,
    );
    flash.add(
      TextComponent(
        text: p.characterData.effectEmoji,
        position: Vector2(170, 120),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: 72)),
      ),
    );
    addTimedWorldComponent(flash, lifetime: 0.7);
    _addPulseRingEffect(
      center: burstCenter,
      radius: 170,
      color: p.characterData.color,
      lifetime: 0.7,
      alpha: 0.42,
      strokeWidth: 6,
    );
    _addRadialEmojiEffect(
      center: burstCenter,
      emojis: characterEffectBurst(p.characterData, 6),
      radius: 105,
      fontSize: 28,
      color: p.characterData.color,
      lifetime: 0.7,
    );
  }

  /// ESFP 필살기: "스포트라이트 집중 조명" - 🔦 연사
  void _ultRapid(Player p) {
    for (int i = 0; i < 16; i++) {
      final angle = i * pi / 8;
      spawnProjectile(
        Projectile(
          position: p.position.clone(),
          direction: Vector2(cos(angle), sin(angle)),
          speed: 250,
          damage: p.attackPower * 1.8,
          color: p.characterData.color,
          radius: 16,
          emoji: p.characterData.projectileEmoji,
        ),
      );
    }
    p.reduceAttackInterval(0.25);
    add(
      TimerComponent(
        period: 3.0,
        removeOnFinish: true,
        onTick: () => p.reduceAttackInterval(-0.25),
      ),
    );
    _addPulseRingEffect(
      center: p.position,
      radius: 125,
      color: p.characterData.color,
      lifetime: 0.55,
      alpha: 0.3,
    );
    _addRadialEmojiEffect(
      center: p.position,
      emojis: characterEffectBurst(p.characterData, 6),
      radius: 88,
      fontSize: 24,
      color: p.characterData.color,
      lifetime: 0.55,
    );
  }

  /// ISFJ 필살기: "안전 제일 보호막" - 반투명 장벽 🟢
  void _ultShield(Player p) {
    p.isInvincible = true;
    p.heal(p.maxHp * 0.35);
    _dealDamageInRadius(p.position, 110, p.attackPower * 2.0);

    final shieldEffect = CircleComponent(
      radius: 90,
      position: p.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.35),
    );
    shieldEffect.add(
      TextComponent(
        text: p.characterData.effectEmoji,
        position: Vector2(90, -15),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: 24)),
      ),
    );
    shieldEffect.add(
      TimerComponent(
        period: 4.5,
        removeOnFinish: true,
        onTick: () => p.isInvincible = false,
      ),
    );
    addTimedWorldComponent(shieldEffect, lifetime: 4.5);
    _addPulseRingEffect(
      center: p.position,
      radius: 110,
      color: const Color(0xFF66BB6A),
      lifetime: 0.75,
      alpha: 0.32,
    );
    _addRadialEmojiEffect(
      center: p.position,
      emojis: characterEffectBurst(p.characterData, 4),
      radius: 74,
      fontSize: 24,
      color: const Color(0xFF66BB6A),
      lifetime: 0.75,
    );
  }

  // ══════════════════════════════════════════
  // ═══ 동료 호출 (ASSIST) ═══
  // ══════════════════════════════════════════
  void performAssist() {
    if (!gameState.isAssistReady) {
      return;
    }
    if (gameState.assistCooldownCurrent <= 0) {
      gameState.useAssist();
    } else if (!gameState.consumeAssistTicket()) {
      return;
    }

    final companionData = gameState.companionData;
    final multiplier = gameState.companionPowerMultiplier;
    final grade = gameState.companionGrade;

    showSkillText(
      companionData.assistText,
      companionData.color,
      player.position,
    );
    playThrottledSfx('sfx_assist.ogg', volume: 0.6, minInterval: 0.15);
    _removeActiveCompanionVisual();

    // 동료 등장 이펙트 (실제 스프라이트 애니메이션)
    final companionPos = player.position.clone()..add(Vector2(0, -50));
    final spriteSheet = images.fromCache(companionData.assetPath);
    final companionWidth = spriteSheet.width / 4;
    final companionVisual = PositionComponent(
      position: companionPos,
      anchor: Anchor.center,
      priority: 15,
    );

    final companion = SpriteAnimationComponent(
      animation: SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.15,
          textureSize: Vector2(companionWidth, spriteSheet.height.toDouble()),
        ),
      ),
      size: Vector2(64, 64),
      position: Vector2.zero(),
      anchor: Anchor.center,
    );

    // 동료 MBTI 텍스트
    final companionLabel = TextComponent(
      text: companionData.mbti,
      position: Vector2(0, -30),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: companionData.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
    );

    companionVisual.add(companion);
    companionVisual.add(companionLabel);
    _activeCompanionVisual = companionVisual;
    _activeCompanionLifetime = 2.0;
    addTimedWorldComponent(
      companionVisual,
      lifetime: 2.0,
      countsAsTransient: false,
    );

    // 동료 필살기 실행 (배율 적용)
    _performCompanionUltimate(companionData, companionPos, multiplier);

    // S등급 보너스: 체력 20% 회복
    if (MbtiCompatibility.hasHealBonus(grade)) {
      player.heal(player.maxHp * 0.2);
    }

    // 2초 후 동료 퇴장
  }

  void _performCompanionUltimate(
    CharacterData data,
    Vector2 pos,
    double multiplier,
  ) {
    final baseDmg = data.attack * multiplier * 3; // 기본 공격력 * 배율 * 3

    final activeEnemies = List<BaseEnemy>.from(this.activeEnemies);
    switch (data.attackType) {
      case AttackType.wave:
        _dealDamageInRadius(pos, 120, baseDmg);
        _addExplosionEffect(pos, 120, data.color);
        break;
      case AttackType.homing:
        for (int i = 0; i < 6; i++) {
          final angle = i * pi / 3;
          spawnProjectile(
            Projectile(
              position: pos.clone(),
              direction: Vector2(cos(angle), sin(angle)),
              speed: 280,
              damage: baseDmg * 0.6,
              color: data.color,
              radius: 7,
              emoji: data.projectileEmoji,
              isSplash: true,
            ),
          );
        }
        break;
      case AttackType.summon:
        // 회복 동료: 체력 회복
        player.heal(player.maxHp * 0.3 * multiplier);
        break;
      case AttackType.straight:
        // 누커 동료: 대형 관통탄
        spawnProjectile(
          Projectile(
            position: pos.clone(),
            direction: Vector2(1, 0),
            speed: 450,
            damage: baseDmg * 2,
            color: data.color,
            radius: 12,
            emoji: data.projectileEmoji,
            isSplash: true,
            splashRadius: 50,
          ),
        );
        break;
      case AttackType.aura:
        // 서포터 동료: 버프 (공격력 임시 증가)
        final originalAtk = player.attackPower;
        player.attackPower += data.attack * multiplier;
        add(
          TimerComponent(
            period: 5.0,
            removeOnFinish: true,
            onTick: () => player.attackPower = originalAtk,
          ),
        );
        break;
      case AttackType.blink:
        if (activeEnemies.isNotEmpty) {
          _dealDamageInRadius(pos, 150, baseDmg * 1.2);
          _addExplosionEffect(pos, 150, data.color);
          _addRadialEmojiEffect(
            center: pos,
            emojis: characterEffectBurst(data, 4),
            radius: 84,
            fontSize: 22,
            color: data.color,
            lifetime: 0.45,
          );
        }
        break;
      case AttackType.rapid:
        // 파이터 동료: 12방향 연사
        for (int i = 0; i < 12; i++) {
          final angle = i * pi / 6;
          spawnProjectile(
            Projectile(
              position: pos.clone(),
              direction: Vector2(cos(angle), sin(angle)),
              speed: 250,
              damage: baseDmg * 0.5,
              color: data.color,
              radius: 4,
              emoji: data.projectileEmoji,
            ),
          );
        }
        break;
      case AttackType.shield:
        // 수호자 동료: 보호막 + 반격
        player.isInvincible = true;
        add(
          TimerComponent(
            period: 3.0,
            removeOnFinish: true,
            onTick: () => player.isInvincible = false,
          ),
        );
        _dealDamageInRadius(pos, 80, baseDmg * 0.8);
        _addExplosionEffect(pos, 80, data.color);
        break;
    }
  }

  void _addExplosionEffect(Vector2 pos, double radius, Color color) {
    if (!canSpawnTransientEffect()) {
      return;
    }
    final effect = CircleComponent(
      radius: radius,
      position: pos.clone(),
      anchor: Anchor.center,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color.withValues(alpha: 0.45),
    );
    addTimedWorldComponent(effect, lifetime: 0.5);
    _addRadialEmojiEffect(
      center: pos,
      emojis: const ['💥', '✨', '💥', '✨'],
      radius: radius * 0.65,
      fontSize: max(22, radius * 0.35),
      color: color,
      lifetime: 0.45,
    );
  }

  void _addRadialEmojiEffect({
    required Vector2 center,
    required List<String> emojis,
    required double radius,
    required double fontSize,
    required Color color,
    double lifetime = 0.6,
  }) {
    if (emojis.isEmpty) {
      return;
    }
    final cappedCount =
        activeEnemies.length >= 12 ||
            activeProjectiles.length >= 12 ||
            world.children.length >= 60
        ? min(2, emojis.length)
        : emojis.length;
    for (var i = 0; i < cappedCount; i++) {
      final angle = (pi * 2 / cappedCount) * i;
      final offset = Vector2(cos(angle), sin(angle)) * radius;
      final glyph = TextComponent(
        text: emojis[i],
        position: center + offset,
        anchor: Anchor.center,
        priority: 110,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
      );
      addTimedWorldComponent(glyph, lifetime: lifetime);
    }
  }

  void _addPulseRingEffect({
    required Vector2 center,
    required double radius,
    required Color color,
    double lifetime = 0.6,
    double alpha = 0.35,
    double strokeWidth = 5,
  }) {
    if (!canSpawnTransientEffect()) {
      return;
    }
    final ring = CircleComponent(
      radius: radius,
      position: center.clone(),
      anchor: Anchor.center,
      priority: 105,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: alpha),
    );
    addTimedWorldComponent(ring, lifetime: lifetime);
  }

  // ══════════════════════════════════════════
  // ═══ 게임 이벤트 ═══
  // ══════════════════════════════════════════
  void onEnemyKilled(BaseEnemy enemy) {
    unregisterEnemy(enemy);
    enemySpawner.onEnemyKilled();
  }

  /// 웨이브 클리어 시 자동 저장
  Future<void> autoSave() async {
    await saveManager?.saveGame(
      character: gameState.selectedCharacter,
      companion: gameState.selectedCompanion,
      wave: gameState.currentWave,
      playerSnapshot: PlayerSnapshot(
        hp: player.currentHp,
        maxHp: player.maxHp,
        attackPower: player.attackPower,
        speed: player.speed,
        multiShotCount: player.multiShotCount,
        attackInterval: player.attackInterval,
        ultCooldownCurrent: gameState.ultCooldownCurrent,
        assistCooldownCurrent: gameState.assistCooldownCurrent,
        ultTicketCount: gameState.ultTicketCount,
        assistTicketCount: gameState.assistTicketCount,
      ),
      kills: 0,
      hpLevel: gameState.hpLevel,
      atkLevel: gameState.attackLevel,
      spdLevel: gameState.speedLevel,
    );
  }

  void onAllWavesCleared() {
    _awaitingResumeConfirmation = false;
    _countdownResumeAuthorized = false;
    _resumePromptToken++;
    BgmManager.revokeGameplayRestore();
    unawaited(setBgmTrack(BgmTrack.lobby, forceRestart: true));
    playThrottledSfx('sfx_wave_clear.ogg', volume: 0.9, minInterval: 0.2);
    gameState.victory();
    saveManager?.deleteSave(); // 클리어 시 세이브 삭제
    overlays.add('Victory');
    pauseEngine();
  }

  void onPlayerDeath() {
    _removeActiveCompanionVisual();
    _awaitingResumeConfirmation = false;
    _countdownResumeAuthorized = false;
    _resumePromptToken++;
    BgmManager.revokeGameplayRestore();
    gameState.syncHp(current: 0, max: player.maxHp);
    setBgmTrack(BgmTrack.gameOver, forceRestart: true);
    playThrottledSfx('sfx_player_die.ogg', volume: 1.0, minInterval: 0.8);
    gameState.gameOver();
    saveManager?.deleteSave(); // 사망 시 세이브 삭제
    overlays.add('GameOver');
    pauseEngine();
    debugLogState('player_death');
  }

  Future<void> restartGame() async {
    _awaitingResumeConfirmation = false;
    _countdownResumeAuthorized = false;
    _resumePromptToken++;
    BgmManager.revokeGameplayRestore();
    overlays.remove('ResumePrompt');
    overlays.remove('Countdown');
    overlays.remove('GameOver');
    overlays.remove('Victory');
    _clearDynamicWorld();
    gameState.reset();
    unawaited(setBgmTrack(BgmTrack.battle, forceRestart: true));

    final characterData = MbtiCharacters.getByType(gameState.selectedCharacter);
    player = Player(characterData: characterData);
    player.position = mapSize / 2;
    world.add(player);
    camera.follow(player, snap: true);
    _applyResponsiveCameraZoom(size);

    gameState.initHp(characterData.maxHp);
    gameState.initUltCooldown(characterData.ultCooldown);
    gameState.initAssistCooldown();

    enemySpawner = EnemySpawner();
    add(enemySpawner);
    enemySpawner.startWave(0);

    debugLogState('restart_game');
    resumeGameplayIfAllowed(reason: 'restart_game');
  }

  /// 현재 웨이브에서 동일 캐릭터/강화레벨로 재시작
  /// ⚠️ onLoad()를 호출하면 안 됨! (gameState.reset()으로 모든 강화가 날아감)
  void restartFromCurrentWave() async {
    _awaitingResumeConfirmation = false;
    _countdownResumeAuthorized = false;
    _resumePromptToken++;
    BgmManager.revokeGameplayRestore();
    overlays.remove('ResumePrompt');
    overlays.remove('Countdown');
    final currentWave = gameState.currentWave - 1; // 0-indexed

    // 현재(사망 시점) 스탯 백업 (인게임 아이템 획득 및 커피 강화분 유지)
    final backedAttack = player.attackPower;
    final backedSpeed = player.speed;
    final backedMultiShot = player.multiShotCount;
    final backedMaxHp = player.maxHp;
    final backedAttackInterval = player.attackInterval;
    final backedUltCooldownCurrent = gameState.ultCooldownCurrent;
    final backedAssistCooldownCurrent = gameState.assistCooldownCurrent;
    final backedUltTicketCount = gameState.ultTicketCount;
    final backedAssistTicketCount = gameState.assistTicketCount;

    debugLog('[REVIVE] === BACKUP ===');
    debugLog(
      '[REVIVE] attack=$backedAttack, speed=$backedSpeed, multiShot=$backedMultiShot',
    );
    debugLog(
      '[REVIVE] maxHp=$backedMaxHp, attackInterval=$backedAttackInterval',
    );
    debugLog(
      '[REVIVE] ultCd=$backedUltCooldownCurrent, assistCd=$backedAssistCooldownCurrent',
    );
    debugLog(
      '[REVIVE] coffeeBeans=${gameState.coffeeBeans}, hpLv=${gameState.hpLevel}, atkLv=${gameState.attackLevel}',
    );

    overlays.remove('GameOver');
    overlays.remove('Victory');
    _clearDynamicWorld();
    unawaited(setBgmTrack(BgmTrack.battle, forceRestart: true));
    debugLogState('restart_from_current_wave');

    // ── 맵 재구성 (onLoad의 맵 부분만 수동 실행) ──
    await _ensureStaticWorld();

    // ── 플레이어 재생성 (백업 스탯 주입) ──
    final characterData = MbtiCharacters.getByType(gameState.selectedCharacter);
    player = Player(
      characterData: characterData,
      restoredMaxHp: backedMaxHp,
      restoredHp: backedMaxHp, // 풀피 리스폰
      restoredSpeed: backedSpeed,
      restoredAttack: backedAttack,
      restoredMultiShot: backedMultiShot,
      restoredAttackInterval: backedAttackInterval,
    );
    player.position = mapSize / 2;
    world.add(player);
    camera.follow(player, snap: true);
    _applyResponsiveCameraZoom(size);

    debugLog('[REVIVE] === PLAYER CREATED with restored params ===');

    // ── GameState 복원 (reset 호출하지 않음!) ──
    gameState.resetForRetry();
    gameState.initHp(backedMaxHp);
    gameState.initUltCooldown(characterData.ultCooldown);
    gameState.initAssistCooldown();
    gameState.syncUltCooldown(backedUltCooldownCurrent);
    gameState.syncAssistCooldown(backedAssistCooldownCurrent);
    gameState.syncUltTickets(backedUltTicketCount);
    gameState.syncAssistTickets(backedAssistTicketCount);

    debugLog(
      '[REVIVE] gameState maxHp=${gameState.maxHp}, currentHp=${gameState.currentHp}',
    );

    // ── 적 스포너 재시작 ──
    enemySpawner = EnemySpawner();
    add(enemySpawner);
    enemySpawner.startWave(currentWave);

    startCountdownResume(reason: 'restart_from_current_wave');

    debugLog('[REVIVE] === COMPLETE === wave=$currentWave');
  }

  void startWithCharacter(CharacterType type) {
    gameState.selectCharacter(type);
    restartGame();
  }

  Future<void> returnToLobby() async {
    _awaitingResumeConfirmation = false;
    _countdownResumeAuthorized = false;
    _resumePromptToken++;
    BgmManager.revokeGameplayRestore();
    overlays.remove('ResumePrompt');
    overlays.remove('Countdown');
    await autoSave(); // 로비로 돌아가기 전에 현재 상태 저장
    pauseEngine();
    onReturnToLobby?.call();
  }
}
