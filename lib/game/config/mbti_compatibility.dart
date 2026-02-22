import 'character_data.dart';

/// MBTI 궁합 등급
enum CompatibilityGrade { s, a, b, c }

/// MBTI 궁합 데이터
class MbtiCompatibility {
  /// 궁합표 - [메인][동료] = 등급
  static final Map<CharacterType, Map<CharacterType, CompatibilityGrade>>
  _chart = {
    CharacterType.estj: {
      CharacterType.entp: CompatibilityGrade.b,
      CharacterType.infp: CompatibilityGrade.c,
      CharacterType.istp: CompatibilityGrade.a,
      CharacterType.enfj: CompatibilityGrade.a,
      CharacterType.intj: CompatibilityGrade.s,
      CharacterType.esfp: CompatibilityGrade.a,
      CharacterType.isfj: CompatibilityGrade.s,
    },
    CharacterType.entp: {
      CharacterType.estj: CompatibilityGrade.b,
      CharacterType.infp: CompatibilityGrade.a,
      CharacterType.istp: CompatibilityGrade.s,
      CharacterType.enfj: CompatibilityGrade.b,
      CharacterType.intj: CompatibilityGrade.s,
      CharacterType.esfp: CompatibilityGrade.b,
      CharacterType.isfj: CompatibilityGrade.c,
    },
    CharacterType.infp: {
      CharacterType.estj: CompatibilityGrade.c,
      CharacterType.entp: CompatibilityGrade.a,
      CharacterType.istp: CompatibilityGrade.b,
      CharacterType.enfj: CompatibilityGrade.s,
      CharacterType.intj: CompatibilityGrade.b,
      CharacterType.esfp: CompatibilityGrade.a,
      CharacterType.isfj: CompatibilityGrade.a,
    },
    CharacterType.istp: {
      CharacterType.estj: CompatibilityGrade.a,
      CharacterType.entp: CompatibilityGrade.s,
      CharacterType.infp: CompatibilityGrade.b,
      CharacterType.enfj: CompatibilityGrade.c,
      CharacterType.intj: CompatibilityGrade.a,
      CharacterType.esfp: CompatibilityGrade.s,
      CharacterType.isfj: CompatibilityGrade.b,
    },
    CharacterType.enfj: {
      CharacterType.estj: CompatibilityGrade.a,
      CharacterType.entp: CompatibilityGrade.b,
      CharacterType.infp: CompatibilityGrade.s,
      CharacterType.istp: CompatibilityGrade.c,
      CharacterType.intj: CompatibilityGrade.a,
      CharacterType.esfp: CompatibilityGrade.a,
      CharacterType.isfj: CompatibilityGrade.s,
    },
    CharacterType.intj: {
      CharacterType.estj: CompatibilityGrade.s,
      CharacterType.entp: CompatibilityGrade.s,
      CharacterType.infp: CompatibilityGrade.b,
      CharacterType.istp: CompatibilityGrade.a,
      CharacterType.enfj: CompatibilityGrade.a,
      CharacterType.esfp: CompatibilityGrade.c,
      CharacterType.isfj: CompatibilityGrade.b,
    },
    CharacterType.esfp: {
      CharacterType.estj: CompatibilityGrade.a,
      CharacterType.entp: CompatibilityGrade.b,
      CharacterType.infp: CompatibilityGrade.a,
      CharacterType.istp: CompatibilityGrade.s,
      CharacterType.enfj: CompatibilityGrade.a,
      CharacterType.intj: CompatibilityGrade.c,
      CharacterType.isfj: CompatibilityGrade.a,
    },
    CharacterType.isfj: {
      CharacterType.estj: CompatibilityGrade.s,
      CharacterType.entp: CompatibilityGrade.c,
      CharacterType.infp: CompatibilityGrade.a,
      CharacterType.istp: CompatibilityGrade.b,
      CharacterType.enfj: CompatibilityGrade.s,
      CharacterType.intj: CompatibilityGrade.b,
      CharacterType.esfp: CompatibilityGrade.a,
    },
  };

  /// 궁합 등급 조회
  static CompatibilityGrade getGrade(
    CharacterType main,
    CharacterType companion,
  ) {
    return _chart[main]?[companion] ?? CompatibilityGrade.b;
  }

  /// 궁합에 따른 파워 배율
  static double getPowerMultiplier(CompatibilityGrade grade) {
    switch (grade) {
      case CompatibilityGrade.s:
        return 1.5;
      case CompatibilityGrade.a:
        return 1.2;
      case CompatibilityGrade.b:
        return 1.0;
      case CompatibilityGrade.c:
        return 0.7;
    }
  }

  /// 궁합에 따른 쿨타임 배율
  static double getCooldownMultiplier(CompatibilityGrade grade) {
    switch (grade) {
      case CompatibilityGrade.s:
        return 0.8; // 20% 쿨감
      case CompatibilityGrade.a:
        return 0.9;
      case CompatibilityGrade.b:
        return 1.0;
      case CompatibilityGrade.c:
        return 1.3; // 30% 쿨증가
    }
  }

  /// 등급별 라벨
  static String getGradeLabel(CompatibilityGrade grade) {
    switch (grade) {
      case CompatibilityGrade.s:
        return 'S';
      case CompatibilityGrade.a:
        return 'A';
      case CompatibilityGrade.b:
        return 'B';
      case CompatibilityGrade.c:
        return 'C';
    }
  }

  /// 등급별 설명
  static String getGradeDescription(CompatibilityGrade grade) {
    switch (grade) {
      case CompatibilityGrade.s:
        return '최고의 궁합! 필살기 150% + 체력 회복';
      case CompatibilityGrade.a:
        return '좋은 궁합! 필살기 120%';
      case CompatibilityGrade.b:
        return '보통 궁합. 필살기 100%';
      case CompatibilityGrade.c:
        return '안 맞는 궁합... 필살기 70%';
    }
  }

  /// S등급이면 체력 회복 보너스 제공
  static bool hasHealBonus(CompatibilityGrade grade) {
    return grade == CompatibilityGrade.s;
  }
}
