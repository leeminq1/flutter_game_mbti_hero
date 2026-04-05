/// 적 종류 열거형
enum EnemyType {
  slime, // 슬라임 (졸려운 인턴)
  bat, // 박쥐 (수다스러운 동료)
  charger, // 돌격병 (급한 이메일)
  sniper, // 저격수 (지적질 상사)
  tanker, // 탱커 (방어적인 팀원)
  bug, // 벌레 (사무실 바퀴벌레)
  stapler, // 호치키스 (서류 빌런)
  sharp, // 압정 (날카로운 조각)
  mbtiBoss, // MBTI 보스 (5, 10, 15...)
  midBoss, // 중간보스 (대리님 - 3, 6, 9...)
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
      final isMbtiBossWave = i % 5 == 0 && i != 30; // 30 is final boss
      final isFinalBoss = i == 30;

      // 총 적 수: Wave 1=30, Wave 2=36, Wave 3=42 ... (+6씩)
      var totalEnemies = 30 + 6 * (i - 1);
      if (i >= 5) {
        totalEnemies -= ((i - 4) * 2).clamp(0, 12);
      }
      if (i >= 10 && i < 20) {
        totalEnemies += (2 + ((i - 10) ~/ 3)).clamp(2, 5);
      }
      if (i >= 21) {
        totalEnemies -= (6 + (i - 21)).clamp(6, 12);
      }
      if (isMbtiBossWave) {
        totalEnemies -= 6;
      } else if (isBossWave) {
        totalEnemies -= 4;
      }
      if (totalEnemies < 24) {
        totalEnemies = 24;
      }

      final enemies = <EnemyType, int>{};

      if (isFinalBoss) {
        // 최종 보스전 + 추가 MBTI 보스
        enemies[EnemyType.finalBoss] = 1;
        enemies[EnemyType.mbtiBoss] = 2; // 최종전에는 MBTI 보스 2명 동시 스폰!
        final mobs = totalEnemies - 3;
        enemies[EnemyType.bat] = (mobs * 0.2).toInt();
        enemies[EnemyType.sharp] = (mobs * 0.2).toInt();
        enemies[EnemyType.bug] = (mobs * 0.2).toInt();
        enemies[EnemyType.stapler] = (mobs * 0.2).toInt();
        enemies[EnemyType.charger] = (mobs * 0.2).toInt();
      } else {
        // 보스 배정
        if (isBossWave) {
          enemies[EnemyType.midBoss] = 1 + (i ~/ 10);
        }
        if (isMbtiBossWave) {
          enemies[EnemyType.mbtiBoss] = 1 + (i ~/ 15);
        }

        final bossCount =
            (enemies[EnemyType.midBoss] ?? 0) +
            (enemies[EnemyType.mbtiBoss] ?? 0);
        final mobs = totalEnemies - bossCount;

        // 일반 몹 스폰 분배
        if (i < 3) {
          enemies[EnemyType.slime] = (mobs * 0.6).toInt();
          enemies[EnemyType.bat] = (mobs * 0.4).toInt();
        } else if (i < 7) {
          enemies[EnemyType.slime] = (mobs * 0.3).toInt();
          enemies[EnemyType.bat] = (mobs * 0.2).toInt();
          enemies[EnemyType.bug] = (mobs * 0.2).toInt();
          enemies[EnemyType.charger] = (mobs * 0.15)
              .toInt(); // 0.3→0.15 (50% 감소)
        } else if (i < 10) {
          // 강한 적 비율 완화 (sniper/tanker/stapler/sharp 줄임)
          enemies[EnemyType.slime] = (mobs * 0.15).toInt();
          enemies[EnemyType.bat] = (mobs * 0.15).toInt();
          enemies[EnemyType.charger] = (mobs * 0.075)
              .toInt(); // 0.15→0.075 (50% 감소)
          enemies[EnemyType.sniper] = (mobs * 0.10).toInt();
          enemies[EnemyType.tanker] = (mobs * 0.08).toInt();
          enemies[EnemyType.bug] = (mobs * 0.15).toInt();
          enemies[EnemyType.stapler] = (mobs * 0.08).toInt();
          enemies[EnemyType.sharp] = (mobs * 0.10).toInt();
        } else if (i < 20) {
          enemies[EnemyType.slime] = (mobs * 0.13).toInt();
          enemies[EnemyType.bat] = (mobs * 0.12).toInt();
          enemies[EnemyType.bug] = (mobs * 0.13).toInt();
          enemies[EnemyType.charger] = (mobs * 0.10).toInt();
          enemies[EnemyType.sniper] = (mobs * 0.12).toInt();
          enemies[EnemyType.tanker] = (mobs * 0.10).toInt();
          enemies[EnemyType.stapler] = (mobs * 0.10).toInt();
          enemies[EnemyType.sharp] = (mobs * 0.11).toInt();
        } else {
          enemies[EnemyType.slime] = (mobs * 0.10).toInt();
          enemies[EnemyType.bat] = (mobs * 0.10).toInt();
          enemies[EnemyType.bug] = (mobs * 0.10).toInt();
          enemies[EnemyType.charger] = (mobs * 0.11).toInt();
          enemies[EnemyType.sniper] = (mobs * 0.13).toInt();
          enemies[EnemyType.tanker] = (mobs * 0.10).toInt();
          enemies[EnemyType.stapler] = (mobs * 0.11).toInt();
          enemies[EnemyType.sharp] = (mobs * 0.13).toInt();
        }
      }

      // 스폰 간격 완화 (최소 0.25초, 감소폭 줄임)
      double spawnInterval = 0.6 - (i * 0.01);
      if (spawnInterval < 0.25) spawnInterval = 0.25;

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
