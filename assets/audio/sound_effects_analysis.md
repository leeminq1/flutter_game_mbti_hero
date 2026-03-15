# 🎵 MBTI 히어로 - 사운드 이펙트(SFX) & BGM 분석 리포트

현재 게임 코드를 기반으로 타격감과 플레이 경험을 향상시키기 위해 필요한 오디오 에셋들을 체계적으로 분류했습니다. 개발 효율을 위해 필수(P0)와 권장(P1)으로 나누어 정리했습니다.

---

## 1. 배경음악 (BGM - Background Music)
게임의 흐름과 긴장감을 조절하는 루프 음악입니다.

| 파일명 | 상황 (Hook) | 우선순위 | 설명 |
|---|---|---|---|
| `bgm_lobby.mp3` | 메인 앱 실행, 캐릭터 선택창, 결과창 | P1 | 직장인의 출근길이나 야근을 연상시키는 경쾌하거나 리드미컬한 음악 |
| `bgm_battle.mp3` | 일반 전투 (Wave 1~4, 6~9 등) 진행 중 | P0 | 전투의 텐션을 올리는 빠른 템포의 음악 |
| `bgm_boss.mp3` | 보스 등장 (Wave 5, 10 등) 및 보스전 진행 중 | P0 | 위기감을 고조시키는 강렬하고 긴박한 음악 |
| `bgm_gameover.mp3` | 플레이어 체력 0으로 사망 시 | P1 | 야근에 지쳐 쓰러지는 듯한 코믹하거나 우울한 짧은 루프 |

---

## 2. 플레이어 및 무기 사운드 (Player SFX)
가장 많이 듣게 될 소리이므로 귀가 피로하지 않아야 합니다.

| 파일명 | 코드 발생 위치 | 우선순위 | 설명 |
|---|---|---|---|
| `sfx_shoot.wav` | `player.dart` - `_shootAtEnemy()` / `_shootForward()` | P0 | 기본 공격 발사 소리 (서류 던지기, 총 쏘기 등 가벼운 소리) |
| `sfx_player_hit.wav` | `mbti_game.dart` - `player.takeDamage()` | P0 | 적과 부딪히거나 적 발사체에 맞았을 때 타격음 (신음소리 또는 둔탁한 타격음) |
| `sfx_player_die.wav` | `mbti_game.dart` - 플레이어 체력 0 도달 시 | P0 | 쓰러질 때 이펙트음 |
| `sfx_ultimate.wav` | `game_state.dart` - `useUlt()` | P0 | 화면 깜박임과 동시에 발동되는 체력 회복/광역기 전용 강렬한 사운드 |
| `sfx_assist.wav` | `game_state.dart` - `useAssist()` | P0 | 동료 능력치 상승 또는 도움을 받을 때의 경쾌한 버프 사운드 |

---

## 3. 적 및 보스 사운드 (Enemy SFX)
타격감에 가장 큰 영향을 미치는 요소 중 하나입니다.

| 파일명 | 코드 발생 위치 | 우선순위 | 설명 |
|---|---|---|---|
| `sfx_enemy_spawn.wav` | `enemy_spawner.dart` - `_spawnEnemy()` | P1 | 바퀴벌레, 압정 등이 필드에 등장할 때 (선택적) |
| `sfx_enemy_hit.wav` | `base_enemy.dart` - `takeDamage()` | P0 | **가장 중요한 타격음**. 경쾌하게 터지는 소리나 맞는 소리 |
| `sfx_enemy_die.wav` | `base_enemy.dart` - `die()` | P0 | 적이 죽고 폭발 이펙트가 나올 때 터지는 소리 |
| `sfx_boss_warning.wav` | `enemy_spawner.dart` - `_spawnBoss()` 전 텍스트 팝업 | P0 | "보스 출현!" 문구 뜰 때 사이렌(삐- 삐- 삐-) 소리 |
| `sfx_boss_attack.wav` | `mbti_boss_enemy.dart` - 보스 발사체 생성 시 | P1 | 보스의 묵직한 마법이나 발사체 공격음 |

---

## 4. 아이템 획득 및 UI (Item & UI SFX)
성장의 재미를 청각적으로 체감하게 해줍니다.

| 파일명 | 코드 발생 위치 | 우선순위 | 설명 |
|---|---|---|---|
| `sfx_coin.wav` | `coffee_bean.dart` - 플레이어 충돌 시 | P0 | 커피콩(경험치/재화)을 획득할 때 찰랑/뿅 하는 소리 |
| `sfx_powerup.wav` | `power_up.dart` - 플레이어 충돌 시 | P0 | 멀티샷, 공격력 등 능력치 박스 먹을 때 기분 좋은 효과음 |
| `sfx_heal.wav` | `power_up.dart` / `힐러 힐 발동 시` | P1 | 체력이 차오르는 띠링~ 소리 |
| `sfx_wave_clear.wav` | `enemy_spawner.dart` - Wave 종료 시 텍스트 팝업 | P1 | 한 웨이브가 끝나고 다음 웨이브 대기 상태일 때 징글 |
| `sfx_button.wav` | 캐릭터 선택, 이어서 하기 등 각종 UI 버튼 탭 | P1 | 메뉴를 누를 때 깔끔한 클릭음 |

---

## 💡 개발 시 고려사항

1. **파일 포맷**: 모바일(Web/Android) 환경 최적화를 위해 BGM은 `.mp3` 또는 `.ogg`, 짧은 효과음(SFX)은 `.wav` 형식을 권장합니다.
2. **사운드 풀(Sound Pool) 캐싱**: 타격음(`sfx_enemy_hit.wav`), 총알 발사음(`sfx_shoot.wav`), 코인 획득음(`sfx_coin.wav`)처럼 **1초에도 여러 번 재생되는 소리**는 한 번에 여러 개가 겹쳐서 들려야 하므로, 게임 시작 시(onLoad) `FlameAudio.audioCache`에 미리 로드(Pre-load) 해두어야 화면 멈춤(렉)이 발생하지 않습니다.
3. **볼륨 조절**: BGM은 0.3~0.5 정도로 작게 깔고, 타격음 등 핵심 SFX를 0.8~1.0 수준으로 높여야 쾌적합니다.
