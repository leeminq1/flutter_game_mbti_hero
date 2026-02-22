import 'dart:ui';

/// 캐릭터 타입 열거형 (8종 MBTI)
enum CharacterType { estj, entp, infp, istp, enfj, intj, esfp, isfj }

/// 공격 타입
enum AttackType {
  wave, // ESTJ: 주변 파동
  homing, // ENTP: 유도 투사체 + 스플래시
  summon, // INFP: 소환수 자동 추적
  straight, // ISTP: 전방 직선 투사체
  aura, // ENFJ: 버프 오라 + 일반탄
  blink, // INTJ: 순간이동 슬래시
  rapid, // ESFP: 빠른 연타
  shield, // ISFJ: 보호막 투사체
}

/// 캐릭터 능력치 데이터
class CharacterData {
  final CharacterType type;
  final String name;
  final String mbti;
  final String title;
  final String role; // 역할 (탱커, 마법사, 힐러, etc.)
  final String description;
  final double maxHp;
  final double attack;
  final double speed;
  final double baseAttackSpeed; // 기본 공격 속도 (간격, 초)
  final double knockbackPower; // 공격 히트 시 적 밀어내는 힘
  final int pierceCount; // 관통 가능 횟수
  final double ultCooldown;
  final Color color;
  final AttackType attackType;
  final bool isFreeCharacter;
  final String assetPath;
  final String assistText;
  final List<String> idleQuotes;

  const CharacterData({
    required this.type,
    required this.name,
    required this.mbti,
    required this.title,
    required this.role,
    required this.description,
    required this.maxHp,
    required this.attack,
    required this.speed,
    required this.baseAttackSpeed,
    this.knockbackPower = 0.0,
    this.pierceCount = 1,
    required this.ultCooldown,
    required this.color,
    required this.attackType,
    required this.isFreeCharacter,
    required this.assetPath,
    required this.assistText,
    required this.idleQuotes,
  });
}

