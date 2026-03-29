import 'package:flutter/material.dart';

import '../game/mbti_game.dart';

class ResumeOverlay extends StatelessWidget {
  final MbtiGame game;

  const ResumeOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: const Color(0xFF17172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_circle_outline,
                color: Colors.amber,
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                '다시 진행할까요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '앱이 백그라운드에 있는 동안 전투를 멈춰 두었습니다.\n계속하기를 누르면 3, 2, 1 카운트 후 재개합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: game.confirmLifecycleResume,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade600, Colors.orange.shade700],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        '계속하기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => game.cancelLifecycleResume(returnToLobby: true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home, color: Colors.white70),
                      SizedBox(width: 6),
                      Text(
                        '로비로 이동',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
