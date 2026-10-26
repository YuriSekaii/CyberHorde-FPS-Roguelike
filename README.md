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
* **Single Player**: Standard horde survival starting from Wave 1.
* **Host Co-op (Server)**: Hosts an ENet multiplayer squad lobby (default port: `7777`).
* **Join Co-op (Client)**: Connects to a host IP (`127.0.0.1` for local multi-instance testing).
* **Boss Battle (Wave 50 Test Protocol)**: Direct deployment to the **Wave 50 Apex Overlord** fight without grinding earlier waves.
  * **Authorization Key**: Requires entering `HereComeTheChallenger`.
  * **Loadout**: Automatically equips all perks fully maxed (infinite-stack perks get 10 stacks each).
  * **Mode**: Playable Solo or Hosted as Co-op.

---

## 🔄 In-Game Auto-Updater

* **Check for Updates**: Click `🔄 CHECK FOR UPDATES` in the main lobby. Runs an async `git fetch` against remote GitHub.
* **Status**: Confirms current commit hash (`✓ GAME IS UP TO DATE!`) or shows available commit count and recent commit messages.
* **1-Click Pull & Restart**: Click `⬇ UPDATE GAME NOW (GIT PULL)` to pull changes, then `🚀 RESTART GAME NOW` to relaunch.

---

## 🌐 Co-op Multiplayer Protocol

* **Networking**: High-level ENet multiplayer (`ENetMultiplayerPeer`) over UDP port `7777`.
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
| **Select Upgrade Card** | `1`, `2`, `3` or `Click` | Picks 1 of 3 cards on level up or cache opening |
| **Reroll Cards** | `Click` button | Rerolls 3 cards with Scrap (starts at 500, doubles per use) |
| **Pause Menu** | `Escape` | Audio volume, mouse sensitivity, display options |
| **Toggle Window / Fullscreen**| `F11`, `Alt + Enter`, `M` (menus) | Cycles Windowed and Borderless Fullscreen |
| **Toggle Damage Numbers** | `F8` or Pause Menu | Toggles floating damage labels ON/OFF |

---

## ⚙️ Performance & Optimization Architecture

* **Bullet Mesh Capping**: Rendered bullet meshes are capped at 40. Excess bullets simulate as non-visual raycasts with 100% damage, pierce, and status effects intact. Bullet lights capped at 8.
* **Static Particle & Light Pooling**: 24 pre-allocated GPU explosion instances and 48 beam meshes prevent dynamic instantiation stalls. Explosion lights capped at 4 concurrent lights.
* **Optimized AoE**: Synchronous single-pass queries using `EnemyBase.all_enemies` with 2D AABB pre-filtering (`absf(dx) > r or absf(dz) > r`) eliminate `sqrt()` math. Bullets/explosions keep physics monitoring disabled.
* **Horde Limits**: Arena enemy limit capped at 40 (`MAX_CONCURRENT_ENEMIES`). Pairwise enemy-on-enemy collision solving is disabled via `collision_mask = 5` (world + player only).
* **Damage Label Throttling**: Active damage numbers capped at 35; toggleable via `F8`.

---

## 🔫 Weapons Arsenal

| Weapon | Key | Fire Mode | Base Damage | Pellets | Fire Rate | Mag | Reload | Base Crit | Key Mechanics |
| :--- | :---: | :--- | :--- | :---: | :--- | :---: | :---: | :---: | :--- |
| **Pulse Carbine** | `1` | Automatic | 22.0 | 1 | 0.12s (8.33/s) | 32 | 1.2s | 10% | High-velocity kinetic rifle |
| **Scatter Cannon** | `2` | Semi-Auto | 18.0 / pellet (180 total) | 10 | 0.65s (1.54/s) | 8 | 1.6s | 5% | Wide close-quarters spread (0.103125 cone) |
| **Plasma Core** | `3` | Hold-to-Charge, Release-to-Fire | 150 direct + 150 AoE | 1 | 0.30 shot/s (3.33s cd + 0.18s charge) | 5 | 2.0s | 25% | Slow heavy orb (~23.3 m/s), ~2.5m effective capture width, 5.0m AoE (7.5m with *Explosive Payload*), Tesla Arc radial synergy |

