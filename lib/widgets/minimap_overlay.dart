import 'dart:async';

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';

import '../game/components/enemies/base_enemy.dart';
import '../game/mbti_game.dart';

class MiniMapOverlay extends StatefulWidget {
  final MbtiGame game;

  const MiniMapOverlay({super.key, required this.game});

  @override
  State<MiniMapOverlay> createState() => _MiniMapOverlayState();
}

class _MiniMapOverlayState extends State<MiniMapOverlay> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    if (!game.isLoaded) {
      return const SizedBox.shrink();
    }

    Vector2 playerPosition;
    try {
      playerPosition = game.player.position.clone();
    } catch (_) {
      return const SizedBox.shrink();
    }

    final enemies = List<BaseEnemy>.from(game.activeEnemies);
    final bossCount = enemies.where((enemy) => enemy.isBoss).length;

    return IgnorePointer(
      child: RepaintBoundary(
        child: Container(
          width: 112,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xCC101626),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'MAP',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    bossCount > 0 ? 'BOSS' : '${enemies.length}',
                    style: TextStyle(
                      color: bossCount > 0 ? Colors.redAccent : Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AspectRatio(
                aspectRatio: 1,
                child: CustomPaint(
                  painter: _MiniMapPainter(
                    mapSize: game.mapSize.clone(),
                    viewportSize: game.size.clone(),
                    playerPosition: playerPosition,
                    enemyPositions: enemies.map((enemy) => enemy.position.clone()).toList(),
                    bossPositions: enemies
                        .where((enemy) => enemy.isBoss)
                        .map((enemy) => enemy.position.clone())
                        .toList(),
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

class _MiniMapPainter extends CustomPainter {
  final Vector2 mapSize;
  final Vector2 viewportSize;
  final Vector2 playerPosition;
  final List<Vector2> enemyPositions;
  final List<Vector2> bossPositions;

  _MiniMapPainter({
    required this.mapSize,
    required this.viewportSize,
    required this.playerPosition,
    required this.enemyPositions,
    required this.bossPositions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mapRect = Offset.zero & size;
    final background = Paint()..color = const Color(0xFF0A0F19);
    final border = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(mapRect, const Radius.circular(10)),
      background,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mapRect, const Radius.circular(10)),
      border,
    );

    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4;
      final dy = size.height * i / 4;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }

    final viewportRect = Rect.fromCenter(
      center: _mapToCanvas(playerPosition, size),
      width: (viewportSize.x / mapSize.x).clamp(0.08, 1.0) * size.width,
      height: (viewportSize.y / mapSize.y).clamp(0.08, 1.0) * size.height,
    ).intersect(mapRect.deflate(1));
    final viewportPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(viewportRect, viewportPaint);

    final enemyPaint = Paint()..color = const Color(0xFFFFD54F);
    for (final enemy in enemyPositions) {
      canvas.drawCircle(_mapToCanvas(enemy, size), 1.8, enemyPaint);
    }

    final bossPaint = Paint()..color = Colors.redAccent;
    for (final boss in bossPositions) {
      canvas.drawCircle(_mapToCanvas(boss, size), 3.2, bossPaint);
    }

    final playerPaint = Paint()..color = const Color(0xFF4DD0E1);
    canvas.drawCircle(_mapToCanvas(playerPosition, size), 3, playerPaint);
  }

  Offset _mapToCanvas(Vector2 world, Size size) {
    final x = (world.x / mapSize.x).clamp(0.0, 1.0) * size.width;
    final y = (world.y / mapSize.y).clamp(0.0, 1.0) * size.height;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) {
    return true;
  }
}
