import 'character_data.dart';

/// MBTI 궁합 등급
enum CompatibilityGrade { s, a, b, c }

/// MBTI 궁합 데이터
class MbtiCompatibility {
  /// 기존 8종 캐릭터는 기존 수치를 우선 유지한다.
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

  static const Set<String> _specialBestPairs = {
    'ENFP-INFJ',
    'ENFP-INTJ',
    'ENFP-ISFP',
    'ENTJ-INTP',
    'ENTJ-ISTJ',
    'ESFJ-ISFP',
    'ESFJ-ISTJ',
    'ESTP-ISTP',
    'INFJ-INFP',
  };

  static const Set<String> _specialConflictPairs = {
    'ENFP-ISTJ',
    'ENTJ-INFP',
    'ENTJ-ISFP',
    'ESFJ-INTP',
    'ESTP-INFJ',
  };

  static CompatibilityGrade getGrade(
    CharacterType main,
    CharacterType companion,
  ) {
    if (main == companion) {
      return CompatibilityGrade.a;
    }

    final explicit = _chart[main]?[companion];
    if (explicit != null) {
      return explicit;
    }

    return _gradeFromTraits(main.name.toUpperCase(), companion.name.toUpperCase());
  }

  static CompatibilityGrade _gradeFromTraits(String main, String companion) {
    final pairKey = _pairKey(main, companion);
    if (_specialBestPairs.contains(pairKey)) {
      return CompatibilityGrade.s;
    }
    if (_specialConflictPairs.contains(pairKey)) {
      return CompatibilityGrade.c;
    }

    var score = 0;

    if (main[1] == companion[1]) {
      score += 2; // N/S
    }
    if (main[2] == companion[2]) {
      score += 2; // T/F
    }
    if (main[3] == companion[3]) {
      score += 1; // J/P
    }
    if (main.substring(1) == companion.substring(1)) {
      score += 2;
    }
    if (_temperament(main) == _temperament(companion)) {
      score += 1;
    }
    if (_interactionStyle(main) == _interactionStyle(companion)) {
      score += 1;
    }
    if (main[0] != companion[0]) {
      score += 1; // E/I 보완
    }
    if (main[1] != companion[1] &&
        main[2] != companion[2] &&
        main[3] != companion[3]) {
      score -= 2;
    }

    if (score >= 6) {
      return CompatibilityGrade.s;
    }
    if (score >= 4) {
      return CompatibilityGrade.a;
    }
    if (score <= 1) {
      return CompatibilityGrade.c;
    }
    return CompatibilityGrade.b;
  }

  static String _pairKey(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}-${sorted[1]}';
  }

  static String _temperament(String type) {
    return '${type[1]}${type[2]}';
  }

  static String _interactionStyle(String type) {
    return '${type[0]}${type[3]}';
  }

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

  static double getCooldownMultiplier(CompatibilityGrade grade) {
    switch (grade) {
      case CompatibilityGrade.s:
        return 0.8;
      case CompatibilityGrade.a:
        return 0.9;
      case CompatibilityGrade.b:
        return 1.0;
      case CompatibilityGrade.c:
        return 1.3;
    }
  }

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

  static String getGradeDescription(CompatibilityGrade grade) {
    switch (grade) {
      case CompatibilityGrade.s:
        return '최고의 궁합! 필살기 150% + 체력 회복';
      case CompatibilityGrade.a:
        return '좋은 궁합! 필살기 120%';
      case CompatibilityGrade.b:
        return '보통 궁합. 필살기 100%';
      case CompatibilityGrade.c:
        return '상극 조합... 필살기 70%';
    }
  }

  static bool hasHealBonus(CompatibilityGrade grade) {
    return grade == CompatibilityGrade.s;
  }
}
