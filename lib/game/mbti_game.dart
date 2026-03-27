import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'components/enemies/base_enemy.dart';
import 'components/player.dart';
import 'components/projectiles/base_projectile.dart';
import 'config/character_data.dart';
import 'config/mbti_compatibility.dart';
import 'managers/enemy_spawner.dart';
import 'managers/game_state.dart';
import '../services/save_manager.dart';

/// MBTI 히어로: 직장인 생존기 - 메인 게임 클래스
class MbtiGame extends FlameGame with HasCollisionDetection {
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

  // [성능] 동시 스킬 텍스트 제한
  int _activeSkillTextCount = 0;
  static const int _maxSkillTextCount = 5;

  // [성능] 사격 사운드 쿨타임 (초당 12회 이하로 제한)
  double _shootSoundCooldown = 0;
  static const double _shootSoundMinInterval = 0.08;

  MbtiGame({this.saveManager, this.loadedSave});

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 프리로드: BGM과 SFX 로드 (미리 로딩하여 딜레이 방지)
    await FlameAudio.audioCache.loadAll([
      'sfx_shoot.ogg', 'sfx_player_hit.ogg', 'sfx_player_die.ogg',
      'sfx_ultimate.ogg', 'sfx_assist.ogg', 'sfx_enemy_spawn.ogg',
      'sfx_enemy_hit.ogg', 'sfx_enemy_die.ogg', 'sfx_boss_warning.ogg',
      'sfx_boss_attack.ogg', 'sfx_coin.ogg', 'sfx_powerup.ogg',
      'sfx_heal.ogg', 'sfx_wave_clear.ogg', 'sfx_button.ogg',
      'bgm_battle.mp3', 'bgm_boss.mp3', 'bgm_gameover.mp3', 'bgm_lobby.mp3'
    ]);

    // BGM 시작 (메인 배틀 음악)
    if (!FlameAudio.bgm.isPlaying) {
      FlameAudio.bgm.play('bgm_battle.mp3', volume: 0.25);
    }

    // 프리로드: 모든 캐릭터의 스프라이트를 미리 캐싱합니다 (어시스트 시 지연 방지)
    for (final char in MbtiCharacters.all) {
      await images.load(char.assetPath);
    }

    // 초기 상태 로드
    if (saveManager != null) {
      final globalData = saveManager!.loadGlobalData();
      gameState.loadGlobalData(
        globalData.coffeeBeans,
        globalData.hpLevel,
        globalData.attackLevel,
        globalData.speedLevel,
        globalData.unlockedCharacters,
      );
    }
    // 맵 배경 (어두운 사무실 색상)
    final background = RectangleComponent(
      size: mapSize,
      paint: Paint()..color = const Color(0xFF1A1A2E),
      priority: -10,
    );
    world.add(background);

    // 바닥 그리드 패턴 (AI 리소스 타일링)
    await _addGridPattern();

    // 장애물 배치
    await _addObstacles();

    // 플레이어 생성
    final characterData = MbtiCharacters.getByType(gameState.selectedCharacter);
    player = Player(characterData: characterData);
    player.position = mapSize / 2; // 맵 중앙에서 시작
    world.add(player);

    // 카메라가 플레이어 추적 (시작 시 스냅핑하여 줌인/팬 효과 방지)
    camera.follow(player, snap: true);

    // 게임 상태 초기화
    gameState.reset();
    gameState.initHp(characterData.maxHp);
    gameState.initUltCooldown(characterData.ultCooldown);
    gameState.initAssistCooldown();

    // 적 스포너 생성 및 시작
    enemySpawner = EnemySpawner();
    add(enemySpawner);
    activeEnemies.clear(); // 캐시 초기화

    // 세이브 데이터 복원
    if (loadedSave != null) {
      gameState.setWave(loadedSave!.wave);
      gameState.initHp(loadedSave!.maxHp);
      gameState.heal(loadedSave!.hp - loadedSave!.maxHp); // 현재 HP 설정
      gameState.takeDamage(loadedSave!.maxHp - loadedSave!.hp); // 실제 HP로
      player.attackPower = loadedSave!.attackPower;
      player.speed = loadedSave!.speed;
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
    pauseEngine();
    overlays.add('Countdown');
  }

