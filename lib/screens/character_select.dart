import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../game/config/character_data.dart';
import '../game/config/mbti_compatibility.dart';
import '../services/save_manager.dart';
import '../services/sfx_manager.dart';
import 'leaderboard_screen.dart';

/// 캐릭터 선택 화면 (캐릭터 → 동료 선택 2단계)
class CharacterSelectScreen extends StatefulWidget {
  final Set<CharacterType> unlockedCharacters;
  final void Function(CharacterType character, CharacterType companion)
  onSelect;
  final void Function(CharacterType) onUnlockRequest;
  final SaveManager? saveManager;
  final void Function(SaveData saveData)? onContinue;

  const CharacterSelectScreen({
    super.key,
    required this.unlockedCharacters,
    required this.onSelect,
    required this.onUnlockRequest,
    this.saveManager,
    this.onContinue,
  });

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class CharacterSelectLayoutSpec {
  const CharacterSelectLayoutSpec._();

  static const double maxContentWidth = 980;
  static const double horizontalPadding = 16;
  static const double crossAxisSpacing = 8;
  static const double mainAxisSpacing = 8;
  static const double minCardWidth = 130;

  static int calculateColumns(double width) {
    final usableWidth = math.max<double>(
      0.0,
      math.min(width, maxContentWidth) - (horizontalPadding * 2),
    );
    final columns =
        ((usableWidth + crossAxisSpacing) / (minCardWidth + crossAxisSpacing))
            .floor();
    return columns.clamp(3, 6).toInt();
  }

  static SliverGridDelegate createGridDelegate(double width) {
    final columns = calculateColumns(width);
    final aspectRatio = width >= 700 ? 0.72 : 0.65;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      childAspectRatio: aspectRatio,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  CharacterType? _selectedCharacter;
  CharacterType? _hoveredType;
  CharacterType? _hoveredCompanion;

  void _handleNewGame(CharacterType character, CharacterType companion) {
    if (widget.saveManager?.hasSaveData == true) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A3E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  '새 게임 시작',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '기존 진행 데이터가 삭제됩니다.\n(레벨, 재화는 유지됩니다.)\n\n정말 다시 시작할까요?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCircleButton(
                      label: 'No',
                      color: Colors.grey,
                      icon: Icons.close,
                      onTap: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(width: 32),
                    _buildCircleButton(
                      label: 'Yes',
                      color: Colors.redAccent,
                      icon: Icons.check,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await widget.saveManager?.deleteSave();
                        await widget.saveManager?.clearCachedUpgradeLevels();
                        widget.onSelect(character, companion);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      widget.onSelect(character, companion);
    }
  }

  Widget _buildCircleButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        SfxManager.playUi('sfx_button.ogg', volume: 0.5);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth = math.min(
              constraints.maxWidth,
              CharacterSelectLayoutSpec.maxContentWidth,
            );
            return Center(
              child: SizedBox(
                width: contentWidth,
                child: _selectedCharacter == null
                    ? _buildCharacterSelectView()
                    : _buildCompanionSelectView(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildResponsiveGrid({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridDelegate = CharacterSelectLayoutSpec.createGridDelegate(
          constraints.maxWidth,
        );
        return GridView.builder(
          gridDelegate: gridDelegate,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }

  // ══════════════════════════════════════════
  // ═══ 정보 태그 헬퍼 ═══
  // ══════════════════════════════════════════
  Widget _infoTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // ═══ 이어서 하기 버튼 ═══
  // ══════════════════════════════════════════
  Widget _buildContinueButton() {
    final saveData = widget.saveManager?.loadGame();
    if (saveData == null) return const SizedBox.shrink();

    final charData = MbtiCharacters.getByType(saveData.character);
    final compData = MbtiCharacters.getByType(saveData.companion);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: () {
          SfxManager.playUi('sfx_button.ogg', volume: 0.5);
          widget.onContinue?.call(saveData);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                charData.color.withValues(alpha: 0.3),
                const Color(0xFF1A1A3E),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: charData.color.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: charData.color.withValues(alpha: 0.2),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              // 캐릭터 아이콘
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: charData.color.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: charData.color, width: 2),
                ),
                child: Center(
                  child: Text(
                    charData.mbti.substring(0, 2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 세이브 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '▶ 이어서 하기',
                      style: TextStyle(
                        color: charData.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${charData.mbti} ${charData.name} + ${compData.mbti}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _infoTag('Wave ${saveData.wave}', Colors.amber),
                        const SizedBox(width: 4),
                        _infoTag(
                          'HP ${saveData.hp.toInt()}',
                          Colors.greenAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _infoTag('HP Lv.${saveData.hpLevel}', Colors.redAccent),
                        const SizedBox(width: 4),
                        _infoTag(
                          'ATK Lv.${saveData.atkLevel}',
                          Colors.orangeAccent,
                        ),
                        const SizedBox(width: 4),
                        _infoTag(
                          'SPD Lv.${saveData.spdLevel}',
                          Colors.lightBlueAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 삭제 버튼 (확인 다이얼로그)
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A2E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        '세이브 삭제',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: const Text(
                        '저장된 게임 데이터를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text(
                            '취소',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            '삭제',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await widget.saveManager?.deleteSave();
                    await widget.saveManager?.clearCachedUpgradeLevels();
                    if (mounted) setState(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // ═══ 1단계: 캐릭터 선택 ═══
  // ══════════════════════════════════════════
  Widget _buildCharacterSelectView() {
    final hasSave = widget.saveManager?.hasSaveData ?? false;

    return Column(
      children: [
        const SizedBox(height: 20),
        // 타이틀 + 순위표 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF6B35)],
                ).createShader(bounds),
                child: const Text(
                  'MBTI 히어로',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const Spacer(),
              // 순위표 버튼
              GestureDetector(
                onTap: () {
                  if (widget.saveManager != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            LeaderboardScreen(saveManager: widget.saveManager!),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                      SizedBox(width: 4),
                      Text(
                        '순위',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 이어서 하기 버튼
        if (hasSave) _buildContinueButton(),
        const SizedBox(height: 4),
        const Text(
          '직장인 생존기',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white38,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '캐릭터를 선택하세요',
          style: TextStyle(fontSize: 14, color: Colors.white54),
        ),
        const SizedBox(height: 20),

        // 캐릭터 카드 그리드
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildResponsiveGrid(
              itemCount: MbtiCharacters.all.length,
              itemBuilder: (context, index) {
                // 해금된 캐릭터가 먼저 오도록 정렬
                final sorted = List<CharacterData>.from(MbtiCharacters.all)
                  ..sort((a, b) {
                    final aUnlocked = widget.unlockedCharacters.contains(
                      a.type,
                    );
                    final bUnlocked = widget.unlockedCharacters.contains(
                      b.type,
                    );
                    if (aUnlocked && !bUnlocked) return -1;
                    if (!aUnlocked && bUnlocked) return 1;
                    return 0;
                  });
                final character = sorted[index];
                final isUnlocked = widget.unlockedCharacters.contains(
                  character.type,
                );
                return _buildCharacterCard(
                  character,
                  isUnlocked,
                  isCompanion: false,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  // ═══ 2단계: 동료 선택 ═══
  // ══════════════════════════════════════════
  Widget _buildCompanionSelectView() {
    final mainChar = MbtiCharacters.getByType(_selectedCharacter!);

    return Column(
      children: [
        const SizedBox(height: 20),
        // 뒤로가기 + 선택한 캐릭터 표시
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedCharacter = null),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 선택한 캐릭터 뱃지
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: mainChar.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: mainChar.color.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mainChar.color,
                      ),
                      child: Center(
                        child: Text(
                          mainChar.mbti[0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${mainChar.mbti} ${mainChar.role}',
                      style: TextStyle(
                        color: mainChar.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '동료를 선택하세요',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'MBTI 궁합에 따라 동료 필살기 파워가 달라집니다',
          style: TextStyle(fontSize: 12, color: Colors.white38),
        ),
        const SizedBox(height: 16),

        // 동료 카드 그리드 (자기 자신 제외)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildResponsiveGrid(
              itemCount: MbtiCharacters.all
                  .where((c) => c.type != _selectedCharacter)
                  .length,
              itemBuilder: (context, index) {
                final companions = MbtiCharacters.all
                    .where((c) => c.type != _selectedCharacter)
                    .toList();
                final companion = companions[index];
                return _buildCompanionCard(companion, mainChar);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  // ═══ 캐릭터 카드 위젯 ═══
  // ══════════════════════════════════════════
  Widget _buildCharacterCard(
    CharacterData character,
    bool isUnlocked, {
    required bool isCompanion,
  }) {
    final isHovered = _hoveredType == character.type;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredType = character.type),
      onExit: (_) => setState(() => _hoveredType = null),
      child: GestureDetector(
        onTap: () {
          SfxManager.playUi('sfx_button.ogg', volume: 0.5);
          if (isUnlocked) {
            if (isCompanion) {
              // 동료 선택 시 onSelect 호출을 _handleNewGame으로 래핑
            } else {
              setState(() => _selectedCharacter = character.type);
            }
          } else {
            widget.onUnlockRequest(character.type);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: isHovered
              ? Matrix4.diagonal3Values(1.03, 1.03, 1.0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isUnlocked
                  ? [
                      character.color.withValues(alpha: 0.3),
                      character.color.withValues(alpha: 0.1),
                    ]
                  : [
                      Colors.grey.shade900,
                      Colors.grey.shade800.withValues(alpha: 0.5),
                    ],
            ),
            border: Border.all(
              color: isUnlocked
                  ? character.color.withValues(alpha: 0.6)
                  : Colors.grey.shade700,
              width: isHovered ? 2 : 1,
            ),
            boxShadow: isHovered && isUnlocked
                ? [
                    BoxShadow(
                      color: character.color.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // MBTI + 역할
                      SizedBox(
                        width: 90, // 고정 너비 제공하여 Row가 넘치지 않도록
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                character.mbti,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isUnlocked
                                      ? character.color
                                      : Colors.grey,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isUnlocked
                                      ? character.color.withValues(alpha: 0.2)
                                      : Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  character.role,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isUnlocked
                                        ? character.color
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        character.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnlocked
                              ? Colors.white70
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 캐릭터 아이콘 (스프라이트 첫 프레임 미리보기)
                      Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUnlocked
                                ? character.color.withValues(alpha: 0.1)
                                : Colors.grey.shade900,
                            border: Border.all(
                              color: isUnlocked
                                  ? character.color
                                  : Colors.grey.shade700,
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 스프라이트 이미지 표시 (캐릭터 이름 소문자 파일명 사용)
                              // 스프라이트 시트이므로 너비를 늘려서 첫번째 프레임만 보이거나
                              // BoxFit.none과 정렬을 통해 크롭해서 보여줍니다.
                              Opacity(
                                opacity: isUnlocked ? 1.0 : 0.3,
                                child: Transform.scale(
                                  scale: 1.5, // 확대해서 보여줌
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: ClipRect(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: 0.25, // 4프레임 중 첫번째 프레임만 표시
                                        child: Image.asset(
                                          'assets/images/characters/${character.type.name.toLowerCase()}.png',
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Icon(
                                                    Icons.person,
                                                    color: character.color,
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (!isUnlocked)
                                const Icon(
                                  Icons.lock,
                                  color: Colors.white,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 능력치 바
                      SizedBox(
                        width: 90, // 고정 너비
                        child: Column(
                          children: [
                            _buildStatBar(
                              'HP',
                              character.maxHp / 120, // max 120 (110 = 91%)
                              isUnlocked,
                              character.color,
                            ),
                            _buildStatBar(
                              'ATK',
                              character.attack / 10, // max 10 (9 = 90%)
                              isUnlocked,
                              character.color,
                            ),
                            _buildStatBar(
                              'SPD',
                              character.speed / 110, // max 110 (100 = 90%)
                              isUnlocked,
                              character.color,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 잠금 오버레이
              if (!isUnlocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, color: Colors.amber, size: 28),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.play_circle_outline,
                                color: Colors.amber,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '광고 해금',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  // ═══ 동료 카드 위젯 (궁합 표시) ═══
  // ══════════════════════════════════════════
  Widget _buildCompanionCard(CharacterData companion, CharacterData mainChar) {
    final grade = MbtiCompatibility.getGrade(
      _selectedCharacter!,
      companion.type,
    );
    final gradeLabel = MbtiCompatibility.getGradeLabel(grade);
    final gradeDesc = MbtiCompatibility.getGradeDescription(grade);
    final multiplier = MbtiCompatibility.getPowerMultiplier(grade);

    final gradeColor = switch (grade) {
      CompatibilityGrade.s => const Color(0xFFFFD700),
      CompatibilityGrade.a => const Color(0xFF69F0AE),
      CompatibilityGrade.b => const Color(0xFF90A4AE),
      CompatibilityGrade.c => const Color(0xFFEF5350),
    };

    final isHovered = _hoveredCompanion == companion.type;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredCompanion = companion.type),
      onExit: (_) => setState(() => _hoveredCompanion = null),
      child: GestureDetector(
        onTap: () {
          _handleNewGame(_selectedCharacter!, companion.type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: isHovered
              ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                companion.color.withValues(alpha: 0.25),
                companion.color.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(
              color: isHovered
                  ? companion.color.withValues(alpha: 0.8)
                  : companion.color.withValues(alpha: 0.5),
              width: isHovered ? 2 : 1,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: companion.color.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 궁합 등급 뱃지 + MBTI
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        companion.mbti,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: companion.color,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 궁합 뱃지
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gradeColor.withValues(alpha: 0.2),
                          border: Border.all(color: gradeColor, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            gradeLabel,
                            style: TextStyle(
                              color: gradeColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  companion.name,
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
                Text(
                  companion.role,
                  style: TextStyle(fontSize: 9, color: companion.color),
                ),
                const SizedBox(height: 4),

                // 캐릭터 원형 아이콘
                Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: companion.color.withValues(alpha: 0.3),
                      border: Border.all(color: companion.color, width: 2),
                    ),
                    child: Center(
                      child: ClipOval(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: 0.25,
                              child: Image.asset(
                                'assets/images/characters/${companion.type.name.toLowerCase()}.png',
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.person, color: companion.color),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // 파워 배율 표시
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '동료 파워 ${(multiplier * 100).toInt()}%',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: gradeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  gradeDesc,
                  style: const TextStyle(fontSize: 8, color: Colors.white38),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBar(
    String label,
    double ratio,
    bool isUnlocked,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isUnlocked ? Colors.white54 : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio.clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: isUnlocked ? color : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════
// ═══ 업그레이드 모달 다이얼로그 ═══
// ══════════════════════════════════════════
class _UpgradeDialog extends StatefulWidget {
  final SaveManager? saveManager;
  const _UpgradeDialog({required this.saveManager});

  @override
  State<_UpgradeDialog> createState() => _UpgradeDialogState();
}

class _UpgradeDialogState extends State<_UpgradeDialog> {
  late GlobalSaveData _data;

  int draftHp = 0;
  int draftAtk = 0;
  int draftSpd = 0;
  int spentBeans = 0;

  final int maxLevel = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final loaded =
        widget.saveManager?.loadGlobalData() ??
        const GlobalSaveData(
          coffeeBeans: 0,
          hpLevel: 0,
          attackLevel: 0,
          speedLevel: 0,
          unlockedCharacters: {},
        );
    setState(() {
      _data = loaded;
      draftHp = 0;
      draftAtk = 0;
      draftSpd = 0;
      spentBeans = 0;
    });
  }

  int _upgradeCost(int level) => (level + 1) * 200;

  int get currentBeans => _data.coffeeBeans - spentBeans;

  void _increment(String type) {
    int currentTotal;
    int cost;
    switch (type) {
      case 'hp':
        currentTotal = _data.hpLevel + draftHp;
        if (currentTotal >= maxLevel) return;
        cost = _upgradeCost(currentTotal);
        if (currentBeans >= cost) {
          setState(() {
            draftHp++;
            spentBeans += cost;
          });
        }
        break;
      case 'atk':
        currentTotal = _data.attackLevel + draftAtk;
        if (currentTotal >= maxLevel) return;
        cost = _upgradeCost(currentTotal);
        if (currentBeans >= cost) {
          setState(() {
            draftAtk++;
            spentBeans += cost;
          });
        }
        break;
      case 'spd':
        currentTotal = _data.speedLevel + draftSpd;
        if (currentTotal >= maxLevel) return;
        cost = _upgradeCost(currentTotal);
        if (currentBeans >= cost) {
          setState(() {
            draftSpd++;
            spentBeans += cost;
          });
        }
        break;
    }
  }

  void _decrement(String type) {
    int currentTotal;
    int costRefund;
    switch (type) {
      case 'hp':
        if (draftHp <= 0) return;
        currentTotal = _data.hpLevel + draftHp;
        costRefund = _upgradeCost(currentTotal - 1);
        setState(() {
          draftHp--;
          spentBeans -= costRefund;
        });
        break;
      case 'atk':
        if (draftAtk <= 0) return;
        currentTotal = _data.attackLevel + draftAtk;
        costRefund = _upgradeCost(currentTotal - 1);
        setState(() {
          draftAtk--;
          spentBeans -= costRefund;
        });
        break;
      case 'spd':
        if (draftSpd <= 0) return;
        currentTotal = _data.speedLevel + draftSpd;
        costRefund = _upgradeCost(currentTotal - 1);
        setState(() {
          draftSpd--;
          spentBeans -= costRefund;
        });
        break;
    }
  }

  void _applyAndSave() async {
    if (spentBeans == 0) {
      Navigator.pop(context);
      return;
    }

    await widget.saveManager?.saveGlobalData(
      coffeeBeans: _data.coffeeBeans - spentBeans,
      hpLevel: _data.hpLevel + draftHp,
      atkLevel: _data.attackLevel + draftAtk,
      spdLevel: _data.speedLevel + draftSpd,
      unlockedCharacters: _data.unlockedCharacters.map((e) => e.name).toList(),
    );

    if (mounted) {
      Navigator.pop(context, true); // trigger reload
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0A0A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '능력치 강화',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('☕', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text(
                  '$currentBeans',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '커피콩을 소모하여 모든 캐릭터의 기본 능력치를\n영구적으로 상승시킵니다. (+5% 씩 증가)',
              style: TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildUpgradeRow(
              icon: Icons.favorite,
              label: '체력 (HP)',
              baseLevel: _data.hpLevel,
              draftLevel: draftHp,
              color: Colors.greenAccent,
              onMinus: () => _decrement('hp'),
              onPlus: () => _increment('hp'),
            ),
            const SizedBox(height: 16),
            _buildUpgradeRow(
              icon: Icons.flash_on,
              label: '공격력 (ATK)',
              baseLevel: _data.attackLevel,
              draftLevel: draftAtk,
              color: Colors.redAccent,
              onMinus: () => _decrement('atk'),
              onPlus: () => _increment('atk'),
            ),
            const SizedBox(height: 16),
            _buildUpgradeRow(
              icon: Icons.speed,
              label: '이동속도 (SPD)',
              baseLevel: _data.speedLevel,
              draftLevel: draftSpd,
              color: Colors.lightBlueAccent,
              onMinus: () => _decrement('spd'),
              onPlus: () => _increment('spd'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: spentBeans > 0 ? _applyAndSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            '적용 및 닫기',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeRow({
    required IconData icon,
    required String label,
    required int baseLevel,
    required int draftLevel,
    required Color color,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    final currentTotal = baseLevel + draftLevel;
    final isMax = currentTotal >= maxLevel;
    final cost = isMax ? 0 : _upgradeCost(currentTotal);
    final canAfford = currentBeans >= cost;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  isMax ? 'MAX' : '비용: ☕ $cost',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: draftLevel > 0 ? onMinus : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.white54,
            disabledColor: Colors.white24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text(
              isMax ? 'MAX' : 'Lv.$currentTotal',
              style: TextStyle(
                color: draftLevel > 0 ? Colors.amber : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),

          IconButton(
            onPressed: (canAfford && !isMax) ? onPlus : null,
            icon: const Icon(Icons.add_circle_outline),
            color: color,
            disabledColor: Colors.white24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
