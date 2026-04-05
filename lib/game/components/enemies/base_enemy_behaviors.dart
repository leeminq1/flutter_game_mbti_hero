part of 'base_enemy.dart';

abstract class EnemyBehavior {
  void update(BaseEnemy enemy, Player player, double dt, double distance);
}

EnemyBehavior createEnemyBehavior(EnemyBehaviorKind kind) {
  switch (kind) {
    case EnemyBehaviorKind.chase:
      return const ChaseEnemyBehavior();
    case EnemyBehaviorKind.bat:
      return const BatEnemyBehavior();
    case EnemyBehaviorKind.chargerRush:
      return ChargerRushEnemyBehavior();
    case EnemyBehaviorKind.sniper:
      return const SniperEnemyBehavior();
    case EnemyBehaviorKind.charge:
      return const ChargeEnemyBehavior();
    case EnemyBehaviorKind.bossChase:
      return BossChaseEnemyBehavior();
    case EnemyBehaviorKind.mbtiBoss:
      return const MbtiBossEnemyBehavior();
  }
}

class ChaseEnemyBehavior implements EnemyBehavior {
  const ChaseEnemyBehavior();

  @override
  void update(BaseEnemy enemy, Player player, double dt, double distance) {
    _moveToward(enemy, player.position - enemy.position, dt);
  }
}

class BatEnemyBehavior implements EnemyBehavior {
  const BatEnemyBehavior();

  @override
  void update(BaseEnemy enemy, Player player, double dt, double distance) {
    final direction = player.position - enemy.position;
    if (direction.length <= 1) {
      return;
    }
    final wobble = sin(enemy.position.x * 0.05 + enemy.position.y * 0.05) * 20;
    final perpendicular =
        Vector2(-direction.y, direction.x).normalized() * wobble;
    enemy.position.add(
      (direction.normalized() * enemy.speed + perpendicular) * dt,
    );
  }
}

class ChargerRushEnemyBehavior implements EnemyBehavior {
  int _phase = 0;
  Vector2? _chargeDirection;
  double _chargeTimer = 0;
  static const double _chargeMaxDuration = 1.5;

  @override
  void update(BaseEnemy enemy, Player player, double dt, double distance) {
    if (player.isRemoved && _phase == 0) {
      return;
    }

    switch (_phase) {
      case 0:
        final direction = player.position - enemy.position;
        if (direction.length <= 1) {
          return;
        }
        if (distance < 200) {
          _chargeDirection = direction.normalized();
          _phase = 1;
          _chargeTimer = 0;
        } else {
          enemy.position.add(direction.normalized() * enemy.speed * 0.5 * dt);
        }
        break;
      case 1:
        _chargeTimer += dt;
        final dir = _chargeDirection;
        if (dir == null) {
          _phase = 0;
          return;
        }
        enemy.position.add(dir * enemy.speed * 2.5 * dt);
        if (_chargeTimer >= _chargeMaxDuration) {
          _phase = 2;
          _showEnemyEmoji(enemy, '💥');
          enemy.die();
        }
        break;
      case 2:
        break;
    }
  }
}

class ChargeEnemyBehavior implements EnemyBehavior {
  const ChargeEnemyBehavior();

  @override
  void update(BaseEnemy enemy, Player player, double dt, double distance) {
    if (player.isRemoved) {
      return;
    }

    if (distance < 40 && enemy.currentHp > 0 && !enemy._isDying) {
      player.takeDamage(enemy.damage * 1.5);
      _showEnemyEmoji(enemy, '💥');
      enemy._isDying = true;
      enemy.game.onEnemyKilled(enemy);
      enemy.removeFromParent();
      return;
    }

    final direction = player.position - enemy.position;
    if (direction.length <= 1) {
      return;
    }

    final multiplier = distance < 200 ? 1.8 : 0.5;
    enemy.position.add(direction.normalized() * enemy.speed * multiplier * dt);
  }
}

class SniperEnemyBehavior implements EnemyBehavior {
  const SniperEnemyBehavior();

  @override
  void update(BaseEnemy enemy, Player player, double dt, double distance) {
    final direction = player.position - enemy.position;
    if (direction.length <= 1) {
      return;
    }

    if (distance < 150) {
      enemy.position.add(direction.normalized() * -enemy.speed * dt);
    } else if (distance > 250) {
      enemy.position.add(direction.normalized() * enemy.speed * dt);
    }

    if (enemy._attackTimer >= enemy.attackCooldown && distance < 300) {
      enemy._attackTimer = 0;
      _fireSniperBurst(enemy, player);
    }
  }
}

class BossChaseEnemyBehavior implements EnemyBehavior {
  final Random _random = Random();