### Weapon Mechanics Notes
* **Plasma Core Charge Cycle**: Requires holding `LMB` for at least 0.18s before releasing to fire. Releasing early cancels without ammo cost or cooldown. The core glow shifts to Warning Red during cooldown/reload, popping to Neon Purple when ready.
* **Independent Cooldown Tracking**: Weapons track fire cooldowns independently across swaps. Holstered weapons continue cooling down in the background, preventing quick-swap cooldown bypass exploits on heavy weapons like the Plasma Core.
* **Tesla Arc Emitter Synergy**: When firing the Plasma Core with Tesla Arc Emitter, a radial lightning bolt strikes **every enemy** in the explosive radius before detonation, and each bolt then chains outward up to 8.5m.

---

## 🎖️ Operative Classes & Specializations

When deploying into a mission (Solo, Co-op, or Boss Battle), each player chooses 1 of 3 combat classes featuring distinct passives and active abilities triggered via `Q`:

| Class | Accent | Role | Passive Specialization | Active Skill (`Q`) |
| :--- | :---: | :--- | :--- | :--- |
| **Medic** | Neon Mint | Support & Sustain | **Nano-Regen & Quick Revive**: All squadmates regenerate 5 HP/s (**Stackable** across multiple Medics). Revive downed teammates **25% faster** (4.0s vs 5.0s). | **Cellular Restore** (20s cd): Instantly recovers 20% Max Shield and 20% Max HP, and grants 2s invulnerability to ALL players. |
| **Rogue** | Neon Amber | Agility & Economy | **Bounty & Thrusters**: Enemies killed by me drop **+300% more XP and Scrap** (4× yield). Gain **+25% MORE movement speed, jump speed, and reload speed**. | **Quantum Dash** (10s cd): Dash 15m in aim direction with complete invulnerability (+0.5s buffer) and **instantly reload all weapons**. Sky/air capable. |
| **Gunner** | Neon Crimson | Heavy Assault DPS | **Reckless Assault**: **+25% Critical Strike Chance** across all weapons and companion drones, but take **10% more damage** from all incoming sources. | **Berserk Protocol** (60s cd): For 5s, gain **+500% MORE fire rate** and **unlimited magazine** across player weapons and companion drones. All weapons become fully automatic (hold to fire), and Plasma Core fires instantly without charging. All weapons and companion drones reload to full magazine when the skill ends. |

> [!NOTE]
> The Legendary perk **Cooldown Reduction** reduces your class active skill cooldown by **50%** (Medic: 10.0s, Rogue: 5.0s, Gunner: 30.0s). In co-op, players can pick identical or complementary classes; multiple Medics stack HP/s aura regeneration for the entire squad.

### 🎯 Active Skill HUD & Cooldown System
The HUD features custom cyberpunk vector icons positioned at the bottom-left directly below the health bar:
* **Medic**: Cellular Restore (`medic_restore.svg`, Neon Mint cross & nanite ECG wave)
* **Rogue**: Quantum Dash (`rogue_dash.svg`, Neon Amber quantum thrusters & velocity chevrons)
* **Gunner**: Berserk Protocol (`gunner_berserk.svg`, Neon Crimson cyber skull & crossed minigun barrels)
* **Dynamic Radial Cooldown Wipe**: When activated into cooldown, the icon turns completely black and regains vibrant color in a clockwise radial sweep as cooldown progresses to 100% readiness, accompanied by live numeric countdown overlays and pulsating active state animations.

---

## 🔥 Squad Fever System

