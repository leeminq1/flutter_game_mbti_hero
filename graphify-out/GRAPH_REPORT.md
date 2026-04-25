# Graph Report - C:\Users\min21\Desktop\flutter_grame\flutter_game  (2026-04-18)

## Corpus Check
- 78 files · ~7,131,031 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 717 nodes · 808 edges · 44 communities detected
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 16 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 18 edges
2. `package:flame/components.dart` - 9 edges
3. `../game/mbti_game.dart` - 8 edges
4. `dart:async` - 8 edges
5. `dart:math` - 8 edges
6. `Create()` - 7 edges
7. `AppDelegate` - 6 edges
8. `../game/config/character_data.dart` - 6 edges
9. `../services/save_manager.dart` - 6 edges
10. `../services/sfx_manager.dart` - 6 edges

## Surprising Connections (you probably didn't know these)
- `build_cooler_feature_graphic()` --calls--> `Text`  [INFERRED]
  C:\Users\min21\Desktop\flutter_grame\flutter_game\create_cooler_feature_graphic.py → C:\Users\min21\Desktop\flutter_grame\flutter_game\lib\widgets\upgrade_overlay.dart
- `OnCreate()` --calls--> `RegisterPlugins()`  [INFERRED]
  C:\Users\min21\Desktop\flutter_grame\flutter_game\windows\runner\flutter_window.cpp → C:\Users\min21\Desktop\flutter_grame\flutter_game\windows\flutter\generated_plugin_registrant.cc
- `OnCreate()` --calls--> `Show()`  [INFERRED]
  C:\Users\min21\Desktop\flutter_grame\flutter_game\windows\runner\flutter_window.cpp → C:\Users\min21\Desktop\flutter_grame\flutter_game\windows\runner\win32_window.cpp
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  C:\Users\min21\Desktop\flutter_grame\flutter_game\windows\runner\main.cpp → C:\Users\min21\Desktop\flutter_grame\flutter_game\windows\runner\utils.cpp
- `wWinMain()` --calls--> `SetQuitOnClose()`  [INFERRED]
  C:\Users\min21\Desktop\flutter_grame\flutter_game\windows\runner\main.cpp → C:\Users\min21\Desktop\flutter_grame\flutter_game\windows\runner\win32_window.cpp

## Communities

### Community 0 - "Community 0"
Cohesion: 0.03
Nodes (68): base_enemy.dart, BaseEnemy, _clearEnemyProjectiles, die, _getBossQuote, _initStats, onCollision, onMount (+60 more)

### Community 1 - "Community 1"
Cohesion: 0.03
Nodes (67): _addExplosionEffect, _addGridPattern, _addObstacles, _addPulseRingEffect, _addRadialEmojiEffect, _addStaticWorldComponent, addTimedWorldComponent, _attackAura (+59 more)

### Community 2 - "Community 2"
Cohesion: 0.04
Nodes (51): build, Container, CountdownOverlay, _CountdownOverlayState, _delayRespectingLifecycle, dispose, initState, Shadow (+43 more)

### Community 3 - "Community 3"
Cohesion: 0.04
Nodes (42): _isDuplicateError, LeaderboardDuplicateNameException, LeaderboardEntry, LeaderboardRemoteDataSource, LeaderboardRepository, _saveLocallyAfterRemoteFailure, SupabaseLeaderboardRemoteDataSource, copyWith (+34 more)

### Community 4 - "Community 4"
Cohesion: 0.04
Nodes (46): build, CharacterSelectScreen, _continueGame, didChangeAppLifecycleState, dispose, HomeScreen, _HomeScreenState, Icon (+38 more)

### Community 5 - "Community 5"
Cohesion: 0.04
Nodes (44): AlertDialog, _applyAndSave, build, _buildCharacterCard, _buildCharacterSelectView, _buildCircleButton, _buildCompanionCard, _buildCompanionSelectView (+36 more)

### Community 6 - "Community 6"
Cohesion: 0.05
Nodes (43): addAssistTicket, addCoffeeBeans, addUltTicket, BossStatus, clearBoss, consumeAssistTicket, consumeUltTicket, _cooldownBucket (+35 more)

### Community 7 - "Community 7"
Cohesion: 0.05
Nodes (42): build, _buildEmptyState, _buildEntryRow, _buildSourceBadge, Center, Column, Container, initState (+34 more)

### Community 8 - "Community 8"
Cohesion: 0.06
Nodes (35): bgm_manager.dart, AudioBootstrap, _applyBackgroundStop, authorizeGameplayRestore, BgmManager, _cancelInactiveStop, _cancelRecovery, _enqueue (+27 more)

### Community 9 - "Community 9"
Cohesion: 0.09
Nodes (25): FlutterWindow(), OnCreate(), RegisterPlugins(), wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16(), Create() (+17 more)

### Community 10 - "Community 10"
Cohesion: 0.08
Nodes (25): _applyAndContinue, build, _buildUpgradeRow, _buildUtilityButton, _buyAssistPass, _buyHeal, _buyUltPass, Container (+17 more)

### Community 11 - "Community 11"
Cohesion: 0.09
Nodes (21): EnemyDefinition, enemyDefinitionFor, StateError, _countEnemyProjectiles, EnemySpawner, _getSpawnPosition, onEnemyKilled, _onWaveCleared (+13 more)

### Community 12 - "Community 12"
Cohesion: 0.09
Nodes (22): ActionOverlay, _ActionOverlayState, build, _buildActionButtons, _buildAssistButton, _buildChargeBadge, _buildJoystick, _buildPauseButton (+14 more)

