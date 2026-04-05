import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/character_data.dart';
import '../../config/wave_data.dart';
import '../player.dart';
import '../projectiles/base_projectile.dart';
import 'base_enemy.dart';

class MbtiBossEnemy extends BaseEnemy {
  static const List<int> _basicBurstPattern = [1, 1, 5];
  static const double _basicAttackRateBoost = 1.2;

  final CharacterData characterData;
  double _ultTimer = 0;
  double _mbtiAttackTimer = 0;
  final Random _mbtiRandom = Random();
  int _basicBurstIndex = 0;

  int get _activeProjectileLoad => game.activeProjectiles.length;

  static double getWaveMultiplier(int waveNumber) {
    switch (waveNumber) {
      case 5:
        return 0.35;
      case 10:
        return 0.45;
      case 15:
        return 0.55;
      case 20:
        return 0.65;
      case 25:
        return 0.70;
      case 30:
        return 0.75;
      default:
        return 0.50;
    }
  }

  MbtiBossEnemy({
    required super.position,
    required this.characterData,
    double playerAttack = 15,
    double playerSpeed = 150,
    double playerMaxHp = 80,
    int waveNumber = 5,
  }) : super(type: EnemyType.mbtiBoss) {
    final mult = getWaveMultiplier(waveNumber);
    maxHp = playerMaxHp * (2.0 + mult * 2.0);
    currentHp = maxHp;
    speed = playerSpeed * (0.32 + mult * 0.14);
    damage = playerAttack * (0.32 + mult * 0.34);
    attackCooldown = characterData.baseAttackSpeed * (1.42 - mult * 0.12);
    expValue = 150 + (waveNumber * 10);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    removeAll(children.whereType<SpriteAnimationComponent>());
    removeAll(children.whereType<RectangleComponent>());

    try {
      final spriteSheet = await game.images.load(characterData.assetPath);
      final anim = SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4,
          stepTime: 0.15,
          textureSize: Vector2(
            spriteSheet.width / 4,
            spriteSheet.height.toDouble(),
          ),
        ),
      );
      add(SpriteAnimationComponent(animation: anim, size: size));
    } catch (e) {
      debugPrint('Error loading MBTI boss sprite: $e');
      add(
        CircleComponent(
          radius: 24.0,
          paint: Paint()..color = characterData.color,
          anchor: Anchor.center,
          position: size / 2,
        ),
      );
    }

    game.gameState.setBoss('${characterData.name} (${characterData.mbti})');
    add(ColorEffectComponent());
  }

  @override
  void update(double dt) {
    super.update(dt);

    final player = game.player;
    if (player.isRemoved) {
      return;
    }

    _ultTimer += dt;
    _mbtiAttackTimer += dt;
    final loadMultiplier = _attackLoadMultiplier();

    if (_mbtiAttackTimer >= attackCooldown / _basicAttackRateBoost) {
      _mbtiAttackTimer = 0;
      _fireMbtiBasicAttack(player);
    }

    if (_ultTimer >= characterData.ultCooldown * 0.75 * loadMultiplier) {
      _ultTimer = 0;
      _fireMbtiUltimate(player);
    }
  }

  void _fireMbtiBasicAttack(Player player) {
    final pDir = (player.position - position).normalized();
    final aimedBurstCount = _basicBurstPattern[_basicBurstIndex];
    _basicBurstIndex = (_basicBurstIndex + 1) % _basicBurstPattern.length;
    final visual = _visualForAttack(characterData.attackType);

    switch (characterData.attackType) {
      case AttackType.wave:
      case AttackType.aura:
      case AttackType.shield:
        _fireAimedBurstProjectiles(
          baseDirection: pDir,
          count: aimedBurstCount,
          projectileSpeed: 100,
          projectileDamage: damage,
          radius: 30,
          color: visual.color,
          emoji: visual.emoji,
          spread: 0.16,
        );
        break;
      case AttackType.homing:
        _fireAimedBurstProjectiles(
          baseDirection: pDir,
          count: aimedBurstCount,
          projectileSpeed: 150,
          projectileDamage: damage * 0.7,
          radius: 12,
          color: visual.color,
          emoji: visual.emoji,
          spread: 0.24,
        );
        break;
      case AttackType.straight:
        _fireAimedBurstProjectiles(
          baseDirection: pDir,
          count: aimedBurstCount,
          projectileSpeed: 250,
          projectileDamage: damage * 1.5,
          radius: 12,
          color: visual.color,
          emoji: visual.emoji,
          spread: 0.13,
        );
        break;
      case AttackType.rapid:
        for (int i = 0; i < aimedBurstCount; i++) {
          final offset = Vector2(
            (_mbtiRandom.nextDouble() - 0.5) * 0.35,
            (_mbtiRandom.nextDouble() - 0.5) * 0.35,
          );
          _spawnProjectile(
            (pDir + offset).normalized(),
            190,
            damage * 0.4,
            8,
            visual.color,
            visual.emoji,
          );
        }
        break;
      case AttackType.summon:
        _fireAimedBurstProjectiles(
          baseDirection: pDir,
          count: aimedBurstCount,
          projectileSpeed: 120,
          projectileDamage: damage,
          radius: 15,
          color: visual.color,
          emoji: visual.emoji,
          spread: 0.18,
        );
        break;
      case AttackType.blink:
        _fireAimedBurstProjectiles(
          baseDirection: pDir,
          count: aimedBurstCount,
          projectileSpeed: 300,
          projectileDamage: damage * 1.2,
          radius: 10,
          color: visual.color,
          emoji: visual.emoji,
          spread: 0.11,
        );
        break;
    }
  }

  void _fireAimedBurstProjectiles({
    required Vector2 baseDirection,
    required int count,
    required double projectileSpeed,
    required double projectileDamage,
    required double radius,
    required Color color,
    required String emoji,
    required double spread,
  }) {
    final baseAngle = atan2(baseDirection.y, baseDirection.x);
    final appliedSpread = count <= 1 ? 0.0 : spread;
    final start = -appliedSpread * (count - 1) / 2;
    for (int i = 0; i < count; i++) {
      final angle = baseAngle + start + (i * appliedSpread);
      _spawnProjectile(
        Vector2(cos(angle), sin(angle)),
        projectileSpeed,
        projectileDamage,
        radius,
        color,
        emoji,
      );
    }
  }

  void _fireMbtiUltimate(Player player) {
    final pDir = (player.position - position).normalized();
    final visual = _visualForAttack(characterData.attackType);
    game.showSkillText(
      '${characterData.mbti} ${visual.label}',
      visual.color,
      position.clone()..y -= 72,
    );

    switch (characterData.attackType) {
      case AttackType.wave:
        final radialCount = _loadAdjustedCount(6, minimum: 4);
        for (int i = 0; i < radialCount; i++) {
          final angle = i * pi * 2 / radialCount;
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            150,
            damage * 2.0,
            20,
            visual.color,
            visual.emoji,
          );
        }
        break;
      case AttackType.homing:
        final burstCount = _loadAdjustedCount(3, minimum: 2);
        for (int i = 0; i < burstCount; i++) {
          final angle = _mbtiRandom.nextDouble() * pi * 2;
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            100,
            damage * 1.5,
            20,
            visual.color,
            visual.emoji,
          );
        }
        break;
      case AttackType.straight:
        for (int i = -1; i <= 1; i++) {
          final angle = atan2(pDir.y, pDir.x) + (i * 0.2);
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            300,
            damage * 2.6,
            26,
            visual.color,
            visual.emoji,
          );
        }
        break;
      case AttackType.rapid:
        final rapidCount = _loadAdjustedCount(4, minimum: 2);
        for (int i = 0; i < rapidCount; i++) {
          final angle =
              atan2(pDir.y, pDir.x) + ((_mbtiRandom.nextDouble() - 0.5) * 0.7);
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            235,
            damage * 0.8,
            15,
            visual.color,
            visual.emoji,
          );
        }
        break;
      case AttackType.summon:
      case AttackType.aura:
      case AttackType.shield:
      case AttackType.blink:
        final radialCount = _loadAdjustedCount(4, minimum: 2);
        for (int i = 0; i < radialCount; i++) {
          final angle = i * pi * 2 / radialCount;
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            100,
            damage * 2.2,
            26,
            visual.color,
            visual.emoji,
          );
        }
        _spawnProjectile(
          pDir,
          200,
          damage * 3.2,
          34,
          visual.color,
          visual.emoji,
        );
        break;
    }
  }

  double _attackLoadMultiplier() {
    if (_activeProjectileLoad >= 20 || game.activeEnemies.length >= 18) {
      return 1.9;
    }
    if (_activeProjectileLoad >= 12 || game.activeEnemies.length >= 14) {
      return 1.5;
    }
    return 1.0;
  }

  int _loadAdjustedCount(int base, {required int minimum}) {
    if (_activeProjectileLoad >= 20 || game.activeEnemies.length >= 18) {
      return max(minimum, (base * 0.3).round());
    }
    if (_activeProjectileLoad >= 12 || game.activeEnemies.length >= 14) {
      return max(minimum, (base * 0.5).round());
    }
    return base;
  }

  void _spawnProjectile(
    Vector2 dir,
    double pSpeed,
    double pDamage,
    double radius,
    Color color,
    String emoji,
  ) {
    final bullet = Projectile(
      position: position.clone(),
      direction: dir,
      speed: pSpeed,
      damage: pDamage,
      color: color,
      emoji: emoji,
      radius: radius,
      useCheapVisual: false,
    );
    bullet.add(TagComponent('enemy_projectile'));
    game.spawnProjectile(bullet);
  }

  _BossAttackVisual _visualForAttack(AttackType type) {
    switch (type) {
      case AttackType.wave:
        return _BossAttackVisual(
          characterData.projectileEmoji,
          characterData.color,
          characterData.attackLabel,
        );
      case AttackType.homing:
        return _BossAttackVisual(
          characterData.projectileEmoji,
          characterData.color,
          characterData.attackLabel,
        );
      case AttackType.straight:
        return _BossAttackVisual(
          characterData.projectileEmoji,
          characterData.color,
          characterData.attackLabel,
        );
      case AttackType.rapid:
        return _BossAttackVisual(
          characterData.projectileEmoji,
          characterData.color,
          characterData.attackLabel,
        );
      case AttackType.summon:
        return _BossAttackVisual(
          characterData.projectileEmoji,
          characterData.color,
          characterData.attackLabel,
        );
      case AttackType.aura:
        return _BossAttackVisual(
          characterData.projectileEmoji,
          characterData.color,
          characterData.attackLabel,
        );
      case AttackType.shield:
        return _BossAttackVisual(
          characterData.projectileEmoji,
          characterData.color,
          characterData.attackLabel,
        );
      case AttackType.blink:
        return _BossAttackVisual(
          characterData.projectileEmoji,
          characterData.color,
          characterData.attackLabel,
        );
    }
  }
}

class ColorEffectComponent extends Component {}

class _BossAttackVisual {
  final String emoji;
  final Color color;
  final String label;

  const _BossAttackVisual(this.emoji, this.color, this.label);
}
