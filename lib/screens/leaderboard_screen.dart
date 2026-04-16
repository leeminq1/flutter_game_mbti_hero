import 'package:flutter/material.dart';

import '../game/config/character_data.dart';
import '../services/leaderboard_repository.dart';
import '../services/leaderboard_types.dart';
import '../services/save_manager.dart';

class LeaderboardScreen extends StatefulWidget {
  final LeaderboardRepository leaderboardRepository;

  const LeaderboardScreen({super.key, required this.leaderboardRepository});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<LeaderboardLoadResult<List<LeaderboardEntry>>> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.leaderboardRepository.loadLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: FutureBuilder<LeaderboardLoadResult<List<LeaderboardEntry>>>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );
            }

            final result =
                snapshot.data ??
                const LeaderboardLoadResult<List<LeaderboardEntry>>(
                  entries: <LeaderboardEntry>[],
                  source: LeaderboardSource.local,
                  usedFallback: false,
                );

            final entries = result.entries;

            return Column(
              children: [
                const SizedBox(height: 16),
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
                          '랭킹',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildSourceBadge(result),
                      const SizedBox(width: 8),
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
                            '닉네임',
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
                            '점수',
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
                Expanded(
                  child: entries.isEmpty
                      ? _buildEmptyState(result)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            return _buildEntryRow(entries[index], index + 1);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSourceBadge(
    LeaderboardLoadResult<List<LeaderboardEntry>> result,
  ) {
    final isRemote = result.source == LeaderboardSource.remote;
    final label = isRemote ? '온라인' : '로컬 랭킹';
    final color = isRemote ? Colors.cyanAccent : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        result.usedFallback ? '$label (폴백)' : label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    LeaderboardLoadResult<List<LeaderboardEntry>> result,
  ) {
    final subtitle = result.source == LeaderboardSource.remote
        ? '아직 온라인 랭킹 기록이 없습니다.'
        : '오프라인 상태라 로컬 랭킹만 표시 중입니다.';

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
            '아직 저장된 기록이 없습니다',
            style: TextStyle(color: Colors.white38, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white24, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(LeaderboardEntry entry, int rank) {
    final charData = MbtiCharacters.getByType(entry.character);

    Color rankColor;
    Color bgColor;
    IconData? medalIcon;
    switch (rank) {
      case 1:
        rankColor = const Color(0xFFFFD700);
        bgColor = const Color(0xFFFFD700).withValues(alpha: 0.08);
        medalIcon = Icons.emoji_events;
        break;
      case 2:
        rankColor = const Color(0xFFC0C0C0);
        bgColor = const Color(0xFFC0C0C0).withValues(alpha: 0.06);
        medalIcon = Icons.emoji_events;
        break;
      case 3:
        rankColor = const Color(0xFFCD7F32);
        bgColor = const Color(0xFFCD7F32).withValues(alpha: 0.06);
        medalIcon = Icons.emoji_events;
        break;
      default:
        rankColor = Colors.white38;
        bgColor = Colors.transparent;
        medalIcon = null;
    }

    String dateStr = '';
    try {
      final dt = DateTime.parse(entry.dateTime).toLocal();
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
