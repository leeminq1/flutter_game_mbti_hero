import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../game/config/character_data.dart';

/// 게임 진행 저장/불러오기 관리
class SaveManager {
  static const String _keyHasSave = 'game_has_save';
  static const String _keyCharacter = 'game_character';
  static const String _keyCompanion = 'game_companion';
  static const String _keyWave = 'game_wave';
  static const String _keyPlayerSnapshot = 'game_player_snapshot';
  static const String _keyHp = 'game_hp';
  static const String _keyMaxHp = 'game_max_hp';
  static const String _keyAttackPower = 'game_attack_power';
  static const String _keySpeed = 'game_speed';
  static const String _keyMultiShot = 'game_multi_shot';
  static const String _keyAttackInterval = 'game_attack_interval';
  static const String _keyUltCooldownCurrent = 'game_ult_cooldown_current';
  static const String _keyAssistCooldownCurrent =
      'game_assist_cooldown_current';
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

  // 리더보드 키
  static const String _keyLeaderboard = 'leaderboard_entries';
  static const int _maxLeaderboardEntries = 50;
  static final List<String> _defaultUnlockedCharacterNames = CharacterType.values
      .map((type) => type.name)
      .toList(growable: false);

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
    required PlayerSnapshot playerSnapshot,
    required int kills,
    int hpLevel = 0,
    int atkLevel = 0,
    int spdLevel = 0,
  }) async {
    await _prefs.setBool(_keyHasSave, true);
    await _prefs.setString(_keyCharacter, character.name);
    await _prefs.setString(_keyCompanion, companion.name);
    await _prefs.setInt(_keyWave, wave);
    await _prefs.setString(_keyPlayerSnapshot, jsonEncode(playerSnapshot.toJson()));
    await _prefs.setDouble(_keyHp, playerSnapshot.hp);
    await _prefs.setDouble(_keyMaxHp, playerSnapshot.maxHp);
    await _prefs.setDouble(_keyAttackPower, playerSnapshot.attackPower);
    await _prefs.setDouble(_keySpeed, playerSnapshot.speed);
    await _prefs.setInt(_keyMultiShot, playerSnapshot.multiShotCount);
    await _prefs.setDouble(_keyAttackInterval, playerSnapshot.attackInterval);
    await _prefs.setDouble(
      _keyUltCooldownCurrent,
      playerSnapshot.ultCooldownCurrent,
    );
    await _prefs.setDouble(
      _keyAssistCooldownCurrent,
      playerSnapshot.assistCooldownCurrent,
    );
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
    final character = CharacterType.values.firstWhere(
      (t) => t.name == charName,
      orElse: () => CharacterType.estj,
    );
    final companion = CharacterType.values.firstWhere(
      (t) => t.name == compName,
      orElse: () => CharacterType.isfj,
    );
    final playerSnapshot = _loadPlayerSnapshot(character);

    return SaveData(
      character: character,
      companion: companion,
      wave: _prefs.getInt(_keyWave) ?? 1,
      playerSnapshot: playerSnapshot,
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
        _defaultUnlockedCharacterNames;
    final mergedChars = {
      ..._defaultUnlockedCharacterNames,
      ...chars,
    };

    return GlobalSaveData(
      coffeeBeans: _prefs.getInt(_keyCoffeeBeans) ?? 0,
      hpLevel: _prefs.getInt(_keyHpLevel) ?? 0,
      attackLevel: _prefs.getInt(_keyAtkLevel) ?? 0,
      speedLevel: _prefs.getInt(_keySpdLevel) ?? 0,
      unlockedCharacters: mergedChars
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
    await _prefs.remove(_keyPlayerSnapshot);
    await _prefs.remove(_keyHp);
    await _prefs.remove(_keyMaxHp);
    await _prefs.remove(_keyAttackPower);
    await _prefs.remove(_keySpeed);
    await _prefs.remove(_keyMultiShot);
    await _prefs.remove(_keyAttackInterval);
    await _prefs.remove(_keyUltCooldownCurrent);
    await _prefs.remove(_keyAssistCooldownCurrent);
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

  PlayerSnapshot _loadPlayerSnapshot(CharacterType character) {
    final snapshotJson = _prefs.getString(_keyPlayerSnapshot);
    if (snapshotJson != null && snapshotJson.isNotEmpty) {
      try {
        return PlayerSnapshot.fromJson(
          jsonDecode(snapshotJson) as Map<String, dynamic>,
          fallbackAttackInterval:
              MbtiCharacters.getByType(character).baseAttackSpeed,
        );
      } catch (_) {
        // Fall through to legacy field recovery.
      }
    }

    final defaultAttackInterval =
        MbtiCharacters.getByType(character).baseAttackSpeed;
    return PlayerSnapshot(
      hp: _prefs.getDouble(_keyHp) ?? 200,
      maxHp: _prefs.getDouble(_keyMaxHp) ?? 200,
      attackPower: _prefs.getDouble(_keyAttackPower) ?? 10,
      speed: _prefs.getDouble(_keySpeed) ?? 100,
      multiShotCount: _prefs.getInt(_keyMultiShot) ?? 3,
      attackInterval:
          _prefs.getDouble(_keyAttackInterval) ?? defaultAttackInterval,
      ultCooldownCurrent: _prefs.getDouble(_keyUltCooldownCurrent) ?? 0,
      assistCooldownCurrent: _prefs.getDouble(_keyAssistCooldownCurrent) ?? 0,
    );
  }

  // ══════════════════════════════════════════
  // ═══ 리더보드 ═══
  // ══════════════════════════════════════════

  /// 리더보드에 기록 추가
  Future<void> addLeaderboardEntry(LeaderboardEntry entry) async {
    final entries = loadLeaderboard();
    entries.add(entry);
    entries.sort((a, b) {
      final waveComp = b.wave.compareTo(a.wave);
      if (waveComp != 0) return waveComp;
      return b.score.compareTo(a.score);
    });
    if (entries.length > _maxLeaderboardEntries) {
      entries.removeRange(_maxLeaderboardEntries, entries.length);
    }
    final jsonList = entries.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_keyLeaderboard, jsonList);
  }

  /// 리더보드 데이터 불러오기
  List<LeaderboardEntry> loadLeaderboard() {
    final jsonList = _prefs.getStringList(_keyLeaderboard) ?? [];
    return jsonList
        .map((s) => LeaderboardEntry.fromJson(jsonDecode(s)))
        .toList();
  }
}

/// 저장 데이터 구조
class SaveData {
  final CharacterType character;
  final CharacterType companion;
  final int wave;
  final PlayerSnapshot playerSnapshot;
  final int kills;
  final int hpLevel;
  final int atkLevel;
  final int spdLevel;

  const SaveData({
    required this.character,
    required this.companion,
    required this.wave,
    required this.playerSnapshot,
    required this.kills,
    this.hpLevel = 0,
    this.atkLevel = 0,
    this.spdLevel = 0,
  });

  double get hp => playerSnapshot.hp;
  double get maxHp => playerSnapshot.maxHp;
  double get attackPower => playerSnapshot.attackPower;
  double get speed => playerSnapshot.speed;
  int get multiShotCount => playerSnapshot.multiShotCount;
  double get attackInterval => playerSnapshot.attackInterval;
  double get ultCooldownCurrent => playerSnapshot.ultCooldownCurrent;
  double get assistCooldownCurrent => playerSnapshot.assistCooldownCurrent;
}

class PlayerSnapshot {
  final double hp;
  final double maxHp;
  final double attackPower;
  final double speed;
  final int multiShotCount;
  final double attackInterval;
  final double ultCooldownCurrent;
  final double assistCooldownCurrent;

  const PlayerSnapshot({
    required this.hp,
    required this.maxHp,
    required this.attackPower,
    required this.speed,
    required this.multiShotCount,
    required this.attackInterval,
    required this.ultCooldownCurrent,
    required this.assistCooldownCurrent,
  });

  Map<String, dynamic> toJson() => {
    'hp': hp,
    'maxHp': maxHp,
    'attackPower': attackPower,
    'speed': speed,
    'multiShotCount': multiShotCount,
    'attackInterval': attackInterval,
    'ultCooldownCurrent': ultCooldownCurrent,
    'assistCooldownCurrent': assistCooldownCurrent,
  };

  factory PlayerSnapshot.fromJson(
    Map<String, dynamic> json, {
    required double fallbackAttackInterval,
  }) {
    return PlayerSnapshot(
      hp: (json['hp'] as num?)?.toDouble() ?? 200,
      maxHp: (json['maxHp'] as num?)?.toDouble() ?? 200,
      attackPower: (json['attackPower'] as num?)?.toDouble() ?? 10,
      speed: (json['speed'] as num?)?.toDouble() ?? 100,
      multiShotCount: (json['multiShotCount'] as num?)?.toInt() ?? 3,
      attackInterval:
          (json['attackInterval'] as num?)?.toDouble() ??
          fallbackAttackInterval,
      ultCooldownCurrent:
          (json['ultCooldownCurrent'] as num?)?.toDouble() ?? 0,
      assistCooldownCurrent:
          (json['assistCooldownCurrent'] as num?)?.toDouble() ?? 0,
    );
  }
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

/// 리더보드 기록 구조
class LeaderboardEntry {
  final String playerName;
  final CharacterType character;
  final CharacterType companion;
  final int wave;
  final int score;
  final String dateTime;

  const LeaderboardEntry({
    required this.playerName,
    required this.character,
    required this.companion,
    required this.wave,
    required this.score,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'name': playerName,
    'char': character.name,
    'comp': companion.name,
    'wave': wave,
    'score': score,
    'date': dateTime,
  };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      playerName: json['name'] ?? 'Unknown',
      character: CharacterType.values.firstWhere(
        (t) => t.name == json['char'],
        orElse: () => CharacterType.estj,
      ),
      companion: CharacterType.values.firstWhere(
        (t) => t.name == json['comp'],
        orElse: () => CharacterType.isfj,
      ),
      wave: json['wave'] ?? 1,
      score: json['score'] ?? 0,
      dateTime: json['date'] ?? '',
    );
  }
}
