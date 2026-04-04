import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../config/character_data.dart';
import '../mbti_game.dart';
import '../../services/sfx_manager.dart';

/// 플레이어 컴포넌트
class Player extends SpriteAnimationComponent
    with HasGameReference<MbtiGame>, CollisionCallbacks {
  static const double hpUpgradePerLevel = 20.0;
  static const double attackUpgradePerLevel = 3.0;
  static const double speedUpgradePerLevel = 10.0;
  static const double maxAttackPickupBonus = 24.0;
  static const double maxSpeedPickupBonus = 48.0;
  static const int maxMultiShotLimit = 10;

  final CharacterData characterData;

  late double currentHp;
  late double maxHp;
  late double speed;
  late double attackPower;
  late double _baseMaxHp;
  late double _baseSpeed;
  late double _baseAttackPower;

  // 무적 상태 (ESTJ 필살기 등)
  bool isInvincible = false;

  // 공격 타이머
  double _attackTimer = 0;
  late double _attackInterval;
  Vector2 _attackFacingDirection = Vector2(1, 0);

  // 데미지 무적 (피격 후 잠시 무적)
  double _damageInvincibleTimer = 0;
  static const double _damageInvincibleDuration = 0.5;
  int _lastDamageFlashBucket = -1;
  static const int _damageFlashBuckets = 12;
  late final List<Color> _damageFlashColors;

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
    final hpBonus = game.gameState.hpLevel * hpUpgradePerLevel;
    final atkBonus = game.gameState.attackLevel * attackUpgradePerLevel;
    final spdBonus = game.gameState.speedLevel * speedUpgradePerLevel;

    // 능력치 초기화
    // 능력치 초기화 (복원 데이터가 있으면 우선 사용)
    _baseMaxHp = characterData.maxHp + hpBonus;
    _baseAttackPower = characterData.attack + atkBonus;
    _baseSpeed = characterData.speed + spdBonus;

    maxHp = restoredMaxHp ?? _baseMaxHp;
    currentHp = (restoredHp ?? maxHp).clamp(0, maxHp).toDouble();
    speed = (restoredSpeed ?? _baseSpeed).clamp(0, maxSpeedCap).toDouble();
    attackPower =
        (restoredAttack ?? _baseAttackPower)
            .clamp(0, maxAttackPowerCap)
            .toDouble();
    _attackInterval = restoredAttackInterval ?? characterData.baseAttackSpeed;
    if (restoredMultiShot != null) {
      multiShotCount =
          restoredMultiShot!.clamp(3, maxMultiShotLimit).toInt();
    }
    _damageFlashColors = List<Color>.generate(
      _damageFlashBuckets + 1,
      (index) => characterData.color.withAlpha(
        ((index / _damageFlashBuckets) * 255).round().clamp(0, 255).toInt(),
      ),
    );

    // 히트박스 추가 (캐릭터 크기보다 약간 작게)
    add(
      CircleHitbox(
        radius: 18,
        position: Vector2(32, 32),
        anchor: Anchor.center,
      ),
    );

    // GameState 초기화
    game.gameState.syncHp(current: currentHp, max: maxHp);
    game.gameState.initUltCooldown(characterData.ultCooldown);
  }

  // 히트박스 반경 상수화
  static const double playerHitboxRadius = 18.0;

  double get attackInterval => _attackInterval;
  Vector2 get attackFacingDirection => _attackFacingDirection.clone();
  double get maxAttackPowerCap => _baseAttackPower + maxAttackPickupBonus;
  double get maxSpeedCap => _baseSpeed + maxSpeedPickupBonus;
  double get baseMaxHp => _baseMaxHp;
  double get baseAttackPower => _baseAttackPower;
  double get baseSpeed => _baseSpeed;

  @override
  void update(double dt) {
    super.update(dt);

    if (game.joystickDirection != Vector2.zero()) {
      final delta = game.joystickDirection;
      position.add(delta * speed * dt);
      if (delta.length2 > 0) {
        _attackFacingDirection = delta.normalized();
      }

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
      final alpha =
          (sin(_damageInvincibleTimer * 20) * 0.5 + 0.5).clamp(0.0, 1.0);
      final bucket = (alpha * _damageFlashBuckets).round().clamp(
        0,
        _damageFlashBuckets,
      ).toInt();
      if (bucket != _lastDamageFlashBucket) {
        paint.color = _damageFlashColors[bucket];
        _lastDamageFlashBucket = bucket;
      }
    } else {
      if (_lastDamageFlashBucket != _damageFlashBuckets) {
        paint.color = characterData.color;
        _lastDamageFlashBucket = _damageFlashBuckets;
      }
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
    final didAttack = game.performAutoAttack(this);
    if (didAttack) {
      game.tryPlayShootSfx();
    }
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
    game.playThrottledSfx(
      'sfx_player_hit.ogg',
      minInterval: 0.08,
    );
    game.gameState.takeDamage(damage);
    _damageInvincibleTimer = _damageInvincibleDuration;

    if (currentHp <= 0) {
      game.onPlayerDeath();
    }
  }

  /// 회복
  void heal(double amount, {bool playEffectSound = true}) {
    currentHp = (currentHp + amount).clamp(0, maxHp);
    if (playEffectSound) {
      SfxManager.playUi(
        'sfx_heal.ogg',
        volume: 0.15,
        minInterval: 0.22,
      );
    }
    game.gameState.heal(amount);
  }

  /// 공격 간격 감소 (연사속도 증가 / 감소)
  void reduceAttackInterval(double amount) {
    _attackInterval = (_attackInterval - amount).clamp(0.1, 3.0);
  }

  void applyPermanentHpUpgrade(double amount) {
    _baseMaxHp += amount;
    maxHp += amount;
    currentHp = maxHp;
    game.gameState.syncHp(current: currentHp, max: maxHp);
  }

  void applyPermanentAttackUpgrade(double amount) {
    _baseAttackPower += amount;
    attackPower =
        (attackPower + amount).clamp(0, maxAttackPowerCap).toDouble();
  }

  void applyPermanentSpeedUpgrade(double amount) {
    _baseSpeed += amount;
    speed = (speed + amount).clamp(0, maxSpeedCap).toDouble();
  }

  void applyAttackBoost(double amount) {
    attackPower =
        (attackPower + amount).clamp(0, maxAttackPowerCap).toDouble();
  }

  void applySpeedBoost(double amount) {
    speed = (speed + amount).clamp(0, maxSpeedCap).toDouble();
  }

  /// 멀티샷 증가 (+2, 최대 10발)
  void increaseMultiShot() {
    multiShotCount = min(maxMultiShotLimit, multiShotCount + 1);
  }
}
