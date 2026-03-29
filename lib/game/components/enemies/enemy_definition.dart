import '../../config/wave_data.dart';

enum EnemyBehaviorKind {
  chase,
  bat,
  chargerRush,
  sniper,
  charge,
  bossChase,
  mbtiBoss,
}

class EnemyDefinition {
  final EnemyType type;
  final double maxHp;
  final double speed;
  final double damage;
  final double attackCooldown;
  final int expValue;
  final double radius;
  final String spritePath;
  final EnemyBehaviorKind behavior;
  final String? bossTitle;

  const EnemyDefinition({
    required this.type,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.attackCooldown,
    required this.expValue,
    required this.radius,
    required this.spritePath,
    required this.behavior,
    this.bossTitle,
  });
}

const Map<EnemyType, EnemyDefinition> enemyDefinitions = {
  EnemyType.slime: EnemyDefinition(
    type: EnemyType.slime,
    maxHp: 30,
    speed: 80,
    damage: 10,
    attackCooldown: 1.0,
    expValue: 2,
    radius: 12,
    spritePath: 'enemies/enemy_0.png',
    behavior: EnemyBehaviorKind.chase,
  ),
  EnemyType.bat: EnemyDefinition(
    type: EnemyType.bat,
    maxHp: 20,
    speed: 80,
    damage: 15,
    attackCooldown: 0.8,
    expValue: 4,
    radius: 10,
    spritePath: 'enemies/enemy_1.png',
    behavior: EnemyBehaviorKind.bat,
  ),
  EnemyType.charger: EnemyDefinition(
    type: EnemyType.charger,
    maxHp: 50,
    speed: 120,
    damage: 25,
    attackCooldown: 2.0,
    expValue: 6,
    radius: 15,
    spritePath: 'enemies/enemy_2.png',
    behavior: EnemyBehaviorKind.chargerRush,
  ),
  EnemyType.sniper: EnemyDefinition(
    type: EnemyType.sniper,
    maxHp: 25,
    speed: 30,
    damage: 35,
    attackCooldown: 3.0,
    expValue: 7,
    radius: 12,
    spritePath: 'enemies/enemy_3.png',
    behavior: EnemyBehaviorKind.sniper,
  ),
  EnemyType.tanker: EnemyDefinition(
    type: EnemyType.tanker,
    maxHp: 100,
    speed: 25,
    damage: 10,
    attackCooldown: 2.0,
    expValue: 8,
    radius: 20,
    spritePath: 'enemies/boss_2_proc.png',
    behavior: EnemyBehaviorKind.chase,
  ),
  EnemyType.bug: EnemyDefinition(
    type: EnemyType.bug,
    maxHp: 15,
    speed: 90,
    damage: 12,
    attackCooldown: 0.8,
    expValue: 3,
    radius: 12,
    spritePath: 'enemies/enemy_bug.png',
    behavior: EnemyBehaviorKind.bat,
  ),
  EnemyType.stapler: EnemyDefinition(
    type: EnemyType.stapler,
    maxHp: 60,
    speed: 40,
    damage: 30,
    attackCooldown: 2.0,
    expValue: 7,
    radius: 18,
    spritePath: 'enemies/enemy_stapler.png',
    behavior: EnemyBehaviorKind.charge,
  ),
  EnemyType.sharp: EnemyDefinition(
    type: EnemyType.sharp,
    maxHp: 25,
    speed: 130,
    damage: 20,
    attackCooldown: 1.0,
    expValue: 5,
    radius: 14,
    spritePath: 'enemies/enemy_sharp.png',
    behavior: EnemyBehaviorKind.charge,
  ),
  EnemyType.mbtiBoss: EnemyDefinition(
    type: EnemyType.mbtiBoss,
    maxHp: 500,
    speed: 50,
    damage: 40,
    attackCooldown: 1.0,
    expValue: 30,
    radius: 24,
    spritePath: 'enemies/enemy_0.png',
    behavior: EnemyBehaviorKind.mbtiBoss,
  ),
  EnemyType.midBoss: EnemyDefinition(
    type: EnemyType.midBoss,
    maxHp: 300,
    speed: 35,
    damage: 35,
    attackCooldown: 1.5,
    expValue: 25,
    radius: 30,
    spritePath: 'enemies/boss_1_proc.png',
    behavior: EnemyBehaviorKind.bossChase,
    bossTitle: '중간보스: 대리님',
  ),
  EnemyType.finalBoss: EnemyDefinition(
    type: EnemyType.finalBoss,
    maxHp: 800,
    speed: 30,
    damage: 50,
    attackCooldown: 1.2,
    expValue: 50,
    radius: 40,
    spritePath: 'enemies/boss_3_proc.png',
    behavior: EnemyBehaviorKind.bossChase,
    bossTitle: '최종보스: 사장님',
  ),
};

EnemyDefinition enemyDefinitionFor(EnemyType type) {
  final definition = enemyDefinitions[type];
  if (definition == null) {
    throw StateError('Missing enemy definition for $type');
  }
  return definition;
}
