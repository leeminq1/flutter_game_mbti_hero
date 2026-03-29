import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../config/character_data.dart';
import '../../config/wave_data.dart';
import '../player.dart';
import '../projectiles/base_projectile.dart';
import 'base_enemy.dart';

class MbtiBossEnemy extends BaseEnemy {
  final CharacterData characterData;
  double _ultTimer = 0;
  double _mbtiAttackTimer = 0;
  final Random _mbtiRandom = Random();

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
    required Vector2 position,
    required this.characterData,
    double playerAttack = 15,
    double playerSpeed = 150,
    double playerMaxHp = 80,
    int waveNumber = 5,
  }) : super(type: EnemyType.mbtiBoss, position: position) {
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

    if (_mbtiAttackTimer >= attackCooldown * loadMultiplier) {
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
    final aimedBurstCount = _loadAdjustedCount(2, minimum: 1);
    final visual = _visualForAttack(characterData.attackType);

    switch (characterData.attackType) {
      case AttackType.wave:
      case AttackType.aura:
      case AttackType.shield:
        _spawnProjectile(pDir, 100, damage, 30, visual.color, visual.emoji);
        break;
      case AttackType.homing:
        final spread = aimedBurstCount == 1 ? 0.0 : 0.24;
        final start = -spread * (aimedBurstCount - 1) / 2;
        for (int i = 0; i < aimedBurstCount; i++) {
          final angle = atan2(pDir.y, pDir.x) + start + (i * spread);
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            150,
            damage * 0.7,
            12,
            visual.color,
            visual.emoji,
          );
        }
        break;
      case AttackType.straight:
        _spawnProjectile(pDir, 250, damage * 1.5, 12, visual.color, visual.emoji);
        break;
      case AttackType.rapid:
        final rapidBurstCount = _loadAdjustedCount(2, minimum: 1);
        for (int i = 0; i < rapidBurstCount; i++) {
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
        _spawnProjectile(pDir, 120, damage, 15, visual.color, visual.emoji);
        break;
      case AttackType.blink:
        _spawnProjectile(pDir, 300, damage * 1.2, 10, visual.color, visual.emoji);
        break;
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
      useCheapVisual:
          _activeProjectileLoad >= 32 || game.activeEnemies.length >= 20,
    );
    bullet.add(TagComponent('enemy_projectile'));
    game.spawnProjectile(bullet);
  }

  _BossAttackVisual _visualForAttack(AttackType type) {
    switch (type) {
      case AttackType.wave:
        return _BossAttackVisual(
          attackProjectileEmoji(type),
          const Color(0xFFFFC857),
          '결재 폭풍',
        );
      case AttackType.homing:
        return _BossAttackVisual(
          attackProjectileEmoji(type),
          const Color(0xFFFF7043),
          '폭탄 추적',
        );
      case AttackType.straight:
        return _BossAttackVisual(
          attackProjectileEmoji(type),
          const Color(0xFF90CAF9),
          '직선 강타',
        );
      case AttackType.rapid:
        return _BossAttackVisual(
          attackProjectileEmoji(type),
          const Color(0xFFFF8A65),
          '난사 패턴',
        );
      case AttackType.summon:
        return _BossAttackVisual(
          attackProjectileEmoji(type),
          const Color(0xFFF48FB1),
          '감정 파동',
        );
      case AttackType.aura:
        return _BossAttackVisual(
          attackProjectileEmoji(type),
          const Color(0xFFFFF176),
          '오라 방출',
        );
      case AttackType.shield:
        return _BossAttackVisual(
          attackProjectileEmoji(type),
          const Color(0xFF81C784),
          '방패 폭주',
        );
      case AttackType.blink:
        return _BossAttackVisual(
          attackProjectileEmoji(type),
          const Color(0xFF80CBC4),
          '순간 베기',
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
