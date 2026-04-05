import 'package:flutter/foundation.dart';
import '../config/character_data.dart';
import '../config/mbti_compatibility.dart';

/// 게임 상태 관리 (Flutter UI와 Flame 간 데이터 연동)
class GameState extends ChangeNotifier {
  static const int _cooldownNotifyBuckets = 180;

  // --- 글로벌 메타 데이터 ---
  int _coffeeBeans = 0;
  int _totalCoffeeEarned = 0; // 총 획득 커피콩 (소비 무관)
  int _hpLevel = 0;
  int _attackLevel = 0;
  int _speedLevel = 0;
  Set<CharacterType> _unlockedCharacters = Set<CharacterType>.from(
    CharacterType.values,
  );

  int get coffeeBeans => _coffeeBeans;
  int get totalCoffeeEarned => _totalCoffeeEarned;
  int get hpLevel => _hpLevel;
  int get attackLevel => _attackLevel;
  int get speedLevel => _speedLevel;
  Set<CharacterType> get unlockedCharacters => _unlockedCharacters;

  void loadGlobalData(
    int beans,
    int hp,
    int atk,
    int spd,
    Set<CharacterType> unlocked,
  ) {
    _coffeeBeans = beans;
    _hpLevel = hp;
    _attackLevel = atk;
    _speedLevel = spd;
    _unlockedCharacters = {
      ...CharacterType.values,
      ...unlocked,
    };
    notifyListeners();
  }

  void addCoffeeBeans(int amount) {
    _coffeeBeans += amount;
    _totalCoffeeEarned += amount; // 총 획득량 누적
    notifyListeners();
  }

  bool spendCoffeeBeans(int amount) {
    if (_coffeeBeans >= amount) {
      _coffeeBeans -= amount;
      notifyListeners();
      return true;
    }
    return false;
  }

  void unlockCharacter(CharacterType type) {
    _unlockedCharacters.add(type);
    notifyListeners();
  }

  void upgradeHp() {
    _hpLevel++;
    notifyListeners();
  }

  void upgradeAttack() {
    _attackLevel++;
    notifyListeners();
  }

  void upgradeSpeed() {
    _speedLevel++;
    notifyListeners();
  }

  // --- 캐릭터 ---
  CharacterType _selectedCharacter = CharacterType.estj;
  CharacterType get selectedCharacter => _selectedCharacter;

  CharacterData get characterData =>
      MbtiCharacters.getByType(_selectedCharacter);

  void selectCharacter(CharacterType type) {
    _selectedCharacter = type;
    notifyListeners();
  }

  // --- 동료 ---
  CharacterType _selectedCompanion = CharacterType.isfj;
  CharacterType get selectedCompanion => _selectedCompanion;
  CharacterData get companionData =>
      MbtiCharacters.getByType(_selectedCompanion);
  CompatibilityGrade get companionGrade =>
      MbtiCompatibility.getGrade(_selectedCharacter, _selectedCompanion);
  double get companionPowerMultiplier =>
      MbtiCompatibility.getPowerMultiplier(companionGrade);

  void selectCompanion(CharacterType type) {
    _selectedCompanion = type;
    notifyListeners();
  }

  // --- 동료 호출 쿨타임 ---
  double _assistCooldownMax = 30;
  double _assistCooldownCurrent = 0;
  int _assistCooldownBucket = 0;
  int _assistTicketCount = 0;

  double get assistCooldownMax => _assistCooldownMax;
  double get assistCooldownCurrent => _assistCooldownCurrent;
  int get assistTicketCount => _assistTicketCount;
  bool get hasAssistTicket => _assistTicketCount > 0;
  bool get isAssistReady => _assistCooldownCurrent <= 0 || hasAssistTicket;
  double get assistCooldownRatio => _assistCooldownMax > 0
      ? (_assistCooldownCurrent / _assistCooldownMax).clamp(0.0, 1.0)
      : 0;

  void initAssistCooldown() {
    final cdMultiplier = MbtiCompatibility.getCooldownMultiplier(
      companionGrade,
    );
    _assistCooldownMax = 30 * cdMultiplier;
    _assistCooldownCurrent = 0;
    _assistCooldownBucket = _cooldownBucket(
      _assistCooldownCurrent,
      _assistCooldownMax,
    );
    notifyListeners();
  }

  void useAssist() {
    _assistCooldownCurrent = _assistCooldownMax;
    _assistCooldownBucket = _cooldownBucket(
      _assistCooldownCurrent,
      _assistCooldownMax,
    );
    notifyListeners();
  }

  bool consumeAssistTicket() {
    if (_assistTicketCount <= 0) {
      return false;
    }
    _assistTicketCount--;
    notifyListeners();
    return true;
  }

  void addAssistTicket([int count = 1]) {
    _assistTicketCount += count;
    notifyListeners();
  }

