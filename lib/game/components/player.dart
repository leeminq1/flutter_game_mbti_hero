import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../config/character_data.dart';
import '../mbti_game.dart';
import 'package:flame_audio/flame_audio.dart';

/// 플레이어 컴포넌트
class Player extends SpriteAnimationComponent
    with HasGameReference<MbtiGame>, CollisionCallbacks {
  final CharacterData characterData;

  late double currentHp;
  late double maxHp;
  late double speed;
  late double attackPower;

  // 무적 상태 (ESTJ 필살기 등)
  bool isInvincible = false;

  // 공격 타이머
  double _attackTimer = 0;
  late double _attackInterval;

  // 데미지 무적 (피격 후 잠시 무적)
  double _damageInvincibleTimer = 0;
  static const double _damageInvincibleDuration = 0.5;

  // 랜덤 대사 타이머
  double _quoteTimer = 0;
  late double _nextQuoteTime;
  final Random _random = Random();

  // 멀티샷 개수 (최초 3개 발사)
  int multiShotCount = 3;

  // 복원용 임시 저장 변수
  final double? restoredHp;
  final double? restoredMaxHp;
  final double? restoredSpeed;
  final double? restoredAttack;
  final int? restoredMultiShot;
  final double? restoredAttackInterval;

  Player({
    required this.characterData,
    this.restoredHp,
    this.restoredMaxHp,
    this.restoredSpeed,
    this.restoredAttack,
    this.restoredMultiShot,
    this.restoredAttackInterval,
  }) : super(
         size: Vector2(64, 64), // 화면에 그려질 크기
         anchor: Anchor.center,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 10~15초 사이 랜덤한 시점에 첫 대사 설정
    _nextQuoteTime = 10.0 + _random.nextDouble() * 5.0;

    // 스프라이트 애니메이션 로드 (가로 4개 프레임 가정)
    try {
      final spriteSheet = await game.images.load(characterData.assetPath);
      final frameWidth = spriteSheet.width / 4;
      final frameHeight = spriteSheet.height.toDouble();

      animation = SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.15,
          textureSize: Vector2(frameWidth, frameHeight),
        ),
      );
    } catch (e) {
      debugPrint('Error loading sprite for ${characterData.name}: $e');
      // 폴백: 색상 사각형
      animation = null;
    }

    // 메타 프로그레션 (글로벌 업그레이드) 적용 - 레벨당 약 1.7% 증가
    final hpMultiplier = 1.0 + (game.gameState.hpLevel * 0.014);
    final atkMultiplier = 1.0 + (game.gameState.attackLevel * 0.014);
    final spdMultiplier = 1.0 + (game.gameState.speedLevel * 0.014);

    // 능력치 초기화
    // 능력치 초기화 (복원 데이터가 있으면 우선 사용)
    maxHp = restoredMaxHp ?? (characterData.maxHp * hpMultiplier);
    currentHp = restoredHp ?? maxHp;
    speed = restoredSpeed ?? (characterData.speed * spdMultiplier);
    attackPower = restoredAttack ?? (characterData.attack * atkMultiplier);
    _attackInterval = restoredAttackInterval ?? characterData.baseAttackSpeed;
    if (restoredMultiShot != null) {
      multiShotCount = restoredMultiShot!;
    }

    // 히트박스 추가 (캐릭터 크기보다 약간 작게)
    add(
      CircleHitbox(
        radius: 18,
        position: Vector2(32, 32),
        anchor: Anchor.center,
      ),
    );

    // GameState 초기화
    game.gameState.initHp(maxHp);
    game.gameState.initUltCooldown(characterData.ultCooldown);
  }

  // 히트박스 반경 상수화
  static const double playerHitboxRadius = 18.0;

  double get attackInterval => _attackInterval;

  @override
  void update(double dt) {
    super.update(dt);

    if (game.joystickDirection != Vector2.zero()) {
      final delta = game.joystickDirection;
      position.add(delta * speed * dt);

      // 스프라이트 반전 (좌/우 방향 전환)
      if (delta.x < 0 && !isFlippedHorizontally) {
        flipHorizontally();
      } else if (delta.x > 0 && isFlippedHorizontally) {
        flipHorizontally();
      }
      // 맵 경계 제한
      position.clamp(
        Vector2(playerHitboxRadius, playerHitboxRadius),
        Vector2(
          game.mapSize.x - playerHitboxRadius,
          game.mapSize.y - playerHitboxRadius,
        ),
      );
    }

    // 자동 공격 타이머
    _attackTimer += dt;
    if (_attackTimer >= _attackInterval) {
      _attackTimer = 0;
      _autoAttack();
    }

    // 데미지 무적 타이머
    if (_damageInvincibleTimer > 0) {
      _damageInvincibleTimer -= dt;
      // 깜빡임 효과
      paint.color = characterData.color.withValues(
        alpha: (sin(_damageInvincibleTimer * 20) * 0.5 + 0.5),
      );
    } else {
      paint.color = characterData.color;
    }

    // 랜덤 대사 타이머
    _quoteTimer += dt;
    if (_quoteTimer >= _nextQuoteTime) {
      _quoteTimer = 0;
      _nextQuoteTime = 10.0 + _random.nextDouble() * 5.0; // 다음 대사까지 10~15초 대기
      if (characterData.idleQuotes.isNotEmpty) {
        final quote = characterData
            .idleQuotes[_random.nextInt(characterData.idleQuotes.length)];
        game.showSkillText(
          quote,
          characterData.color,
          position.clone()..y += 20,
        ); // 캐릭터 약간 아래 출력
      }
    }

    // 필살기 쿨타임 틱
    game.gameState.tickUltCooldown(dt);
    // 동료 호출 쿨타임 틱
    game.gameState.tickAssistCooldown(dt);
  }

  /// 자동 공격 (캐릭터 타입별로 다름)
  void _autoAttack() {
    FlameAudio.play('sfx_shoot.ogg', volume: 0.3);
    game.performAutoAttack(this);
  }

  /// 필살기 사용
  void useUltimate() {
    if (game.gameState.isUltReady) {
      game.gameState.useUlt();
      game.performUltimate(this);
    }
  }

  /// 데미지 받기
  void takeDamage(double damage) {
    if (isInvincible || _damageInvincibleTimer > 0) return;

    currentHp = (currentHp - damage).clamp(0, maxHp);
    FlameAudio.play('sfx_player_hit.ogg');
    game.gameState.takeDamage(damage);
    _damageInvincibleTimer = _damageInvincibleDuration;

    if (currentHp <= 0) {
      game.onPlayerDeath();
    }
  }

  /// 회복
  void heal(double amount) {
    currentHp = (currentHp + amount).clamp(0, maxHp);
    FlameAudio.play('sfx_heal.ogg', volume: 0.6);
    game.gameState.heal(amount);
  }

  /// 공격 간격 감소 (연사속도 증가 / 감소)
  void reduceAttackInterval(double amount) {
    _attackInterval = (_attackInterval - amount).clamp(0.1, 3.0);
  }

  /// 멀티샷 증가 (+2, 최대 10발)
  void increaseMultiShot() {
    multiShotCount = min(10, multiShotCount + 1);
  }
}
