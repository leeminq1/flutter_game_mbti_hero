import 'package:shared_preferences/shared_preferences.dart';
import '../game/config/character_data.dart';

/// 캐릭터 해금 상태 관리
class UnlockManager {
  static const String _prefix = 'character_unlocked_';

  // 기본 해금 캐릭터
  static const Set<CharacterType> freeCharacters = {
    CharacterType.estj,
    CharacterType.entp,
    CharacterType.infp,
    CharacterType.isfj,
  };

  late SharedPreferences _prefs;
  final Set<CharacterType> _unlockedCharacters = {};

  Set<CharacterType> get unlockedCharacters => _unlockedCharacters;

  /// 초기화 (앱 시작 시 호출)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // 기본 캐릭터 항상 해금
    _unlockedCharacters.addAll(freeCharacters);

    // 저장된 해금 상태 로드
    for (final type in CharacterType.values) {
      final key = '$_prefix${type.name}';
      if (_prefs.getBool(key) == true) {
        _unlockedCharacters.add(type);
      }
    }
  }

  /// 캐릭터 해금 여부 확인
  bool isUnlocked(CharacterType type) {
    return _unlockedCharacters.contains(type);
  }

  /// 캐릭터 해금 (광고 시청 후 호출)
  Future<void> unlock(CharacterType type) async {
    _unlockedCharacters.add(type);
    final key = '$_prefix${type.name}';
    await _prefs.setBool(key, true);
  }

  /// 전체 해금 리셋 (디버그용)
  Future<void> resetAll() async {
    _unlockedCharacters.clear();
    _unlockedCharacters.addAll(freeCharacters);

    for (final type in CharacterType.values) {
      final key = '$_prefix${type.name}';
      await _prefs.remove(key);
    }
  }
}
