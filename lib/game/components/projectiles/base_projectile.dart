import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../enemies/base_enemy.dart';
import '../player.dart';

/// 투사체 기본 클래스
class Projectile extends CircleComponent with CollisionCallbacks {
  final Vector2 direction;
  final double speed;
  final double damage;
  final bool isSplash;
  final double splashRadius;
  final String? emoji;
  final double knockbackPower;
  int pierceCount;
  final double lifetime; // 최대 생존 시간 (사거리 조절용)

  double _lifeTimer = 0;

  Projectile({
    required Vector2 position,
    required this.direction,
    required this.speed,
    required this.damage,
    required Color color,
    double radius = 5,
    this.isSplash = false,
    this.splashRadius = 40,
    this.emoji,
    this.knockbackPower = 0.0,
    this.pierceCount = 1,
    this.lifetime = 3.0, // 기본 사거리: 3초 날아감
  }) : super(
         radius: radius,
         position: position,
         anchor: Anchor.center,
         paint: Paint()..color = emoji != null ? Colors.transparent : color,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());

    if (emoji != null) {
      add(
        TextComponent(
          text: emoji!,
          anchor: Anchor.center,
          position: size / 2, // 중앙 배치
          textRenderer: TextPaint(style: TextStyle(fontSize: radius * 1.5)),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 이동
    position.add(direction * speed * dt);

    // 수명 초과 시 제거 (폭발/삭제)
    _lifeTimer += dt;
    if (_lifeTimer >= lifetime) {
      _triggerSplashAndRemove();
    }
  }

  /// 스플래시 데미지 및 폭발 이펙트 (또는 일반 삭제)
  void _triggerSplashAndRemove() {
    if (isSplash && parent != null) {
      // 폭발 범위 내 적(BaseEnemy)에게 스플래시 데미지
      final enemies = parent!.children.whereType<BaseEnemy>().toList();
      for (final enemy in enemies) {
        if (enemy.position.distanceTo(position) <= splashRadius) {
          enemy.takeDamage(damage * 0.5); // 스플래시는 50%의 데미지
        }
      }

      // 폭발 이펙트 (💥)
      final explosion = TextComponent(
        text: '💥',
        position: position.clone(),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: TextStyle(fontSize: splashRadius)),
      );
      explosion.add(
        TimerComponent(
          period: 0.2, // 짧게 표시 후 삭제
          removeOnFinish: true,
          onTick: () => explosion.removeFromParent(),
        ),
      );
      parent!.add(explosion);
    }

    removeFromParent();
  }

  /// 충돌 콜백 - 적과 충돌 시 데미지
  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    // 적 투사체인지 확인 (TagComponent로 구분)
    final isEnemyProjectile = children.whereType<TagComponent>().any(
      (t) => t.tag == 'enemy_projectile',
    );

    if (other is BaseEnemy && !isEnemyProjectile) {
      // 1. 적 데미지
      other.takeDamage(damage);

      // 2. 넉백 적용
      if (knockbackPower > 0) {
        final pushVec = direction * knockbackPower;
        pushVec.clamp(Vector2.all(-50), Vector2.all(50));
        other.position.add(pushVec);
      }

      // 3. 관통 및 삭제 판정
      pierceCount--;
      if (pierceCount <= 0) {
        _triggerSplashAndRemove();
      }
    } else if (other is Player && isEnemyProjectile) {
      // 적의 투사체 -> 플레이어 데미지
      // Player의 takeDamage는 내부적으로 무적 판정을 하므로 바로 호출합니다.
      other.takeDamage(damage);
      removeFromParent();
    }
  }
}

/// 태그 컴포넌트 - 투사체 구분용 (base_enemy.dart에서도 사용)
class TagComponent extends Component {
  final String tag;
  TagComponent(this.tag);
}
