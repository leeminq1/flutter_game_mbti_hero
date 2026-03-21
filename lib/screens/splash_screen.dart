import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ad_manager.dart';
import '../services/save_manager.dart';
import '../services/unlock_manager.dart';
import '../main.dart';
import 'package:flame_audio/flame_audio.dart';

class SplashScreen extends StatefulWidget {
  final UnlockManager unlockManager;
  final AdManager adManager;
  final SaveManager saveManager;

  const SplashScreen({
    super.key,
    required this.unlockManager,
    required this.adManager,
    required this.saveManager,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _canStart = false; // 3초 뒤에 게임 시작 가능 여부

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // 오디오 캐싱 및 로비 BGM 재생
    FlameAudio.audioCache.loadAll([
      'sfx_shoot.ogg', 'sfx_player_hit.ogg', 'sfx_player_die.ogg',
      'sfx_ultimate.ogg', 'sfx_assist.ogg', 'sfx_enemy_spawn.ogg',
      'sfx_enemy_hit.ogg', 'sfx_enemy_die.ogg', 'sfx_boss_warning.ogg',
      'sfx_boss_attack.ogg', 'sfx_coin.ogg', 'sfx_powerup.ogg',
      'sfx_heal.ogg', 'sfx_wave_clear.ogg', 'sfx_button.ogg',
      'bgm_battle.mp3', 'bgm_boss.mp3', 'bgm_gameover.mp3', 'bgm_lobby.mp3'
    ]).then((_) {
      if (mounted) {
        FlameAudio.bgm.play('bgm_lobby.mp3', volume: 0.25);
      }
    });

    // 3초 후 Loading이 끝나고 탭 기능 활성화
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _canStart = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!_canStart) return; // 3초 전에는 탭해도 아무 일도 안 일어남
    
    FlameAudio.play('sfx_button.ogg', volume: 0.5);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(
          unlockManager: widget.unlockManager,
          adManager: widget.adManager,
          saveManager: widget.saveManager,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            // 상단 검은색 영역 (타이틀 & 로딩 텍스트)
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.black,
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 타이틀
                    const Text(
                      'MBTI 히어로',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 10,
                            offset: Offset(2, 2),
                          ),
                          Shadow(color: Colors.redAccent, blurRadius: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '- 직장인 생존기 -',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 로딩 텍스트 or 깜빡이는 터치 텍스트
                    if (!_canStart)
                      const Text(
                        'Loading⏳...',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.yellowAccent,
                        ),
                      )
                    else
                      FadeTransition(
                        opacity: _animation,
                        child: const Column(
                          children: [
                            Text(
                              '직장에서 살아남으려면',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.yellowAccent,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '화면을 터치하세요',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.yellowAccent,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 하단 배경 이미지 영역
            Expanded(
              flex: 4,
              child: SizedBox(
                width: double.infinity,
                child: Image.asset(
                  'assets/images/ui/splash_bg.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.center, // 화면 세로 중앙에 오도록 변경
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