  /// 바닥 타일 추가
  Future<void> _addGridPattern() async {
    try {
      final bgSprite = await images.load('maps/bg_tile.png');
      const tileSize = 512.0;

      for (double x = 0; x < mapSize.x; x += tileSize) {
        for (double y = 0; y < mapSize.y; y += tileSize) {
          world.add(
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
      debugPrint('Error loading map tile: $e');
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
        world.add(obstacle);
      }
    } catch (e) {
      debugPrint('Error loading obstacle: $e');
    }
  }

  /// 조이스틱 방향 업데이트 (Flutter 오버레이에서 호출)
  void updateJoystick(Vector2 direction) {
    _joystickDirection = direction;
  }

  // ══════════════════════════════════════════
  // ═══ 자동 공격 (8종) ═══
  // ══════════════════════════════════════════
  /// 플레이어 자동 공격 공통 헬퍼 (다중 발사 지원)
  void _fireMultiProjectiles({
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
    if (enemies.isEmpty) return;
    final closest = _findClosestEnemy(p.position, enemies);
    if (closest == null) return;

    final baseDir = (closest.position - p.position).normalized();
    final count = p.multiShotCount;
    final spreadAngle = 0.15; // 투사체 간 각도 차이

    final startAngle = -spreadAngle * (count - 1) / 2;

    for (int i = 0; i < count; i++) {
      final angle = startAngle + (i * spreadAngle);
      final dir = baseDir.clone()..rotate(angle);

      world.add(
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
  }

  void performAutoAttack(Player attackingPlayer) {
    final enemies = activeEnemies;  // [성능] O(1) 캐시 접근

    switch (attackingPlayer.characterData.attackType) {
      case AttackType.wave:
        _attackWave(attackingPlayer, enemies);
        break;
      case AttackType.homing:
        _attackHoming(attackingPlayer, enemies);
        break;
      case AttackType.summon:
        _attackSummon(attackingPlayer, enemies);
        break;
      case AttackType.straight:
        _attackStraight(attackingPlayer, enemies);
        break;
      case AttackType.aura:
        _attackAura(attackingPlayer, enemies);
        break;
      case AttackType.blink:
        _attackBlink(attackingPlayer, enemies);
        break;
      case AttackType.rapid:
        _attackRapid(attackingPlayer, enemies);
        break;
      case AttackType.shield:
        _attackShield(attackingPlayer, enemies);
        break;
    }
  }

  /// ESTJ: 로 돌진하는 방패 (파란색 잔상) 🛡️
  void _attackWave(Player p, List<BaseEnemy> enemies) {
    _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 300,
      damageRatio: 1.0,
      radius: 12,
      emoji: '🛡️',
      isSplash: true,
      splashRadius: 30,
      lifetime: 0.4, // 근거리 파동망
    );
  }

  /// ENTP: 팩트 폭격 - 전구 발사 💡
  void _attackHoming(Player p, List<BaseEnemy> enemies) {
    _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 250,
      damageRatio: 1.0,
      radius: 10,
      emoji: '💡',
      isSplash: true,
      splashRadius: 30,
    );
  }

  /// INFP: 내면의 친구 - 정령 소환 (꽃잎 치유 광선 🌸)
  void _attackSummon(Player p, List<BaseEnemy> enemies) {
    _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 180,
      damageRatio: 1.0,
      radius: 10,
      emoji: '🌸',
      lifetime: 2.0, // 원거리 투사체
    );
  }

  /// ISTP: 나사 던지기 - 전방 직선 스패너 투척 🔧
  void _attackStraight(Player p, List<BaseEnemy> enemies) {
    _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 350,
      damageRatio: 1.0,
      radius: 10,
      emoji: '🔧',
      lifetime: 2.5, // 긴 사거리
    );
  }

  /// ENFJ: 리더십 오라 - 깃발 휘두르기 🚩
  void _attackAura(Player p, List<BaseEnemy> enemies) {
    _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 200,
      damageRatio: 1.0,
      radius: 12,
      emoji: '🚩',
      lifetime: 1.0, // 중거리 오라
    );
  }

