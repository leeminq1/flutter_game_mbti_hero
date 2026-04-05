import 'package:flutter/material.dart';

import '../game/components/enemies/base_enemy.dart';
import '../game/components/enemies/mbti_boss_enemy.dart';
import '../game/config/wave_data.dart';
import '../game/managers/game_state.dart';
import '../game/mbti_game.dart';

class HudOverlay extends StatelessWidget {
  static const double _reservedRightHudWidth = 180;

  final GameState gameState;
  final MbtiGame game;

  const HudOverlay({super.key, required this.gameState, required this.game});

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildLeftSection()),
                    const SizedBox(width: 8),
                    _buildWaveSection(),
                  ],
                ),
                if (_bossEntries.isNotEmpty) _buildBossRoster(),
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
        Row(
          children: [
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
        Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_cafe_rounded,
                  size: 15,
                  color: Color(0xFFEAD7A1),
                ),
                const SizedBox(width: 4),
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
            'EN ${gameState.enemiesRemaining}',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  List<_BossHudEntry> get _bossEntries {
    final entries = <_BossHudEntry>[];
    for (final enemy in game.activeEnemies) {
      if (!enemy.isBoss || enemy.maxHp <= 0) {
        continue;
      }

      entries.add(
        _BossHudEntry(
          label: _resolveBossLabel(enemy),
          ratio: (enemy.currentHp / enemy.maxHp).clamp(0.0, 1.0).toDouble(),
          color: _resolveBossColor(enemy),
        ),
      );
    }
    return entries;
  }

  Widget _buildBossRoster() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final reservedWidth = constraints.maxWidth > 420
              ? _reservedRightHudWidth
              : 152.0;
          final availableWidth = (constraints.maxWidth - reservedWidth)
              .clamp(140.0, constraints.maxWidth)
              .toDouble();
          final cardWidth = _bossEntries.length > 1
              ? ((availableWidth - 8) / 2).clamp(104.0, 176.0).toDouble()
              : availableWidth.clamp(146.0, 248.0).toDouble();

          return Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: availableWidth,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bossEntries
                    .map(
                      (entry) => SizedBox(
                        width: cardWidth,
                        child: _BossHpCard(entry: entry),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  String _resolveBossLabel(BaseEnemy enemy) {
    if (enemy is MbtiBossEnemy) {
      return '${enemy.characterData.mbti} ${enemy.characterData.name}';
    }
    final title = enemy.definition.bossTitle;
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return enemy.type.name.toUpperCase();
  }

  Color _resolveBossColor(BaseEnemy enemy) {
    if (enemy is MbtiBossEnemy) {
      return enemy.characterData.color;
    }
    if (enemy.type == EnemyType.finalBoss) {
      return Colors.deepOrangeAccent;
    }
    return Colors.redAccent;
  }
}

class _BossHudEntry {
  final String label;
  final double ratio;
  final Color color;

  const _BossHudEntry({
    required this.label,
    required this.ratio,
    required this.color,
  });
}

class _BossHpCard extends StatelessWidget {
  final _BossHudEntry entry;

  const _BossHpCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final ratio = entry.ratio.clamp(0.0, 1.0);
    final hpColor = entry.color;

    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hpColor.withValues(alpha: 0.9), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: hpColor.withValues(alpha: 0.22),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hpColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  Container(height: 12, color: Colors.white10),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            hpColor.withValues(alpha: 0.95),
                            Colors.orangeAccent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${(ratio * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
