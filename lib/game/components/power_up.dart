import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../mbti_game.dart';
import 'player.dart';
import '../../services/sfx_manager.dart';

/// 파워업 타입
enum PowerUpType {
  attackBoost, // 공격력 증가
  speedBoost, // 이동속도 증가
  healPack, // 체력 회복
  cooldownReduce, // 쿨다임 감소
  multiShot, // 연사속도 증가
}

/// 파워업 아이템 컴포넌트
class PowerUp extends PositionComponent
    with HasGameReference<MbtiGame>, CollisionCallbacks {
  final PowerUpType type;
  double _lifeTimer = 0;
  static const double maxLifetime = 8.0; // 8초 후 사라짐
  static const double collectibleDelay = 0.55;
  double _bobTimer = 0; // 위아래 흔들림
  bool _canBeCollected = false;
  bool _isCollected = false;

  SpriteComponent? _spriteComponent;

  PowerUp({required this.type, required Vector2 position})
    : super(
        size: Vector2(40, 40),
        position: position,
        anchor: Anchor.center,
        priority: 5,
      );

  static String _getIconPath(PowerUpType type) {
    switch (type) {
      case PowerUpType.attackBoost:
        return 'effects/extracted/icon_0.png';
      case PowerUpType.speedBoost:
        return 'effects/extracted/icon_1.png';
      case PowerUpType.healPack:
        return 'effects/extracted/icon_2.png';
      case PowerUpType.cooldownReduce:
        return 'effects/extracted/icon_3.png';
      case PowerUpType.multiShot:
        return 'effects/extracted/icon_4.png';
    }
  }

  static Color _getColor(PowerUpType type) {
    switch (type) {
      case PowerUpType.attackBoost:
        return const Color(0xFFFF5252); // 빨강
      case PowerUpType.speedBoost:
        return const Color(0xFF448AFF); // 파랑
      case PowerUpType.healPack:
        return const Color(0xFF69F0AE); // 초록
      case PowerUpType.cooldownReduce:
        return const Color(0xFFFFD740); // 노랑
      case PowerUpType.multiShot:
        return const Color(0xFFE040FB); // 보라
    }
  }

  static String getLabel(PowerUpType type) {
    switch (type) {
      case PowerUpType.attackBoost:
        return '⚔️ 공격+';
      case PowerUpType.speedBoost:
        return '💨 속도+';
      case PowerUpType.healPack:
        return '💚 체력+';
      case PowerUpType.cooldownReduce:
        return '⏱️ 쿨감';
      case PowerUpType.multiShot:
        return '🔥 연사+';
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final loadedSprite = Sprite(await game.images.load(_getIconPath(type)));
      _spriteComponent = SpriteComponent(sprite: loadedSprite, size: size);
      add(_spriteComponent!);
    } catch (e) {
      debugPrint('Error loading powerup sprite: $e');
      // 폴백: 색상이 있는 사각형
      add(
        RectangleComponent(size: size, paint: Paint()..color = _getColor(type)),
      );
    }

    add(CircleHitbox(radius: 16, anchor: Anchor.center, position: size / 2));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 수명 체크
    _lifeTimer += dt;
    if (_lifeTimer >= maxLifetime) {
      removeFromParent();
      return;
    }
    if (!_canBeCollected && _lifeTimer >= collectibleDelay) {
      _canBeCollected = true;
    }

    // 위아래 흔들림 애니메이션 (시각적 피드백)
    _bobTimer += dt * 5;
    final yOffset = sin(_bobTimer) * 2;
    if (_spriteComponent != null) {
      _spriteComponent!.position.y = yOffset;
    }

    // 사라지기 전 깜빡임 (마지막 2초)
    if (_lifeTimer > maxLifetime - 2) {
      if (_spriteComponent != null) {
        _spriteComponent!.paint.color = Colors.white.withValues(
          alpha: sin(_lifeTimer * 20) * 0.5 + 0.5,
        );
      }
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (_isCollected || !_canBeCollected) {
      return;
    }

    if (other is Player) {
      _isCollected = true;
      SfxManager.playUi(
        'sfx_powerup.ogg',
        volume: 0.18,
        minInterval: 0.16,
      );
      _applyEffect(other);
      // 획득 텍스트 표시
      _showPickupText();
      removeFromParent();
    }
  }

  void _applyEffect(Player player) {
    switch (type) {
      case PowerUpType.attackBoost:
        player.applyAttackBoost(Player.attackPickupBoostAmount);
        break;
      case PowerUpType.speedBoost:
        player.applySpeedBoost(Player.speedPickupBoostAmount);
        break;
      case PowerUpType.healPack:
        player.heal(player.maxHp * 0.25);
        break;
      case PowerUpType.cooldownReduce:
        // 필살기 쿨타임 2~3초 랜덤 감소
        final reduceAmount = 2.0 + Random().nextDouble() * 1.0;
        game.gameState.reduceUltCooldown(reduceAmount);
        break;
      case PowerUpType.multiShot:
        player.increaseMultiShot();
        break;
    }
  }

  void _showPickupText() {
    if (!game.canSpawnTransientEffect()) {
      return;
    }
    final label = getLabel(type);
    final text = TextComponent(
      text: label,
      position: position.clone()..y -= 20,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: _getColor(type),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
    );

    // 1초 후 제거
    text.add(
      TimerComponent(
        period: 1.0,
        removeOnFinish: true,
        onTick: () => text.removeFromParent(),
      ),
    );

    // 위로 떠오르는 효과
    text.add(_FloatUpEffect());

    game.world.add(text);
  }

  /// 적 처치 시 랜덤 파워업 생성
  static PowerUp? trySpawn(Vector2 position) {
    final rand = Random();
    // 30% 확률로 드롭
    if (rand.nextDouble() > 0.28) return null;

    final chance = rand.nextDouble();
    PowerUpType type;

    // 멀티샷 확률을 다른 아이템들보다 높게 설정 (약 32%)
    // 나머지 4개는 각각 약 17%로 균등 분배
    if (chance < 0.22) {
      type = PowerUpType.multiShot;
    } else if (chance < 0.40) {
      type = PowerUpType.attackBoost;
    } else if (chance < 0.58) {
      type = PowerUpType.speedBoost;
    } else if (chance < 0.79) {
      type = PowerUpType.healPack;
    } else {
      type = PowerUpType.cooldownReduce;
    }

    return PowerUp(type: type, position: position.clone());
  }
}

/// 위로 떠오르는 이펙트 (텍스트용)
class _FloatUpEffect extends Component {
  @override
  void update(double dt) {
    super.update(dt);
    final parent = this.parent;
    if (parent is PositionComponent) {
      parent.position.y -= 30 * dt;
    }
  }
}
