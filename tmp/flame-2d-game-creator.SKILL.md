---
name: flame-2d-game-creator
description: Comprehensive guide for designing, scaffolding, reviewing, and refactoring Flutter Flame 2D games with performance-first gameplay architecture, centralized audio management, stable component lifecycles, Flutter overlay integration, and mobile-friendly optimization. Use when building or improving a Flame 2D game, especially for top-down action, wave survival, projectile-heavy combat, or any project where audio, frame pacing, entity counts, and UI/game coordination must be designed correctly from the start.
---

# Flame 2D Game Creator

Design every Flame game from runtime budgets first, not from features first.

Start from these assumptions:
- Mobile CPU and audio backends are limited.
- Projectile-heavy combat will fail if entity lifecycles are not explicit.
- Audio stutter often appears before visual overload.
- Flutter UI and Flame gameplay should cooperate, but must not own the same state in different places.
- On some Android devices, `FlameAudio` playback futures are not reliable enough to use as hard success/failure signals.

## Core architecture

Use this baseline structure:

```text
lib/
  main.dart
  game/
    game.dart or <feature>_game.dart
    components/
      player.dart
      enemies/
      projectiles/
      pickups/
    config/
      character_data.dart
      wave_data.dart
      constants.dart
    managers/
      game_state.dart
      enemy_spawner.dart
  screens/
  widgets/
  services/
    bgm_manager.dart
    sfx_manager.dart
    save_manager.dart
```

Use this ownership split:
- Flame owns simulation, movement, combat, spawn logic, entity lifetime, and collision.
- Flutter owns menus, overlays, dialogs, selection screens, HUD widgets, and store screens.
- `GameState` is the bridge object for UI-readable state only.
- `AudioBootstrap` owns one-time preload/bootstrap.
- `BgmManager` owns long-lived music state.
- `SfxManager` owns short-lived effect playback rules.

Do not mix those responsibilities.

## Non-negotiable runtime rules

### 1. Separate BGM and SFX

Always split audio into two services:
- `BgmManager`: one requested track, one current track, lifecycle-aware restart/stop logic
- `SfxManager`: throttled short effects with shared cooldowns and failure handling

Do not call `FlameAudio.bgm.play` from gameplay components or spawners.
Do not call `FlameAudio.play` directly from combat code, enemies, projectiles, or Flutter buttons.

Route all audio through managers.

### 2. Preload once

Preload audio once through one owner only.

Good:
- splash/bootstrap preloads all SFX and BGM assets once
- `SfxManager` preloads only short effects
- `BgmManager` preloads only music assets
- game instances reuse the cache

Bad:
- splash preloads audio
- game `onLoad()` also preloads the same full list
- `SfxManager` also preloads BGM files
- widgets directly load extra clips later

If preloading happens in multiple places, simplify to one canonical preload path.

### 3. Treat gameplay SFX as optional under load

In action games, music is mandatory and gameplay SFX is best-effort.

Implement all of these in `SfxManager`:
- per-asset minimum interval
- shared cooldown map
- pending-request cap
- duplicate-asset-in-flight suppression
- load-aware skipping based on active enemy/projectile counts
- session-level suppression after repeated playback failure
- debug counters: pending, failures, skipped, suppressed
- do not treat delayed `FlameAudio.play()` completion as a trustworthy success/failure signal on Android

Prioritize dropping:
- rapid fire shots
- enemy hit
- enemy die
- coins
- repeated boss attack sounds

Do not drop:
- essential UI confirmation when tapped
- single game-over transition sound unless audio backend is already failing

### 4. Pause gameplay and recover music through one lifecycle path

App lifecycle handling must pause simulation and recover music through one owner only.

Required behavior:
- on `inactive`, `hidden`, `paused`: pause engine, remember whether gameplay should resume, cancel pending music recovery
- on `inactive`, `hidden`, `paused`: stop requested BGM so background playback cannot continue
- on `resumed`: auto-restore only non-gameplay tracks such as `lobby` or `gameOver`
- on `resumed`: keep gameplay tracks such as `battle` or `boss` silent until the game explicitly resumes
- if gameplay was running before backgrounding, return through a safe resume path such as a resume-confirm popup followed by a countdown instead of resuming the engine directly inside the lifecycle callback
- clear joystick or pressed-direction state when the app backgrounds so dropped touch-up/cancel events cannot leave movement stuck
- add a hard guard in the game update path so world updates do not advance at all while the app lifecycle is inactive

Do not resume if:
- game over screen is open
- game is paused by user
- victory flow is active
- an upgrade/shop overlay intentionally paused gameplay

