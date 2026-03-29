import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/config/character_data.dart';
import 'game/mbti_game.dart';
import 'screens/character_select.dart';
import 'screens/result_screen.dart';
import 'screens/splash_screen.dart';
import 'services/ad_manager.dart';
import 'services/bgm_manager.dart';
import 'services/save_manager.dart';
import 'services/sfx_manager.dart';
import 'services/unlock_manager.dart';
import 'widgets/action_buttons.dart';
import 'widgets/hud_overlay.dart';
import 'widgets/countdown_overlay.dart';
import 'widgets/resume_overlay.dart';
import 'widgets/upgrade_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 모드 잠금 해제, 가로 모드 지원
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // 몰입형 모드 (하단 네비게이션 바 숨기기)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 서비스 초기화
  final unlockManager = UnlockManager();
  await unlockManager.init();

  final adManager = AdManager();
  await adManager.init();

  final saveManager = SaveManager();
  await saveManager.init();

  runApp(
    MbtiHeroApp(
      unlockManager: unlockManager,
      adManager: adManager,
      saveManager: saveManager,
    ),
  );
}

class MbtiHeroApp extends StatelessWidget {
  final UnlockManager unlockManager;
  final AdManager adManager;
  final SaveManager saveManager;

  const MbtiHeroApp({
    super.key,
    required this.unlockManager,
    required this.adManager,
    required this.saveManager,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MBTI 히어로: 직장인 생존기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A1A),
      ),
      home: SplashScreen(
        unlockManager: unlockManager,
        adManager: adManager,
        saveManager: saveManager,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final UnlockManager unlockManager;
  final AdManager adManager;
  final SaveManager saveManager;

  const HomeScreen({
    super.key,
    required this.unlockManager,
    required this.adManager,
    required this.saveManager,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _inGame = false;
  MbtiGame? _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final game = _game;
    if (game != null) {
      game.handleAppLifecycleState(state);
      return;
    }
    BgmManager.handleLifecycleChange(state);
    SfxManager.handleLifecycleChange(state);
  }

  void _startGame(CharacterType type, CharacterType companionType) {
    if (_game != null) return;

    final game = MbtiGame(saveManager: widget.saveManager);

    // 글로벌 데이터 주입 (해금 캐릭터만 글로벌, 나머지는 0)
    final globalData = widget.saveManager.loadGlobalData();
    game.gameState.loadGlobalData(
      0, // 커피콩 0
      0, // HP Lv 0
      0, // ATK Lv 0
      0, // SPD Lv 0
      globalData.unlockedCharacters,
    );

    game.gameState.selectCharacter(type);
    game.gameState.selectCompanion(companionType);
    game.onReturnToLobby = _returnToLobby;

    setState(() {
      _game = game;
      _inGame = true;
    });
  }

  /// 이어서 하기
  void _continueGame(SaveData saveData) {
    if (_game != null) return;

    final game = MbtiGame(
      saveManager: widget.saveManager,
      loadedSave: saveData,
    );

    // 글로벌 데이터 주입 (해금 캐릭터만 글로벌, 레벨은 세이브 데이터에서)
    final globalData = widget.saveManager.loadGlobalData();
    game.gameState.loadGlobalData(
      0, // 커피콩은 항상 0으로 시작
      saveData.hpLevel,
      saveData.atkLevel,
      saveData.spdLevel,
      globalData.unlockedCharacters,
    );

    game.gameState.selectCharacter(saveData.character);
    game.gameState.selectCompanion(saveData.companion);
    game.onReturnToLobby = _returnToLobby;

    setState(() {
      _game = game;
      _inGame = true;
    });
  }

  void _returnToLobby() {
    setState(() {
      _game?.pauseEngine();
      _game = null;
      _inGame = false;
    });
    BgmManager.setTrack(BgmTrack.lobby);
  }

  void _retryGame() {
    if (_game != null) {
      // 광고는 ResultOverlay에서 이미 처리됨
      _game!.restartFromCurrentWave();
    }
  }

  Future<void> _handleUnlockRequest(CharacterType type) async {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A3E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.ondemand_video,
                color: Colors.blueAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                '캐릭터 해금',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '광고를 시청하고\n${MbtiCharacters.getByType(type).mbti} 캐릭터를 해금할까요?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // TODO: 실제 Admob 등 연동
                      await _unlockCharacterAction(type);
                    },
                    child: const Text(
                      '시청하기',
                      style: TextStyle(color: Colors.white),
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

  Future<void> _unlockCharacterAction(CharacterType type) async {
    final currentData = widget.saveManager.loadGlobalData();
    final updatedUnlocks = Set<CharacterType>.from(
      currentData.unlockedCharacters,
    )..add(type);

    await widget.saveManager.saveGlobalData(
      coffeeBeans: currentData.coffeeBeans, // 콩 소모 안함
      hpLevel: currentData.hpLevel,
      atkLevel: currentData.attackLevel,
      spdLevel: currentData.speedLevel,
      unlockedCharacters: updatedUnlocks.map((e) => e.name).toList(),
    );

    await widget.unlockManager.unlock(type);
    setState(() {}); // UI 갱신

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${MbtiCharacters.getByType(type).mbti} 캐릭터가 해금되었습니다!'),
          backgroundColor: MbtiCharacters.getByType(type).color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_inGame || _game == null) {
      // 캐릭터 선택 화면
      return CharacterSelectScreen(
        unlockedCharacters: widget.unlockManager.unlockedCharacters,
        onSelect: _startGame,
        onUnlockRequest: _handleUnlockRequest,
        saveManager: widget.saveManager,
        onContinue: _continueGame,
      );
    }

    // 게임 화면
    return Scaffold(
      body: Stack(
        children: [
          // Flame 게임
          GameWidget(
            game: _game!,
            overlayBuilderMap: {
              'HUD': (context, game) =>
                  HudOverlay(gameState: (game as MbtiGame).gameState),
              'Actions': (context, game) =>
                  ActionOverlay(game: game as MbtiGame),
              'GameOver': (context, game) => ResultOverlay(
                game: game as MbtiGame,
                isVictory: false,
                onRetry: _retryGame,
                onLobby: _returnToLobby,
              ),
              'Victory': (context, game) => ResultOverlay(
                game: game as MbtiGame,
                isVictory: true,
                onRetry: _retryGame,
                onLobby: _returnToLobby,
              ),
              'Pause': (context, game) =>
                  PauseOverlay(game: game as MbtiGame, onLobby: _returnToLobby),
              'ResumePrompt': (context, game) =>
                  ResumeOverlay(game: game as MbtiGame),
              'Countdown': (context, game) =>
                  CountdownOverlay(game: game as MbtiGame),
              'Upgrade': (context, game) =>
                  UpgradeOverlay(game: game as MbtiGame),
            },
            initialActiveOverlays: const ['HUD', 'Actions'],
          ),
        ],
      ),
    );
  }
}
