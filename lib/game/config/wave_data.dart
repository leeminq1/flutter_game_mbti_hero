/// 적 종류 열거형
enum EnemyType {
  slime, // 슬라임 (졸려운 인턴)
  bat, // 박쥐 (수다스러운 동료)
  charger, // 돌격병 (급한 이메일)
  sniper, // 저격수 (지적질 상사)
  tanker, // 탱커 (방어적인 팀원)
  midBoss, // 중간보스 (대리님)
  finalBoss, // 최종보스 (꼰대 이사님)
}

/// 웨이브별 적 설정
class WaveConfig {
  final int waveNumber;
  final String title;
  final Map<EnemyType, int> enemies;
  final double spawnInterval;
  final bool hasObstacles;
  final double waveDuration; // 초

  const WaveConfig({
    required this.waveNumber,
    required this.title,
    required this.enemies,
    required this.spawnInterval,
    this.hasObstacles = false,
    this.waveDuration = 45,
  });
}

/// 30단계 웨이브 데이터 동적 생성
class WaveData {
  static final List<WaveConfig> waves = _generateWaves();

  static List<WaveConfig> _generateWaves() {
    final List<WaveConfig> generated = [];

    for (int i = 1; i <= 30; i++) {
      final isBossWave = i % 3 == 0;
      final isFinalBoss = i == 30;

      // 총 적 수: Wave 1=30, Wave 2=40, Wave 3=50 ... (+10씩)
      final totalEnemies = 30 + 10 * (i - 1);

      final enemies = <EnemyType, int>{};

      if (isFinalBoss) {
        // 최종 보스전
        enemies[EnemyType.finalBoss] = 1;
        final mobs = totalEnemies - 1;
        enemies[EnemyType.bat] = (mobs * 0.4).toInt();
        enemies[EnemyType.sniper] = (mobs * 0.3).toInt();
        enemies[EnemyType.charger] = (mobs * 0.3).toInt();
      } else if (isBossWave) {
        // 보스 웨이브
        enemies[EnemyType.midBoss] = 1 + (i ~/ 10);
        final mobs = totalEnemies - enemies[EnemyType.midBoss]!;
        enemies[EnemyType.slime] = (mobs * 0.5).toInt();
        enemies[EnemyType.bat] = (mobs * 0.3).toInt();
        if (i > 5) {
          enemies[EnemyType.charger] = (mobs * 0.2).toInt();
        } else {
          enemies[EnemyType.slime] = enemies[EnemyType.slime]! + (mobs * 0.2).toInt();
        }
      } else {
        // 일반 웨이브: 1라운드부터 다양하게 생성
        int slimeCount = (totalEnemies * 0.4).toInt();
        int batCount = (totalEnemies * 0.3).toInt();
        int chargerCount = i >= 3 ? (totalEnemies * 0.2).toInt() : 0;
        int sniperCount = totalEnemies - (slimeCount + batCount + chargerCount);

        enemies[EnemyType.slime] = slimeCount;
        enemies[EnemyType.bat] = batCount;
        enemies[EnemyType.charger] = chargerCount;
        enemies[EnemyType.sniper] = sniperCount;
      }

      // 스폰 간격 (최소 0.15초)
      double spawnInterval = 0.6 - (i * 0.015);
      if (spawnInterval < 0.15) spawnInterval = 0.15;

      // 지속 시간 (보스전은 길게)
      double duration = isBossWave ? 60.0 + (i * 2) : 40.0 + i;

      generated.add(
        WaveConfig(
          waveNumber: i,
          title: isFinalBoss
              ? '최종 보스: 꼰대 이사님'
              : isBossWave
              ? '웨이브 $i (징계 위원회)'
              : '웨이브 $i (야근 러시)',
          enemies: enemies,
          spawnInterval: spawnInterval,
          hasObstacles: i > 5 && !isBossWave,
          waveDuration: duration,
        ),
      );
    }

    return generated;
  }
}