Do not:
- restart BGM immediately from multiple lifecycle observers
- run BGM watchdog retries from the main game `update(dt)` loop
- mix Android/player cleanup and app-triggered stop/start calls without a settle delay

### 5. Split static and dynamic world state

Create static world content once:
- background tiles
- permanent map props
- permanent collision objects

Reset dynamic world content separately:
- enemies
- projectiles
- temporary effects
- companion visuals
- runtime timers owned by combat flow

Use helpers such as:
- `_ensureStaticWorld()`
- `_clearDynamicWorld()`
- `_addStaticWorldComponent()`
- `addTimedWorldComponent()`

Do not rebuild static scenery on every retry or revive.

### 6. Cache live entities

Maintain explicit runtime lists:
- `activeEnemies`
- `activeProjectiles`
- transient effect count or registry

Register/unregister through component lifecycle:
- enemy `onMount` -> register
- enemy `onRemove` -> unregister
- projectile `onMount` -> register
- projectile `onRemove` -> unregister

Do not repeatedly scan `world.children.whereType<T>()` in hot paths.

Use snapshots only when a loop can mutate the source collection during damage or death.

### 7. Budget entities and effects

Set hard caps up front.

Minimum recommended caps:
- max active enemies
- max active projectiles
- max transient text/effect components
- max concurrent pending SFX requests

When over budget:
- skip low-value effects first
- keep damage and collisions correct
- keep player control responsive

Never let decorative feedback create the main performance failure.

### 8. Use timed helpers for every transient object

Any temporary world component must be added through a shared helper that:
- increments transient counters
- removes automatically after a lifetime
- decrements counters on finish

Use this for:
- damage bursts
- warning text
- emoji effects
- wave clear banners
- assist visuals
- ultimate overlays

Do not create ad-hoc `world.add(...)` temporary components everywhere.

### 9. Keep Flutter rebuilds bucketed

`GameState` should notify Flutter only when UI-visible values materially change.

Good candidates for bucketed notification:
- ult cooldown
- assist cooldown
- progress bars
- boss HP

Do not call `notifyListeners()` every frame for cooldown ratios.
Bucket progress into coarse steps.

### 10. Design combat abilities to be local by default

For top-down action games, default ultimate design should be:
- local burst
- cone
- line
- ring
- nearby aura
- short-duration buff

Avoid full-map damage unless the entire game is balanced around that rarity.

If one character has global damage while others have local bursts, that character will dominate both balance and performance cost.

## Recommended service design

### BgmManager

`BgmManager` should expose:
- `preloadTracks()`
- `setTrack(track, forceRestart: false)`
- `stop(clearRequest: false)`
- `handleLifecycleChange(state)`
- `currentTrack`
- `requestedTrack`

Rules:
- preload only BGM assets here, never in `SfxManager`
- ignore same-track replay unless forced
- serialize stop/start work so only one BGM operation runs at a time
- stop old track before switching and allow a short settle delay before restart
- never start music while app is inactive
- on background, prefer explicit stop over speculative pause/resume if the backend is device-fragile
- on resume, auto-restore only non-gameplay tracks; require explicit game-owned restore for battle music
- avoid watchdog restarts by default; add them only with strong evidence and strict debouncing
- do not build primary failure detection around short timeouts on `FlameAudio.bgm.play()` or `stop()`
- do not let overlays, dialogs, countdowns, or ad callbacks call `resumeEngine()` directly; route resume through a lifecycle-aware game method instead
- do not auto-resume combat from `resumed` while Android surface/audio cleanup may still be in flight

### SfxManager

`SfxManager` should expose:
- `preloadAllAudio()`
- `update(dt)`
- `resetGameplaySession()`
- `playUi(asset, volume, minInterval)`
- `playGameplay(asset, volume, minInterval, activeEnemies, activeProjectiles)`
- debug getters for pending, failure, skipped, suppressed

Rules:
- one place for cooldown policy
- one place for overload policy
- one place for failure suppression
- same API for widgets and gameplay, different policy flags
- short failure backoff is preferred over restart storms
- do not hold pending SFX slots until `FlameAudio.play()` futures complete; release them on fixed short windows instead

## Recommended Flame game design

### Game class responsibilities

The root game class should:
- preload or request preload completion
- create player
- create world and camera
- own runtime registries
- own debug instrumentation
- own ability dispatch
- own helper methods for timed effects, area damage, projectile spawn

The game class should not:
- contain long-lived Flutter widget state
- directly serialize preferences
- own reward ad business logic

### Player responsibilities