  void tickAssistCooldown(double dt) {
    if (_assistCooldownCurrent > 0) {
      _assistCooldownCurrent = (_assistCooldownCurrent - dt).clamp(
        0,
        _assistCooldownMax,
      );
      final nextBucket = _cooldownBucket(
        _assistCooldownCurrent,
        _assistCooldownMax,
      );
      if (nextBucket != _assistCooldownBucket) {
        _assistCooldownBucket = nextBucket;
        notifyListeners();
      }
    }
  }

  void syncAssistCooldown(double current) {
    _assistCooldownCurrent = current.clamp(0, _assistCooldownMax);
    _assistCooldownBucket = _cooldownBucket(
      _assistCooldownCurrent,
      _assistCooldownMax,
    );
    notifyListeners();
  }

  void syncAssistTickets(int count) {
    _assistTicketCount = count.clamp(0, 99);
    notifyListeners();
  }

  // --- HP ---
  double _maxHp = 200;
  double _currentHp = 200;

  double get maxHp => _maxHp;
  double get currentHp => _currentHp;
  double get hpRatio => _maxHp > 0 ? (_currentHp / _maxHp).clamp(0.0, 1.0) : 0;
  bool get isDead => _currentHp <= 0;

  void initHp(double max) {
    _maxHp = max;
    _currentHp = max;
    notifyListeners();
  }

  void syncHp({required double current, required double max}) {
    _maxHp = max;
    _currentHp = current.clamp(0, max);
    notifyListeners();
  }

  void takeDamage(double damage) {
    _currentHp = (_currentHp - damage).clamp(0, _maxHp);
    notifyListeners();
  }

  void heal(double amount) {
    _currentHp = (_currentHp + amount).clamp(0, _maxHp);
    notifyListeners();
  }

  // --- 웨이브 ---
  int _currentWave = 1;
  final int _totalWaves = 30;
  int _enemiesRemaining = 0;

  int get currentWave => _currentWave;
  int get totalWaves => _totalWaves;
  int get enemiesRemaining => _enemiesRemaining;

  void setWave(int wave) {
    _currentWave = wave;
    notifyListeners();
  }

  void setEnemiesRemaining(int count) {
    _enemiesRemaining = count;
    notifyListeners();
  }

  void decrementEnemies() {
    _enemiesRemaining = (_enemiesRemaining - 1).clamp(0, 9999);
    notifyListeners();
  }

  // --- 필살기 쿨타임 ---
  double _ultCooldownMax = 25;
  double _ultCooldownCurrent = 0;
  int _ultCooldownBucket = 0;
  int _ultTicketCount = 0;

  double get ultCooldownMax => _ultCooldownMax;
  double get ultCooldownCurrent => _ultCooldownCurrent;
  int get ultTicketCount => _ultTicketCount;
  bool get hasUltTicket => _ultTicketCount > 0;
  bool get isUltReady => _ultCooldownCurrent <= 0 || hasUltTicket;
  double get ultCooldownRatio => _ultCooldownMax > 0
      ? (_ultCooldownCurrent / _ultCooldownMax).clamp(0.0, 1.0)
      : 0;

  void initUltCooldown(double max) {
    _ultCooldownMax = max;
    _ultCooldownCurrent = 0;
    _ultCooldownBucket = _cooldownBucket(
      _ultCooldownCurrent,
      _ultCooldownMax,
    );
    notifyListeners();
  }

  void useUlt() {
    _ultCooldownCurrent = _ultCooldownMax;
    _ultCooldownBucket = _cooldownBucket(
      _ultCooldownCurrent,
      _ultCooldownMax,
    );
    notifyListeners();
  }

  bool consumeUltTicket() {
    if (_ultTicketCount <= 0) {
      return false;
    }
    _ultTicketCount--;
    notifyListeners();
    return true;
  }

  void addUltTicket([int count = 1]) {
    _ultTicketCount += count;
    notifyListeners();
  }

  void tickUltCooldown(double dt) {
    if (_ultCooldownCurrent > 0) {
      _ultCooldownCurrent = (_ultCooldownCurrent - dt).clamp(
        0,
        _ultCooldownMax,
      );
      final nextBucket = _cooldownBucket(_ultCooldownCurrent, _ultCooldownMax);
      if (nextBucket != _ultCooldownBucket) {
        _ultCooldownBucket = nextBucket;
        notifyListeners();
      }
    }
  }

  void reduceUltCooldown(double amount) {
    _ultCooldownCurrent = (_ultCooldownCurrent - amount).clamp(
      0,
      _ultCooldownMax,
    );
    _ultCooldownBucket = _cooldownBucket(_ultCooldownCurrent, _ultCooldownMax);
    notifyListeners();
  }