  /// INTJ: 순간이동 슬래시 - 가장 가까운 적 위치로 순간이동 후 범위 공격
  void _attackBlink(Player attackingPlayer, List<BaseEnemy> enemies) {
    if (enemies.isEmpty) return; // 적 없으면 패스
    final closest = _findClosestEnemy(attackingPlayer.position, enemies);
    if (closest == null) return;

    final dist = attackingPlayer.position.distanceTo(closest.position);
    if (dist > 200) {
      // 멀리 있으면 청사진 투척 📜
      _fireMultiProjectiles(
        p: attackingPlayer,
        enemies: enemies,
        speed: 320,
        damageRatio: 1.0,
        radius: 10,
        emoji: '📜',
      );
    } else {
      // 가까이 있으면 범위 공격 (처형 보너스)
      final hpRatio = closest.currentHp / closest.maxHp;
      final executeDmg = attackingPlayer.attackPower * (0.5 + (1 - hpRatio));
      _dealDamageInRadius(attackingPlayer.position, 50, executeDmg);

      // 멀티샷 비례 추가 딜 및 범위 증가 효과
      if (attackingPlayer.multiShotCount > 1) {
        _dealDamageInRadius(
          attackingPlayer.position,
          50 + (10.0 * attackingPlayer.multiShotCount),
          attackingPlayer.attackPower * 0.2 * attackingPlayer.multiShotCount,
        );
      }

      // 단검 슬래시 이펙트 🗡️
      final slash = TextComponent(
        text: '🗡️',
        position: closest.position.clone()..add(Vector2(-10, -20)),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: 40)),
      );
      slash.add(
        TimerComponent(
          period: 0.2,
          removeOnFinish: true,
          onTick: () => slash.removeFromParent(),
        ),
      );
      world.add(slash);
    }
  }

  /// ESFP: 빠른 연타 - 마이크 음파 🎤
  void _attackRapid(Player p, List<BaseEnemy> enemies) {
    // 멀티샷 갯수에 약간의 패널티(원래 2발 발사하므로 계수 보정)
    _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 280,
      damageRatio: 0.7,
      radius: 10,
      emoji: '🎤',
    );
  }

  /// ISFJ: 냄비 뚜껑 방어 투사체 🍲
  void _attackShield(Player p, List<BaseEnemy> enemies) {
    _fireMultiProjectiles(
      p: p,
      enemies: enemies,
      speed: 200,
      damageRatio: 1.0,
      radius: 12,
      emoji: '🍲',
    );

    // 20% + 멀티샷 비례 확률로 약간 회복
    final healChance = 0.2 + (p.multiShotCount * 0.05);
    if (Random().nextDouble() < healChance) {
      p.heal(p.maxHp * 0.02);
    }
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

  void _dealDamageInRadius(Vector2 center, double radius, double damage) {
    for (final enemy in activeEnemies) {  // [성능] 캐시 사용
      if (center.distanceTo(enemy.position) <= radius + enemy.radius) {
        enemy.takeDamage(damage);
      }
    }
  }

  void showSkillText(String text, Color color, Vector2 pos) {
    // [성능] 동시 스킬 텍스트 최대 5개로 제한
    if (_activeSkillTextCount >= _maxSkillTextCount) return;
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
          textComp.removeFromParent();
        },
      ),
    );

    world.add(textComp);
  }

  // ══════════════════════════════════════════
  // ═══ 필살기 (8종) ═══
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
    FlameAudio.play('sfx_ultimate.ogg');
  }

  /// ESTJ 필살기: "철벽 방어" - 전신 보호막 🛡️ + 범위 데미지
  void _ultWave(Player p) {
    _dealDamageInRadius(p.position, 225, p.attackPower * 4.5);
    final bigWave = CircleComponent(
      radius: 225,
      position: p.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = p.characterData.color.withValues(alpha: 0.4),
    );
    bigWave.add(
      TimerComponent(
        period: 0.75,
        removeOnFinish: true,
        onTick: () => bigWave.removeFromParent(),
      ),
    );
    world.add(bigWave);
    // 4.5초 무적 + 전신 보호막 🛡️ 이펙트
    p.isInvincible = true;
    final shieldVisual = TextComponent(
      text: '🛡️',
      position: Vector2(p.size.x / 2, -20),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: TextStyle(fontSize: 30)),
    );
    p.add(shieldVisual);

    add(
      TimerComponent(
        period: 4.5,
        removeOnFinish: true,
        onTick: () {
          p.isInvincible = false;
          shieldVisual.removeFromParent();
        },
      ),
    );
  }

  /// ENTP 필살기: "브레인스토밍 폭발" - 광역 폭발 💥
  void _ultHoming(Player p) {
    for (int i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      final dir = Vector2(cos(angle), sin(angle));
      final offset = dir * 30.0;
      world.add(
        Projectile(
          position: p.position.clone()..add(offset),
          direction: dir,
          speed: 300,
          damage: p.attackPower * 3,
          color: p.characterData.color,
          radius: 22.5,
          emoji: '💥',
          isSplash: true,
        ),
      );
    }
  }

  /// INFP 필살기: "힐링 서클" - 장판형 회복 🌿
  void _ultSummon(Player p) {
    p.heal(p.maxHp * 0.6);
    p.isInvincible = true;

    final circle = CircleComponent(
      radius: 120,
      position: p.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.3),
    );
    circle.add(
      TextComponent(
        text: '🌿',
        position: Vector2(120, 120),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: 40)),
      ),
    );
    world.add(circle);

    add(
      TimerComponent(
        period: 4.5,
        removeOnFinish: true,
        onTick: () {
          p.isInvincible = false;
          circle.removeFromParent();
        },
      ),
    );
  }

  /// ISTP 필살기: "기계 장치 폭발" - 부품 파편 ⚙️
  void _ultStraight(Player p) {
    var dir = _joystickDirection.clone();
    if (dir == Vector2.zero()) dir = Vector2(1, 0);
    dir.normalize();
    world.add(
      Projectile(
        position: p.position.clone(),
        direction: dir,
        speed: 500,
        damage: p.attackPower * 7.5,
        color: p.characterData.color,
        radius: 30,
        emoji: '⚙️',
        isSplash: true,
        splashRadius: 90,
      ),
    );
  }

  /// ENFJ 필살기: "사기 진작 오라" - 황금빛 왕관 ✨
  void _ultAura(Player p) {
    final originalAtk = p.attackPower;
    p.attackPower *= 3; // 2 -> 3 (1.5x effectiveness)

    _dealDamageInRadius(p.position, 180, p.attackPower * 1.5);

    final auraEffect = CircleComponent(
      radius: 180,
      position: p.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.25),
    );
    auraEffect.add(
      TextComponent(
        text: '✨',
        position: Vector2(180, 60),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: 50)),
      ),
    );
    auraEffect.add(
      TimerComponent(
        period: 7.5,
        removeOnFinish: true,
        onTick: () {
          auraEffect.removeFromParent();
          p.attackPower = originalAtk;
        },
      ),
    );
    world.add(auraEffect);
  }

  /// INTJ 필살기: "단검 기습" - 날카로운 일격 🗡️ (맵 전체)
  void _ultBlink(Player p) {
    final allEnemies = world.children.whereType<BaseEnemy>().toList();
    for (final enemy in allEnemies) {
      enemy.takeDamage(p.attackPower * 3);
    }
    // 전체 맵 플래시 이펙트
    final flash = RectangleComponent(
      position: Vector2.zero(),
      size: mapSize,
      paint: Paint()..color = const Color(0xFF00BCD4).withValues(alpha: 0.3),
      priority: 100,
    );
    flash.add(
      TextComponent(
        text: '🗡️',
        position: mapSize / 2,
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: 100)),
      ),
    );
    flash.add(
      TimerComponent(
        period: 0.75,
        removeOnFinish: true,
        onTick: () => flash.removeFromParent(),
      ),
    );
    world.add(flash);
  }

  /// ESFP 필살기: "스포트라이트 집중 조명" - 🔦 연사
  void _ultRapid(Player p) {
    // 즉시 24방향 발사
    for (int i = 0; i < 24; i++) {
      final angle = i * pi / 12;
      world.add(
        Projectile(
          position: p.position.clone(),
          direction: Vector2(cos(angle), sin(angle)),
          speed: 250,
          damage: p.attackPower * 2.25,
          color: p.characterData.color,
          radius: 18,
          emoji: '🔦',
        ),
      );
    }
    // 4.5초간 공격속도 대폭 증가
    p.reduceAttackInterval(0.45);
    add(
      TimerComponent(
        period: 4.5,
        removeOnFinish: true,
        onTick: () => p.reduceAttackInterval(-0.45),
      ),
    );
  }

  /// ISFJ 필살기: "안전 제일 보호막" - 반투명 장벽 🟢
  void _ultShield(Player p) {
    p.isInvincible = true;
    p.heal(p.maxHp * 0.45);

    final shieldEffect = CircleComponent(
      radius: 60,
      position: p.position.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.35),
    );
    shieldEffect.add(
      TextComponent(
        text: '🟢',
        position: Vector2(60, -15),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: 24)),
      ),
    );

    shieldEffect.add(
      TimerComponent(
        period: 7.5,
        removeOnFinish: true,
        onTick: () {
          shieldEffect.removeFromParent();
          p.isInvincible = false;
        },
      ),
    );
    world.add(shieldEffect);
  }

  // ══════════════════════════════════════════
  // ═══ 동료 호출 (ASSIST) ═══
  // ══════════════════════════════════════════
  void performAssist() {
    if (!gameState.isAssistReady) return;
    gameState.useAssist();

    final companionData = gameState.companionData;
    final multiplier = gameState.companionPowerMultiplier;
    final grade = gameState.companionGrade;

    showSkillText(
      companionData.assistText,
      companionData.color,
      player.position,
    );
    FlameAudio.play('sfx_assist.ogg', volume: 0.6);

    // 동료 등장 이펙트 (실제 스프라이트 애니메이션)
    final companionPos = player.position.clone()..add(Vector2(0, -50));
    final spriteSheet = images.fromCache(companionData.assetPath);
    final companionWidth = spriteSheet.width / 4;

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
      position: companionPos,
      anchor: Anchor.center,
      priority: 15,
    );

    // 동료 MBTI 텍스트
    final companionLabel = TextComponent(
      text: companionData.mbti,
      position: companionPos.clone()..add(Vector2(0, -30)),
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

    world.add(companion);
    world.add(companionLabel);

    // 동료 필살기 실행 (배율 적용)
    _performCompanionUltimate(companionData, companionPos, multiplier);

    // S등급 보너스: 체력 20% 회복
    if (MbtiCompatibility.hasHealBonus(grade)) {
      player.heal(player.maxHp * 0.2);
    }

    // 2초 후 동료 퇴장
    add(
      TimerComponent(
        period: 2.0,
        removeOnFinish: true,
        onTick: () {
          companion.removeFromParent();
          companionLabel.removeFromParent();
        },
      ),
    );
  }

  void _performCompanionUltimate(
    CharacterData data,
    Vector2 pos,
    double multiplier,
  ) {
    final baseDmg = data.attack * multiplier * 3; // 기본 공격력 * 배율 * 3

    switch (data.attackType) {
      case AttackType.wave:
        _dealDamageInRadius(pos, 120, baseDmg);
        _addExplosionEffect(pos, 120, data.color);
        break;
      case AttackType.homing:
        for (int i = 0; i < 6; i++) {
          final angle = i * pi / 3;
          world.add(
            Projectile(
              position: pos.clone(),
              direction: Vector2(cos(angle), sin(angle)),
              speed: 280,
              damage: baseDmg * 0.6,
              color: data.color,
              radius: 7,
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
        world.add(
          Projectile(
            position: pos.clone(),
            direction: Vector2(1, 0),
            speed: 450,
            damage: baseDmg * 2,
            color: data.color,
            radius: 12,
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
        // 암살자 동료: 전체 적 데미지
        for (final enemy in activeEnemies) {  // [성능] 캐시 사용
          enemy.takeDamage(baseDmg);
        }
        break;
      case AttackType.rapid:
        // 파이터 동료: 12방향 연사
        for (int i = 0; i < 12; i++) {
          final angle = i * pi / 6;
          world.add(
            Projectile(
              position: pos.clone(),
              direction: Vector2(cos(angle), sin(angle)),
              speed: 250,
              damage: baseDmg * 0.5,
              color: data.color,
              radius: 4,
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
    final effect = CircleComponent(
      radius: radius,
      position: pos.clone(),
      anchor: Anchor.center,
      paint: Paint()..color = color.withValues(alpha: 0.3),
    );
    effect.add(
      TimerComponent(
        period: 0.5,
        removeOnFinish: true,
        onTick: () => effect.removeFromParent(),
      ),
    );
    world.add(effect);
  }

  // ══════════════════════════════════════════
  // ═══ 게임 이벤트 ═══
  // ══════════════════════════════════════════
  /// 적이 스폰될 때 호출 (EnemySpawner/BaseEnemy에서 호출)
  void registerEnemy(BaseEnemy enemy) {
    activeEnemies.add(enemy);
  }

  /// 적이 죽거나 제거될 때 호출 (BaseEnemy에서 호출)
  void unregisterEnemy(BaseEnemy enemy) {
    activeEnemies.remove(enemy);
  }

  void onEnemyKilled(BaseEnemy enemy) {
    unregisterEnemy(enemy);
    enemySpawner.onEnemyKilled();
  }

  /// 웨이브 클리어 시 자동 저장
  void autoSave() {
    saveManager?.saveGame(
      character: gameState.selectedCharacter,
      companion: gameState.selectedCompanion,
      wave: gameState.currentWave,
      hp: gameState.currentHp,
      maxHp: gameState.maxHp,
      attackPower: player.attackPower,
      speed: player.speed,
      kills: 0,
      hpLevel: gameState.hpLevel,
      atkLevel: gameState.attackLevel,
      spdLevel: gameState.speedLevel,
    );
  }

  void onAllWavesCleared() {
    gameState.victory();
    saveManager?.deleteSave(); // 클리어 시 세이브 삭제
    overlays.add('Victory');
    pauseEngine();
  }

  void onPlayerDeath() {
    FlameAudio.bgm.stop();
    FlameAudio.bgm.play('bgm_gameover.mp3', volume: 0.4);
    FlameAudio.play('sfx_player_die.ogg');
    gameState.gameOver();
    saveManager?.deleteSave(); // 사망 시 세이브 삭제
    overlays.add('GameOver');
    pauseEngine();
  }

  void restartGame() {
    overlays.remove('GameOver');
    overlays.remove('Victory');
    world.removeAll(world.children);
    removeAll(children.whereType<EnemySpawner>());
    activeEnemies.clear(); // [성능] 캐시 정리
    _activeSkillTextCount = 0;
    gameState.reset();
    FlameAudio.bgm.stop();
    FlameAudio.bgm.play('bgm_battle.mp3', volume: 0.25);
    resumeEngine();
    onLoad();
  }

  /// 현재 웨이브에서 동일 캐릭터/강화레벨로 재시작
  /// ⚠️ onLoad()를 호출하면 안 됨! (gameState.reset()으로 모든 강화가 날아감)
  void restartFromCurrentWave() async {
    final currentWave = gameState.currentWave - 1; // 0-indexed

    // 현재(사망 시점) 스탯 백업 (인게임 아이템 획득 및 커피 강화분 유지)
    final backedAttack = player.attackPower;
    final backedSpeed = player.speed;
    final backedMultiShot = player.multiShotCount;
    final backedMaxHp = gameState.maxHp;
    final backedAttackInterval = player.attackInterval;

    debugPrint('[REVIVE] === BACKUP ===');
    debugPrint(
      '[REVIVE] attack=$backedAttack, speed=$backedSpeed, multiShot=$backedMultiShot',
    );
    debugPrint(
      '[REVIVE] maxHp=$backedMaxHp, attackInterval=$backedAttackInterval',
    );
    debugPrint(
      '[REVIVE] coffeeBeans=${gameState.coffeeBeans}, hpLv=${gameState.hpLevel}, atkLv=${gameState.attackLevel}',
    );

    overlays.remove('GameOver');
    overlays.remove('Victory');
    world.removeAll(world.children);
    removeAll(children.whereType<EnemySpawner>());
    activeEnemies.clear(); // [성능] 캐시 정리
    _activeSkillTextCount = 0;

    // ── 맵 재구성 (onLoad의 맵 부분만 수동 실행) ──
    final background = RectangleComponent(
      size: mapSize,
      paint: Paint()..color = const Color(0xFF1A1A2E),
      priority: -10,
    );
    world.add(background);
    await _addGridPattern();
    await _addObstacles();

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

    debugPrint('[REVIVE] === PLAYER CREATED with restored params ===');

    // ── GameState 복원 (reset 호출하지 않음!) ──
    gameState.resetForRetry();
    gameState.initHp(backedMaxHp);
    gameState.initUltCooldown(characterData.ultCooldown);
    gameState.initAssistCooldown();

    debugPrint(
      '[REVIVE] gameState maxHp=${gameState.maxHp}, currentHp=${gameState.currentHp}',
    );

    resumeEngine();

    // ── 적 스포너 재시작 ──
    enemySpawner = EnemySpawner();
    add(enemySpawner);
    enemySpawner.startWave(currentWave);

    debugPrint('[REVIVE] === COMPLETE === wave=$currentWave');
  }

  void startWithCharacter(CharacterType type) {
    gameState.selectCharacter(type);
    restartGame();
  }

  void returnToLobby() {
    autoSave(); // 로비로 돌아가기 전에 현재 상태 저장
    pauseEngine();
    onReturnToLobby?.call();
  }
}
