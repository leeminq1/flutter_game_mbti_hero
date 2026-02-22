import 'package:flutter/material.dart';
import '../game/mbti_game.dart';

class CountdownOverlay extends StatefulWidget {
  final MbtiGame game;

  const CountdownOverlay({super.key, required this.game});

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay>
    with SingleTickerProviderStateMixin {
  int _count = 3;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(
      begin: 2.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );

    _startCountdown();
  }

  Future<void> _startCountdown() async {
    for (int i = 3; i > 0; i--) {
      if (mounted) {
        setState(() => _count = i);
        _controller.forward(from: 0.0);
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() => _count = 0); // 0 = START
      _controller.forward(from: 0.0);
    }
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      if (widget.game.paused) {
        widget.game.resumeEngine(); // 게임 재개 (몬스터, 캐릭터 동작 시작)
      }
      widget.game.overlays.remove('Countdown');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Text(
                  _count > 0 ? '$_count' : 'START!',
                  style: TextStyle(
                    fontSize: _count > 0 ? 120 : 80,
                    fontWeight: FontWeight.w900,
                    color: _count > 0 ? Colors.amber : Colors.greenAccent,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(
                        color: (_count > 0 ? Colors.amber : Colors.greenAccent)
                            .withValues(alpha: 0.5),
                        blurRadius: 30,
                      ),
                      const Shadow(
                        color: Colors.black,
                        blurRadius: 10,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
