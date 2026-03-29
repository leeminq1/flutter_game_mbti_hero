# Audio Architecture

## Why the previous structure failed

The audio freezes were not caused primarily by oversized `.mp3` files.

The main failure mode was command contention on the Android audio backend:
- BGM preload and SFX preload were mixed in one service.
- Audio preload happened in both splash flow and game `onLoad()`.
- BGM restart requests could come from multiple places at once:
  - splash resume flow
  - home screen lifecycle flow
  - game start/retry/game-over transitions
  - watchdog recovery logic
- Background/foreground transitions raced with `stop -> seek -> reset -> prepareAsync`
  while new playback requests were already being issued.

That created a bad pattern:
- lifecycle pause/reset from Android
- app code issues more `play/stop/restart`
- stale `MediaPlayer` callbacks finish late
- recovery logic interprets that as missing BGM
- recovery logic restarts again

The result was frame stalls, repeated timeout logs, and audio state churn.

There was a second structural bug as well:
- the code treated `FlameAudio` playback futures as authoritative health signals
- on the affected Android device, those futures often completed late or not at all
- meanwhile native `MediaPlayer` playback could already be preparing or even starting

That means timeout-based failure detection was producing false negatives.

## Final ownership model

### Bootstrap ownership

`AudioBootstrap` is the only bootstrap owner.

Responsibilities:
- preload SFX once
- preload BGM assets once
- run during splash/bootstrap only

Rules:
- game instances must not preload global audio
- widgets must not trigger ad-hoc preload calls
- retry/revive/game-over must reuse already prepared audio state

Files:
- [audio_bootstrap.dart](C:\Users\min21\Desktop\flutter_grame\flutter_game\lib\services\audio_bootstrap.dart)
- [splash_screen.dart](C:\Users\min21\Desktop\flutter_grame\flutter_game\lib\screens\splash_screen.dart)

### BGM ownership

`BgmManager` is the only owner of music playback.

Responsibilities:
- keep one requested track
- keep one current track
- serialize all stop/start work
- avoid timeout-based failure inference from playback futures
- avoid immediate resume storms after lifecycle changes

Rules:
- do not preload BGM in `SfxManager`
- do not call `FlameAudio.bgm.play` outside `BgmManager`
- do not run watchdog restarts from the game loop by default
- do not issue overlapping BGM restarts from multiple screens/components
- do not use short timeout wrappers around `FlameAudio.bgm.play()` / `stop()` as a primary failure detector

File:
- [bgm_manager.dart](C:\Users\min21\Desktop\flutter_grame\flutter_game\lib\services\bgm_manager.dart)

### SFX ownership

`SfxManager` is the only owner of short effect playback.

Responsibilities:
- preload only short SFX
- throttle duplicate/in-flight effects
- skip low-value gameplay SFX under load
- release in-flight bookkeeping on fixed windows instead of waiting for backend futures
- avoid treating delayed `FlameAudio.play()` futures as authoritative backend health signals

Rules:
- UI effects and gameplay effects share one backend, but not one policy
- gameplay SFX may be dropped under pressure
- UI sounds should stay sparse and low-frequency
- no direct `FlameAudio.play` outside `SfxManager`
- do not depend on `FlameAudio.play()` future completion to clear pending state

File:
- [sfx_manager.dart](C:\Users\min21\Desktop\flutter_grame\flutter_game\lib\services\sfx_manager.dart)

## Lifecycle contract

### Background

On `inactive`, `hidden`, or `paused`:
- gameplay pauses in the game class
- `BgmManager` marks the app inactive
- pending BGM recoveries are cancelled
- requested music is explicitly stopped so background playback cannot continue
- SFX pending bookkeeping is cleared so stale in-flight state does not leak across resume
- game update loops must not advance at all while lifecycle is inactive, even if a UI overlay or delayed callback tries to resume the engine

### Foreground

On `resumed`:
- gameplay should return only through a safe resume path such as a resume-confirm popup plus countdown, not an immediate engine resume inside the lifecycle callback
- `BgmManager` checks whether a requested track exists and whether music is already playing
- non-gameplay tracks such as `lobby` and `gameOver` may auto-restore on app resume
- gameplay tracks such as `battle` and `boss` must wait for an explicit gameplay resume path
- if music is already alive, no extra refresh is issued
- SFX resumes with empty in-flight bookkeeping rather than stale pending slots

This avoids restart storms while Android is still cleaning up the previous player state,
without leaving the lobby silent after a normal app return.

## Prohibited patterns

Do not reintroduce any of these:
- BGM assets inside `SfxManager.preloadAssets`
- audio preload in both splash and game `onLoad()`
- BGM watchdog calls from `update(dt)`
- calling `BgmManager.setTrack(...)` from many unrelated flows without ownership review
- direct `FlameAudio.bgm.play(...)` or `FlameAudio.play(...)` outside managers
- forcing immediate BGM restart on every foreground event
- restoring battle or boss music from a generic app `resumed` event without checking gameplay ownership
- resuming Flame simulation immediately from the app lifecycle callback while Android surfaces and audio backends are still settling
- leaving BGM alive during background and hoping the backend will self-recover
- keeping stale joystick/input state across background transitions
- calling `resumeEngine()` directly from Flutter overlays or delayed callbacks without checking lifecycle ownership first
- timeout-driven failure loops around `FlameAudio` futures

## Recommended extension path

If future audio complexity grows, extend in this order:
1. keep current ownership boundaries
2. add explicit reasons/metrics to `BgmManager.setTrack(...)`
3. split UI SFX and gameplay SFX budgets further
4. if backend instability continues on Android, move BGM onto a dedicated player path separate from effect playback

Do not solve future audio bugs by adding more restart triggers.

## Wave 5+ combat stability

Wave 5 is the first real stress boundary in this project.

Why:
- it is the first MBTI boss wave
- it is the first wave-clear path that opens the upgrade overlay
- later waves combine higher enemy counts with more projectile-heavy patterns

That means audio/lifecycle fixes are necessary but not sufficient.
Combat pressure must also be bounded.

Required rules for wave 5+:
- do not scale enemy HP exponentially by boss clears or wave milestones
- keep wave scaling shallow enough that fights end decisively
- do not build boss barrages by chaining many `TimerComponent`s for one attack
- prefer immediate bounded bursts with load-aware shot counts
- reduce boss attack cadence automatically when active projectile counts are already high
- slow enemy spawning when projectile pressure is already elevated
- log wave start, boss spawn, wave clear, and hotspot states for wave 5+

Recommended performance strategy:
1. reduce combat duration before reducing spectacle
2. remove timer churn before lowering enemy caps
3. shed projectile density under load before dropping core game rules
4. keep diagnostics focused on active enemies, active projectiles, world child count, and skipped effects