The player component should:
- move
- auto-attack on interval
- apply damage flash
- expose current combat stats
- call back into game for attack execution

The player should not:
- directly decide audio policy
- directly search the entire world for enemies

### Enemy responsibilities

Enemies should:
- register with game on mount
- unregister on remove
- own only their own AI and collision logic
- use game helpers for sound and projectile spawning

Enemies should not:
- start or switch BGM
- scan arbitrary global component lists unless provided by game

### Projectile responsibilities

Projectiles should:
- move
- self-expire by lifetime
- use cached enemy lists for splash checks
- unregister on remove

Projectiles should not:
- own UI
- spawn unlimited secondary effects without checking effect budget

## UI and overlay integration

Use `GameWidget` overlays for:
- HUD
- pause
- countdown
- upgrade/shop
- game over
- victory

Overlay rules:
- Flutter reads `GameState`
- overlays call game intent methods, not internal mutable fields
- lifecycle pause from app background is separate from pause button logic

Keep selection screens and lobby fully outside Flame.

## Save and retry design

Separate:
- global meta progression
- current run save
- leaderboard/history

Retry should keep only what the design explicitly allows.

Use two reset modes:
- full reset for new game
- retry reset for same-wave revive

Explicitly document what survives revive:
- attack
- speed
- multishot
- upgrades
- beans
- current wave

Do not let retry accidentally recreate static world or leak old timers.

## Effects and visual language

Differentiate ultimates by both mechanics and visuals.

Minimum effect recipe for a strong-looking ultimate:
- 1 main shape: circle, ring, line, cone, or aura
- 1 focal text or glyph
- 1 secondary radial icon pattern or burst
- automatic timed removal

Recommended pattern:
- tank/shield: shield icons, shock ring, warm white or blue accent
- mage/burst: spark or idea icons, larger radial spread
- healer/support: green sanctuary ring, heart or leaf motifs
- marksman/engineer: target/gear motifs, narrow line burst
- assassin/tactician: blades or crossed weapons, localized burst
- performer/rapid: star, mic, sparkle motifs with short high-energy burst

Do not use the exact same plain filled circle for every ultimate.

### 11. Treat wave 5+ as the first stress boundary

In wave-survival Flame games, wave 5 is often the first time special bosses,
upgrade overlays, and heavier enemy mixes overlap.

Design for that point explicitly:
- do not let enemy HP scale exponentially with wave or boss clears
- do not let boss patterns create many chained `TimerComponent`s for one barrage
- prefer immediate bounded bursts with load-aware projectile counts
- slow boss cadence when active projectile pressure is already high
- slow or defer new enemy spawns while projectile pressure is elevated
- add wave-specific diagnostics at start, boss spawn, clear, and hotspot moments

If wave 1-4 are smooth but wave 5+ stalls:
1. audit boss HP scaling first
2. audit chained timers second
3. audit projectile density third
4. only then lower enemy caps or visuals

## Instrumentation and debugging

Keep debug logs for:
- active enemies
- active projectiles
- transient effects
- world child count
- current/requested BGM
- pending/failure/suppressed SFX counts
- skipped effect count

Log at:
- wave start
- boss spawn
- wave clear
- revive/restart
- player death
- periodic heartbeat in debug

The goal is to answer:
- did counts reset correctly
- did projectiles leak
- did audio fail before frame drops
- did background/resume break music state

## Anti-patterns to forbid

Do not do these:
- direct `FlameAudio.play()` inside player/enemy/projectile hot paths
- repeated full-world scans during combat
- full-screen damage ultimates as a default balance choice
- multiple audio preload owners
- recreating map background on retry
- calling `notifyListeners()` every frame for cooldown UI
- leaving temporary components without timed cleanup
- pausing game only visually while simulation continues underneath
- mixing user pause state and app lifecycle pause state into one flag without history
- leaving dead or commented old combat implementations after refactors

## Review checklist for any new Flame project

Before calling the structure production-ready, verify:
- audio is centralized into BGM and SFX managers
- preload happens once
- backgrounding pauses simulation and stops music
- static world and dynamic world are separated
- active enemy/projectile registries exist
- hard caps exist for enemies, projectiles, and transient effects
- every transient component has deterministic cleanup
- UI updates are bucketed
- combat loops do not scan the whole world every attack
- boss/projectile patterns are bounded
- retry/revive cannot accumulate world objects or timers
- debug instrumentation can explain performance regressions quickly

## Build order for new games

When creating a new Flame action game, build in this order:

