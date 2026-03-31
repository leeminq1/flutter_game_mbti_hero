import 'package:flutter/material.dart';
import '../game/mbti_game.dart';

/// 보스 처치 후 강화 오버레이
class UpgradeOverlay extends StatefulWidget {
  final MbtiGame game;

  const UpgradeOverlay({super.key, required this.game});

  @override
  State<UpgradeOverlay> createState() => _UpgradeOverlayState();
}

class _UpgradeOverlayState extends State<UpgradeOverlay> {
  late int baseHp;
  late int baseAtk;
  late int baseSpd;

  int draftHp = 0;
  int draftAtk = 0;
  int draftSpd = 0;
  int spentBeans = 0;

  final int maxLevel = 7;

  @override
  void initState() {
    super.initState();
    final gs = widget.game.gameState;
    baseHp = gs.hpLevel;
    baseAtk = gs.attackLevel;
    baseSpd = gs.speedLevel;
  }

  // 강화 비용: (레벨 + 1) * 100 (기존 50에서 2배 증가)
  int _upgradeCost(int level) => (level + 1) * 100;

  int get currentBeans => widget.game.gameState.coffeeBeans - spentBeans;

  void _increment(String type) {
    int currentTotal;
    int cost;
    switch (type) {
      case 'hp':
        currentTotal = baseHp + draftHp;
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
        currentTotal = baseAtk + draftAtk;
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
        currentTotal = baseSpd + draftSpd;
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
        currentTotal = baseHp + draftHp;
        costRefund = _upgradeCost(currentTotal - 1);
        setState(() {
          draftHp--;
          spentBeans -= costRefund;
        });
        break;
      case 'atk':
        if (draftAtk <= 0) return;
        currentTotal = baseAtk + draftAtk;
        costRefund = _upgradeCost(currentTotal - 1);
        setState(() {
          draftAtk--;
          spentBeans -= costRefund;
        });
        break;
      case 'spd':
        if (draftSpd <= 0) return;
        currentTotal = baseSpd + draftSpd;
        costRefund = _upgradeCost(currentTotal - 1);
        setState(() {
          draftSpd--;
          spentBeans -= costRefund;
        });
        break;
    }
  }

  void _applyAndContinue() {
    final gs = widget.game.gameState;

    // 실제 비용 지불
    if (spentBeans > 0) {
      gs.spendCoffeeBeans(spentBeans);
    }

    // HP 적용
    if (draftHp > 0) {
      for (int i = 0; i < draftHp; i++) {
        gs.upgradeHp();
      }
      final hpBonus = 20.0 * draftHp;
      widget.game.player.maxHp += hpBonus;
      widget.game.player.currentHp = widget.game.player.maxHp;
      gs.syncHp(
        current: widget.game.player.currentHp,
        max: widget.game.player.maxHp,
      );
    }

    // ATK 적용
    if (draftAtk > 0) {
      for (int i = 0; i < draftAtk; i++) {
        gs.upgradeAttack();
      }
      widget.game.player.attackPower += (3 * draftAtk);
    }

    // SPD 적용
    if (draftSpd > 0) {
      for (int i = 0; i < draftSpd; i++) {
        gs.upgradeSpeed();
      }
      widget.game.player.speed += (10 * draftSpd);
    }

    if (spentBeans > 0) {
      _saveGlobal();
    }

    widget.game.overlays.remove('Upgrade');
    widget.game.resumeGameplayIfAllowed(reason: 'upgrade_overlay');
  }

  void _saveGlobal() {
    widget.game.saveManager?.saveGlobalData(
      coffeeBeans: widget.game.gameState.coffeeBeans,
      hpLevel: widget.game.gameState.hpLevel,
      atkLevel: widget.game.gameState.attackLevel,
      spdLevel: widget.game.gameState.speedLevel,
      unlockedCharacters: widget.game.gameState.unlockedCharacters
          .map((c) => c.name)
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 350),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A3E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 타이틀
              const Icon(Icons.star, color: Colors.amber, size: 40),
              const SizedBox(height: 8),
              const Text(
                '보스 처치!',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '커피콩을 분배하여 능력을 강화하세요',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),

              // 보유 커피
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('☕', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      '$currentBeans',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 강화 항목들
              _buildUpgradeRow(
                icon: Icons.favorite,
                label: 'HP',
                baseLevel: baseHp,
                draftLevel: draftHp,
                color: Colors.redAccent,
                onMinus: () => _decrement('hp'),
                onPlus: () => _increment('hp'),
              ),
              const SizedBox(height: 8),
              _buildUpgradeRow(
                icon: Icons.flash_on,
                label: 'ATK',
                baseLevel: baseAtk,
                draftLevel: draftAtk,
                color: Colors.orangeAccent,
                onMinus: () => _decrement('atk'),
                onPlus: () => _increment('atk'),
              ),
              const SizedBox(height: 8),
              _buildUpgradeRow(
                icon: Icons.speed,
                label: 'SPD',
                baseLevel: baseSpd,
                draftLevel: draftSpd,
                color: Colors.lightBlueAccent,
                onMinus: () => _decrement('spd'),
                onPlus: () => _increment('spd'),
              ),

              const SizedBox(height: 24),

              // 계속하기 버튼 (적용)
              GestureDetector(
                onTap: _applyAndContinue,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      spentBeans > 0 ? '적용 및 계속하기' : '게임으로 돌아가기',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

          // 마이너스 버튼
          IconButton(
            onPressed: draftLevel > 0 ? onMinus : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.white54,
            disabledColor: Colors.white24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          // 현재 레벨 표시
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

          // 플러스 버튼
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