Operatives channel combat momentum into a squad-shared **Fever** gauge displayed under the wave/XP bar:

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
* **Economy & Horde Buffs**: Tier D provides no bonuses. Each tier above D grants **+25% MORE** XP and Scrap drops, **+25% MORE** enemy spawn rate (halving spawn interval at S), expands concurrent enemy cap up to 80, and reduces round intermission delay down to 2.25s at Tier S to sustain combat momentum.
* **Rarer Perk Upgrades**: Common perk base weight is increased by 25% from 64 to 80. Advancing Fever tiers decays Common weight by $80 \times 0.75^{\text{tier}}$, more than doubling the offering probability of Rare, Epic, and Legendary cards at Tier S.

---

## 🧬 Roguelike Upgrades System

### Upgrade Mechanics
* **Card Offer**: Leveling up or opening a Loot Cache offers 3 cards. Rarity rates: Common (~79.2% at Tier D down to ~54.7% at Tier S), with Rare, Epic, and Legendary cards appearing more than twice as frequently at max Fever.
* **Scrap Reroll**: Reshuffles 3 cards. Costs 500 Scrap initially, doubling per use (500 → 1,000 → 2,000 → 4,000...), shared across co-op.
* **Crits & Explosions**: Projectiles roll weapon crit chance (+ *Precision Optics*). Base crit multiplier is 2.0× (+ *Hollow-Point Rounds*). Explosions derive damage from initial hit damage and do not double-dip crits.
* **Knockback Removal**: Player weapons have zero knockback on enemies to prevent stunlock exploits.
* **Tesla Chaining**: Arcs sequentially up to 2–8 targets within 8.5m. Can bounce back and forth (ping-pong) between 2+ alive targets; prioritizes unhit targets first.

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
| **Hyper-Penetrator** | `Rare` | Projectiles pierce through +1 enemy | 2 |
| **Aegis Energy Shield** | `Rare` | +25 Regenerating Shield capacity (grants shield on pick) | Infinite |
| **Vampiric Siphon** | `Rare` | Restores +4 HP on enemy kill | 1 |
| **Cryo Rounds** | `Rare` | Bullets slow targets by 40% for 3 seconds | 1 |
| **Nanite Scavenger** | `Rare` | +40% XP and Scrap drops from defeated enemies | 1 |
| **Explosive Payload** | `Epic` | Bullets explode on impact. Plasma Core AoE +50% (5.0m → 7.5m) | 1 |
| **Reactive Phase-Shield** | `Epic` | Taking damage grants 0.5s invulnerability | 2 (1s max) |
| **Null Barrier** | `Epic` | Nullifies damage instance every 10s (triggers invulnerability perks) | 1 |
| **Multi-Barrel Splitter** | `Epic` | +100% Projectiles per shot (doubles shot count) | 2 |
| **Tesla Arc Emitter** | `Epic` | Hits arc chain lightning to 2 targets (+2 per stack, up to 8 max within 8.5m). Synergizes with Plasma Core | 4 |
| **Smart Bouncing Core** | `Epic` | Bullets ricochet with on-hit explosion & chain lightning per bounce | 2 |
| **Assault Drone Unit** | `Epic` | Deploys autonomous companion drone with 1 of 3 weapons (1/4 base fire rate, inherits all weapon perks, Gunner passive crit bonus, and Gunner Berserk Protocol active) | 3 |
| **Emergency Defibrillator**| `Legendary`| Prevents fatal damage + 5s invulnerability. Recharges every 10 waves | 1 |
| **Cooldown Reduction** | `Legendary`| Reduces your class active skill cooldown by 50% | 1 |

---

## 👾 Enemy Scaling & Catalog

### Wave Scaling Formulas
* **Enemy Count per Wave**: $10 + \text{Wave} \times 6$ (Wave 50 Final Boss = $\infty$).
* **Spawn Interval**: $\text{clamp}(2.0 - \text{Wave} \times 0.1, 0.4, 2.0)$ (Wave 50 = $0.2\text{s}$).
* **Compounding HP**: $+10\%$ per wave ($\text{Base} \times 1.10^{\text{Wave}-1}$).
* **Compounding Damage**: $+5\%$ per wave ($\text{Base} \times 1.05^{\text{Wave}-1}$).
* **Speed & Attack Rate**: $+5\%$ compounding every 10 waves ($1.05^{\lfloor\text{Wave}/10\rfloor}$).
* **Damage Reduction**: $+10\%$ every 10 waves (capped at 50% max at Wave 50).
* **Basic Spawn Decay**: Swarmer & Spitter weights decay $5\%$ multiplicatively every 5 waves ($\text{Weight} \times 0.95^{\lfloor\text{Wave}/5\rfloor}$).