1. Create `GameState`, `BgmManager`, and `SfxManager` before abilities.
2. Define static-vs-dynamic world reset boundaries before adding revive logic.
3. Add runtime registries and caps before adding projectile-heavy enemies.
4. Add `addTimedWorldComponent()` before adding flashy effects.
5. Add app lifecycle pause/resume before polishing audio.
6. Add HUD overlays after state bridging is stable.
7. Add debug instrumentation before large balance passes.
8. Add ultimates only after local AoE and projectile rules are already budgeted.

## How to use this skill

When asked to build or refactor a Flame game:
- enforce centralized audio managers first
- enforce cached runtime registries second
- enforce lifecycle-safe pause/resume third
- enforce static/dynamic world split fourth
- only then add new enemies, abilities, or effects

If the existing project already works but becomes slow after audio or FX additions, audit audio ownership first, then entity counts, then Flutter rebuild frequency.

## Enemy architecture for reusable Flame projects

Do not let one `BaseEnemy` class own all of these at once:
- type stats
- collision radius
- sprite asset selection
- boss HUD metadata
- AI dispatch
- special attack patterns
- death/drop cleanup

Use this split instead:

1. `EnemyDefinition`
- immutable data only
- includes hp, speed, damage, cooldown, exp, radius, sprite path, behavior kind, optional boss title

2. `BaseEnemy`
- owns lifecycle, registration, damage intake, hit flash, death, reward drop, and collision handling
- reads from `EnemyDefinition`
- does not contain giant stat/sprite/radius switches

3. `EnemyBehaviorKind`
- a small enum such as `chase`, `bat`, `chargerRush`, `sniper`, `charge`, `bossChase`
- `BaseEnemy.update()` should dispatch through one `_runBehavior()` method based on the definition

4. Specialized subclasses only when justified
- if a boss or elite no longer fits the shared state machine, move it to its own subclass
- do not keep stretching `BaseEnemy` once it starts needing many one-off fields

Recommended pattern:

```dart
class BaseEnemy extends PositionComponent {
  late final EnemyDefinition definition;

  BaseEnemy({required EnemyType type}) {
    definition = enemyDefinitionFor(type);
  }

  void _initStats() {
    maxHp = definition.maxHp;
    speed = definition.speed;
    damage = definition.damage;
    attackCooldown = definition.attackCooldown;
  }

  void update(double dt) {
    _runBehavior(player, dt, distanceToPlayer);
  }
}
```

What this buys you:
- adding a new enemy usually means adding one definition entry, not editing multiple switches
- balance passes become data edits instead of code edits
- sprite swaps and radius tuning stop touching combat code
- `BaseEnemy` becomes a stable reusable template for future Flame games

Red flags that mean it is time to split further:
- more than one large `switch (type)` remains in `BaseEnemy`
- boss-only fields keep increasing
- several enemy types need private state that others never use
- projectile logic, movement logic, and boss UI logic all live in the same update branch

## Enemy behavior objects

Once enemy-specific state starts appearing, definition data alone is not enough.
Move behavior and its private runtime state out of `BaseEnemy`.

Good examples:
- charger rush phase, locked direction, rush timer
- sniper burst cadence and retreat/advance logic
- boss bullet pattern selection and boss-only projectile helpers

Recommended split:

1. `EnemyDefinition`
- immutable tuning data

2. `BaseEnemy`
- lifecycle
- registration
- damage intake
- death and reward handling
- collision handling
- common visual feedback

3. `EnemyBehavior`
- owns per-behavior update logic
- may own private runtime state for that behavior only

4. Behavior implementations
- `ChaseEnemyBehavior`
- `BatEnemyBehavior`
- `ChargerRushEnemyBehavior`
- `SniperEnemyBehavior`
- `ChargeEnemyBehavior`
- `BossChaseEnemyBehavior`

Recommended runtime wiring:

```dart
class BaseEnemy extends PositionComponent {
  late final EnemyDefinition definition;
  late final EnemyBehavior behavior;

  BaseEnemy({required EnemyType type}) {
    definition = enemyDefinitionFor(type);
    behavior = createEnemyBehavior(definition.behavior);
  }

  @override
  void update(double dt) {
    final player = game.player;
    final distance = position.distanceTo(player.position);
    behavior.update(this, player, dt, distance);
  }
}
```

Why this is better:
- charger-only state stops polluting every enemy instance
- sniper burst logic stops living in the base class
- boss projectile patterns become isolated and easier to balance
- `BaseEnemy` becomes reusable across multiple Flame projects

Review rule:
- if a behavior needs its own timers, phases, locked vectors, burst counters, or random pattern selection, do not keep that state in `BaseEnemy`
- move it into the behavior object or a dedicated subclass
