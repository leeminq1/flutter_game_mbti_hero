import 'package:flutter/material.dart';
import '../game/managers/game_state.dart';

/// HUD 오버레이 - HP바, 커피, 웨이브 정보
class HudOverlay extends StatelessWidget {
  final GameState gameState;

  const HudOverlay({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gameState,
      builder: (context, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상단 행: 좌측(캐릭터+HP) / 우측(웨이브)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 좌측: 캐릭터 아이콘 + HP바 + 커피
                    Expanded(child: _buildLeftSection()),

                    const SizedBox(width: 8),

                    // 우측: 웨이브 정보 (고정 크기)
                    _buildWaveSection(),
                  ],
                ),

                // 보스 HP바 (보스 활성 시)
                if (gameState.bossActive) _buildBossHpBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftSection() {
    final isLowHp = gameState.hpRatio < 0.3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 캐릭터 아이콘 + 이름 + HP바
        Row(
          children: [
            // 캐릭터 아이콘
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: gameState.characterData.color,
                border: Border.all(color: Colors.white24, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: gameState.characterData.color.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  gameState.characterData.mbti[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // MBTI 이름 + HP 바
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gameState.characterData.mbti,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 130,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: isLowHp ? Colors.red : Colors.white24,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: gameState.hpRatio,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isLowHp
                                    ? [Colors.red.shade900, Colors.red]
                                    : [
                                        Colors.green.shade700,
                                        Colors.greenAccent,
                                      ],
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${gameState.currentHp.toInt()} / ${gameState.maxHp.toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 4),

        // 커피콩 (HP바 아래에 표시)
        Padding(
          padding: const EdgeInsets.only(left: 44), // 아이콘 너비 + 간격만큼 들여쓰기
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('☕', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 3),
                Text(
                  '${gameState.coffeeBeans}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'W${gameState.currentWave}/${gameState.totalWaves}',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '적: ${gameState.enemiesRemaining}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBossHpBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Text(
            '🔥 ${gameState.bossName} 🔥',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 240,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade800, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: gameState.bossHpRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade900, Colors.orange.shade700],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${(gameState.bossHpRatio * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
