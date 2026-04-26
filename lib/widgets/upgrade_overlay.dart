import 'dart:async';

import 'package:flutter/material.dart';

import '../game/components/player.dart';
import '../game/mbti_game.dart';

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

  final int maxLevel = 10;
  static const int _healCost = 180;
  static const int _ultPassCost = 260;
  static const int _assistPassCost = 220;

  @override
  void initState() {
    super.initState();
    final gs = widget.game.gameState;
    baseHp = gs.hpLevel;
    baseAtk = gs.attackLevel;
    baseSpd = gs.speedLevel;
  }

  int _upgradeCost(int level) => (level + 1) * 200;

  int get currentBeans => widget.game.gameState.coffeeBeans - spentBeans;
  bool get _canBuyHeal =>
      currentBeans >= _healCost &&
      widget.game.player.currentHp < widget.game.player.maxHp - 0.5;
  bool get _canBuyUltTicket => currentBeans >= _ultPassCost;
  bool get _canBuyAssistTicket => currentBeans >= _assistPassCost;

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

  void _buyHeal() {
    if (!_canBuyHeal) return;
    widget.game.gameState.spendCoffeeBeans(_healCost);
    widget.game.player.heal(widget.game.player.maxHp * 0.45);
    unawaited(widget.game.autoSave());
    setState(() {});
  }

  void _buyUltPass() {
    if (!_canBuyUltTicket) return;
    widget.game.gameState.spendCoffeeBeans(_ultPassCost);
    widget.game.gameState.addUltTicket();
    unawaited(widget.game.autoSave());
    setState(() {});
  }

  void _buyAssistPass() {
    if (!_canBuyAssistTicket) return;
    widget.game.gameState.spendCoffeeBeans(_assistPassCost);
    widget.game.gameState.addAssistTicket();
    unawaited(widget.game.autoSave());
    setState(() {});
  }

  void _applyAndContinue() {
    final gs = widget.game.gameState;

    if (spentBeans > 0) {
      gs.spendCoffeeBeans(spentBeans);
    }

    if (draftHp > 0) {
      for (int i = 0; i < draftHp; i++) {
        gs.upgradeHp();
      }
      widget.game.player.applyPermanentHpUpgrade(
        Player.hpUpgradePerLevel * draftHp,
      );
    }

    if (draftAtk > 0) {
      for (int i = 0; i < draftAtk; i++) {
        gs.upgradeAttack();
      }
      widget.game.player.applyPermanentAttackUpgrade(
        Player.attackUpgradePerLevel * draftAtk,
      );
    }

    if (draftSpd > 0) {
      for (int i = 0; i < draftSpd; i++) {
        gs.upgradeSpeed();
      }
      widget.game.player.applyPermanentSpeedUpgrade(
        Player.speedUpgradePerLevel * draftSpd,
      );
    }

    unawaited(widget.game.autoSave());

    widget.game.overlays.remove('Upgrade');
    widget.game.resumeGameplayIfAllowed(reason: 'upgrade_overlay');
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 6),
                const Text(
                  '전투 중 아이템 강화와 별개로,\n아래는 현재 플레이의 보스 보상 강화입니다.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
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
                      const Icon(
                        Icons.local_cafe_rounded,
                        color: Color(0xFFEAD7A1),
                        size: 18,
                      ),
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
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '긴급 지원',
                    style: TextStyle(
                      color: Colors.amber.shade200,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildUtilityButton(
                  icon: Icons.favorite,
                  label: '응급 회복',
                  description:
                      widget.game.player.currentHp >=
                          widget.game.player.maxHp - 0.5
                      ? '체력이 이미 MAX입니다'
                      : '현재 체력 45% 회복',
                  cost: _healCost,
                  color: Colors.greenAccent,
                  enabled: _canBuyHeal,
                  onTap: _buyHeal,
                ),
                const SizedBox(height: 8),
                _buildUtilityButton(
                  icon: Icons.bolt,
                  label: 'ULT 이용권',
                  description: '필살기를 쿨다운과 무관하게 1회 사용',
                  cost: _ultPassCost,
                  color: Colors.orangeAccent,
                  enabled: _canBuyUltTicket,
                  ownedCount: widget.game.gameState.ultTicketCount,
                  onTap: _buyUltPass,
                ),
                const SizedBox(height: 8),
                _buildUtilityButton(
                  icon: Icons.groups_2,
                  label: 'ASSIST 이용권',
                  description: '동료 호출을 쿨다운과 무관하게 1회 사용',
                  cost: _assistPassCost,
                  color: Colors.cyanAccent,
                  enabled: _canBuyAssistTicket,
                  ownedCount: widget.game.gameState.assistTicketCount,
                  onTap: _buyAssistPass,
                ),
                const SizedBox(height: 24),
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
                        spentBeans > 0 ? '적용 후 계속하기' : '게임으로 돌아가기',
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
                Row(
                  children: [
                    const Icon(
                      Icons.local_cafe_rounded,
                      size: 13,
                      color: Color(0xFFEAD7A1),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMax ? 'MAX' : '$cost',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
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

  Widget _buildUtilityButton({
    required IconData icon,
    required String label,
    required String description,
    required int cost,
    required Color color,
    required bool enabled,
    int ownedCount = 0,
    required VoidCallback onTap,
  }) {
    final canAfford = currentBeans >= cost && enabled;
    final isDisabled = !enabled;

    return GestureDetector(
      onTap: canAfford ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.white.withValues(alpha: 0.04)
              : color.withValues(alpha: canAfford ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? Colors.white12
                : canAfford
                ? color.withValues(alpha: 0.45)
                : Colors.white24,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDisabled
                  ? Colors.white24
                  : canAfford
                  ? color
                  : Colors.white38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isDisabled
                          ? Colors.white38
                          : canAfford
                          ? Colors.white
                          : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: isDisabled ? Colors.white38 : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isDisabled)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '불가',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isDisabled)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'MAX',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else ...[
              if (ownedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'x$ownedCount',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              const Icon(
                Icons.local_cafe_rounded,
                size: 14,
                color: Color(0xFFEAD7A1),
              ),
              const SizedBox(width: 4),
              Text(
                '$cost',
                style: TextStyle(
                  color: canAfford ? Colors.amber : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
