import 'package:flutter/material.dart';
import '../game/config/character_data.dart';
import '../services/save_manager.dart';

/// 리더보드 화면
class LeaderboardScreen extends StatelessWidget {
  final SaveManager saveManager;

  const LeaderboardScreen({super.key, required this.saveManager});

  @override
  Widget build(BuildContext context) {
    final entries = saveManager.loadLeaderboard();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
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
                  const SizedBox(width: 16),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF6B35)],
                    ).createShader(bounds),
                    child: const Text(
                      '🏆 순위표',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '총 ${entries.length}개 기록',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 테이블 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '#',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '이름',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '캐릭터',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(
                        'Wave',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '☕ 점수',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 리스트
            Expanded(
              child: entries.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return _buildEntryRow(entries[index], index + 1);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            '아직 기록이 없습니다',
            style: TextStyle(color: Colors.white38, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            '게임을 플레이하고 기록을 남겨보세요!',
            style: TextStyle(color: Colors.white24, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(LeaderboardEntry entry, int rank) {
    final charData = MbtiCharacters.getByType(entry.character);

    // 순위별 색상
    Color rankColor;
    Color bgColor;
    IconData? medalIcon;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD700); // 금
        bgColor = const Color(0xFFFFD700).withValues(alpha: 0.08);
        medalIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = const Color(0xFFC0C0C0); // 은
        bgColor = const Color(0xFFC0C0C0).withValues(alpha: 0.06);
        medalIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32); // 동
        bgColor = const Color(0xFFCD7F32).withValues(alpha: 0.06);
        medalIcon = Icons.emoji_events;
        break;
      default:
        rankColor = Colors.white38;
        bgColor = Colors.transparent;
        medalIcon = null;
    }

    // 날짜 포맷
    String dateStr = '';
    try {
      final dt = DateTime.parse(entry.dateTime);
      dateStr =
          '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      dateStr = '';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: rank <= 3
            ? Border.all(color: rankColor.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        children: [
          // 순위
          SizedBox(
            width: 30,
            child: medalIcon != null
                ? Icon(medalIcon, color: rankColor, size: 18)
                : Text(
                    '$rank',
                    style: TextStyle(
                      color: rankColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          // 이름
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.playerName,
                  style: TextStyle(
                    color: rank <= 3 ? rankColor : Colors.white,
                    fontSize: 14,
                    fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
              ],
            ),
          ),
          // 캐릭터
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: charData.color.withValues(alpha: 0.3),
                    border: Border.all(color: charData.color, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      charData.mbti[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    charData.mbti,
                    style: TextStyle(
                      color: charData.color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // 웨이브
          SizedBox(
            width: 50,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'W${entry.wave}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // 점수
          SizedBox(
            width: 60,
            child: Text(
              '${entry.score}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: rank <= 3 ? rankColor : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