### Community 13 - "Community 13"
Cohesion: 0.13
Nodes (14): BatEnemyBehavior, BossChaseEnemyBehavior, ChargeEnemyBehavior, ChargerRushEnemyBehavior, ChaseEnemyBehavior, createEnemyBehavior, EnemyBehavior, _fireSniperBurst (+6 more)

### Community 14 - "Community 14"
Cohesion: 0.13
Nodes (6): dispose, fl_register_plugins(), main(), my_application_activate(), my_application_dispose(), my_application_new()

### Community 15 - "Community 15"
Cohesion: 0.23
Nodes (10): max, create_icon(), ensure_dir(), main(), make_feature_graphic(), make_screenshot(), import_io_bytes(), process_boss() (+2 more)

### Community 16 - "Community 16"
Cohesion: 0.15
Nodes (12): getCooldownMultiplier, getGrade, getGradeDescription, getGradeLabel, getPowerMultiplier, _gradeFromTraits, hasHealBonus, _interactionStyle (+4 more)

### Community 17 - "Community 17"
Cohesion: 0.17
Nodes (10): AdManager, _createInterstitialAd, _ensureInitialized, init, showReviveRewardedAd, debugLog, debugLogError, dart:io (+2 more)

### Community 18 - "Community 18"
Cohesion: 0.42
Nodes (8): crop_to_alpha_bounds(), is_dark(), is_light(), list_target_files(), main(), parse_args(), process_image(), remove_edge_background()

### Community 19 - "Community 19"
Cohesion: 0.29
Nodes (2): AppDelegate, FlutterAppDelegate

### Community 20 - "Community 20"
Cohesion: 0.33
Nodes (5): attackProjectileEmoji, CharacterData, getByType, MbtiCharacters, dart:ui

### Community 21 - "Community 21"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), MainFlutterWindow, NSWindow

### Community 22 - "Community 22"
Cohesion: 0.8
Nodes (4): create_cool_feature_graphic(), create_promo_image(), get_font(), main()

### Community 23 - "Community 23"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 24 - "Community 24"
Cohesion: 0.4
Nodes (2): RunnerTests, XCTestCase

### Community 25 - "Community 25"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 26 - "Community 26"
Cohesion: 0.5
Nodes (3): LeaderboardDuplicateNameException, LeaderboardLoadResult, LeaderboardSubmitResult

### Community 27 - "Community 27"
Cohesion: 1.0
Nodes (2): import_io_bytes(), process_sheet()

### Community 28 - "Community 28"
Cohesion: 1.0
Nodes (2): create_promo_images(), ensure_dir()

### Community 29 - "Community 29"
Cohesion: 0.67
Nodes (2): WaveConfig, WaveData

### Community 30 - "Community 30"
Cohesion: 1.0
Nodes (0): 

### Community 31 - "Community 31"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 32 - "Community 32"
Cohesion: 1.0
Nodes (0): 

### Community 33 - "Community 33"
Cohesion: 1.0
Nodes (0): 

### Community 34 - "Community 34"
Cohesion: 1.0
Nodes (0): 

### Community 35 - "Community 35"
Cohesion: 1.0
Nodes (0): 

### Community 36 - "Community 36"
Cohesion: 1.0
Nodes (0): 

### Community 37 - "Community 37"
Cohesion: 1.0
Nodes (0): 

### Community 38 - "Community 38"
Cohesion: 1.0
Nodes (0): 

### Community 39 - "Community 39"
Cohesion: 1.0
Nodes (0): 

### Community 40 - "Community 40"
Cohesion: 1.0
Nodes (0): 

### Community 41 - "Community 41"
Cohesion: 1.0
Nodes (0): 

### Community 42 - "Community 42"
Cohesion: 1.0
Nodes (0): 

### Community 43 - "Community 43"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **516 isolated node(s):** `Loads, rescales to fill height, and center crops to exact target size.`, `Creates a drop shadow layer for the given RGBA image`, `MainActivity`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `-registerWithRegistry` (+511 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 30`** (2 nodes): `check_sizes.py`, `main()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 31`** (2 nodes): `MainActivity.kt`, `MainActivity`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 32`** (1 nodes): `run_with_supabase.ps1`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 33`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 34`** (1 nodes): `settings.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 35`** (1 nodes): `build.gradle.kts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (1 nodes): `GeneratedPluginRegistrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (1 nodes): `Runner-Bridging-Header.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 39`** (1 nodes): `my_application.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 40`** (1 nodes): `generated_plugin_registrant.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 41`** (1 nodes): `resource.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 42`** (1 nodes): `utils.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 43`** (1 nodes): `win32_window.h`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 2` to `Community 0`, `Community 1`, `Community 4`, `Community 5`, `Community 7`, `Community 10`, `Community 11`, `Community 12`?**
  _High betweenness centrality (0.282) - this node is a cross-community bridge._
- **Why does `../game/config/character_data.dart` connect `Community 3` to `Community 4`, `Community 5`, `Community 7`?**
  _High betweenness centrality (0.094) - this node is a cross-community bridge._
- **Why does `dart:async` connect `Community 8` to `Community 1`, `Community 2`, `Community 4`, `Community 7`, `Community 17`?**
  _High betweenness centrality (0.081) - this node is a cross-community bridge._
- **What connects `Loads, rescales to fill height, and center crops to exact target size.`, `Creates a drop shadow layer for the given RGBA image`, `MainActivity` to the rest of the system?**
  _516 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.03 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._