import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../config/character_data.dart';
import '../../config/wave_data.dart';
import 'base_enemy.dart';
import '../projectiles/base_projectile.dart';
import '../player.dart';

class MbtiBossEnemy extends BaseEnemy {
  final CharacterData characterData;
  double _ultTimer = 0;
  double _mbtiAttackTimer = 0;
  final Random _mbtiRandom = Random();

  /// 웨이브별 보스 난이도 배율 (플레이어 대비)
  static double getWaveMultiplier(int waveNumber) {
    switch (waveNumber) {
      case 5:
        return 0.40;
      case 10:
        return 0.50;
      case 15:
        return 0.60;
      case 20:
        return 0.70;
      case 25:
        return 0.75;
      case 30:
        return 0.80;
      default:
        return 0.50; // 기본값
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
    // 플레이어 스탯 기반으로 보스 능력치 설정
    maxHp = playerMaxHp * (3.0 + mult * 5.0); // 체력 2배 버프 (3~8배)
    currentHp = maxHp;
    speed = playerSpeed * (0.385 + mult * 0.22); // 속도 10% 상승
    damage = playerAttack * (0.48 + mult * 0.6); // 공격력 20% 상승
    attackCooldown =
        characterData.baseAttackSpeed * (1.2 - mult * 0.3); // 쿨타임 점점 짧아짐
    expValue = 150 + (waveNumber * 10);
  }

  @override
  Future<void> onLoad() async {
    // BaseEnemy의 onLoad를 부분적으로 우회하기 위해 직접 구현
    // 부모의 onLoad를 호출하되, 스프라이트는 우리가 다시 덮어씌움
    await super.onLoad();

    // 부모가 로드한 스프라이트 및 애니메이션 컴포넌트 모두 제거 (Hitbox는 유지해야 함!)
    removeAll(children.whereType<SpriteAnimationComponent>());
    removeAll(
      children.whereType<RectangleComponent>(),
    ); // BaseEnemy가 추가할 수도 있는 체력바 제거

    // MBTI 전용 스프라이트 로드
    try {
      final spriteSheet = await game.images.load(characterData.assetPath);
      final anim = SpriteAnimation.fromFrameData(
        spriteSheet,
        SpriteAnimationData.sequenced(
          amount: 4, // 4프레임 걷기 애니메이션 (기존 플레이어와 동일)
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

    // 이름 및 체력바 등록
    game.gameState.setBoss('타락한 ${characterData.name} (${characterData.mbti})');

    // 이펙트를 위해 틴트 컴포넌트 추가
    add(ColorEffectComponent());
  }

  @override
  void update(double dt) {
    // 부모의 이동 로직 및 기본 데미지 처리 호출
    super.update(dt);

    final player = game.player;
    if (player.isRemoved) return;

    // 쿨타임 증가
    _ultTimer += dt;
    _mbtiAttackTimer += dt;

    if (_mbtiAttackTimer >= attackCooldown) {
      _mbtiAttackTimer = 0;
      _fireMbtiBasicAttack(player);
    }

    // 궁극기 쿨타임 확인
    if (_ultTimer >= characterData.ultCooldown * 0.6) {
      // 보스는 쿨타임이 플레이어보다 짧음
      _ultTimer = 0;
      _fireMbtiUltimate(player);

      // 대사 출력
      game.showSkillText(
        '${characterData.mbti} 궁극기 발동!!',
        characterData.color,
        position.clone()..y -= 40,
      );
    }
  }

  void _fireMbtiBasicAttack(Player player) {
    final pDir = (player.position - position).normalized();

    switch (characterData.attackType) {
      case AttackType.wave: // ESTJ 파동
      case AttackType.aura: // ENFJ 오라
      case AttackType.shield: // ISFJ 보호막 파동
        _spawnProjectile(
          pDir,
          100,
          damage,
          30,
          Colors.transparent,
          characterData.iconEmoji,
        );
        break;
      case AttackType.homing: // ENTP 유도유사 (임시로 3갈래)
        for (int i = -1; i <= 1; i++) {
          final angle = atan2(pDir.y, pDir.x) + (i * 0.3);
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            150,
            damage * 0.7,
            12,
            Colors.transparent,
            '💣',
          );
        }
        break;
      case AttackType.straight: // ISTP 직선탄 (빠르고 강함)
        _spawnProjectile(pDir, 250, damage * 1.5, 12, Colors.transparent, '🔧');
        break;
      case AttackType.rapid: // ESFP 연타 (약한 거 여러개)
        for (int i = 0; i < 3; i++) {
          final offset = Vector2(
            (_mbtiRandom.nextDouble() - 0.5) * 0.5,
            (_mbtiRandom.nextDouble() - 0.5) * 0.5,
          );
          Future.delayed(Duration(milliseconds: i * 100), () {
            if (!isRemoved) {
              _spawnProjectile(
                (pDir + offset).normalized(),
                200,
                damage * 0.4,
                8,
                Colors.transparent,
                '🔥',
              );
            }
          });
        }
        break;
      case AttackType.summon: // INFP 소환수 대신 힐링 투사체(플레이어에게 데미지)
        _spawnProjectile(pDir, 120, damage, 15, Colors.transparent, '💖');
        break;
      case AttackType.blink: // INTJ 순간 베기 투사체
        _spawnProjectile(
          pDir,
          300,
          damage * 1.2,
          10,
          Colors.transparent,
          '🗡️',
        );
        break;
    }
  }

  void _fireMbtiUltimate(Player player) {
    final pDir = (player.position - position).normalized();

    switch (characterData.attackType) {
      case AttackType.wave:
        // 사방으로 결재판 방출
        for (int i = 0; i < 12; i++) {
          final angle = i * 3.14159 * 2 / 12;
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            150,
            damage * 2.0,
            20,
            Colors.transparent,
            '💼',
          );
        }
        break;
      case AttackType.homing:
        // 플레이어 주위로 폭탄비
        for (int i = 0; i < 8; i++) {
          final angle = _mbtiRandom.nextDouble() * 3.14159 * 2;
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            100,
            damage * 1.5,
            20,
            Colors.transparent,
            '💣',
          );
        }
        break;
      case AttackType.straight:
        // 거대한 스패너 3방향
        for (int i = -1; i <= 1; i++) {
          final angle = atan2(pDir.y, pDir.x) + (i * 0.2);
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            300,
            damage * 3.0,
            30,
            Colors.transparent,
            '🔧',
          );
        }
        break;
      case AttackType.rapid:
        // 엄청난 속도의 화염 난사
        for (int i = 0; i < 15; i++) {
          final angle =
              atan2(pDir.y, pDir.x) + ((_mbtiRandom.nextDouble() - 0.5) * 1.0);
          Future.delayed(Duration(milliseconds: i * 50), () {
            if (!isRemoved) {
              _spawnProjectile(
                Vector2(cos(angle), sin(angle)),
                250,
                damage * 0.8,
                15,
                Colors.transparent,
                '🔥',
              );
            }
          });
        }
        break;
      case AttackType.summon:
      case AttackType.aura:
      case AttackType.shield:
      case AttackType.blink:
        // 일괄 거대 투사체 + 원형 패턴 조합
        for (int i = 0; i < 8; i++) {
          final angle = i * 3.14159 * 2 / 8;
          _spawnProjectile(
            Vector2(cos(angle), sin(angle)),
            100,
            damage * 2.5,
            30,
            Colors.transparent,
            characterData.iconEmoji,
          );
        }
        _spawnProjectile(
          pDir,
          200,
          damage * 4.0,
          40,
          Colors.transparent,
          characterData.iconEmoji,
        );
        break;
    }
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
    );
    bullet.add(TagComponent('enemy_projectile')); // 적으로부터 발사됨을 명시
    game.world.add(bullet);
  }
}

class ColorEffectComponent extends Component {}
