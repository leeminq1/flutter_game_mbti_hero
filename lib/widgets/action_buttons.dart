import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import '../game/mbti_game.dart';

/// 공격 & 필살기 버튼 + 조이스틱 오버레이
class ActionOverlay extends StatefulWidget {
  final MbtiGame game;

  const ActionOverlay({super.key, required this.game});

  @override
  State<ActionOverlay> createState() => _ActionOverlayState();
}

class _ActionOverlayState extends State<ActionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // 조이스틱 상태
  // 조이스틱 위치
  static const double _joystickRadius = 50;
  static const double _knobRadius = 20;
  Offset _joystickCenter = const Offset(_joystickRadius, _joystickRadius);
  Offset _joystickKnob = const Offset(_joystickRadius, _joystickRadius);
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // === 좌측: 조이스틱 ===
        Positioned(left: 40, bottom: 150, child: _buildJoystick()),

        // === 우측: 공격/필살기 버튼 ===
        Positioned(right: 40, bottom: 150, child: _buildActionButtons()),

        // === 우측 중단: 일시정지 버튼 (Wave 정보 아래) ===
        Positioned(right: 16, top: 70, child: _buildPauseButton()),
      ],
    );
  }

  /// 조이스틱 위젯
  Widget _buildJoystick() {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
          _joystickCenter = const Offset(_joystickRadius, _joystickRadius);
          _joystickKnob = _joystickCenter;
        });
      },
      onPanUpdate: (details) {
        final offset = details.localPosition;
        final delta = offset - _joystickCenter;
        final distance = delta.distance;

        Offset clampedKnob;
        if (distance > _joystickRadius) {
          clampedKnob =
              _joystickCenter +
              Offset.fromDirection(delta.direction, _joystickRadius);
        } else {
          clampedKnob = offset;
        }

        setState(() {
          _joystickKnob = clampedKnob;
        });

        // 게임에 방향 전달
        final normalizedDelta = clampedKnob - _joystickCenter;
        const maxDist = _joystickRadius;
        widget.game.updateJoystick(
          Vector2(normalizedDelta.dx / maxDist, normalizedDelta.dy / maxDist),
        );
      },
      onPanEnd: (_) {
        setState(() {
          _isDragging = false;
          _joystickKnob = _joystickCenter;
        });
        widget.game.updateJoystick(Vector2.zero());
      },
      child: SizedBox(
        width: _joystickRadius * 2,
        height: _joystickRadius * 2,
        child: CustomPaint(
          painter: _JoystickPainter(
            center: _joystickCenter,
            knob: _isDragging ? _joystickKnob : _joystickCenter,
            radius: _joystickRadius,
            knobRadius: _knobRadius,
            isDragging: _isDragging,
          ),
        ),
      ),
    );
  }

  /// 필살기 + 동료 호출 버튼 (공격은 자동)
  Widget _buildActionButtons() {
    return ListenableBuilder(
      listenable: widget.game.gameState,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 동료 호출 버튼
            _buildAssistButton(),
            const SizedBox(height: 12),
            // 필살기 버튼
            _buildUltButton(),
          ],
        );
      },
    );
  }

  Widget _buildAssistButton() {
    final gs = widget.game.gameState;
    final isReady = gs.isAssistReady;
    final cooldownRatio = gs.assistCooldownRatio;
    final companionColor = gs.companionData.color;

    return GestureDetector(
      onTap: () {
        if (isReady) {
          widget.game.performAssist();
        }
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isReady ? _pulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReady
                ? companionColor.withValues(alpha: 0.7)
                : Colors.grey.shade800,
            border: Border.all(
              color: isReady ? companionColor : Colors.grey.shade600,
              width: 2,
            ),
            boxShadow: isReady
                ? [
                    BoxShadow(
                      color: companionColor.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!isReady)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    value: 1 - cooldownRatio,
                    color: companionColor.withValues(alpha: 0.5),
                    backgroundColor: Colors.transparent,
                    strokeWidth: 2,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    gs.companionData.iconEmoji,
                    style: TextStyle(
                      fontSize: 20,
                      color: isReady ? Colors.white : Colors.white24,
                    ),
                  ),
                  Text(
                    'ASSIST',
                    style: TextStyle(
                      color: isReady ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
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

  Widget _buildUltButton() {
    final isReady = widget.game.gameState.isUltReady;
    final cooldownRatio = widget.game.gameState.ultCooldownRatio;
    final color = widget.game.gameState.characterData.color;

    return GestureDetector(
      onTap: () {
        if (isReady) {
          widget.game.player.useUltimate();
        }
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isReady ? _pulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isReady
                ? color.withValues(alpha: 0.8)
                : Colors.grey.shade800,
            border: Border.all(
              color: isReady ? color : Colors.grey.shade600,
              width: 3,
            ),
            boxShadow: isReady
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!isReady)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: 1 - cooldownRatio,
                    color: color.withValues(alpha: 0.5),
                    backgroundColor: Colors.transparent,
                    strokeWidth: 3,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.game.gameState.characterData.iconEmoji,
                    style: TextStyle(
                      fontSize: 24,
                      color: isReady ? Colors.white : Colors.white24,
                    ),
                  ),
                  Text(
                    'ULT',
                    style: TextStyle(
                      color: isReady ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
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

  Widget _buildPauseButton() {
    return SafeArea(
      child: GestureDetector(
        onTap: () {
          widget.game.gameState.togglePause();
          if (widget.game.gameState.isPaused) {
            widget.game.pauseEngine();
            widget.game.overlays.add('Pause');
          } else {
            widget.game.resumeEngine();
            widget.game.overlays.remove('Pause');
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.pause, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

/// 조이스틱 커스텀 페인터
class _JoystickPainter extends CustomPainter {
  final Offset center;
  final Offset knob;
  final double radius;
  final double knobRadius;
  final bool isDragging;

  _JoystickPainter({
    required this.center,
    required this.knob,
    required this.radius,
    required this.knobRadius,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 외부 원 (조이스틱 범위)
    final outerPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDragging ? 0.2 : 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, outerPaint);

    final outerBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDragging ? 0.4 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, outerBorderPaint);

    // 내부 원 (손잡이)
    final knobPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDragging ? 0.6 : 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knob, knobRadius, knobPaint);
  }

  @override
  bool shouldRepaint(covariant _JoystickPainter oldDelegate) {
    return knob != oldDelegate.knob || isDragging != oldDelegate.isDragging;
  }
}
