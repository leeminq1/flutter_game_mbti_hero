import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../components/enemies/base_enemy.dart';
import '../components/enemies/mbti_boss_enemy.dart';
import '../config/wave_data.dart';
import '../config/character_data.dart';
import '../mbti_game.dart';

/// 웨이브 기반 적 스폰 매니저
class EnemySpawner extends Component with HasGameReference<MbtiGame> {
  final Random _random = Random();

  // 현재 웨이브 설정
  WaveConfig? _currentWave;
  int _currentWaveIndex = 0;

  // 스폰 관리
  double _spawnTimer = 0;
  final List<_SpawnEntry> _spawnQueue = [];
  int _totalEnemiesInWave = 0;

  // 웨이브 상태
  bool _waveActive = false;
  bool _allWavesCleared = false;

  // 웨이브 전환 딜레이
  double _waveTransitionTimer = 0;
  static const double _waveTransitionDelay = 2.0;
  bool _waitingForNextWave = false;

  // 보스 스폰 관리
  bool _bossSpawned = false;

  /// 웨이브 시작
  void startWave(int waveIndex) {
    if (waveIndex >= WaveData.waves.length) {
      _allWavesCleared = true;
      game.onAllWavesCleared();
      return;
    }

    _currentWaveIndex = waveIndex;
    _currentWave = WaveData.waves[waveIndex];
    _spawnTimer = 0;
    _waveActive = true;
    _waitingForNextWave = false;
    _bossSpawned = false;

    // 스폰 큐 구성 (보스 제외)
    _spawnQueue.clear();
    _totalEnemiesInWave = 0;
    for (final entry in _currentWave!.enemies.entries) {
      if (entry.key == EnemyType.midBoss ||
          entry.key == EnemyType.finalBoss ||
          entry.key == EnemyType.mbtiBoss) {
        // 보스는 큐에 넣지 않음 — 나중에 remaining <= 10일 때 스폰
        _totalEnemiesInWave += entry.value;
        continue;
      }
      for (int i = 0; i < entry.value; i++) {
        _spawnQueue.add(_SpawnEntry(type: entry.key));
        _totalEnemiesInWave++;
      }
    }
    // 랜덤 섞기
    _spawnQueue.shuffle(_random);

    // GameState 업데이트
    game.gameState.setWave(_currentWaveIndex + 1);
    game.gameState.setEnemiesRemaining(_totalEnemiesInWave);
    game.debugLogState('start_wave_${_currentWaveIndex + 1}');
    debugPrint(
      '[WAVE ${_currentWaveIndex + 1}] Started: total=$_totalEnemiesInWave, queue=${_spawnQueue.length}, isMbti=${(_currentWaveIndex + 1) % 5 == 0}, bosses=${_currentWave!.enemies[EnemyType.mbtiBoss] ?? 0}',
    );
    if ((_currentWaveIndex + 1) >= 5) {
      debugPrint(
        '[WAVE PERF] wave=${_currentWaveIndex + 1} batch=$_batchSize '
        'spawnInterval=${_effectiveSpawnInterval.toStringAsFixed(2)} '
        'enemyCap=${game.maxActiveEnemies} queue=${_spawnQueue.length}',
      );
    }
  }

  /// 현재 웨이브의 배치 크기 (조금 덜 몰려나오도록 5부터 시작, 완만한 증가)
  int get _batchSize {
    final base = _currentWaveIndex >= 4 ? 4 : 5;
    final growth = _currentWaveIndex >= 4 ? 1.05 : 1.10;
    return (base * pow(growth, _currentWaveIndex)).toInt().clamp(4, 16);
  }

  /// 현재 웨이브의 스폰 간격 (더 천천히 줄어들게)
  double get _effectiveSpawnInterval {
    double interval = 1.02 - (_currentWaveIndex * 0.010);
    if (_currentWaveIndex >= 4) {
      interval += 0.16;
    }
    return interval.clamp(0.68, 1.18);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_allWavesCleared || !_waveActive) {
      // 다음 웨이브 대기
      if (_waitingForNextWave) {
        _waveTransitionTimer -= dt;
        if (_waveTransitionTimer <= 0) {
          startWave(_currentWaveIndex + 1);
        }
      }
      return;
    }

    if (_currentWave == null) return;

    // 보스 웨이브에서 적이 10 이하가 되면 보스 스폰 (중간보스 또는 MBTI 보스)
    final isBossWave = (_currentWaveIndex + 1) % 3 == 0;
    final isMbtiBossWave =
        (_currentWaveIndex + 1) % 5 == 0 && (_currentWaveIndex + 1) != 30;
    final isFinalBossWave = (_currentWaveIndex + 1) == 30;

