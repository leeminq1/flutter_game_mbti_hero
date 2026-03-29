import 'package:flutter/material.dart';
import '../game/mbti_game.dart';
import '../services/save_manager.dart';

/// 결과 화면 (승리 / 패배) - 광고 게이트 방식
class ResultOverlay extends StatefulWidget {
  final MbtiGame game;
  final bool isVictory;
  final VoidCallback onRetry;
  final VoidCallback onLobby;

  const ResultOverlay({
    super.key,
    required this.game,
    required this.isVictory,
    required this.onRetry,
    required this.onLobby,
  });

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay> {
  bool _adWatched = false;
  bool _watchingAd = false;
  bool _recordSaved = false;

  void _watchAd() async {
    if (_watchingAd) return;
    setState(() => _watchingAd = true);

    // AdManager Mock (나중에 실제 AdMob 연동)
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _adWatched = true;
        _watchingAd = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isVictory ? Colors.amber : Colors.red.shade800,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isVictory ? Colors.amber : Colors.red)
                    .withValues(alpha: 0.3),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘
              Icon(
                widget.isVictory ? Icons.celebration : Icons.nightlight_round,
                size: 56,
                color: widget.isVictory ? Colors.amber : Colors.red.shade400,
              ),
              const SizedBox(height: 12),

              // 메인 텍스트
              Text(
                widget.isVictory ? '퇴근 성공!' : '야근 확정...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: widget.isVictory ? Colors.amber : Colors.red.shade400,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.isVictory ? 'Victory!' : 'Game Over...',
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 8),

              // 웨이브 정보
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Wave ${widget.game.gameState.currentWave} / ${widget.game.gameState.totalWaves}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 버튼 영역 (2-phase)
              if (!_adWatched) ...[
                // Phase 1: 광고 보고 다시하기
                GestureDetector(
                  onTap: _watchingAd ? null : _watchAd,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _watchingAd
                            ? [Colors.grey.shade700, Colors.grey.shade800]
                            : [Colors.amber.shade700, Colors.orange.shade800],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _watchingAd
                              ? Icons.hourglass_top
                              : Icons.play_circle_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _watchingAd ? '광고 시청 중...' : '📺 광고 보고 다시하기',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 기록 저장 버튼
                if (!_recordSaved)
                  GestureDetector(
                    onTap: () => _showSaveRecordDialog(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.cyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: Colors.cyan, size: 16),
                          SizedBox(width: 6),
                          Text(
                            '🏆 기록 저장',
                            style: TextStyle(
                              color: Colors.cyan,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          '기록 저장 완료!',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                // 로비로 (광고 없이 가능)
                GestureDetector(
                  onTap: widget.onLobby,
                  child: const Text(
                    '로비로 돌아가기',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ] else ...[
                // Phase 2: 광고 시청 완료 → 다시하기 / 로비
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: _buildButton(
                        label: '다시하기',
                        icon: Icons.replay,
                        color: Colors.amber,
                        onTap: widget.onRetry,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: _buildButton(
                        label: '로비',
                        icon: Icons.home,
                        color: Colors.white54,
                        onTap: widget.onLobby,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSaveRecordDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A3E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
              const SizedBox(height: 12),
              const Text(
                '기록 저장',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Wave ${widget.game.gameState.currentWave} | ☕ ${widget.game.gameState.totalCoffeeEarned}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                maxLength: 12,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: '닉네임 입력',
                  hintStyle: const TextStyle(color: Colors.white38),
                  counterStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.cyan.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.cyan.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyan),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            '취소',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx);
                        await _saveRecord(name);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.cyan.shade600,
                              Colors.cyan.shade800,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            '저장',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveRecord(String name) async {
    final game = widget.game;
    final entry = LeaderboardEntry(
      playerName: name,
      character: game.gameState.selectedCharacter,
      companion: game.gameState.selectedCompanion,
      wave: game.gameState.currentWave,
      score: game.gameState.totalCoffeeEarned,
      dateTime: DateTime.now().toIso8601String(),
    );
    await game.saveManager?.addLeaderboardEntry(entry);
    if (mounted) {
      setState(() => _recordSaved = true);
    }
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 일시정지 오버레이
class PauseOverlay extends StatelessWidget {
  final MbtiGame game;
  final VoidCallback? onLobby;

  const PauseOverlay({super.key, required this.game, this.onLobby});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '일시정지',
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // 계속하기 버튼
              GestureDetector(
                onTap: () {
                  game.gameState.togglePause();
                  game.resumeGameplayIfAllowed(reason: 'pause_overlay');
                  game.overlays.remove('Pause');
                },
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '계속하기',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 로비로 돌아가기 버튼
              GestureDetector(
                onTap: () {
                  game.overlays.remove('Pause');
                  game.returnToLobby(); // autoSave() 호출 후 로비로
                },
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '로비로',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
}