/// 전체 캐릭터 데이터 정의
class MbtiCharacters {
  static const List<CharacterData> all = [
    // ── 기존 4캐릭터 ──
    CharacterData(
      type: CharacterType.estj,
      name: '칼퇴 부장님',
      mbti: 'ESTJ',
      title: '엄격한 관리자',
      role: '🛡️ 탱커',
      description: '결재판을 방패처럼 든 부장님.\n높은 체력, 강한 근거리 파동.',
      maxHp: 200,
      attack: 15,
      speed: 100,
      baseAttackSpeed: 1.2, // 느리고 묵직함
      knockbackPower: 120.0, // 강한 넉백
      pierceCount: 99, // 파동형은 무한 관통
      ultCooldown: 25,
      color: Color(0xFF4A90D9),
      attackType: AttackType.wave,
      isFreeCharacter: true,
      assetPath: 'characters/estj.png',
      assistText: '[동료] ESTJ: 내 뒤로 숨게! 철벽 방어!',
      idleQuotes: ['오늘 야근은 없다.', '다들 집중해!', '결재 서류는 내가 막아주지!'],
    ),
    CharacterData(
      type: CharacterType.entp,
      name: '아이디어 천재',
      mbti: 'ENTP',
      title: '논쟁을 즐기는 변론가',
      role: '🧙 마법사',
      description: '확성기와 폭탄을 든 트롤러.\n높은 공격력, 유도 미사일.',
      maxHp: 80,
      attack: 18,
      speed: 120,
      baseAttackSpeed: 0.8,
      knockbackPower: 30.0, // 약한 넉백
      ultCooldown: 20,
      color: Color(0xFF9B59B6),
      attackType: AttackType.homing,
      isFreeCharacter: true,
      assetPath: 'characters/entp.png',
      assistText: '[동료] ENTP: 다 비켜보라고! 아이디어 폭격!!',
      idleQuotes: ['이게 바로 혁신이지!', '아, 진짜 좋은 아이디어 떠올랐다!', '규칙은 깨라고 있는 거 아니겠어?'],
    ),
    CharacterData(
      type: CharacterType.infp,
      name: '감성 디자이너',
      mbti: 'INFP',
      title: '열정적인 중재자',
      role: '💚 힐러',
      description: '침낭을 뒤집어쓴 감성파.\n자가 회복, 소환수 공격.',
      maxHp: 90,
      attack: 8,
      speed: 110,
      baseAttackSpeed: 1.5, // 소환수 의존으로 본체 공격 느림
      ultCooldown: 15,
      color: Color(0xFFE91E8C),
      attackType: AttackType.summon,
      isFreeCharacter: false,
      assetPath: 'characters/infp.png',
      assistText: '[동료] INFP: 너무 무리하지 마세요.. 힐링 장막!',
      idleQuotes: ['잠깐 쉬어가는 건 어때요?', '싸움은 별로 안 좋아하는데...', '조금만 더 힘내볼게요.'],
    ),
    CharacterData(
      type: CharacterType.istp,
      name: '야근의 달인',
      mbti: 'ISTP',
      title: '만능 재주꾼',
      role: '⚔️ 누커',
      description: '몽키스패너를 든 작업복 차림.\n극강 공격력, 관통 직선탄.',
      maxHp: 100,
      attack: 25,
      speed: 130,
      baseAttackSpeed: 0.6,
      knockbackPower: 10.0,
      pierceCount: 3, // 3마리 관통
      ultCooldown: 30,
      color: Color(0xFFE74C3C),
      attackType: AttackType.straight,
      isFreeCharacter: false,
      assetPath: 'characters/istp.png',
      assistText: '[동료] ISTP: 퇴근 좀 하자. 기계 철거!',
      idleQuotes: ['아, 귀찮아.', '이거면 되나?', '빨리 끝내고 집에 가자.'],
    ),

    // ── 신규 4캐릭터 ──
    CharacterData(
      type: CharacterType.enfj,
      name: '팀의 맏형',
      mbti: 'ENFJ',
      title: '정의로운 사회운동가',
      role: '🎯 서포터',
      description: '동료를 이끄는 카리스마 리더.\n버프 오라, 동료 시너지 UP.',
      maxHp: 110,
      attack: 10,
      speed: 115,
      baseAttackSpeed: 0.9,
      knockbackPower: 20.0,
      ultCooldown: 22,
      color: Color(0xFFFFD700),
      attackType: AttackType.aura,
      isFreeCharacter: false,
      assetPath: 'characters/enfj.png',
      assistText: '[동료] ENFJ: 다들 힘내자고! 사기 진작 오라!',
      idleQuotes: ['우린 할 수 있어!', '서로 돕는 게 팀이지!', '다 같이 이겨내자!'],
    ),
    CharacterData(
      type: CharacterType.intj,
      name: '전략 기획자',
      mbti: 'INTJ',
      title: '용의주도한 전략가',
      role: '🗡️ 암살자',
      description: '냉철한 분석과 순간이동.\n적 HP 낮을수록 데미지 UP.',
      maxHp: 85,
      attack: 20,
      speed: 125,
      baseAttackSpeed: 0.35, // 매우 빠른 연속 베기 (단검)
      knockbackPower: 0.0, // 넉백 없음 (암살자)
      pierceCount: 2,
      ultCooldown: 28,
      color: Color(0xFF00BCD4),
      attackType: AttackType.blink,
      isFreeCharacter: false,
      assetPath: 'characters/intj.png',
      assistText: '[동료] INTJ: 허점이 보이는군. 약점 찌르기!',
      idleQuotes: ['계획대로 진행 중.', '확률은 99.9%다.', '감정적인 대처는 무의미해.'],
    ),
    CharacterData(
      type: CharacterType.esfp,
      name: '분위기 메이커',
      mbti: 'ESFP',
      title: '자유로운 영혼의 연예인',
      role: '💥 파이터',
      description: '최고 속도의 빠른 연타.\n연속 처치 시 공격력 증가.',
      maxHp: 120,
      attack: 12,
      speed: 140,
      baseAttackSpeed: 0.25, // 게임 내 최고 속도
      knockbackPower: 5.0,
      ultCooldown: 18,
      color: Color(0xFFFF9800),
      attackType: AttackType.rapid,
      isFreeCharacter: false,
      assetPath: 'characters/esfp.png',
      assistText: '[동료] ESFP: 파티 타임!! 스포트라이트 온!',
      idleQuotes: ['오늘도 신나게 놀아볼까!', '내가 왔으니 안심해!', '이런 상황도 즐겨야지!'],
    ),
    CharacterData(
      type: CharacterType.isfj,
      name: '살림꾼 사원',
      mbti: 'ISFJ',
      title: '용감한 수호자',
      role: '🛡️ 수호자',
      description: '팀을 지키는 든든한 수호자.\n보호막, 피격 시 반격.',
      maxHp: 150,
      attack: 8,
      speed: 95,
      baseAttackSpeed: 2.0, // 방어막 전개, 공격 매우 느림
      knockbackPower: 150.0, // 방패 밀치기 특화
      ultCooldown: 25,
      color: Color(0xFF4CAF50),
      attackType: AttackType.shield,
      isFreeCharacter: false,
      assetPath: 'characters/isfj.png',
      assistText: '[동료] ISFJ: 안전이 제일이죠! 비상 보호막 전개!',
      idleQuotes: ['제가 지켜드릴게요!', '조심해서 나쁠 건 없죠.', '모두 무사했으면 좋겠어요.'],
    ),
  ];

  static CharacterData getByType(CharacterType type) {
    return all.firstWhere((c) => c.type == type);
  }
}
