import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../config/wave_data.dart';
import '../../mbti_game.dart';
import '../player.dart';
import '../projectiles/base_projectile.dart';
import '../power_up.dart';
import 'package:flame_audio/flame_audio.dart';

class BaseEnemy extends PositionComponent
    with HasGameReference<MbtiGame>, CollisionCallbacks {
  final EnemyType type;
  late double maxHp;
  late double currentHp;
  late double speed;
  late double damage;
  late double attackCooldown;
  double _attackTimer = 0;

  // Charger 전용 상태 (enemy_2: 돌진 후 자폭)
  int _chargePhase = 0; // 0=접근, 1=돌진중, 2=자폭
  Vector2? _chargeDirection; // 고정된 돌진 방향
  double _chargeTimer = 0; // 돌진 경과 시간
  static const double _chargeMaxDuration = 1.5; // 돌진 최대 시간(초)

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

  BaseEnemy({required this.type, required Vector2 position})
    : super(size: Vector2(64, 64), position: position, anchor: Anchor.center) {
    _collisionRadius = _getRadius(type);
    _initStats();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 웨이브 스케일링 (보스 클리어마다 체력 2배)
    final currentWave = game.gameState.currentWave;
    final bossClears = (currentWave - 1) ~/ 3;
    final hpMultiplier = pow(2, bossClears).toDouble();

    maxHp *= hpMultiplier;
    currentHp = maxHp;

    if (_isBoss) {
      _nextQuoteTime = 8.0 + _random.nextDouble() * 4.0;
    }

    // 스프라이트 로드 (타입별 에셋 동적 적용)
    try {
      String imageFile = 'enemies/enemy_0.png';
      switch (type) {
        case EnemyType.slime:
          imageFile = 'enemies/enemy_0.png';
          break;
        case EnemyType.midBoss:
          imageFile = 'enemies/boss_1_proc.png'; // 서류 지옥 대리
          break;
        case EnemyType.tanker:
          imageFile = 'enemies/boss_2_proc.png'; // 결재 도장 팀장
          break;
        case EnemyType.bug:
          imageFile = 'enemies/enemy_bug.png'; // 벌레
          break;
        case EnemyType.stapler:
          imageFile = 'enemies/enemy_stapler.png'; // 호치키스
          break;
        case EnemyType.sharp:
          imageFile = 'enemies/enemy_sharp.png'; // 압정
          break;
        case EnemyType.mbtiBoss:
          imageFile = 'enemies/enemy_0.png'; // 예비용 (실제론 MbtiBossEnemy에서 처리)
          break;
        case EnemyType.bat:
          imageFile = 'enemies/enemy_1.png'; // 수다쟁이 동료
          break;
        case EnemyType.charger:
          imageFile = 'enemies/enemy_2.png'; // 급한 메신저
          break;
        case EnemyType.sniper:
          imageFile = 'enemies/enemy_3.png'; // 지적질 상사
          break;
        case EnemyType.finalBoss:
          imageFile = 'enemies/boss_3_proc.png'; // 골프채 이사
          break;
      }

      final spriteSheet = await game.images.load(imageFile);

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
    _registerBoss(type);
  }

  void _initStats() {
    switch (type) {
      case EnemyType.slime:
        maxHp = 30;
        speed = 80;
        damage = 10;
        attackCooldown = 1.0;
        expValue = 2;
        break;
      case EnemyType.bat:
        maxHp = 20;
        speed = 80;
        damage = 15;
        attackCooldown = 0.8;
        expValue = 4;
        break;
      case EnemyType.charger:
        maxHp = 50;
        speed = 120;
        damage = 25;
        attackCooldown = 2.0;
        expValue = 6;
        break;
      case EnemyType.sniper:
        maxHp = 25;
        speed = 30;
        damage = 35;
        attackCooldown = 3.0;
        expValue = 7;
        break;
      case EnemyType.tanker:
        maxHp = 100;
        speed = 25;
        damage = 10;
        attackCooldown = 2.0;
        expValue = 8;
        break;
      case EnemyType.bug:
        maxHp = 15;
        speed = 90;
        damage = 12;
        attackCooldown = 0.8;
        expValue = 3;
        break;
      case EnemyType.stapler:
        maxHp = 60;
        speed = 40;
        damage = 30;
        attackCooldown = 2.0;
        expValue = 7;
        break;
      case EnemyType.sharp:
        maxHp = 25;
        speed = 130;
        damage = 20;
        attackCooldown = 1.0;
        expValue = 5;
        break;
      case EnemyType.mbtiBoss:
        maxHp = 500;
        speed = 50;
        damage = 40;
        attackCooldown = 1.0;
        expValue = 30;
        break;
      case EnemyType.midBoss:
        maxHp = 300;
        speed = 35;
        damage = 35;
        attackCooldown = 1.5;
        expValue = 25;
        break;
      case EnemyType.finalBoss:
        maxHp = 800;
        speed = 30;
        damage = 50;
        attackCooldown = 1.2;
        expValue = 50;
        break;
    }

    // 약간의 속도 무작위성 추가 (+/- 10%)
    final rand = Random();
    speed += (rand.nextDouble() - 0.5) * (speed * 0.2);

    currentHp = maxHp;
  }

  static double _getRadius(EnemyType type) {
    switch (type) {
      case EnemyType.slime:
        return 12.0;
      case EnemyType.bat:
        return 10.0;
      case EnemyType.charger:
        return 15.0;
      case EnemyType.sniper:
        return 12.0;
      case EnemyType.tanker:
        return 20.0;
      case EnemyType.bug:
        return 12.0;
      case EnemyType.stapler:
        return 18.0;
      case EnemyType.sharp:
        return 14.0;
      case EnemyType.mbtiBoss:
        return 24.0;
      case EnemyType.midBoss:
        return 30.0;
      case EnemyType.finalBoss:
        return 40.0;
    }
  }

  void _registerBoss(EnemyType type) {
    if (type == EnemyType.midBoss) {
      game.gameState.setBoss('중간보스: 대리님');
    } else if (type == EnemyType.finalBoss) {
      game.gameState.setBoss('최종보스: 꼰대 이사님');
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

    // 타입별 AI 행동
    switch (type) {
      case EnemyType.slime:
        // 직선 추적
        _chasePlayer(player, dt);
        break;
      case EnemyType.bat:
        // 빠른 추적 + 약간 지그재그
        _chaseBatStyle(player, dt);
        break;
      case EnemyType.charger:
        // 한 방향으로 돌진 후 자동 자폭 (피할 수 있음)
        _chargerRushAttack(player, dt, distToPlayer);
        break;
      case EnemyType.sniper:
        // 일정 거리 유지하며 원거리 공격
        _sniperBehavior(player, dt, distToPlayer);
        break;
      case EnemyType.tanker:
        // 플레이어에게 무조건 직진
        _chasePlayer(player, dt);
        break;
      case EnemyType.bug:
        // 박쥐처럼 약간 지그재그 추적
        _chaseBatStyle(player, dt);
        break;
      case EnemyType.stapler:
        // 돌격병처럼 접근 후 돌격
        _chargeAttack(player, dt, distToPlayer);
        break;
      case EnemyType.sharp:
        // 호전적으로 매우 빠른 돌격
        _chargeAttack(player, dt, distToPlayer);
        break;
      case EnemyType.mbtiBoss:
        // MBTI 보스: 자체 update에서 공격 처리, 여기선 추적만
        _chasePlayer(player, dt);
        break;
      case EnemyType.midBoss:
      case EnemyType.finalBoss:
        // 보스: 추적 + 특수 공격
        _chasePlayer(player, dt);
        _bossAttack(player, dt, distToPlayer);
        break;
    }

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
    if (player != null && !player.isRemoved) {
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

  /// 기본 추적: 플레이어 방향으로 이동
  void _chasePlayer(Player player, double dt) {
    final direction = (player.position - position);
    if (direction.length > 1) {
      position.add(direction.normalized() * speed * dt);
    }
  }

  /// 박쥐: 빠른 추적 + 약간의 흔들림
  void _chaseBatStyle(Player player, double dt) {
    final direction = (player.position - position);
    if (direction.length > 1) {
      // 사인파로 약간 흔들림 추가
      final wobble = sin(position.x * 0.05 + position.y * 0.05) * 20;
      final perpendicular =
          Vector2(-direction.y, direction.x).normalized() * wobble;
      position.add((direction.normalized() * speed + perpendicular) * dt);
    }
  }

  /// Charger 전용: 접근 → 방향 고정 돌진 → 자동 자폭 (피할 수 있음)
  void _chargerRushAttack(Player player, double dt, double distance) {
    if (player.isRemoved && _chargePhase == 0) return;

    switch (_chargePhase) {
      case 0: // 접근 단계: 천천히 플레이어에게 접근
        final direction = (player.position - position);
        if (direction.length <= 1) return;

        if (distance < 200) {
          // 범위 안에 들어오면 방향 고정 후 돌진 시작
          _chargeDirection = direction.normalized();
          _chargePhase = 1;
          _chargeTimer = 0;
        } else {
          // 천천히 접근
          position.add(direction.normalized() * speed * 0.5 * dt);
        }
        break;

      case 1: // 돌진 단계: 고정된 방향으로 빠르게 직진
        _chargeTimer += dt;
        final dir = _chargeDirection!;
        position.add(dir * speed * 2.5 * dt);

        // 돌진 중 플레이어와 충돌 체크 (접촉 데미지는 onCollision에서 처리)
        // 일정 시간 후 자동 자폭
        if (_chargeTimer >= _chargeMaxDuration) {
          _chargePhase = 2;
          _selfDestruct();
        }
        break;

      case 2: // 자폭 완료 상태 (이미 처리됨)
        break;
    }
  }

  /// 자동 자폭: 폭발 이펙트 + 소멸 (보상 지급)
  void _selfDestruct() {
    // 폭발 이펙트 (💥)
    final explosion = TextComponent(
      text: '💥',
      position: position.clone(),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(fontSize: 64)),
      priority: 10,
    );
    explosion.add(
      TimerComponent(
        period: 0.3,
        removeOnFinish: true,
        onTick: () => explosion.removeFromParent(),
      ),
    );
    game.world.add(explosion);

    // 자폭 시에도 보상 지급 (die() 호출)
    die();
  }

  /// 돌격병(stapler, sharp): 가까우면 빠르게 돌격 후 폭발 (자폭)
  void _chargeAttack(Player player, double dt, double distance) {
    if (player.isRemoved) return;

    // 자폭 거리 도달 시
    if (distance < 40 && currentHp > 0) {
      player.takeDamage(damage * 1.5); // 자폭 데미지

      // 폭발 이펙트 (💥)
      final explosion = TextComponent(
        text: '💥',
        position: position.clone(),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: const TextStyle(fontSize: 64)),
        priority: 10,
      );
      explosion.add(
        TimerComponent(
          period: 0.3,
          removeOnFinish: true,
          onTick: () => explosion.removeFromParent(),
        ),
      );
      game.world.add(explosion);

      // 자폭은 보상/아이템 드랍 없이 바로 소멸
      game.onEnemyKilled(this);
      removeFromParent();
      return;
    }

    final direction = (player.position - position);
    if (direction.length <= 1) return;

    if (distance < 200) {
      // 돌격! 속도 1.8배
      position.add(direction.normalized() * speed * 1.8 * dt);
    } else {
      // 천천히 접근
      position.add(direction.normalized() * speed * 0.5 * dt);
    }
  }

  /// 저격수: 거리 유지하며 원거리 공격
  void _sniperBehavior(Player player, double dt, double distance) {
    final direction = (player.position - position);
    if (direction.length <= 1) return;

    if (distance < 150) {
      // 너무 가까우면 뒤로 도주
      position.add(direction.normalized() * -speed * dt);
    } else if (distance > 250) {
      // 너무 멀면 접근
      position.add(direction.normalized() * speed * dt);
    }

    // 원거리 공격 (쿨다운 기반)
    if (_attackTimer >= attackCooldown && distance < 300) {
      _attackTimer = 0;
      _shootAtPlayer(player);
    }
  }

  /// 저격수 원거리 공격 - 투사체 발사 (웨이브 10 미만: 2연발, 이상: 5연발)
  void _shootAtPlayer(Player player) {
    if (player.isRemoved) return;

    int shotCount = 0;
    final int currentWave = game.gameState.currentWave;
    final int maxShots = currentWave >= 10 ? 5 : 2;
    const double burstInterval = 0.15; // 0.15초 간격 연속 발사

    void fireBullet() {
      if (isRemoved || player.isRemoved) return;

      final direction = (player.position - position).normalized();
      final bullet = Projectile(
        position: position.clone(),
        direction: direction,
        speed: 175, // 기존 250에서 30% 감소
        damage: damage,
        color: const Color(0xFFFF1744),
        radius: 4,
      );
      // 적 투사체임을 표시 (콜라이더에서 플레이어만 때리도록)
      bullet.add(TagComponent('enemy_projectile'));
      game.world.add(bullet);

      shotCount++;
      if (shotCount < maxShots) {
        add(
          TimerComponent(
            period: burstInterval,
            removeOnFinish: true,
            onTick: fireBullet,
          ),
        );
      }
    }

    // 첫 발사 시작
    fireBullet();
  }

  /// 보스 특수 공격 패턴 - 무작위 탄막 생성
  void _bossAttack(Player player, double dt, double distance) {
    _attackTimer += dt;
    if (_attackTimer >= attackCooldown) {
      _attackTimer = 0;
      FlameAudio.play('sfx_boss_attack.ogg', volume: 0.7);

      final rand = Random();
      final pattern = rand.nextInt(3);
      final isFinal = type == EnemyType.finalBoss;

      if (pattern == 0) {
        // 패턴 1: 원형 탄막
        final numBullets = isFinal ? 16 : 12;
        for (int i = 0; i < numBullets; i++) {
          final angle = i * 3.14159 * 2 / numBullets;
          final dir = Vector2(cos(angle), sin(angle));
          _fireBossProjectile(dir, 120, damage * 0.5, '🔥', 6);
        }
      } else if (pattern == 1) {
        // 패턴 2: 샷건 (5갈래 탄막)
        final pDir = (player.position - position).normalized();
        final baseAngle = atan2(pDir.y, pDir.x);
        final spread = isFinal ? 3 : 2;
        for (int i = -spread; i <= spread; i++) {
          final angle = baseAngle + (i * 0.2);
          final dir = Vector2(cos(angle), sin(angle));
          _fireBossProjectile(dir, 180, damage * 0.8, '🗡️', 8);
        }
      } else {
        // 패턴 3: 느리고 거대한 맹독탄/폭탄
        final pDir = (player.position - position).normalized();
        _fireBossProjectile(pDir, 60, damage * 2.0, isFinal ? '☠️' : '💣', 20);
      }
    }
  }

  void _fireBossProjectile(
    Vector2 dir,
    double pSpeed,
    double pDamage,
    String emoji,
    double radius,
  ) {
    final bullet = Projectile(
      position: position.clone(),
      direction: dir,
      speed: pSpeed,
      damage: pDamage,
      color: Colors.transparent,
      emoji: emoji,
      radius: radius,
    );
    bullet.add(TagComponent('enemy_projectile'));
    game.world.add(bullet);
  }

  /// 데미지 받기
  void takeDamage(double dmg) {
    if (currentHp <= 0) return;

    currentHp -= dmg;
    FlameAudio.play('sfx_enemy_hit.ogg', volume: 0.4);
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
      type == EnemyType.midBoss ||
      type == EnemyType.finalBoss ||
      type == EnemyType.mbtiBoss;

  /// 사망 처리
  void die() {
    FlameAudio.play('sfx_enemy_die.ogg', volume: 0.5);
    
    if (_isBoss) {
      game.gameState.clearBoss();
      // 보스 사망 시 모든 적 투사체 제거
      _clearEnemyProjectiles();
    }

    // 커피콩 보상
    FlameAudio.play('sfx_coin.ogg', volume: 0.4);
    game.gameState.addCoffeeBeans(expValue);

    // 파워업 드랍 시도
    final powerUp = PowerUp.trySpawn(position);
    if (powerUp != null) {
      game.world.add(powerUp);
    }

    game.onEnemyKilled(this);
    removeFromParent();
  }

  /// 보스 사망 시 모든 적 투사체 제거
  void _clearEnemyProjectiles() {
    final projectiles = game.world.children.whereType<Projectile>().toList();
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
