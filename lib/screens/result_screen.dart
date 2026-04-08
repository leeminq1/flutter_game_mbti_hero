import 'dart:async';

import 'package:flutter/material.dart';

import '../game/mbti_game.dart';
import '../services/ad_manager.dart';
import '../services/save_manager.dart';

class ResultOverlay extends StatefulWidget {
  final MbtiGame game;
  final bool isVictory;
  final VoidCallback onRetry;
  final VoidCallback onLobby;

  const ResultOverlay({
    super.key,
    required this.game,
    required this.isVictory,
    required this.onRetry,
    required this.onLobby,
  });

  @override
  State<ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends State<ResultOverlay> {
  static const List<String> _endingScenePaths = [
    'assets/images/ending/ending_scene_1.png',
    'assets/images/ending/ending_scene_2.png',
    'assets/images/ending/ending_scene_3.png',
  ];

  static const List<String> _endingSceneCaptions = [
    '\uD558\uB8E8 \uC5C5\uBB34\uAC00 \uCC28\uBD84\uD788 \uB9C8\uBB34\uB9AC\uB429\uB2C8\uB2E4',
    '\uB9C8\uC9C0\uB9C9 \uACB0\uC7AC\uAE4C\uC9C0 \uB05D\uB0B8 \uD6C4 \uD55C\uC228\uC744 \uB3CC\uB9BD\uB2C8\uB2E4',
    '\uD1F4\uADFC\uAE38 \uBC1C\uAC78\uC74C\uC5D0 \uC870\uC6A9\uD55C \uD574\uBC29\uAC10\uC774 \uB0A8\uC2B5\uB2C8\uB2E4',
  ];

  bool _adWatched = false;
  bool _watchingAd = false;
  bool _recordSaved = false;
  int _endingSceneIndex = 0;
  Timer? _endingSceneTimer;

  bool get _isFinalClear =>
      widget.isVictory &&
      widget.game.gameState.currentWave >= widget.game.gameState.totalWaves;

  @override
  void initState() {
    super.initState();
    _configureEndingSequence();
    _precacheEndingScenes();
  }

  @override
  void didUpdateWidget(covariant ResultOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldWasFinalClear =
        oldWidget.isVictory &&
        oldWidget.game.gameState.currentWave >= oldWidget.game.gameState.totalWaves;
    if (oldWasFinalClear != _isFinalClear) {
      _configureEndingSequence();
      _precacheEndingScenes();
    }
  }

  @override
  void dispose() {
    _endingSceneTimer?.cancel();
    super.dispose();
  }

  void _configureEndingSequence() {
    _endingSceneTimer?.cancel();
    _endingSceneIndex = 0;
    if (!_isFinalClear) return;
    _endingSceneTimer = Timer.periodic(const Duration(milliseconds: 2600), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_endingSceneIndex >= _endingScenePaths.length - 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _endingSceneIndex++;
      });
    });
  }

  void _precacheEndingScenes() {
    if (!_isFinalClear) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final path in _endingScenePaths) {
        precacheImage(AssetImage(path), context);
      }
    });
  }

  Future<void> _watchAd() async {
    if (_watchingAd) return;
    setState(() => _watchingAd = true);

    final watched = await AdManager().showReviveRewardedAd();

    if (!mounted) return;
    setState(() {
      _adWatched = watched;
      _watchingAd = false;
    });

    // 광고를 성공적으로 보고 닫았다면 바로 부활 (유저가 버튼을 한 번 더 누르지 않도록 자동 실행)
    if (watched) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          widget.onRetry();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: widget.isVictory
            ? _buildVictoryCard(context)
            : _buildDefeatCard(context),
      ),
    );
  }

  Widget _buildVictoryCard(BuildContext context) {
    final gameState = widget.game.gameState;
    final title = _isFinalClear
        ? '\uB4DC\uB514\uC5B4 \uD1F4\uADFC\uD588\uC2B5\uB2C8\uB2E4'
        : '\uC6E8\uC774\uBE0C \uD074\uB9AC\uC5B4!';
    final subtitle = _isFinalClear
        ? '\uC624\uB298\uC758 \uBAA8\uB4E0 \uC5C5\uBB34\uB97C \uB9C8\uCE68\uC2B5\uB2C8\uB2E4'
        : '\uC7A0\uC2DC \uC228\uC744 \uACE0\uB974\uACE0 \uB2E4\uC74C \uAD6D\uBA74\uC744 \uC900\uBE44\uD558\uC138\uC694';
    final body = _isFinalClear
        ? '\uAE34 \uC57C\uADFC\uACFC \uB05D\uC5C6\uB294 \uACB0\uC7AC, \uB9E4\uC11C\uC6B4 \uBCF4\uC2A4 \uC6E8\uC774\uBE0C\uB97C \uBAA8\uB450 \uBC84\uD154\uB0C8\uC2B5\uB2C8\uB2E4.\n'
              '\uC624\uB298\uC758 \uC5C5\uBB34\uB294 \uC5EC\uAE30\uC11C \uC644\uC804\uD788 \uC885\uB8CC\uC785\uB2C8\uB2E4.\n\n'
              '\uACE0\uC0DD \uB9CE\uC73C\uC168\uC2B5\uB2C8\uB2E4.\n'
              '\uC55E\uC73C\uB85C\uC758 \uC77C\uC0C1\uC5D0\uB3C4 \uC870\uC6A9\uD558\uC9C0\uB9CC \uBD84\uBA85\uD55C \uD589\uBCF5\uC774 \uC624\uB798 \uC774\uC5B4\uC9C0\uAE38 \uBC14\uB78D\uB2C8\uB2E4.'
        : '\uC624\uB298\uB3C4 \uD55C \uAD6C\uAC04\uC744 \uB118\uC5C8\uC2B5\uB2C8\uB2E4.\n'
              '\uB2E4\uC74C \uC6E8\uC774\uBE0C\uB97C \uD5A5\uD574 \uB9AC\uB4EC\uC744 \uB2E4\uC2DC \uC815\uBE44\uD574\uBCF4\uC138\uC694.';

    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: const Color(0xFF11162B),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD38A), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD38A).withValues(alpha: 0.22),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isFinalClear) ...[
            _buildEndingSceneShowcase(),
            const SizedBox(height: 18),
          ],
          const Icon(
            Icons.mark_email_read_rounded,
            size: 54,
            color: Color(0xFFFFD38A),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFE7B5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD38A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: const Color(0xFFFFD38A).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'WAVE ${gameState.currentWave} / ${gameState.totalWaves} CLEAR',
              style: const TextStyle(
                color: Color(0xFFFFD38A),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE7D2A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.drafts_rounded,
                      color: Color(0xFF7A5A1C),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isFinalClear
                          ? '\uD1F4\uADFC \uD3B8\uC9C0'
                          : '\uC815\uB9AC \uBA54\uBAA8',
                      style: const TextStyle(
                        color: Color(0xFF7A5A1C),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF3B3124),
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '\uCD1D \uD68D\uB4DD \uCEE4\uD53C\uCF54\uC778 ${gameState.totalCoffeeEarned}',
                  style: const TextStyle(
                    color: Color(0xFF8B6A2E),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isFinalClear)
            _buildFinalClearPrimaryAction(context)
          else ...[
            if (!_recordSaved)
              GestureDetector(
                onTap: () => _showSaveRecordDialog(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.cyan.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.cyan, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '\uAE30\uB85D \uC800\uC7A5',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '\uAE30\uB85D \uC800\uC7A5 \uC644\uB8CC',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _buildButton(
              label: '\uB85C\uBE44\uB85C \uAC00\uAE30',
              icon: Icons.home_rounded,
              color: const Color(0xFFFFD38A),
              onTap: widget.onLobby,
            ),
          ],
        ],
      ),
    );

    if (!_isFinalClear) {
      return card;
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: card,
      ),
    );
  }

  Widget _buildEndingSceneShowcase() {
    final scenePath = _endingScenePaths[_endingSceneIndex];
    final sceneCaption = _endingSceneCaptions[_endingSceneIndex];

    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFFFD38A).withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 1400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 1.04,
                            end: 1.0,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                    child: Image.asset(
                      scenePath,
                      key: ValueKey<String>(scenePath),
                      fit: BoxFit.cover,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.48),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: Text(
                        sceneCaption,
                        key: ValueKey<String>(sceneCaption),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_endingScenePaths.length, (index) {
            final isActive = index == _endingSceneIndex;
            final isPassed = index < _endingSceneIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 28 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFFFD38A)
                    : isPassed
                    ? const Color(0xFFFFD38A).withValues(alpha: 0.55)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDefeatCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.shade800, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.nightlight_round,
            size: 56,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            '\uC57C\uADFC \uD655\uC815...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.red.shade400,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Game Over...',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Wave ${widget.game.gameState.currentWave} / ${widget.game.gameState.totalWaves}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!_adWatched) ...[
            GestureDetector(
              onTap: _watchingAd ? null : _watchAd,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _watchingAd
                        ? [Colors.grey.shade700, Colors.grey.shade800]
                        : [Colors.amber.shade700, Colors.orange.shade800],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _watchingAd
                          ? Icons.hourglass_top
                          : Icons.favorite,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _watchingAd
                          ? '로딩 중...'
                          : '무료로 부활하기',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (!_recordSaved)
              GestureDetector(
                onTap: () => _showSaveRecordDialog(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.cyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: Colors.cyan, size: 16),
                      SizedBox(width: 6),
                      Text(
                        '\uAE30\uB85D \uC800\uC7A5',
                        style: TextStyle(
                          color: Colors.cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '\uAE30\uB85D \uC800\uC7A5 \uC644\uB8CC!',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: widget.onLobby,
              child: const Text(
                '\uB85C\uBE44\uB85C \uB3CC\uC544\uAC00\uAE30',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: _buildButton(
                    label: '\uC774\uC5B4\uD558\uAE30',
                    icon: Icons.play_arrow_rounded,
                    color: Colors.amber,
                    onTap: widget.onRetry,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: _buildButton(
                    label: '\uB85C\uBE44',
                    icon: Icons.home,
                    color: Colors.white54,
                    onTap: widget.onLobby,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinalClearPrimaryAction(BuildContext context) {
    if (!_recordSaved) {
      return GestureDetector(
        onTap: () => _showSaveRecordDialog(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.cyan.withValues(alpha: 0.35),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.save_rounded, color: Colors.cyan, size: 18),
              SizedBox(width: 8),
              Text(
                '\uAE30\uB85D \uC800\uC7A5',
                style: TextStyle(
                  color: Colors.cyan,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildButton(
      label: '\uB85C\uBE44\uB85C \uAC00\uAE30',
      icon: Icons.home_rounded,
      color: const Color(0xFFFFD38A),
      onTap: () => _showLobbyConfirmDialog(context),
    );
  }

  void _showSaveRecordDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A3E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
              const SizedBox(height: 12),
              const Text(
                '\uAE30\uB85D \uC800\uC7A5',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Wave ${widget.game.gameState.currentWave} | \u2615 ${widget.game.gameState.totalCoffeeEarned}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                maxLength: 12,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: '\uB2C9\uB124\uC784 \uC785\uB825',
                  hintStyle: const TextStyle(color: Colors.white38),
                  counterStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.cyan.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.cyan.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyan),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            '\uCDE8\uC18C',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(ctx);
                        await _saveRecord(name);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.cyan.shade600,
                              Colors.cyan.shade800,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            '\uC800\uC7A5',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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

  Future<void> _showLobbyConfirmDialog(BuildContext context) async {
    final shouldGoLobby = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A3E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFD38A).withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD38A).withValues(alpha: 0.16),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.home_rounded,
                color: Color(0xFFFFD38A),
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text(
                '\uB85C\uBE44\uB85C \uC774\uB3D9',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '\uAE30\uB85D\uC744 \uC800\uC7A5\uD588\uC2B5\uB2C8\uB2E4.\n\uB85C\uBE44\uB85C \uB3CC\uC544\uAC00\uC2DC\uACA0\uC2B5\uB2C8\uAE4C?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            '\uCDE8\uC18C',
                            style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD38A), Color(0xFFE4B860)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            '\uB85C\uBE44\uB85C \uAC00\uAE30',
                            style: TextStyle(
                              color: Color(0xFF2C220E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldGoLobby == true && mounted) {
      widget.onLobby();
    }
  }

  Future<void> _saveRecord(String name) async {
    final game = widget.game;
    final saveManager = game.saveManager;
    if (saveManager == null) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('\uAE30\uB85D \uC800\uC7A5\uC744 \uC900\uBE44\uD560 \uC218 \uC5C6\uC2B5\uB2C8\uB2E4.')),
      );
      return;
    }

    try {
      final entry = LeaderboardEntry(
        playerName: name,
        character: game.gameState.selectedCharacter,
        companion: game.gameState.selectedCompanion,
        wave: game.gameState.currentWave,
        score: game.gameState.totalCoffeeEarned,
        dateTime: DateTime.now().toIso8601String(),
      );
      await saveManager.addLeaderboardEntry(entry);
      if (!mounted) return;
      setState(() => _recordSaved = true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('\uAE30\uB85D\uC774 \uC800\uC7A5\uB418\uC5C8\uC2B5\uB2C8\uB2E4.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('\uAE30\uB85D \uC800\uC7A5\uC5D0 \uC2E4\uD328\uD588\uC2B5\uB2C8\uB2E4.')),
      );
    }
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  final MbtiGame game;
  final VoidCallback? onLobby;

  const PauseOverlay({super.key, required this.game, this.onLobby});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '\uC77C\uC2DC\uC815\uC9C0',
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  game.gameState.togglePause();
                  game.resumeGameplayIfAllowed(reason: 'pause_overlay');
                  game.overlays.remove('Pause');
                },
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '\uACC4\uC18D\uD558\uAE30',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  game.overlays.remove('Pause');
                  game.returnToLobby();
                },
                child: Container(
                  width: 180,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '\uB85C\uBE44\uB85C',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
