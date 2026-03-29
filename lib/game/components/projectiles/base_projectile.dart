import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../mbti_game.dart';
import '../enemies/base_enemy.dart';
import '../player.dart';

/// 투사체 기본 클래스
class Projectile extends CircleComponent
    with HasGameReference<MbtiGame>, CollisionCallbacks {
  final Vector2 direction;
  final double speed;
  final double damage;
  final bool isSplash;
  final double splashRadius;
  final String? emoji;
  final double knockbackPower;
  int pierceCount;
  final double lifetime;
  final bool useCheapVisual;

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
    this.lifetime = 2.2,
    this.useCheapVisual = false,
  }) : super(
         radius: radius,
         position: position,
         anchor: Anchor.center,
         paint: Paint()
           ..color = _resolvePaintColor(
             color: color,
             emoji: emoji,
             useCheapVisual: useCheapVisual,
           ),
       );

  static Color _resolvePaintColor({
    required Color color,
    required String? emoji,
    required bool useCheapVisual,
  }) {
    if (emoji != null && !useCheapVisual) {
      return Colors.transparent;
    }
    if (useCheapVisual && color == Colors.transparent) {
      return const Color(0xFFFFB74D);
    }
    return color;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());

    if (emoji != null && !useCheapVisual) {
      add(
        TextComponent(
          text: emoji!,
          anchor: Anchor.center,
          position: size / 2,
          textRenderer: TextPaint(style: TextStyle(fontSize: radius * 1.5)),
        ),
      );
    }
  }

  @override
  void onMount() {
    super.onMount();
    game.registerProjectile(this);
  }

  @override
  void onRemove() {
    game.unregisterProjectile(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.add(direction * speed * dt);

    _lifeTimer += dt;
    if (_lifeTimer >= lifetime) {
      _triggerSplashAndRemove();
    }
  }

  void _triggerSplashAndRemove() {
    if (isSplash && parent != null) {
      final enemies = List<BaseEnemy>.from(game.activeEnemies);
      for (final enemy in enemies) {
        if (enemy.position.distanceTo(position) <= splashRadius) {
          enemy.takeDamage(damage * 0.5);
        }
      }

      final shouldShowExplosionEffect =
          game.canSpawnTransientEffect() &&
          game.activeProjectiles.length < 18 &&
          game.activeEnemies.length < 18;
      if (shouldShowExplosionEffect) {
        final explosion = TextComponent(
          text: '💥',
          position: position.clone(),
          anchor: Anchor.center,
          textRenderer: TextPaint(style: TextStyle(fontSize: splashRadius)),
        );
        game.addTimedWorldComponent(explosion, lifetime: 0.12);
      }
    }

    removeFromParent();
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    final isEnemyProjectile = children.whereType<TagComponent>().any(
      (t) => t.tag == 'enemy_projectile',
    );

    if (other is BaseEnemy && !isEnemyProjectile) {
      other.takeDamage(damage);

      if (knockbackPower > 0) {
        final pushVec = direction * knockbackPower;
        pushVec.clamp(Vector2.all(-50), Vector2.all(50));
        other.position.add(pushVec);
      }

      pierceCount--;
      if (pierceCount <= 0) {
        _triggerSplashAndRemove();
      }
    } else if (other is Player && isEnemyProjectile) {
      other.takeDamage(damage);
      removeFromParent();
    }
  }
}

/// 태그 컴포넌트 - 투사체 구분용
class TagComponent extends Component {
  final String tag;
  TagComponent(this.tag);
}