### Enemy Stats

| Enemy Type | Base HP | Speed | Damage | Attack Cooldown | Attack Type & Range | Base Weight | Notes |
| :--- | :---: | :---: | :---: | :---: | :--- | :---: | :--- |
| **Cyber Swarmer** | 35.0 | 7.0 m/s | 10.0 | 0.8s | Melee bite (1.6m 3D sphere, $\le 1.8$m height) | ~45–55% | Decays every 5 waves |
| **Plasma Spitter** | 75.0 | 4.5 m/s | 18.0 | 2.4s | Homing orb (25.0m) | 30.0% | Wave 3+, decays every 5 waves |
| **Armored Goliath (Brute)** | 500.0 | 4.5 m/s | 35.0 | 3.5s | Slam AoE (7.2m, 5.7m trigger, 0.56s windup) + 10.0 knockup | 7.2% | Wave 6+ heavy tank |
| **Cyber Charger** | 220.0 | 3.2 m/s | 48.0 | 2.5s | 30 m/s rush attack | ~4.0–4.25% | Wave 11+, wall crash causes 3.5s self-stun |
| **Void Spawner** | 4,000.0 | 2.8 m/s | — | 4.5s spawn | High-altitude flight (8.5m), spawns Spawnlings | 0.25% | Wave 20+, drops Loot Cache on defeat |
| **Cyber Spawnling** | 14.0 | 12.0 m/s | 2.5 / 0.15s | 0.15s tick | Rapid spinning drill contact | Portal spawn | **Immune to AoE, ricochet, & lightning; direct bullet hits only** |
| **Apex Overlord (Boss)** | 1,000,000.0 | 3.2–105 m/s | 120–540 | Multi-stage | Multi-stage ground & aerial attack loops | Wave 50 | Fixed HP & cadence; infinite horde until boss dies |

### 👑 Wave 50 Final Boss: Apex Overlord Stages
Reaching Wave 50 spawns the Apex Overlord on the center platform with an infinite horde (0.2s spawn interval, 40 concurrent cap). Victory triggers only when the boss is slain.
* **Stage 1 (100%–66% HP)**: Ground pursuit. Close Slam AoE (14.25m radius, 1.6× damage + knockup) or long-range dual plasma (0.45× damage).
* **Stage 2 (66%–33% HP)**: Aerial flight (Y ≈ 14m). Plasma bombs (6.75m AoE, 0.85× damage), Red Aura target lock (0.7s telegraph), and Hyper Dive (60 m/s, 15.75m AoE, 2.2× damage).
* **Stage 3 (<33% HP)**: Winged Fallen Angel. 6-muzzle needle curtain (65 m/s, 0.09× damage per needle), Cataclysmic Mega Orb (18.0m AoE, 2.8× damage), 8.0s exhaustion vulnerability window, and Supersonic Dive (105 m/s, 17.25m AoE, 2.5× damage).

---

## 💎 Pickups & Arena Elements

