import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../components/enemies/base_enemy.dart';
import '../config/wave_data.dart';
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
      if (entry.key == EnemyType.midBoss || entry.key == EnemyType.finalBoss) {
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
  }

  /// 현재 웨이브의 배치 크기 (조금 덜 몰려나오도록 5부터 시작, 완만한 증가)
  int get _batchSize {
    final base = 5;
    return (base * pow(1.15, _currentWaveIndex)).toInt().clamp(5, 40);
  }

  /// 현재 웨이브의 스폰 간격 (더 천천히 줄어들게)
  double get _effectiveSpawnInterval {
    double interval = 1.0 - (_currentWaveIndex * 0.015);
    return interval.clamp(0.4, 1.0);
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

    // 보스 웨이브에서 적이 10 이하가 되면 보스 스폰
    final isBossWave = (_currentWaveIndex + 1) % 3 == 0;
    if (isBossWave && !_bossSpawned && game.gameState.enemiesRemaining <= 10) {
      _spawnBoss();
    }

    // 개별 스폰 타이머 (배치를 잘게 쪼개어 연속 스폰)
    final singleSpawnInterval =
        _effectiveSpawnInterval / _batchSize.clamp(1, 100);
    _spawnTimer += dt;
    if (_spawnTimer >= singleSpawnInterval && _spawnQueue.isNotEmpty) {
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
    final isFinalBoss = (_currentWaveIndex + 1) == 30;
    final bossType = isFinalBoss ? EnemyType.finalBoss : EnemyType.midBoss;
    final bossCount = _currentWave!.enemies[bossType] ?? 1;
    for (int i = 0; i < bossCount; i++) {
      final spawnPos = _getSpawnPosition();
      final boss = BaseEnemy(type: bossType, position: spawnPos);
      game.world.add(boss);
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

    textComp.add(
      TimerComponent(
        period: 2.5,
        removeOnFinish: true,
        onTick: () => textComp.removeFromParent(),
      ),
    );
    game.world.add(textComp);
  }

  /// 현재 웨이브 클리어
  void _onWaveCleared() {
    if (!_waveActive) return; // 중복 방지
    _waveActive = false;
    game.autoSave(); // 웨이브가 끝날 때 자동 저장

    // 보스 웨이브 클리어 시 (3의 배수) → 강화 선택 화면
    final clearedWaveNumber = _currentWaveIndex + 1;
    if (clearedWaveNumber % 3 == 0) {
      game.pauseEngine();
      game.overlays.add('Upgrade');
      // 강화 오버레이에서 '계속하기' 누르면 resumeEngine + 다음 웨이브
      _waitingForNextWave = true;
      _waveTransitionTimer = _waveTransitionDelay;

      // 강화가 끝난 다음 웨이브 시작 시 강해짐 알람 출력
      Future.delayed(const Duration(milliseconds: 500), () {
        if (game.isAttached) {
          _showBossDifficultyText();
        }
      });
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
