# ⚡ CyberHorde: Rogue Protocol

[![Engine](https://img.shields.io/badge/Engine-Godot%204.7-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Renderer](https://img.shields.io/badge/Renderer-Vulkan%20Forward%2B-red)](https://vulkan.org)
[![Multiplayer](https://img.shields.io/badge/Networking-ENet%20Co--op%20Multiplayer-brightgreen)](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
[![Repository](https://img.shields.io/badge/GitHub-YuriSekaii%2FCyberHorde--FPS--Roguelike-181717?logo=github)](https://github.com/YuriSekaii/CyberHorde-FPS-Roguelike)

A fast-paced 3D First-Person Horde Roguelike Shooter with online co-op multiplayer built in Godot 4.7. Survive escalating cybernetic waves, harvest Nanite XP and Scrap, crack open loot caches, and assemble overpowered builds solo or in squad co-op.

---

## 🎮 Quick Start & Launchers

The project includes bundled Godot 4.7.2 (`engine.zip`, 82 MB) that auto-unpacks on first run with zero external setup.

| Launcher Script | Description |
| :--- | :--- |
| **`Play_Game.bat`** | Launches the game lobby (Solo, Host, Join, Boss Battle, Updates). Auto-unpacks engine if missing. |
| **`Update_Game.bat`** | Runs `git pull` from Windows Explorer. |
| **`Test_Coop_2Players.bat`** | Launches two game windows side-by-side for local 2-player co-op testing. |
| **`Open_In_Godot_Editor.bat`** | Opens the project directly inside the Godot 4.7 Editor. |
| **`Push_To_GitHub.bat`** | Stages, commits, and pushes local changes to `origin main`. |

### Game Modes
* **Single Player**: Standard horde survival starting from Stage 1 (Day) Wave 1. Beating the Wave 50 boss continues into Stage 2 (Night) Wave 1 (see [Stages](#-stages)).
* **Host LAN Co-op (Server)**: Hosts an ENet multiplayer squad lobby on your network (default port: `7777`).
* **Join LAN Co-op (Client)**: Connects to a host IP (`127.0.0.1` for local multi-instance testing).
* **Host Online Lobby (Internet)**: Creates an online lobby and shows a 5-character code (e.g. `K7QXM`). Share it with up to 3 friends anywhere on the internet. No port forwarding needed.
* **Join Online Lobby (Code)**: Enter the host's lobby code and click Connect.
* **Boss Battle (Wave 50 Test Protocol)**: Direct deployment to a late-game target without grinding earlier waves.
  * **Target** (dropdown): `Stage 1 · Wave 50 — Apex Overlord`, `Stage 2 · Wave 50 — Blood Ghoul (Blood Moon)`, or `Stage 2 · Wave 1 — Nightfall Jungle`.
  * **Authorization Key**: Requires entering `HereComeTheChallenger`.
  * **Loadout**: Wave 50 targets start at Level 50 with all perks fully maxed (infinite-stack perks get 10 stacks each). The `Stage 2 · Wave 1` target starts fresh like a real Stage 2: Level 1, no perks.
  * **Mode**: Playable Solo or Hosted as Co-op.

---

## 🔄 In-Game Auto-Updater

* **Check for Updates**: Click `🔄 CHECK FOR UPDATES` in the main lobby. Runs an async `git fetch` against remote GitHub.
* **Status**: Confirms current commit hash (`✓ GAME IS UP TO DATE!`) or shows available commit count and recent commit messages.
* **1-Click Pull & Restart**: Click `⬇ UPDATE GAME NOW (GIT PULL)` to pull changes, then `🚀 RESTART GAME NOW` to relaunch.
* **desktop.ini Cleanup**: Before every fetch/pull, stray Windows `desktop.ini` files inside `.git` are deleted (they break git with `fatal: bad object refs/desktop.ini`).

---

## 🌐 Co-op Multiplayer Protocol

* **LAN Networking**: High-level ENet multiplayer (`ENetMultiplayerPeer`) over UDP port `7777`.
* **Online Networking**: The same high-level RPCs, sent through the CyberHorde lobby relay at `wss://phu-ai-lab.tailbca584.ts.net/cyberhorde` (Tailscale Funnel → [`server/lobby_relay.py`](server/lobby_relay.py) on port `8095`). The lobby creator is the authoritative host (peer 1). Joiners get ids 2–4, and a lobby holds max 4 players. When the host leaves, the lobby closes.
* **Squad Avatars**: Host (Player 1) has Neon Cyan accents; Client (Player 2) has Neon Amber accents. Overhead tags show name and live HP bar.
* **Shared Economy**: XP and Scrap are squad-shared. Upgrade card selection is simultaneous; choosing cards activates an **Aegis Stasis** protective shield.
* **Revive System**: Downed players enter a crawling beacon state. Teammates hold `E` for 5 seconds within 3m to revive them with 50% HP and 3s invulnerability (4.0s for Medics).
* **Targeting AI**: Horde units dynamically acquire and split aggro toward the nearest active, non-downed player.

---

## 🕹️ Controls

| Action | Input | Details |
| :--- | :--- | :--- |
| **Move** | `W`, `A`, `S`, `D` | Ground movement with smooth acceleration |
| **Look / Aim** | `Mouse` | Pitch clamped with subtle weapon sway |
| **Jump** | `Spacebar` | Includes 150ms coyote time and jump buffering |
| **Sprint** | `Shift` (hold) | 1.4× movement speed multiplier |
| **Fire** | `Left Mouse Button` | Primary weapon attack |
| **Reload** | `R` | Manual reload (automatic when magazine is empty) |
| **Switch Weapon** | `1`, `2`, `3` or `Mouse Wheel` | Instant cycle between Rifle, Shotgun, and Plasma |
| **Interact / Cache** | `E` | Opens floating Loot Caches |
| **Revive Ally** | `E` (hold 5s) | Within 3m of downed squadmate (4.0s for Medics) |
| **Class Active Skill** | `Q` | Triggers class active (Medic: Restore, Rogue: Dash, Gunner: Berserk) |
| **Escape Trap** | Mash `A` / `D` | Breaks a Bog Slime engulf (−0.5s per press) or a Blood Ghoul pin (10 presses). Quantum Dash can't break traps |
| **Select Upgrade Card** | `1`, `2`, `3` or `Click` | Picks 1 of 3 cards on level up or cache opening |
| **Reroll Cards** | `Click` button | Rerolls 3 cards with Scrap (starts at 500, doubles per use) |
| **Pause Menu** | `Escape` | Audio volume, mouse sensitivity, display options |
| **Toggle Window / Fullscreen**| `F11`, `Alt + Enter`, `M` (menus) | Cycles Windowed and Borderless Fullscreen |
| **Toggle Damage Numbers** | `F8` or Pause Menu | Toggles floating damage labels ON/OFF |
| **FPS Limit** | Pause Menu | Cycles 30 / 60 (default) / Unlimited; saved to settings |
| **FPS / GPU Readout** | `F3` | Shows FPS, active limit and measured GPU ms per frame |

---

## ⚙️ Performance & Optimization Architecture

* **Bullet Mesh Capping**: Rendered bullet meshes are capped at 40. Excess bullets simulate as non-visual raycasts with 100% damage, pierce, and status effects intact (hidden bullets track their position in a variable and never move their node). Bullet lights capped at 8.
* **Bullet Pooling**: Bullets are plain `Node3D` raycast sweepers (no physics body) recycled from a 512-slot static pool, sharing one ray query. Bullets that leave the arena (|X/Z| > 42m, Y > 50m) are recycled early.
* **Bullet Simulation Budget**: Past 400 live bullets, multi-pellet volleys (player and drones) merge into fewer, heavier pellets — 1/2 the pellets past 400, 1/3 past 800, … — with the same total volley damage (explosions and Tesla arcs scale with it). Only reached in extreme cases such as Berserk Protocol with a maxed Scatter Cannon.
* **Static Particle & Light Pooling**: 24 pre-allocated GPU explosion instances and 48 beam meshes prevent dynamic instantiation stalls. Explosion lights capped at 4 concurrent lights.
* **Optimized AoE**: Synchronous single-pass queries using `EnemyBase.all_enemies` with 2D AABB pre-filtering (`absf(dx) > r or absf(dz) > r`) eliminate `sqrt()` math. Bullets/explosions keep physics monitoring disabled.
* **Horde Limits**: Arena enemy limit capped at 40 (`MAX_CONCURRENT_ENEMIES`). Pairwise enemy-on-enemy collision solving is disabled via `collision_mask = 5` (world + player only).
* **Damage Label Throttling**: Active damage numbers capped at 35 (crits 50), checked before spawning; toggleable via `F8`.
* **Hit Feedback Throttling**: Boss HP bar redraws at most once per frame; the same SFX can't restart within 15ms; ricochet and Tesla Arc zaps are throttled to one per 35ms.
* **Frame Rate Cap**: Hard FPS cap via `Engine.max_fps` (30 / 60 / Unlimited, independent of VSync); drops to 30 while unfocused (`GameManager.BACKGROUND_MAX_FPS`). Physics stays at 60 Hz. Note: Task Manager GPU % is relative to the current clock — at a 60 FPS cap the driver downclocks the GPU, so ~30–40% is normal (measured on an RTX 3090: 450 MHz of 2115 MHz, ~2.5 ms/frame at that clock vs ~0.26 ms at full clock).

---

## 🔫 Weapons Arsenal

| Weapon | Key | Fire Mode | Base Damage | Pellets | Fire Rate | Mag | Reload | Base Crit | Key Mechanics |
| :--- | :---: | :--- | :--- | :---: | :--- | :---: | :---: | :---: | :--- |
| **Pulse Carbine** | `1` | Automatic | 22.0 | 1 | 0.12s (8.33/s) | 32 | 1.2s | 10% | High-velocity kinetic rifle |
| **Scatter Cannon** | `2` | Semi-Auto | 16.0 / pellet (192 total) | 12 | 0.65s (1.54/s) | 8 | 1.6s | 5% | Wide close-quarters spread (0.10828125 cone) |
| **Plasma Core** | `3` | Hold-to-Charge, Release-to-Fire | 150 direct + 150 AoE | 1 | 0.15 shot/s (~6.67s cd + 0.18s charge) | 5 | 2.0s | 25% | Slow heavy orb (~23.3 m/s), ~2.5m effective capture width, 5.0m AoE (6.25m with *Explosive Payload*), Tesla Arc radial synergy |

### Weapon Mechanics Notes
* **Plasma Core Charge Cycle**: Requires holding `LMB` for at least 0.18s before releasing to fire. Releasing early cancels without ammo cost or cooldown. The core glow shifts to Warning Red during cooldown/reload, popping to Neon Purple when ready.
* **Independent Cooldown Tracking**: Weapons track fire cooldowns independently across swaps. Holstered weapons continue cooling down in the background, preventing quick-swap cooldown bypass exploits on heavy weapons like the Plasma Core.
* **Tesla Arc Emitter Synergy**: When firing the Plasma Core with Tesla Arc Emitter, a radial lightning bolt strikes **every enemy** in the explosive radius before detonation, and each bolt then chains outward up to 8.5m.

---

## 🎖️ Operative Classes & Specializations

When deploying into a mission (Solo, Co-op, or Boss Battle), each player chooses 1 of 3 combat classes featuring distinct passives and active abilities triggered via `Q`:

| Class | Accent | Role | Passive Specialization | Active Skill (`Q`) |
| :--- | :---: | :--- | :--- | :--- |
| **Medic** | Neon Mint | Support & Sustain | **Nano-Regen & Quick Revive**: All squadmates regenerate **5% Max HP/s** (**Stackable** across multiple Medics). Revive downed teammates **25% faster** (4.0s vs 5.0s). | **Cellular Restore** (20s cd): Instantly recovers 20% Max Shield and 20% Max HP, then **cleanses** Poison & Bleed (the heal still takes the Bleed cut) and grants 2s **invulnerability + Status Immune** (no new Poison / Bleed; traps & pins still apply), then regenerates another 20% Max Shield/HP over 10s (2%/s; recast refreshes, no stacking) to ALL players. |
| **Rogue** | Neon Amber | Agility & Economy | **Bounty & Thrusters**: Enemies killed by me drop **+200% more XP and Scrap** (3× yield; Scrap still drops at the normal 45% chance). Gain **+25% MORE movement speed, jump speed, and reload speed** (reload bonus also applies to companion drones). | **Quantum Dash** (10s cd): Dash 15m in aim direction with complete invulnerability (+0.5s buffer) and **instantly reload all weapons**. Sky/air capable. |
| **Gunner** | Neon Crimson | Heavy Assault DPS | **Reckless Assault**: **+25% Critical Strike Chance** across all weapons and companion drones, but take **10% more damage** from all incoming sources. | **Berserk Protocol** (30s cd): For 5s, gain **invulnerability**, **Suppression Immune** (can't be pinned or trapped; casting it while pinned/engulfed breaks free instantly and counts as an escape, so the Blood Ghoul is knocked down and the Bog Slime pauses), **+500% MORE fire rate** and **unlimited magazine** across player weapons and companion drones. All weapons become fully automatic (hold to fire), and Plasma Core fires instantly without charging. All weapons and companion drones reload to full magazine when the skill ends. |

> [!NOTE]
> The Legendary perk **Cooldown Reduction** reduces your class active skill cooldown by **50%** (Medic: 10.0s, Rogue: 5.0s, Gunner: 15.0s). In co-op, players can pick identical or complementary classes; multiple Medics stack %Max HP/s aura regeneration for the entire squad.

### 🎯 Active Skill HUD & Cooldown System
The HUD features custom cyberpunk vector icons positioned at the bottom-left directly below the health bar:
* **Medic**: Cellular Restore (`medic_restore.svg`, Neon Mint cross & nanite ECG wave)
* **Rogue**: Quantum Dash (`rogue_dash.svg`, Neon Amber quantum thrusters & velocity chevrons)
* **Gunner**: Berserk Protocol (`gunner_berserk.svg`, Neon Crimson cyber skull & crossed minigun barrels)
* **Dynamic Radial Cooldown Wipe**: When activated into cooldown, the icon turns completely black and regains vibrant color in a clockwise radial sweep as cooldown progresses to 100% readiness, accompanied by live numeric countdown overlays and pulsating active state animations.

---

## 🔥 Squad Fever System

Operatives channel combat momentum into a squad-shared **Fever** rank shown in the top-right corner as a large tier letter (D gray, C cyan, B green, A orange, S pink) that fills from bottom to top with the current tier's duration:

| Fever Tier | Duration Window | Drop XP & Scrap | Spawn Rate (Less Interval) | Concurrent Enemy Cap | Intermission Delay | Common Weight Formula |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **D** | 0.0s – 20.0s | Baseline (+0%) | Baseline (1.0×) | 40 enemies | 4.5s | $80.0 \times 0.75^0 = 80.0$ |
| **C** | 0.0s – 20.0s | **+25% MORE** | **+25% MORE** (1.25×) | 50 enemies | 3.6s | $80.0 \times 0.75^1 = 60.0$ |
| **B** | 0.0s – 20.0s | **+50% MORE** | **+50% MORE** (1.50×) | 60 enemies | 3.0s | $80.0 \times 0.75^2 = 45.0$ |
| **A** | 0.0s – 20.0s | **+75% MORE** | **+75% MORE** (1.75×) | 70 enemies | 2.57s | $80.0 \times 0.75^3 = 33.75$ |
| **S** | 0.0s – 20.0s (Cap) | **+100% MORE** (2.0×) | **+100% MORE** (2.0×) | 80 enemies | 2.25s (Half Delay) | $80.0 \times 0.75^4 \approx 25.31$ |

### Fever Mechanics
* **Progression**: Start at **Tier D** (0.0s). Each enemy kill increases the active tier duration by **+2.0s**.
* **Promotion**: Reaching **20.0s** immediately promotes to the next tier, starting at **1.0s** of the new tier (caps at 20.0s at Tier S).
* **Demotion**: If current tier duration decays to **0.0s**, demotes to the lower tier at **19.0s** (clamps at 0.0s at Tier D).
* **Hit Penalty**: Every hit taken drains **10.0s** from the current tier. The drain stops at 0.0s of the current tier, which then demotes to the lower tier at **19.0s**; any leftover penalty is discarded. Hits nullified by Null Barrier or blocked by invulnerability (dash, skills, Phase-Shield) cost nothing.
* **Promotion Callout**: Each promotion flashes a short fade-out text under the rank letter listing what the new tier grants.
* **Economy & Horde Buffs**: Tier D provides no bonuses. Each tier above D grants **+25% MORE** XP and Scrap drops, **+25% MORE** enemy spawn rate (halving spawn interval at S), expands concurrent enemy cap up to 80, and reduces round intermission delay down to 2.25s at Tier S to sustain combat momentum.
* **Rarer Perk Upgrades**: Common perk base weight is increased by 25% from 64 to 80. Advancing Fever tiers decays Common weight by $80 \times 0.75^{\text{tier}}$, more than doubling the offering probability of Rare, Epic, and Legendary cards at Tier S.

---

## 🧬 Roguelike Upgrades System

### Upgrade Mechanics
* **Card Offer**: Leveling up or opening a Loot Cache offers 3 cards. Rarity rates: Common (~79.2% at Tier D down to ~54.7% at Tier S), with Rare, Epic, and Legendary cards appearing more than twice as frequently at max Fever.
* **Scrap Reroll**: Reshuffles 3 cards. Costs 500 Scrap initially, doubling per use (500 → 1,000 → 2,000 → 4,000...), shared across co-op.
* **Crits & Explosions**: Projectiles roll weapon crit chance (+ *Precision Optics*). Base crit multiplier is 2.0× (+ *Hollow-Point Rounds*). Explosions derive damage from initial hit damage and do not double-dip crits.
* **Knockback Removal**: Player weapons have zero knockback on enemies to prevent stunlock exploits.
* **Tesla Chaining**: Arcs sequentially up to 2–4 targets within 8.5m dealing 75% bullet damage (+50% damage boost). Does not trigger on ricochets (retains Plasma Core ricochet synergy). Can bounce back and forth (ping-pong) between 2+ alive targets; prioritizes unhit targets first.

### Perk Catalog

| Upgrade | Rarity | Effect | Max Stacks |
| :--- | :--- | :--- | :---: |
| **Heavy Caliber** | `Common` | +25% Projectile Damage across all weapons | Infinite |
| **Vital Plating** | `Common` | +25 Maximum Health (heals immediately on selection) | Infinite |
| **Precision Optics** | `Common` | +10% Critical Strike Chance | 5 |
| **Overclock Trigger** | `Common` | +25% Fire Rate | 6 |
| **Rapid Loader** | `Common` | +25% Reload Speed across all weapons | 6 |
| **Extended Mag** | `Common` | +30% Magazine Capacity across all weapons | 6 |
| **Kinetic Thrusters** | `Common` | +18% Movement Speed and +15% Jump Power | 1 |
| **Nanite Magnet** | `Common` | +60% XP & Loot collection radius | 2 |
| **Hardened Alloy** | `Rare` | +10% Damage Reduction against all incoming damage | 5 (50% max) |
| **Hollow-Point Rounds** | `Rare` | +0.5× Critical Hit Damage Multiplier | Infinite |
| **Hyper-Penetrator** | `Rare` | Projectiles pierce through +1 enemy (pierced enemies are excluded from the bullet's sweep, so it carries on to the next target) | 2 |
| **Aegis Energy Shield** | `Rare` | +25 Regenerating Shield capacity (grants shield on pick) | Infinite |
| **Vampiric Siphon** | `Rare` | Restores +4 HP on enemy kill | 1 |
| **Cryo Rounds** | `Rare` | Every damage instance you deal (direct, ricochet, explosion AoE, chain lightning, drone) slows the target by 25% for 3 seconds | 1 |
| **Nanite Scavenger** | `Rare` | +40% XP and Scrap drops from defeated enemies | 1 |
| **Explosive Payload** | `Epic` | Bullets explode on impact (2.5m AoE). Plasma Core AoE +25% (5.0m → 6.25m) | 1 |
| **Reactive Phase-Shield** | `Epic` | Taking damage grants 0.25s invulnerability | 1 |
| **Null Barrier** | `Epic` | Nullifies damage instance every 10s (triggers invulnerability perks) | 1 |
| **Multi-Barrel Splitter** | `Epic` | +100% Projectiles per shot (doubles shot count) | 2 |
| **Tesla Arc Emitter** | `Epic` | Direct hits arc chain lightning (75% damage) to 2 targets (+2 per stack, up to 4 max within 8.5m; no ricochet trigger except Plasma Core). Synergizes with Plasma Core | 2 |
| **Smart Bouncing Core** | `Epic` | Bullets ricochet with on-hit explosion per bounce (and Plasma Core chain lightning) | 2 |
| **Assault Drone Unit** | `Epic` | Deploys autonomous companion drone with 1 of 3 weapons (1/4 base fire rate, inherits all weapon perks, Gunner passive crit bonus, Gunner Berserk Protocol active, and Rogue passive reload speed). Drones never target Spawnlings | 3 |
| **Emergency Defibrillator**| `Legendary`| Prevents fatal damage, fully restores HP & Shield + 5s invulnerability. Recharges every 10 waves | 1 |
| **Cooldown Reduction** | `Legendary`| Reduces your class active skill cooldown by 50% | 1 |

---

## 👾 Enemy Scaling & Catalog

### Wave Scaling Formulas
* **Enemy Count per Wave**: $10 + \text{Wave} \times 6$ (Wave 50 Final Boss = $\infty$).
* **Spawn Interval**: $\text{clamp}(2.0 - \text{Wave} \times 0.1, 0.4, 2.0)$ (Wave 50 = $0.2\text{s}$).
* **Scaling Wave**: All per-wave formulas below use the *scaling wave*, which is the current stage's wave: every stage restarts the curve at Wave 1.
* **Compounding HP**: $+10\%$ per wave ($\text{Base} \times 1.10^{\text{Wave}-1}$).
* **Compounding Damage**: $+5\%$ per wave ($\text{Base} \times 1.05^{\text{Wave}-1}$).
* **Speed & Attack Rate**: $+5\%$ compounding every 10 waves ($1.05^{\lfloor\text{Wave}/10\rfloor}$).
* **Damage Reduction**: $+10\%$ every 10 waves (capped at 50% max at Wave 50).
* **Basic Spawn Decay**: Swarmer & Spitter weights decay $5\%$ multiplicatively every 5 waves ($\text{Weight} \times 0.95^{\lfloor\text{Wave}/5\rfloor}$).
* **Basic Unit Upgrades (Stage 1)**: From **Wave 31** the Volt Bomber fully replaces the Cyber Swarmer; from **Wave 41** the Photon Hornet fully replaces the Plasma Spitter (same spawn weights; Wave 50 boss escorts use the upgraded units).

### Enemy Stats (Stage 1)

| Enemy Type | Base HP | Speed | Damage | Attack Cooldown | Attack Type & Range | Base Weight | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- | :---: | :--- |
| **Cyber Swarmer** | 35.0 | 7.0 m/s | 10.0 | 0.8s | Melee bite (1.6m 3D sphere, $\le 1.8$m height) | ~45–55% | Decays every 5 waves |
| **Plasma Spitter** | 75.0 | 4.5 m/s | 18.0 | 2.4s | Homing orb (25.0m) | 30.0% | Wave 3+, decays every 5 waves |
| **Volt Bomber** | 35.0 | 8.0 m/s | 25.0 | — | Suicide blast (3.0m radius); auto-detonates within 2.0m of an operative and on death | Swarmer's | Wave 31+, replaces Swarmer |
| **Photon Hornet** | 90.0 | 5.5 m/s | 18.0 | 1.2s | Thin laser bolt, 48 m/s (28.0m); orbits target at ~11m, hovers ~3.5m up | Spitter's | Wave 41+, replaces Spitter |
| **Armored Goliath (Brute)** | 500.0 | 4.5 m/s | 35.0 | 3.5s | Slam AoE (7.2m, 5.7m trigger, 0.56s windup) + 10.0 knockup | 7.2% | Wave 6+ heavy tank |
| **Cyber Charger** | 220.0 | 3.2 m/s | 48.0 | 2.5s | 30 m/s rush attack | ~4.0–4.25% | Wave 11+, rushes only with a clear lane; wall crash causes 3.5s self-stun |
| **Void Spawner** | 4,000.0 | 2.8 m/s | — | 4.5s spawn | High-altitude flight (8.5m), spawns Spawnlings | 0.25% | Wave 20+, drops Loot Cache on defeat |
| **Cyber Spawnling** | 14.0 | 12.0 m/s | 2.5 / 0.15s | 0.15s tick | Rapid spinning drill contact | Portal spawn | **Immune to AoE, ricochet, & lightning; direct bullet hits only. Ignored by companion drones** |
| **Apex Overlord (Boss)** | 1,000,000.0 | 3.2–105 m/s | 120–540 | Multi-stage | Multi-stage ground & aerial attack loops | Wave 50 | Fixed HP & cadence; infinite horde until boss dies |

### 👑 Stage 1 Wave 50 Final Boss: Apex Overlord Phases
Reaching Wave 50 spawns the Apex Overlord on the center platform with an infinite horde (0.2s spawn interval, 40 concurrent cap). Victory triggers only when the boss is slain.
* **Phase 1 (100%–66% HP)**: Ground pursuit. Close Slam AoE (14.25m radius, 1.6× damage + knockup) or long-range dual plasma (0.45× damage).
* **Phase 2 (66%–33% HP)**: Aerial flight (Y ≈ 14m). Plasma bombs (6.75m AoE, 0.85× damage), Red Aura target lock (0.7s telegraph), and Hyper Dive (60 m/s, 15.75m AoE, 2.2× damage).
* **Phase 3 (<33% HP)**: Winged Fallen Angel. 6-muzzle needle curtain (65 m/s, 0.09× damage per needle), Cataclysmic Mega Orb (18.0m AoE, 2.8× damage), 8.0s exhaustion vulnerability window, and Supersonic Dive (105 m/s, 17.25m AoE, 2.5× damage). Needles that hit the ground (and the dive impact) leave ice spikes that deal needle damage every 0.5s on contact; the Mega Orb impact detonates them all in a ripple (3m radius, 2× needle damage). The spike blast also punches 4.5m straight down, so spikes on the platform still hit operatives hiding under it.

---

## 🌙 Stages

| Stage | Time | Arena | Roster | Wave 50 Boss |
| :---: | :---: | :--- | :--- | :--- |
| **1** | Day | Cyber arena (center platform, ramps, pillars, cover, jump pads) | Swarmer, Spitter, Brute, Charger, Void Spawner, Bomber, Hornet | Apex Overlord |
| **2** | Night | Moonlit jungle (flat grass, 26 trees, no platform, no jump pads) | Shadow Spider, Venom Wyvern, Bog Slime, Mantis Stalker, Spore Pit | Blood Ghoul (Red Moon) |

* **Progression**: Killing Stage 1's Wave 50 boss clears the horde and starts Stage 2 at **Wave 1** after a 10s "NIGHT FALLS IN" intermission. The arena swaps and the squad regroups at the center. Killing the Stage 2 boss wins the run.
* **Fresh build each stage**: Entering Stage 2 resets level (Lv 1), XP, all perks (drones, shield, Second Wind…), Scrap, reroll cost and Fever, and enemy scaling restarts at Wave 1. Operatives return to 100 Max HP at full health. Class and run stats (kills, damage, time) are kept. A level-up pick still open from Stage 1 is dropped.
* **HUD**: Wave label reads `DAY — WAVE n` / `NIGHT — WAVE n`; a banner announces Stage 2 and the Blood Moon.
* **Wave rules** (count, spawn interval, Loot Cache every 2 waves, infinite Wave 50 horde) are the same in both stages; only the roster differs.

### 🌲 Stage 2 Arena: Nightfall Jungle
* Same 80×80m footprint, perimeter walls (dark hedge) and invisible sky barriers as Stage 1. All flat ground covered in wind-swayed grass. Tree trunks are the only cover and block shots and movement. Silhouette treeline beyond the walls.
* **The Moon is the only light source** (52° high, cool blue, energy 2.54 for both the night moon and the Red Moon). Ambient light is near zero, so the moon shadow of every canopy is an almost pitch-black pool on the ground. Wave 50 turns it into a **Red Moon** (light, moon disc, sky and fog fade to blood red).
* The tree layout uses a fixed seed, so every co-op peer builds the same jungle. Ground enemies path on a navmesh baked from the trunks at load. The squad spawn area (9m radius around the center) has no trees.

### 🕷️ Stage 2 Enemy Stats

| Enemy Type | Base HP | Speed | Damage | Attack Cooldown | Attack Type & Range | Base Weight | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- | :---: | :--- |
| **Shadow Spider** | 40.0 | 6.0 m/s | 8.0 bite / 24.0 pounce | 0.8s bite, 5s pounce | Swarmer-style bite (1.6m); pounces when within 5m | 100% → ~19% | Pitch-black body, only its red eyes glow. Weight decays 5% every 5 waves and another 10% every 10 waves |
| **Venom Wyvern** | 70.0 | 5.0 m/s | 8.0 + Poison | 3.4s | Fast venom glob, 42 m/s (30m); glides ~3.2m above its target at ~14m range | 17.5% → 15% | Wave 6+. Decays 5% every 5 waves |
| **Bog Slime** | 800.0 | 3.0 m/s | 10 dmg/s (trap) | — | Touch (1.6m) engulfs the operative for 3s | 5% | Wave 11+. Hunched translucent lime ooze rising from a spreading puddle; a fanged skull shows through its clearer head, bone spikes and arrows jut from its back. Spits the operative out, then pauses 1.2s |
| **Mantis Stalker** | 200.0 | 2.0 m/s watched / 20.0 m/s unwatched | 40.0 | 1.5s watched / 0.3s unwatched | Scythe slash (2.3m) | 1% | Wave 21+. Brown void-mantis. "Watched" = inside any operative's view cone (~37°) with clear line of sight. **Unwatched: 75% damage reduction**, multiplied with the wave reduction (e.g. 40% wave DR → takes 15%) |
| **Spore Pit (Mini-Boss)** | 5,000.0 | Rooted | 60.0 | 2.8s | Global mortar: spore glob arcs into the sky and lands on a random operative's spot (5m AoE, 2.2s flight, landing zone marked); leaves a 5m poison puddle for 3s | 0.1% | Wave 31+, no alive cap. Drops a Loot Cache |
| **Blood Ghoul (Boss)** | 1,000,000.0 | 24 m/s flee & hunt / 30–45 m/s tree hop / 42 m/s leap | 200 (fixed) | 0.3s pin strikes | Shadow ambush, Engage Mode tree hops, pin, lifesteal, Bleed; 4 HP phases | Wave 50 | Fixed HP & damage; infinite horde until it dies |

### 🧪 Stage 2 Status Effects
| Effect | Source | Effect | Stacking |
| :--- | :--- | :--- | :--- |
| **Poison** | Venom Wyvern glob hit; standing in a Spore Pit puddle | −25% move speed and 5 dmg/s for 3s (× the wave damage factor $1.05^{\text{ScalingWave}-1}$). Hits shield first | Doesn't stack: a new hit refreshes the duration |
| **Engulf (Trap)** | Bog Slime touch | Can't move or jump for 3s while taking 10 dmg/s (× wave damage factor). Other enemies and projectiles still hit you. Each `A`/`D` press removes 0.5s | 3s trap immunity after release |
| **Pin (Trap)** | Blood Ghoul leap | Knocked flat on your back, camera locked looking up at the Ghoul (no mouse look). Held until you press `A`/`D` **10 times**. The Ghoul strikes every 0.3s meanwhile | 3s trap immunity after release |
| **Bleed** | Every Blood Ghoul attack | Lose 1% Max HP/s, **5% Max HP/s while moving**. Drains HP directly, bypassing shield and damage reduction. **All healing received −75%** (stims, Vampiric, Medic skill & regen) | Each hit **adds 1.5s** (base 1.5s, no cap): a long pin builds a long bleed |

* Status-effect damage (Poison, Engulf, Bleed ticks) never triggers Reactive Phase-Shield, doesn't consume Null Barrier and doesn't cost Fever. Invulnerability (dash, skills, Second Wind, Phase-Shield) blocks new traps and nullifies status-effect damage, but effect durations keep counting down. Going down clears all effects.
* **Status Immune** (Medic Cellular Restore, 2s) blocks new Poison and Bleed only. **Suppression Immune** (Gunner Berserk Protocol, 5s) blocks pins and traps; the HUD lists both with timers.
* The HUD tints the screen (green engulf, pulsing red pin), shows a `MASH [A] [D] TO ESCAPE` prompt with a progress bar, and lists active effects with timers above the hotbar.

### 🩸 Wave 50 Final Boss: Blood Ghoul
A tall, starved wendigo-like horror: an emaciated pitch-black body with ribs pressing through the hide, a sunken belly, long thin sinewy limbs and knobby knees, crowned by a vast antler rack. Its skull-like face has swept-back pointed ears, deep black sockets with burning red eyes and a too-wide mouth of long jagged fangs that pours fresh blood down its throat and belly. The cracked hide is splattered all over with its victims' blood (crusted patches, runs dribbling down, sprayed droplets, blood caked in the cracks, fresh glistening patches), and torn strips of hide hang from its loins, flanks and arms. Its huge long-fingered hands are drenched in blood to the elbow, and blood drips from every hooked claw (drops swell on the tips and fall). While it hides its eyes go dark and the claws stop dripping, so in a canopy shadow it's practically invisible; the eyes ignite when it hunts and blaze while it leaps and pins. It spawns hidden (no spawn telegraph) under the tree farthest from the squad.
* **Hide**: Crouches in a tree's moon shadow. Once an operative stays within **25m for 2s**, it silently locks their current position (no sound, flash or indicator) and leaps at it at 42 m/s.
* **Pin**: Touching an operative mid-leap pins them flat on their back (0.5× damage pounce): their camera drops to the ground and stays locked on the Ghoul straddling them, which rakes with alternating claws every **0.3s**: each hand cocks high and 45° out to its side, then slashes diagonally in across the victim's face as the torso wrenches that shoulder into the blow (blood from its claws drips onto the victim's view) (each hit plays a flesh-tearing rip and jolts the view) (0.2× damage, heals the Ghoul **1% Max HP** per landed strike) until they mash `A`/`D` 10 times. On escape it's knocked down for 2s, then flees at 24 m/s to a random tree (preferring ones ≥14m from every operative) and hides again.
* **Miss**: If the leap touches no one, momentum drags it 5m past the locked spot (or into a trunk) and it falls, **stunned for 5s**, then flees.
* **Engage Mode (anti-camping)**: After **10s** total spent hiding with no operative in its 25m reach (time with someone in reach doesn't count; the count only restarts after a leap or a 1% flee), it engages: its eyes smoulder red (visible from afar, dimmer than its hunting blaze) and it takes **90% less damage while hiding**. Once **no operative has looked at it for 2s** (view cone + clear line of sight, like a Mantis Stalker; staring pauses the count, 2s of staring resets it), it hops (30 m/s arc) to another tree closer to the nearest operative: the closest to them within 22m, else the nearest tree still ≥3m closer. If no tree gets it closer, it **leaps straight at them from any range** instead. After each hop the 2s unwatched count restarts. Once someone is within 25m the usual lock and leap take over; leaping ends Engage Mode.
* **Hidden**: While hiding it only takes **direct bullet hits** (immune to explosions, ricochets and chain lightning, like a Spawnling) and companion drones ignore it. After losing **1% Max HP** in one stay in the shadows (tree hops don't reset the count), it flees to another random tree and **drops Engage Mode**, **immune to all damage** until it reaches that tree.
* All its attacks inflict **Bleed**. Fixed **200 damage** (no wave scaling): pounce 100, pin strike 40; 50% damage reduction at the Stage 2 final wave.
* **Phases** (by HP; each one only escalates, so pin lifesteal can't undo it; a low growl marks each change):

| Phase | HP | Changes |
|:---|:---|:---|
| **1** | > 2/3 | As above |
| **2** | ≤ 2/3 | Engage Mode triggers after **5s**; hops after **1s** unwatched; hops **+50% speed** (45 m/s) |
| **3** | ≤ 1/3 | **Permanently engaged** (leaps and the 1% flee no longer end it); hops the **instant** nobody is looking at it |
| **4** | ≤ 10% | **Stops hiding**: endlessly sprints (24 m/s) at the nearest operative, closes to 12m, then locks for **1.5s** and leaps; after a pin, knockdown (**1.5s**) or miss stun (**4s**) it resumes the hunt instead of fleeing. **90% damage reduction** while exposed (on top of the wave reduction) |

---

## 💎 Pickups & Arena Elements

* **Arena Layout (Stage 1)**: 80×80m floor (walls at $|X|, |Z| = 40\text{m}$) with a raised center platform (top at 3.9m) reached by N/S walkable ramps (18° slope, flush with the floor, open sides — no jump needed), 4 tall pillars at $(\pm17.5, \pm17.5)$ and 4 jump pads at $(\pm22.5, \pm22.5)$. Matte slate-grey palette (darker floor, lighter walls) keeps glare low so neon enemies and pickups stand out.
* **Cover**: 6 solid cyan-trim pieces that block shots both ways — 2 waist-high walls flanking the platform (E/W) and 4 tall 2.6m barricades in a pinwheel at $(24, -9)$, $(9, 24)$, $(-24, 9)$, $(-9, -24)$. Ground enemies (Swarmer, Bomber, Brute, Charger stalk) follow a navmesh baked from the arena colliders at load, so they take the ramps to reach operatives on the platform (nav-only obstacles along the ramp sides make the low front edge the only way on, so they never try to climb a ramp side), and still slide along cover faces when bumped (the Boss only slides); a Charger only winds up its rush with a clear lane to the player (no ramming ramp sides or cover from below), but still crashes and stuns if the player ducks behind cover mid-rush. Wave spawns and loot caches use a physics overlap check so nothing spawns inside pillars, ramps or cover.
* **Arena Walls & Non-Intrusive Sky Barriers**: Standard 8m visible perimeter walls preserve the open-sky horizon. An invisible upper barrier (Layer 5, up to 48m) blocks operatives and enemies from dashing or flying into the abyss while letting all weapon projectiles pass freely through into the sky without exploding or ricocheting.
* **Abyss Safety & Void Fall Recovery**: Falling into the abyss ($Y < -15\text{m}$) teleports the operative back onto the arena floor with a 20% HP penalty and 2.0s invulnerability. Any enemy unit that somehow ends up out of the arena (beyond perimeter walls $|X|, |Z| > 39.5\text{m}$, below floor $Y < -1.0\text{m}$, or above sky boundary $Y > 45.0\text{m}$) is instantly eliminated with all loot drops safely placed onto the arena floor.
* **Nanite XP Crystals** *(Cyan/Green)*: Magnetize to player; fills squad level-up bar.
* **Medical Stims** *(Red)*: Instantly restores 25 HP. Drops more frequently at low health.
* **Scrap Currency** *(Gold)*: Currency collected to fund card rerolls.
* **Loot Caches**: Spawns every 2 waves and drops from defeated Void Spawners and Spore Pits. Press `E` for bonus scrap/health and 1 free card pick.
* **Jump Pads**: 4 Stage 1 launch pads propelling players skyward for aerial traversal (none in the Stage 2 jungle).
* **Spawn Telegraphs**: Each incoming enemy is announced by a color-coded ground portal (spinning ring, filling disc, low 0.5m glow, sparks under ~1.4m, countdown label at 1.2m) kept low so it never blocks the view. The Void Spawner's portal instead beams up to its sky spawn point.

---

## 📂 Project Architecture

```
CyberHorde-FPS-Roguelike/
├── project.godot                     # Core Godot 4.7 configuration & autoloads
├── Play_Game.bat / Update_Game.bat   # 1-click launch and git pull scripts
├── Test_Coop_2Players.bat            # 2-player local co-op launcher
├── Open_In_Godot_Editor.bat          # Godot Editor launcher
├── Push_To_GitHub.bat                # Git commit & push script
├── server/
│   ├── lobby_relay.py                # Online lobby relay (WebSocket, lobby codes, max 4 players)
│   └── run_relay.bat                 # Starts the relay hidden in the background (port 8095)
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd           # ★ Perk catalog (`upgrade_database`), stats, level/reroll logic, current stage
│   │   ├── network_manager.gd        # LAN (ENet) + online lobby squad management & signals
│   │   └── sound_manager.gd          # Pure synthesized 16-bit PCM procedural audio
│   ├── network/
│   │   └── relay_peer.gd             # MultiplayerPeerExtension that sends multiplayer packets through the lobby relay
│   ├── player/
│   │   ├── player.gd                 # First/third-person controller, defensive perks, weapons, Stage 2 status effects
│   │   └── drone.gd                  # Companion drone perk AI
│   ├── enemies/
│   │   ├── enemy_base.gd             # Base enemy class (target selection, health, damage)
│   │   ├── swarmer.gd / spitter.gd   # Basic swarmer and ranged spitter AI
│   │   ├── bomber.gd / hornet.gd     # Late-wave suicide bomber and laser gunship drone AI
│   │   ├── brute.gd / charger.gd     # Heavy ground-slammer and charging bull AI
│   │   ├── spawner.gd / spawnling.gd # Sky carrier spawner and drill minion AI
│   │   ├── boss.gd                   # Stage 1 Wave 50 Apex Overlord multi-stage boss AI
│   │   ├── spider.gd / wyvern.gd     # Stage 2 pouncing spider and venom-spitting flyer AI
│   │   ├── slime.gd / stalker.gd     # Stage 2 trapping slime and gaze-reactive mantis AI
│   │   ├── spore_pit.gd              # Stage 2 rooted mortar mini-boss (drops Loot Cache)
│   │   └── blood_ghoul.gd            # Stage 2 Wave 50 Blood Ghoul shadow-ambush boss AI
│   ├── projectiles/
│   │   ├── bullet.gd                 # Projectile simulation, pierce, ricochet, explosions, Tesla arcs
│   │   ├── enemy_projectile.gd       # Spitter plasma orb / Hornet laser (enemy_laser.tscn) / Wyvern venom (poison)
│   │   ├── spore_mortar.gd           # Spore Pit sky-lobbed glob with landing-zone marker
│   │   ├── spore_poison_zone.gd      # 3s poison puddle left by each spore impact
│   │   └── explosion.gd              # Static pooled AoE blast and particle system
│   ├── loot/
│   │   ├── loot_pickup.gd            # Pickups (XP, Stim, Scrap) and magnet logic
│   │   └── chest.gd                  # Interactive Loot Cache
│   ├── ui/
│   │   ├── lobby_menu.gd / hud.gd    # Lobby and in-game HUD
│   │   ├── upgrade_menu.gd           # Upgrade card presentation and Scrap rerolls
│   │   └── pause_menu.gd / game_over.gd
│   └── world/
│       ├── wave_spawner.gd           # Wave director, per-stage enemy weights, Wave 50 bosses, stage transitions
│       ├── jungle_arena.gd           # Stage 2 night jungle: trees, grass, moonlight, Red Moon, hide spots
│       ├── arena_navigation.gd       # Bakes the ground-enemy navmesh from arena colliders at load
│       └── jump_pad.gd / spawn_indicator.gd
└── scenes/                           # Godot .tscn files mirroring the scripts directory structure
```

---

## 🛠️ Developer Guide: Architecture & Extending the Game

### 1. Multiplayer Networking Architecture
* **Autoload**: [`scripts/autoload/network_manager.gd`](scripts/autoload/network_manager.gd) manages `ENetMultiplayerPeer` (LAN) or the relay peer (online), peer connections, and lobby events.
* **Online Relay**: [`scripts/network/relay_peer.gd`](scripts/network/relay_peer.gd) connects one WebSocket to the relay. Binary frames carry an int32 LE header: the target peer when sending (`0` = all, `<0` = all except), the source peer when receiving. Text frames carry JSON control messages (`create`, `join`, `peer_connected`, `peer_disconnected`, `error`). The relay is TCP, so every packet arrives reliable and ordered.
* **Running the Relay** (only on the Funnel PC): run `server/run_relay.bat`. On startup it adds the route `tailscale funnel --bg --set-path=/cyberhorde http://127.0.0.1:8095`. Health check: `https://phu-ai-lab.tailbca584.ts.net/cyberhorde` returns `CyberHorde lobby relay OK`.
* **Player Ownership**: Each player node is named `"Player_%d" % peer_id`. `set_multiplayer_authority(id)` controls authority. Local players run first-person rigs; remote peers show third-person models and overhead HP tags.
* **RPC Rule**: Any RPC sent from client to server must specify `@rpc("any_peer", ...)` to prevent authority rejection in Godot 4.

### 2. How to Add or Modify Perks
1. **Catalog Definition** in [`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd):
   * Add/edit entries in `upgrade_database` dictionary (`id`, `name`, `desc`, `rarity`, `color`, `max_stacks`).
2. **Stat Declaration & Reset**:
   * Add bonus variables in `game_manager.gd` and reset them in `reset_game()`.
3. **Application**:
   * Implement value increments in `apply_upgrade(upgrade_id: String)`.
4. **Hook Execution**:
   * Player/Defense: hook in [`scripts/player/player.gd`](scripts/player/player.gd) (`_update_stats()` or `take_damage()`).
   * Projectiles/Hit effects: hook in [`scripts/projectiles/bullet.gd`](scripts/projectiles/bullet.gd).
   * Loot/Economy: hook in [`scripts/loot/loot_pickup.gd`](scripts/loot/loot_pickup.gd).

### 3. How to Add a Weapon
1. In [`scripts/player/player.gd`](scripts/player/player.gd): Add a new `Weapon.new()` instance in `_setup_weapons()` and append to `weapons`.
2. In [`scenes/player/player.tscn`](scenes/player/player.tscn): Add visual mesh under `Head/Camera3D/WeaponRig`.
3. Update `_switch_weapon()` and `_update_third_person_weapon()` in `player.gd` for model visibility.

### 4. How to Add an Enemy Type
1. Inherit from [`scripts/enemies/enemy_base.gd`](scripts/enemies/enemy_base.gd) in `scripts/enemies/` and override `_behave(delta)`.
2. Create scene in `scenes/enemies/` with `CharacterBody3D` (`collision_mask = 5`).
3. In [`scripts/world/wave_spawner.gd`](scripts/world/wave_spawner.gd): Preload scene, assign type ID, and configure wave weight in `_select_enemy_type()` (Stage 1) or `_select_stage2_enemy_type()` (Stage 2). Add a spawn telegraph theme in [`scripts/world/spawn_indicator.gd`](scripts/world/spawn_indicator.gd).

### 5. How Stages Work
* `GameManager.current_stage` drives everything; `GameManager.set_stage()` emits `stage_changed`, and [`scripts/main.gd`](scripts/main.gd) swaps the arena scene from `STAGE_ARENAS`.
* The server's wave spawner advances the stage when the Wave 50 boss dies (`rpc_advance_stage`) and starts the new stage at Wave 1. Every peer calls `GameManager.reset_stage_progression()` first, which emits `progression_reset` (player full-heals, HUD refreshes, an open upgrade pick closes).
* Enemy stats scale from `GameManager.get_scaling_wave()`; damage-over-time effects use `get_wave_damage_factor()`.
* Player status effects live in `player.gd`: `apply_poison()`, `apply_bleed()`, `apply_trap(source, duration, dps, presses_needed)`. A trap source gets `on_trap_released(player, escaped)` when it ends.

### 6. Web Export Roadmap
* Switch `project.godot` renderer to `gl_compatibility` (WebGL2).
* Online lobbies already run over WebSocket (`relay_peer.gd`), so a browser build can use them directly. LAN mode stays desktop-only (ENet).
* Serve with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` headers for `SharedArrayBuffer`.
