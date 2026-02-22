import 'package:shared_preferences/shared_preferences.dart';
import '../game/config/character_data.dart';

/// 게임 진행 저장/불러오기 관리
class SaveManager {
  static const String _keyHasSave = 'game_has_save';
  static const String _keyCharacter = 'game_character';
  static const String _keyCompanion = 'game_companion';
  static const String _keyWave = 'game_wave';
  static const String _keyHp = 'game_hp';
  static const String _keyMaxHp = 'game_max_hp';
  static const String _keyAttackPower = 'game_attack_power';
  static const String _keySpeed = 'game_speed';
  static const String _keyKills = 'game_kills';
  static const String _keySaveHpLevel = 'game_hp_level';
  static const String _keySaveAtkLevel = 'game_atk_level';
  static const String _keySaveSpdLevel = 'game_spd_level';

  // 글로벌(메타) 저장 키
  static const String _keyCoffeeBeans = 'global_coffee_beans';
  static const String _keyHpLevel = 'global_hp_level';
  static const String _keyAtkLevel = 'global_atk_level';
  static const String _keySpdLevel = 'global_spd_level';
  static const String _keyUnlockedChars = 'global_unlocked_chars';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 저장 데이터가 있는지
  bool get hasSaveData => _prefs.getBool(_keyHasSave) ?? false;

  /// 게임 상태 저장
  Future<void> saveGame({
    required CharacterType character,
    required CharacterType companion,
    required int wave,
    required double hp,
    required double maxHp,
    required double attackPower,
    required double speed,
    required int kills,
    int hpLevel = 0,
    int atkLevel = 0,
    int spdLevel = 0,
  }) async {
    await _prefs.setBool(_keyHasSave, true);
    await _prefs.setString(_keyCharacter, character.name);
    await _prefs.setString(_keyCompanion, companion.name);
    await _prefs.setInt(_keyWave, wave);
    await _prefs.setDouble(_keyHp, hp);
    await _prefs.setDouble(_keyMaxHp, maxHp);
    await _prefs.setDouble(_keyAttackPower, attackPower);
    await _prefs.setDouble(_keySpeed, speed);
    await _prefs.setInt(_keyKills, kills);
    await _prefs.setInt(_keySaveHpLevel, hpLevel);
    await _prefs.setInt(_keySaveAtkLevel, atkLevel);
    await _prefs.setInt(_keySaveSpdLevel, spdLevel);
  }

  /// 저장된 게임 데이터 불러오기
  SaveData? loadGame() {
    if (!hasSaveData) return null;

    final charName = _prefs.getString(_keyCharacter) ?? 'estj';
    final compName = _prefs.getString(_keyCompanion) ?? 'isfj';

    return SaveData(
      character: CharacterType.values.firstWhere(
        (t) => t.name == charName,
        orElse: () => CharacterType.estj,
      ),
      companion: CharacterType.values.firstWhere(
        (t) => t.name == compName,
        orElse: () => CharacterType.isfj,
      ),
      wave: _prefs.getInt(_keyWave) ?? 1,
      hp: _prefs.getDouble(_keyHp) ?? 200,
      maxHp: _prefs.getDouble(_keyMaxHp) ?? 200,
      attackPower: _prefs.getDouble(_keyAttackPower) ?? 10,
      speed: _prefs.getDouble(_keySpeed) ?? 100,
      kills: _prefs.getInt(_keyKills) ?? 0,
      hpLevel: _prefs.getInt(_keySaveHpLevel) ?? 0,
      atkLevel: _prefs.getInt(_keySaveAtkLevel) ?? 0,
      spdLevel: _prefs.getInt(_keySaveSpdLevel) ?? 0,
    );
  }

  /// 글로벌 데이터 저장 (커피콩, 레벨, 해금 캐릭터)
  Future<void> saveGlobalData({
    required int coffeeBeans,
    required int hpLevel,
    required int atkLevel,
    required int spdLevel,
    required List<String> unlockedCharacters,
  }) async {
    await _prefs.setInt(_keyCoffeeBeans, coffeeBeans);
    await _prefs.setInt(_keyHpLevel, hpLevel);
    await _prefs.setInt(_keyAtkLevel, atkLevel);
    await _prefs.setInt(_keySpdLevel, spdLevel);
    await _prefs.setStringList(_keyUnlockedChars, unlockedCharacters);
  }

  /// 글로벌 데이터 불러오기
  GlobalSaveData loadGlobalData() {
    final chars =
        _prefs.getStringList(_keyUnlockedChars) ??
        ['estj', 'entp', 'infp', 'isfj'];

    return GlobalSaveData(
      coffeeBeans: _prefs.getInt(_keyCoffeeBeans) ?? 0,
      hpLevel: _prefs.getInt(_keyHpLevel) ?? 0,
      attackLevel: _prefs.getInt(_keyAtkLevel) ?? 0,
      speedLevel: _prefs.getInt(_keySpdLevel) ?? 0,
      unlockedCharacters: chars
          .map(
            (name) => CharacterType.values.firstWhere(
              (t) => t.name == name,
              orElse: () => CharacterType.estj,
            ),
          )
          .toSet(),
    );
  }

  /// 현재 게임 진행 저장 데이터 삭제 (글로벌 데이터는 유지)
  Future<void> deleteSave() async {
    await _prefs.remove(_keyHasSave);
    await _prefs.remove(_keyCharacter);
    await _prefs.remove(_keyCompanion);
    await _prefs.remove(_keyWave);
    await _prefs.remove(_keyHp);
    await _prefs.remove(_keyMaxHp);
    await _prefs.remove(_keyAttackPower);
    await _prefs.remove(_keySpeed);
    await _prefs.remove(_keyKills);
    await _prefs.remove(_keySaveHpLevel);
    await _prefs.remove(_keySaveAtkLevel);
    await _prefs.remove(_keySaveSpdLevel);
  }

  /// 저장 요약 텍스트 (UI 표시용)
  String getSaveSummary() {
    if (!hasSaveData) return '';
    final data = loadGame();
    if (data == null) return '';
    final charData = MbtiCharacters.getByType(data.character);
    return '${charData.mbti} ${charData.name} | Wave ${data.wave} | HP ${data.hp.toInt()}';
  }
}

/// 저장 데이터 구조
class SaveData {
  final CharacterType character;
  final CharacterType companion;
  final int wave;
  final double hp;
  final double maxHp;
  final double attackPower;
  final double speed;
  final int kills;
  final int hpLevel;
  final int atkLevel;
  final int spdLevel;

  const SaveData({
    required this.character,
    required this.companion,
    required this.wave,
    required this.hp,
    required this.maxHp,
    required this.attackPower,
    required this.speed,
    required this.kills,
    this.hpLevel = 0,
    this.atkLevel = 0,
    this.spdLevel = 0,
  });
}

/// 글로벌 저장 데이터 구조 (영구 보존)
class GlobalSaveData {
  final int coffeeBeans;
  final int hpLevel;
  final int attackLevel;
  final int speedLevel;
  final Set<CharacterType> unlockedCharacters;

  const GlobalSaveData({
    required this.coffeeBeans,
    required this.hpLevel,
    required this.attackLevel,
    required this.speedLevel,
    required this.unlockedCharacters,
  });
}