  void syncUltCooldown(double current) {
    _ultCooldownCurrent = current.clamp(0, _ultCooldownMax);
    _ultCooldownBucket = _cooldownBucket(_ultCooldownCurrent, _ultCooldownMax);
    notifyListeners();
  }

  void syncUltTickets(int count) {
    _ultTicketCount = count.clamp(0, 99);
    notifyListeners();
  }

  // --- 게임 상태 ---
  bool _isGameOver = false;
  bool _isVictory = false;
  bool _isPaused = false;

  bool get isGameOver => _isGameOver;
  bool get isVictory => _isVictory;
  bool get isPaused => _isPaused;

  void gameOver() {
    _isGameOver = true;
    _isVictory = false;
    notifyListeners();
  }

  void victory() {
    _isGameOver = true;
    _isVictory = true;
    notifyListeners();
  }

  void togglePause() {
    _isPaused = !_isPaused;
    notifyListeners();
  }

  // --- 보스 상태 ---
  final List<BossStatus> _bossStatuses = [];

  bool get bossActive => _bossStatuses.isNotEmpty;
  String get bossName => _bossStatuses.isNotEmpty ? _bossStatuses.first.name : '';
  double get bossHpRatio => _bossStatuses.isNotEmpty ? _bossStatuses.first.hpRatio : 1.0;
  List<BossStatus> get bossStatuses => List.unmodifiable(_bossStatuses);

  void setBoss(String name, {String? id}) {
    final bossId = id ?? name;
    final index = _bossStatuses.indexWhere((boss) => boss.id == bossId);
    if (index >= 0) {
      _bossStatuses[index] = BossStatus(
        id: bossId,
        name: name,
        hpRatio: _bossStatuses[index].hpRatio,
      );
    } else {
      _bossStatuses.add(BossStatus(id: bossId, name: name, hpRatio: 1.0));
    }
    notifyListeners();
  }

  void updateBossHp(double ratio, {String? id}) {
    if (_bossStatuses.isEmpty) {
      return;
    }
    final clampedRatio = ratio.clamp(0.0, 1.0).toDouble();
    if (id == null) {
      final first = _bossStatuses.first;
      _bossStatuses[0] = BossStatus(
        id: first.id,
        name: first.name,
        hpRatio: clampedRatio,
      );
      notifyListeners();
      return;
    }

    final index = _bossStatuses.indexWhere((boss) => boss.id == id);
    if (index < 0) {
      return;
    }

    final current = _bossStatuses[index];
    _bossStatuses[index] = BossStatus(
      id: current.id,
      name: current.name,
      hpRatio: clampedRatio,
    );
    notifyListeners();
  }

  void clearBoss({String? id}) {
    if (id == null) {
      if (_bossStatuses.isEmpty) {
        return;
      }
      _bossStatuses.clear();
      notifyListeners();
      return;
    }

    final before = _bossStatuses.length;
    _bossStatuses.removeWhere((boss) => boss.id == id);
    if (_bossStatuses.length != before) {
      notifyListeners();
    }
  }

  // --- 리셋 ---
  void reset() {
    _totalCoffeeEarned = 0;
    _currentHp = _maxHp;
    _currentWave = 1;
    _enemiesRemaining = 0;
    _ultCooldownCurrent = 0;
    _assistCooldownCurrent = 0;
    _ultTicketCount = 0;
    _assistTicketCount = 0;
    _ultCooldownBucket = _cooldownBucket(_ultCooldownCurrent, _ultCooldownMax);
    _assistCooldownBucket = _cooldownBucket(
      _assistCooldownCurrent,
      _assistCooldownMax,
    );
    _isGameOver = false;
    _isVictory = false;
    _isPaused = false;
    _bossStatuses.clear();
    notifyListeners();
  }

  /// 다시하기용 리셋 (HP/쿨다운만 초기화, 웨이브/캐릭터/강화/커피 유지)
  void resetForRetry() {
    _currentHp = _maxHp;
    _enemiesRemaining = 0;
    _ultCooldownCurrent = 0;
    _assistCooldownCurrent = 0;
    _ultTicketCount = 0;
    _assistTicketCount = 0;
    _ultCooldownBucket = _cooldownBucket(_ultCooldownCurrent, _ultCooldownMax);
    _assistCooldownBucket = _cooldownBucket(
      _assistCooldownCurrent,
      _assistCooldownMax,
    );
    _isGameOver = false;
    _isVictory = false;
    _isPaused = false;
    _bossStatuses.clear();
    notifyListeners();
  }

  int _cooldownBucket(double current, double max) {
    if (max <= 0) {
      return 0;
    }
    return ((current / max).clamp(0.0, 1.0) * _cooldownNotifyBuckets)
        .round();
  }
}

class BossStatus {
  final String id;
  final String name;
  final double hpRatio;

  const BossStatus({
    required this.id,
    required this.name,
    required this.hpRatio,
  });
}