    if ((isBossWave || isMbtiBossWave || isFinalBossWave) &&
        !_bossSpawned &&
        game.gameState.enemiesRemaining <= 10) {
      debugPrint(
        '[WAVE ${_currentWaveIndex + 1}] Boss spawn triggered! remaining=${game.gameState.enemiesRemaining}, isMbti=$isMbtiBossWave, isMid=$isBossWave',
      );
      debugPrint(
        '[WAVE PERF] boss wave=${_currentWaveIndex + 1} '
        'projectiles=${game.activeProjectiles.length} '
        'world=${game.world.children.length}',
      );
      _spawnBoss();
    }

    // 개별 스폰 타이머 (배치를 잘게 쪼개어 연속 스폰)
    final bossPressureThrottle = _bossSpawned && isMbtiBossWave
        ? 2.4
        : _bossSpawned && isBossWave
        ? 1.4
        : 1.0;
    final maxEnemiesWhileBossActive = _bossSpawned && isMbtiBossWave
        ? 14
        : _bossSpawned && isBossWave
        ? 18
        : game.maxActiveEnemies;
    final projectileBudgetWhileBossActive = _bossSpawned && isMbtiBossWave
        ? 12
        : _bossSpawned && isBossWave
        ? 16
        : 20;
    final singleSpawnInterval =
        (_effectiveSpawnInterval * bossPressureThrottle) /
        _batchSize.clamp(1, 100);
    _spawnTimer += dt;
    if (_spawnTimer >= singleSpawnInterval &&
        _spawnQueue.isNotEmpty &&
        game.activeEnemies.length < maxEnemiesWhileBossActive &&
        game.activeProjectiles.length < projectileBudgetWhileBossActive) {
      _spawnTimer = 0;
      _spawnEnemy(_spawnQueue.removeAt(0));
    }
  }

  /// 적 스폰
  void _spawnEnemy(_SpawnEntry entry) {
    final spawnPos = _getSpawnPosition();
    final enemy = BaseEnemy(type: entry.type, position: spawnPos);
    game.world.add(enemy);
  }

  /// 보스 스폰 (적이 10 이하일 때)
  void _spawnBoss() {
    _bossSpawned = true;
    game.playThrottledSfx(
      'sfx_boss_warning.ogg',
      volume: 0.8,
      minInterval: 0.4,
    );
    game.debugLogState('boss_spawn');
    
    final isFinalBoss = (_currentWaveIndex + 1) == 30;
    final isMbtiBossWave = (_currentWaveIndex + 1) % 5 == 0 && !isFinalBoss;
    final isMidBossWave = (_currentWaveIndex + 1) % 3 == 0;

    // Spawn MBTI Boss if applicable
    if (isMbtiBossWave || isFinalBoss) {
      final bossCount = _currentWave!.enemies[EnemyType.mbtiBoss] ?? 0;
      for (int i = 0; i < bossCount; i++) {
        final spawnPos = _getSpawnPosition();
        _showBossSpawnMarker(
          spawnPos,
          label: isFinalBoss ? 'FINAL BOSS' : 'MBTI BOSS',
        );

        // 랜덤 MBTI 캐릭터 선택 (0~7)
        final randomCharType = CharacterType.values[_random.nextInt(8)];
        final characterData = MbtiCharacters.getByType(randomCharType);

        final mbtiBoss = MbtiBossEnemy(
          position: spawnPos,
          characterData: characterData,
          playerAttack: game.player.attackPower,
          playerSpeed: game.player.speed,
          playerMaxHp: game.gameState.maxHp,
          waveNumber: _currentWaveIndex + 1,
        );
        game.world.add(mbtiBoss);
        debugPrint(
          '[BOSS] MBTI Boss spawned: ${characterData.name} (${characterData.mbti}) at $spawnPos | playerAtk=${game.player.attackPower}, bossHp=${mbtiBoss.maxHp}, bossDmg=${mbtiBoss.damage}',
        );

        // 보스 등장 경고 텍스트 표시
        final warningText = TextComponent(
          text: '⚠️ MBTI 보스: ${characterData.name} 등장! ⚠️',
          position: game.player.position.clone()..y -= 100,
          anchor: Anchor.center,
          priority: 30,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 10)],
            ),
          ),
        );
        game.addTimedWorldComponent(warningText, lifetime: 3.0);
      }
    }

    // Spawn Mid or Final Boss if applicable
    if (isMidBossWave || isFinalBoss) {
      final bossType = isFinalBoss ? EnemyType.finalBoss : EnemyType.midBoss;
      final bossCount = _currentWave!.enemies[bossType] ?? 0;
      for (int i = 0; i < bossCount; i++) {
        final spawnPos = _getSpawnPosition();
        _showBossSpawnMarker(
          spawnPos,
          label: isFinalBoss ? 'FINAL BOSS' : 'MID BOSS',
        );
        final boss = BaseEnemy(type: bossType, position: spawnPos);
        game.world.add(boss);
      }
    }
  }

  /// 맵 가장자리에서 랜덤 스폰 위치 생성
  Vector2 _getSpawnPosition() {
    final playerPos = game.player.position;
    final mapSize = game.mapSize;

    // 플레이어로부터 최소 200 거리의 맵 가장자리
    final side = _random.nextInt(4); // 0=상, 1=하, 2=좌, 3=우
    double x, y;

    switch (side) {
      case 0: // 상단
        x = _random.nextDouble() * mapSize.x;
        y = max(0, playerPos.y - 400);
        break;
      case 1: // 하단
        x = _random.nextDouble() * mapSize.x;
        y = min(mapSize.y, playerPos.y + 400);
        break;
      case 2: // 좌측
        x = max(0, playerPos.x - 400);
        y = _random.nextDouble() * mapSize.y;
        break;
      default: // 우측
        x = min(mapSize.x, playerPos.x + 400);
        y = _random.nextDouble() * mapSize.y;
        break;
    }

    return Vector2(x.clamp(10, mapSize.x - 10), y.clamp(10, mapSize.y - 10));
  }

  /// 적이 죽었을 때 호출
  void onEnemyKilled() {
    game.gameState.decrementEnemies();
    final remaining = game.gameState.enemiesRemaining;

    if (remaining <= 0 && _spawnQueue.isEmpty) {
      _onWaveCleared();
    }
  }

  /// 보스 난이도 텍스트 알림
  void _showBossDifficultyText() {
    final textComp = TextComponent(
      text: '회사 관리자가 더 강해집니다!!!',
      position: game.mapSize / 2,
      anchor: Anchor.center,
      priority: 30,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 10)],
        ),
      ),
    );

    game.addTimedWorldComponent(textComp, lifetime: 2.5);
  }

  /// 현재 웨이브 클리어
  void _showBossSpawnMarker(Vector2 spawnPos, {required String label}) {
    final marker = CircleComponent(
      radius: 96,
      position: spawnPos,
      anchor: Anchor.center,
      priority: 26,
      paint: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.redAccent.withValues(alpha: 0.75),
    );
    marker.add(
      TextComponent(
        text: label,
        position: Vector2(0, -112),
        anchor: Anchor.center,
        priority: 27,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
      ),
    );
    game.addTimedWorldComponent(marker, lifetime: 1.4);
  }

  void _onWaveCleared() {
    if (!_waveActive) return; // 중복 방지
    _waveActive = false;
    game.playThrottledSfx(
      'sfx_wave_clear.ogg',
      volume: 0.8,
      minInterval: 0.3,
    );
    
    final clearedWaveNumber = _currentWaveIndex + 1;
    game.debugLogState('wave_cleared');
    debugPrint(
      '[WAVE $clearedWaveNumber] cleared: upgradeOverlay=${clearedWaveNumber % 3 == 0 || clearedWaveNumber % 5 == 0} '
      'isMbtiBossWave=${clearedWaveNumber % 5 == 0 && clearedWaveNumber != 30} '
      'isMidBossWave=${clearedWaveNumber % 3 == 0}',
    );
    
    game.autoSave(); // 웨이브가 끝날 때 자동 저장

    // 보스 웨이브 클리어 시 (3의 배수 또는 5의 배수) → 강화 선택 화면
    if (clearedWaveNumber % 3 == 0 || clearedWaveNumber % 5 == 0) {
      game.pauseEngine();
      game.overlays.add('Upgrade');
      // 강화 오버레이에서 '계속하기' 누르면 resumeEngine + 다음 웨이브
      _waitingForNextWave = true;
      _waveTransitionTimer = _waveTransitionDelay;

      // 강화가 끝난 다음 웨이브 시작 시 강해짐 알람 출력
      add(
        TimerComponent(
          period: 0.5,
          removeOnFinish: true,
          onTick: () {
            if (game.isAttached) {
              _showBossDifficultyText();
            }
          },
        ),
      );
    } else {
      _waitingForNextWave = true;
      _waveTransitionTimer = _waveTransitionDelay;
    }
  }

  /// 리셋
  void reset() {
    _currentWaveIndex = 0;
    _currentWave = null;
    _spawnQueue.clear();
    _waveActive = false;
    _allWavesCleared = false;
    _waitingForNextWave = false;
    _bossSpawned = false;
  }
}

class _SpawnEntry {
  final EnemyType type;
  _SpawnEntry({required this.type});
}
