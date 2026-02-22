import 'package:flutter/foundation.dart';
import '../config/character_data.dart';
import '../config/mbti_compatibility.dart';

/// 게임 상태 관리 (Flutter UI와 Flame 간 데이터 연동)
class GameState extends ChangeNotifier {
  // --- 글로벌 메타 데이터 ---
  int _coffeeBeans = 0;
  int _hpLevel = 0;
  int _attackLevel = 0;
  int _speedLevel = 0;
  Set<CharacterType> _unlockedCharacters = {
    CharacterType.estj,
    CharacterType.entp,
    CharacterType.infp,
    CharacterType.isfj,
  };

  int get coffeeBeans => _coffeeBeans;
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
    _unlockedCharacters = unlocked;
    notifyListeners();
  }

  void addCoffeeBeans(int amount) {
    _coffeeBeans += amount;
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

  double get assistCooldownMax => _assistCooldownMax;
  double get assistCooldownCurrent => _assistCooldownCurrent;
  bool get isAssistReady => _assistCooldownCurrent <= 0;
  double get assistCooldownRatio => _assistCooldownMax > 0
      ? (_assistCooldownCurrent / _assistCooldownMax).clamp(0.0, 1.0)
      : 0;

  void initAssistCooldown() {
    final cdMultiplier = MbtiCompatibility.getCooldownMultiplier(
      companionGrade,
    );
    _assistCooldownMax = 30 * cdMultiplier;
    _assistCooldownCurrent = 0;
    notifyListeners();
  }

  void useAssist() {
    _assistCooldownCurrent = _assistCooldownMax;
    notifyListeners();
  }

  void tickAssistCooldown(double dt) {
    if (_assistCooldownCurrent > 0) {
      _assistCooldownCurrent = (_assistCooldownCurrent - dt).clamp(
        0,
        _assistCooldownMax,
      );
      notifyListeners();
    }
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

  double get ultCooldownMax => _ultCooldownMax;
  double get ultCooldownCurrent => _ultCooldownCurrent;
  bool get isUltReady => _ultCooldownCurrent <= 0;
  double get ultCooldownRatio => _ultCooldownMax > 0
      ? (_ultCooldownCurrent / _ultCooldownMax).clamp(0.0, 1.0)
      : 0;

  void initUltCooldown(double max) {
    _ultCooldownMax = max;
    _ultCooldownCurrent = 0;
    notifyListeners();
  }

  void useUlt() {
    _ultCooldownCurrent = _ultCooldownMax;
    notifyListeners();
  }

  void tickUltCooldown(double dt) {
    if (_ultCooldownCurrent > 0) {
      _ultCooldownCurrent = (_ultCooldownCurrent - dt).clamp(
        0,
        _ultCooldownMax,
      );
      notifyListeners();
    }
  }

  void reduceUltCooldown(double amount) {
    _ultCooldownCurrent = (_ultCooldownCurrent - amount).clamp(
      0,
      _ultCooldownMax,
    );
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
  bool _bossActive = false;
  String _bossName = '';
  double _bossHpRatio = 1.0;

  bool get bossActive => _bossActive;
  String get bossName => _bossName;
  double get bossHpRatio => _bossHpRatio;

  void setBoss(String name) {
    _bossActive = true;
    _bossName = name;
    _bossHpRatio = 1.0;
    notifyListeners();
  }

  void updateBossHp(double ratio) {
    _bossHpRatio = ratio.clamp(0.0, 1.0);
    notifyListeners();
  }

  void clearBoss() {
    _bossActive = false;
    notifyListeners();
  }

  // --- 리셋 ---
  void reset() {
    _coffeeBeans = 0;
    _hpLevel = 0;
    _attackLevel = 0;
    _speedLevel = 0;
    _currentHp = _maxHp;
    _currentWave = 1;
    _enemiesRemaining = 0;
    _ultCooldownCurrent = 0;
    _assistCooldownCurrent = 0;
    _isGameOver = false;
    _isVictory = false;
    _isPaused = false;
    _bossActive = false;
    notifyListeners();
  }

  /// 다시하기용 리셋 (HP/쿨다운만 초기화, 웨이브/캐릭터/강화/커피 유지)
  void resetForRetry() {
    _coffeeBeans = 0;
    _currentHp = _maxHp;
    _enemiesRemaining = 0;
    _ultCooldownCurrent = 0;
    _assistCooldownCurrent = 0;
    _isGameOver = false;
    _isVictory = false;
    _isPaused = false;
    _bossActive = false;
    notifyListeners();
  }
}
