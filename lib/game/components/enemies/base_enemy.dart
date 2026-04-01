import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../config/wave_data.dart';
import '../../mbti_game.dart';
import '../player.dart';
import '../projectiles/base_projectile.dart';
import '../power_up.dart';
import 'enemy_definition.dart';

part 'base_enemy_behaviors.dart';

class BaseEnemy extends PositionComponent
    with HasGameReference<MbtiGame>, CollisionCallbacks {
  final EnemyType type;
  late final EnemyDefinition definition;
  late final EnemyBehavior _behavior;
  late double maxHp;
  late double currentHp;
  late double speed;
  late double damage;
  late double attackCooldown;
  double _attackTimer = 0;

  // 피격 이펙트
  double _hitFlashTimer = 0;
  static const double _hitFlashDuration = 0.15;

  // 보스 랜덤 대사 타이머
  double _quoteTimer = 0;
  late double _nextQuoteTime;
  static final Random _random = Random();

  // 드롭 경험치
  late int expValue;

  // 히트박스 반경 크기 기억
  late double _collisionRadius;
  double get radius => _collisionRadius;
  bool _registeredWithGame = false;
  bool _isDying = false;

  BaseEnemy({required this.type, required Vector2 position})
    : super(size: Vector2(64, 64), position: position, anchor: Anchor.center) {
    definition = enemyDefinitionFor(type);
    _behavior = createEnemyBehavior(definition.behavior);
    _collisionRadius = definition.radius;
    _initStats();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 웨이브 스케일링 (보스 클리어마다 체력 2배)
    final currentWave = game.gameState.currentWave;
    final waveIndex = max(0, currentWave - 1);
    final waveMultiplier = 1.0 + (waveIndex * 0.045);
    final bossBonus = _isBoss ? 0.25 + ((waveIndex ~/ 5) * 0.05) : 0.0;
    final lateWaveBonus = currentWave >= 5 ? 1.3 : 1.0;
    final hpMultiplier = (waveMultiplier + bossBonus) * lateWaveBonus;

    maxHp *= hpMultiplier;
    currentHp = maxHp;

    if (_isBoss) {
      _nextQuoteTime = 8.0 + _random.nextDouble() * 4.0;
    }

    // 스프라이트 로드 (타입별 에셋 동적 적용)
    try {
      final spriteSheet = await game.images.load(definition.spritePath);

      // 단일 이미지 1프레임 애니메이션으로 변환
      final anim = SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 1,
          stepTime: 1.0,
          textureSize: Vector2(
            spriteSheet.width.toDouble(),
            spriteSheet.height.toDouble(),
          ),
        ),
      );

      // Animation child 컴포넌트 추가
      add(SpriteAnimationComponent(animation: anim, size: size));
    } catch (e) {
      debugPrint('Error loading enemy sprite: $e');
      // 폴백: 색상이 있는 원형 컴포넌트
      add(
        CircleComponent(
          radius: _collisionRadius,
          paint: Paint()..color = Colors.red.withValues(alpha: 0.5),
          anchor: Anchor.center,
          position: size / 2,
        ),
      );
    }

    add(
      CircleHitbox(
        radius: _collisionRadius,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );

    // 보스 등록
    _registerBoss();
  }

  @override
  void onMount() {
    super.onMount();
    if (!_registeredWithGame) {
      game.registerEnemy(this);
      _registeredWithGame = true;
    }
  }

  @override
  void onRemove() {
    if (_registeredWithGame) {
      game.unregisterEnemy(this);
      _registeredWithGame = false;
    }
    super.onRemove();
  }

  void _initStats() {
    maxHp = definition.maxHp;
    speed = definition.speed;
    damage = definition.damage;
    attackCooldown = definition.attackCooldown;
    expValue = definition.expValue;

    // 약간의 속도 무작위성 추가 (+/- 10%)
    final rand = Random();
    speed += (rand.nextDouble() - 0.5) * (speed * 0.2);

    currentHp = maxHp;
  }

  void _registerBoss() {
    final bossTitle = definition.bossTitle;
    if (bossTitle != null) {
      game.gameState.setBoss(bossTitle);
    }
  }

  String _getBossQuote() {
    final quotes = [
      '야근 수당은 없다!',
      '내일까지 무조건 끝내놔!',
      '이것도 못 하나?',
      '다시 해와!',
      '실망이 아주 큽니다.',
      '회사가 장난이야!?',
      '요즘 애들은 말이야...',
    ];
    return quotes[_random.nextInt(quotes.length)];
  }

  @override
  void update(double dt) {
    super.update(dt);

    final player = game.player;
    final distToPlayer = position.distanceTo(player.position);

    _behavior.update(this, player, dt, distToPlayer);

    // 접촉 데미지 쿨다운
    _attackTimer += dt;

    // 피격 이펙트 (빨간색 틴트)
    if (_hitFlashTimer > 0) {
      _hitFlashTimer -= dt;
      if (_hitFlashTimer <= 0) {
        for (final child in children) {
          if (child is HasPaint) {
            child.paint.colorFilter = null;
          }
        }
      }
    }

    // 보스 랜덤 대사 출력
    if (_isBoss) {
      _quoteTimer += dt;
      if (_quoteTimer >= _nextQuoteTime) {
        _quoteTimer = 0;
        _nextQuoteTime = 8.0 + _random.nextDouble() * 4.0;
        final quote = _getBossQuote();
        game.showSkillText(quote, Colors.redAccent, position.clone()..y -= 40);
      }
    }

    // 플레이어를 향해 이동
    if (!player.isRemoved) {
      final dir = (player.position - position).normalized();
      // position.add(dir * speed * dt); // This line is handled by specific AI behaviors

      // 방향에 따른 스프라이트 반전
      if (dir.x < 0 && !isFlippedHorizontally) {
        flipHorizontally();
      } else if (dir.x > 0 && isFlippedHorizontally) {
        flipHorizontally();
      }
    }

    // 맵 경계 제한
    position.clamp(
      Vector2(_collisionRadius, _collisionRadius),
      Vector2(
        game.mapSize.x - _collisionRadius,
        game.mapSize.y - _collisionRadius,
      ),
    );
  }

  /// 데미지 받기
  void takeDamage(double dmg) {
    if (currentHp <= 0) return;

    currentHp -= dmg;
    game.playThrottledSfx(
      'sfx_enemy_hit.ogg',
      volume: 0.4,
      minInterval: 0.04,
    );
    _hitFlashTimer = _hitFlashDuration;

    // 보스인 경우 UI 체력바 업데이트
    if (_isBoss) {
      game.gameState.updateBossHp(currentHp / maxHp);
    }

    // PositionComponent에는 paint 속성이 없으므로 자식들을 반투명하게 만듦 (단순 구현)
    for (final child in children) {
      if (child is HasPaint) {
        child.paint.colorFilter = const ColorFilter.mode(
          Colors.white,
          BlendMode.srcATop,
        );
      }
    }

    if (currentHp <= 0) {
      die();
    }
  }

  bool get _isBoss =>
      definition.bossTitle != null || type == EnemyType.mbtiBoss;

  bool get isBoss => _isBoss;

  /// 사망 처리
  void die() {
    if (_isDying) {
      return;
    }
    _isDying = true;
    game.playThrottledSfx(
      'sfx_enemy_die.ogg',
      volume: 0.5,
      minInterval: 0.08,
    );
    
    if (_isBoss) {
      game.gameState.clearBoss();
      // 보스 사망 시 모든 적 투사체 제거
      _clearEnemyProjectiles();
    }

    // 커피콩 보상
    game.playThrottledSfx(
      'sfx_coin.ogg',
      volume: 0.08,
      minInterval: 0.28,
    );
    game.gameState.addCoffeeBeans(expValue);

    // 파워업 드랍 시도
    final powerUp = PowerUp.trySpawn(position);
    if (powerUp != null) {
      final awayFromPlayer = powerUp.position - game.player.position;
      final dropDirection = awayFromPlayer.length2 > 0
          ? awayFromPlayer.normalized()
          : Vector2(0, -1);
      final sideOffset = Vector2(-dropDirection.y, dropDirection.x) *
          (_random.nextDouble() * 28 - 14);
      powerUp.position =
          powerUp.position +
          (dropDirection * 52) +
          sideOffset;
      powerUp.position.clamp(
        Vector2(28, 28),
        Vector2(game.mapSize.x - 28, game.mapSize.y - 28),
      );
      game.world.add(powerUp);
    }

    game.onEnemyKilled(this);
    removeFromParent();
  }

  /// 보스 사망 시 모든 적 투사체 제거
  void _clearEnemyProjectiles() {
    final projectiles = List<Projectile>.from(game.activeProjectiles);
    for (final p in projectiles) {
      final isEnemyProjectile = p.children.whereType<TagComponent>().any(
        (t) => t.tag == 'enemy_projectile',
      );
      if (isEnemyProjectile) {
        p.removeFromParent();
      }
    }
  }

  /// 접촉 시 플레이어에게 데미지
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is Player && _attackTimer >= attackCooldown) {
      _attackTimer = 0;
      other.takeDamage(damage);
    }
  }
}