* **Arena Walls & Non-Intrusive Sky Barriers**: Standard 8m visible perimeter walls preserve the open-sky horizon. An invisible upper barrier (Layer 5, up to 48m) blocks operatives and enemies from dashing or flying into the abyss while letting all weapon projectiles pass freely through into the sky without exploding or ricocheting.
* **Abyss Safety & Void Fall Recovery**: Falling into the abyss ($Y < -15\text{m}$) teleports the operative back onto the arena floor with a 20% HP penalty and 2.0s invulnerability. Any enemy unit that somehow ends up out of the arena (beyond perimeter walls $|X|, |Z| > 31.5\text{m}$, below floor $Y < -1.0\text{m}$, or above sky boundary $Y > 45.0\text{m}$) is instantly eliminated with all loot drops safely placed onto the arena floor.
* **Nanite XP Crystals** *(Cyan/Green)*: Magnetize to player; fills squad level-up bar.
* **Medical Stims** *(Red)*: Instantly restores 25 HP. Drops more frequently at low health.
* **Scrap Currency** *(Gold)*: Currency collected to fund card rerolls.
* **Loot Caches**: Spawns every 2 waves and drops from defeated Void Spawners. Press `E` for bonus scrap/health and 1 free card pick.
* **Jump Pads**: 4 arena launch pads propelling players skyward for aerial traversal.

---

## 📂 Project Architecture

```
CyberHorde-FPS-Roguelike/
├── project.godot                     # Core Godot 4.7 configuration & autoloads
├── Play_Game.bat / Update_Game.bat   # 1-click launch and git pull scripts
├── Test_Coop_2Players.bat            # 2-player local co-op launcher
├── Open_In_Godot_Editor.bat          # Godot Editor launcher
├── Push_To_GitHub.bat                # Git commit & push script
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd           # ★ Perk catalog (`upgrade_database`), stats, level/reroll logic
│   │   ├── network_manager.gd        # ENet multiplayer squad management & signals
│   │   └── sound_manager.gd          # Pure synthesized 16-bit PCM procedural audio
│   ├── player/
│   │   ├── player.gd                 # First/third-person controller, defensive perks, weapons
│   │   └── drone.gd                  # Companion drone perk AI
│   ├── enemies/
│   │   ├── enemy_base.gd             # Base enemy class (target selection, health, damage)
│   │   ├── swarmer.gd / spitter.gd   # Basic swarmer and ranged spitter AI
│   │   ├── brute.gd / charger.gd     # Heavy ground-slammer and charging bull AI
│   │   ├── spawner.gd / spawnling.gd # Sky carrier spawner and drill minion AI
│   │   └── boss.gd                   # Wave 50 Apex Overlord multi-stage boss AI
│   ├── projectiles/
│   │   ├── bullet.gd                 # Projectile simulation, pierce, ricochet, explosions, Tesla arcs
│   │   ├── enemy_projectile.gd       # Spitter plasma orb
│   │   └── explosion.gd              # Static pooled AoE blast and particle system
│   ├── loot/
│   │   ├── loot_pickup.gd            # Pickups (XP, Stim, Scrap) and magnet logic
│   │   └── chest.gd                  # Interactive Loot Cache
│   ├── ui/
│   │   ├── lobby_menu.gd / hud.gd    # Lobby and in-game HUD
│   │   ├── upgrade_menu.gd           # Upgrade card presentation and Scrap rerolls
│   │   └── pause_menu.gd / game_over.gd
│   └── world/
│       ├── wave_spawner.gd           # Wave director, enemy weights, Wave 50 boss battle director
│       └── jump_pad.gd / spawn_indicator.gd
└── scenes/                           # Godot .tscn files mirroring the scripts directory structure
```

---

## 🛠️ Developer Guide: Architecture & Extending the Game

### 1. Multiplayer Networking Architecture
* **Autoload**: [`scripts/autoload/network_manager.gd`](scripts/autoload/network_manager.gd) manages `ENetMultiplayerPeer`, peer connections, and lobby events.
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
3. In [`scripts/world/wave_spawner.gd`](scripts/world/wave_spawner.gd): Preload scene, assign type ID, and configure wave weight.

### 5. Web Export Roadmap
* Switch `project.godot` renderer to `gl_compatibility` (WebGL2).
* Replace `ENetMultiplayerPeer` with `WebSocketMultiplayerPeer` or `WebRTCMultiplayerPeer` for browser socket support.
* Serve with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` headers for `SharedArrayBuffer`.
