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
      await _waitUntilAppActive();
      if (!mounted) {
        return;
      }

      if (mounted) {
        setState(() => _count = i);
        _controller.forward(from: 0.0);
      }
      await _delayRespectingLifecycle(const Duration(seconds: 1));
    }

    await _waitUntilAppActive();
    if (!mounted) {
      return;
    }

    if (mounted) {
      setState(() => _count = 0); // 0 = START
      _controller.forward(from: 0.0);
    }
    await _delayRespectingLifecycle(const Duration(milliseconds: 800));

    if (mounted) {
      if (widget.game.isAwaitingResumeConfirmation) {
        widget.game.overlays.remove('Countdown');
        return;
      }
      if (widget.game.paused) {
        widget.game.resumeGameplayIfAllowed(
          reason: 'countdown_overlay',
          consumeCountdownAuthorization: true,
        );
      }
      widget.game.overlays.remove('Countdown');
    }
  }

  Future<void> _waitUntilAppActive() async {
    while (mounted &&
        (!widget.game.isAppLifecycleActive ||
            widget.game.isAwaitingResumeConfirmation)) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _delayRespectingLifecycle(Duration duration) async {
    var remaining = duration;
    const slice = Duration(milliseconds: 100);

    while (mounted && remaining > Duration.zero) {
      await _waitUntilAppActive();
      if (!mounted) {
        return;
      }

      final current = remaining > slice ? slice : remaining;
      await Future.delayed(current);
      remaining -= current;
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