  @override
  void update(BaseEnemy enemy, Player player, double dt, double distance) {
    _moveToward(enemy, player.position - enemy.position, dt);

    if (enemy._attackTimer < enemy.attackCooldown) {
      return;
    }

    enemy._attackTimer = 0;
    enemy.game.playThrottledSfx(
      'sfx_boss_attack.ogg',
      volume: 0.7,
      minInterval: 0.18,
    );

    final pattern = _random.nextInt(3);
    final isFinal = enemy.type == EnemyType.finalBoss;
    final projectilePressure = enemy.game.activeProjectiles.length;

    if (pattern == 0) {
      final baseBullets = isFinal ? 10 : 8;
      final pressurePenalty = projectilePressure >= 42
          ? 4
          : projectilePressure >= 28
          ? 2
          : 0;
      final numBullets = max(6, baseBullets - pressurePenalty);
      for (int i = 0; i < numBullets; i++) {
        final angle = i * pi * 2 / numBullets;
        final dir = Vector2(cos(angle), sin(angle));
        _spawnEnemyProjectile(
          enemy,
          dir,
          projectileSpeed: 120,
          projectileDamage: enemy.damage * 0.5,
          emoji: '🔥',
          radius: 6,
        );
      }
      return;
    }

    if (pattern == 1) {
      final targetDir = (player.position - enemy.position).normalized();
      final baseAngle = atan2(targetDir.y, targetDir.x);
      final spreadPenalty = projectilePressure >= 36 ? 1 : 0;
      final spread = max(1, (isFinal ? 2 : 1) - spreadPenalty);
      for (int i = -spread; i <= spread; i++) {
        final angle = baseAngle + (i * 0.2);
        final dir = Vector2(cos(angle), sin(angle));
        _spawnEnemyProjectile(
          enemy,
          dir,
          projectileSpeed: 180,
          projectileDamage: enemy.damage * 0.8,
          emoji: '🗡️',
          radius: 8,
        );
      }
      return;
    }

    final targetDir = (player.position - enemy.position).normalized();
    _spawnEnemyProjectile(
      enemy,
      targetDir,
      projectileSpeed: 60,
      projectileDamage: enemy.damage * 2.0,
      emoji: isFinal ? '☠️' : '💣',
      radius: 20,
    );
  }
}

class MbtiBossEnemyBehavior implements EnemyBehavior {
  const MbtiBossEnemyBehavior();

  @override
  void update(BaseEnemy enemy, Player player, double dt, double distance) {
    _moveToward(enemy, player.position - enemy.position, dt);
  }
}

void _moveToward(BaseEnemy enemy, Vector2 direction, double dt) {
  if (direction.length > 1) {
    enemy.position.add(direction.normalized() * enemy.speed * dt);
  }
}

void _showEnemyEmoji(
  BaseEnemy enemy,
  String emoji, {
  double fontSize = 64,
  double lifetime = 0.3,
}) {
  final effect = TextComponent(
    text: emoji,
    position: enemy.position.clone(),
    anchor: Anchor.center,
    textRenderer: TextPaint(style: TextStyle(fontSize: fontSize)),
    priority: 10,
  );
  effect.add(
    TimerComponent(
      period: lifetime,
      removeOnFinish: true,
      onTick: () => effect.removeFromParent(),
    ),
  );
  enemy.game.addTimedWorldComponent(effect, lifetime: lifetime);
}

void _spawnEnemyProjectile(
  BaseEnemy enemy,
  Vector2 direction, {
  required double projectileSpeed,
  required double projectileDamage,
  required String? emoji,
  required double radius,
  Color color = Colors.transparent,
}) {
  final bullet = Projectile(
    position: enemy.position.clone(),
    direction: direction,
    speed: projectileSpeed,
    damage: projectileDamage,
    color: color,
    emoji: emoji,
    radius: radius,
    useCheapVisual:
        emoji == null ||
        (!enemy.isBoss &&
            (enemy.game.activeProjectiles.length >= 28 ||
                enemy.game.activeEnemies.length >= 18)),
  );
  bullet.add(TagComponent('enemy_projectile'));
  enemy.game.spawnProjectile(bullet);
}

void _fireSniperBurst(BaseEnemy enemy, Player player) {
  if (player.isRemoved) {
    return;
  }

  final currentWave = enemy.game.gameState.currentWave;
  final projectilePressure = enemy.game.activeProjectiles.length;
  final maxShots = projectilePressure >= 32
      ? 1
      : currentWave >= 15
      ? 3
      : 2;
  final baseDirection = (player.position - enemy.position).normalized();
  final baseAngle = atan2(baseDirection.y, baseDirection.x);
  final spreadStep = maxShots >= 3 ? 0.08 : 0.05;
  final startAngle = -spreadStep * (maxShots - 1) / 2;

  for (int i = 0; i < maxShots; i++) {
    final angle = baseAngle + startAngle + (i * spreadStep);
    _spawnEnemyProjectile(
      enemy,
      Vector2(cos(angle), sin(angle)),
      projectileSpeed: 175,
      projectileDamage: enemy.damage,
      emoji: null,
      radius: 4,
      color: const Color(0xFFFF1744),
    );
  }
}
