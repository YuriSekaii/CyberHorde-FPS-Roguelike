# ⚡ CyberHorde: Rogue Protocol

[![Engine](https://img.shields.io/badge/Engine-Godot%204.7-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Renderer](https://img.shields.io/badge/Renderer-Vulkan%20Forward%2B-red)](https://vulkan.org)
[![Multiplayer](https://img.shields.io/badge/Networking-ENet%20Co--op%20Multiplayer-brightgreen)](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
[![Repository](https://img.shields.io/badge/GitHub-YuriSekaii%2FCyberHorde--FPS--Roguelike-181717?logo=github)](https://github.com/YuriSekaii/CyberHorde-FPS-Roguelike)

A fast-paced 3D First-Person Horde Roguelike Shooter featuring **Online Co-op Multiplayer** built with **Godot 4.7**.

Survive escalating cybernetic hordes, harvest magnetized Nanite XP crystals and scrap, crack open holographic loot caches, and craft overpowered character builds through dynamic roguelike upgrades—either solo or side-by-side with your squad!

---

## 🎮 How to Play

### 1-Click Launchers:
* **`Play_Game.bat`**: Launches the game window immediately with the cyberpunk Main Lobby (`Single Player`, `Host Co-op`, `Join Co-op`, or `Check for Updates`).
* **`Update_Game.bat`**: 1-click update script to automatically run `git pull` from Windows Explorer.
* **`Test_Coop_2Players.bat`**: Instantly launches two game windows side-by-side on your desktop so you can test 2-player co-op locally with zero setup!
* **`Open_In_Godot_Editor.bat`**: Opens the project directly inside the Godot 4.7 Editor for inspecting scenes, tweaking stats, or modifying scripts.
* **`Push_To_GitHub.bat`**: Automatically stages, commits, and pushes any local modifications to your remote GitHub repository (`main` branch).

---

## 🔄 Check for Updates & Auto-Updater Feature

CyberHorde includes an integrated **In-Game Software Updater** powered by `UpdateManager`:

* **In-Game Update Check**:
  * On launch and at any time in the main lobby, click `🔄 CHECK FOR UPDATES`.
  * The game runs a non-blocking asynchronous check against the remote GitHub repository (`git fetch`).
* **Smart Update Notification**:
  * If the game is already up to date, it displays your current commit hash and a green confirmation: `✓ GAME IS UP TO DATE!`.
  * If a new version exists on GitHub, it highlights the number of new commits and shows a changelog summary:
    ```
    ⚡ UPDATE AVAILABLE! (2 new commits found)
    • feat: New laser drone companion
    • fix: Spawner balancing
    ```
* **1-Click In-Game Update (`git pull`)**:
  * Click `⬇ UPDATE GAME NOW (GIT PULL)` directly in the lobby menu.
  * The updater pulls the latest changes in the background while keeping the UI responsive.
  * Once the update finishes, click `🚀 RESTART GAME NOW` to immediately reload the updated game!

---

## 🌐 Co-op Multiplayer Protocol

Team up with your squad in fast-paced online horde survival using Godot 4 high-level ENet multiplayer:

* **Host a Mission**: Click `🌐 HOST CO-OP MISSION (SERVER)`. Your local IP address and port (default: `7777`) will be displayed. Tell your friend to join your IP!
* **Join a Squad**: Click `🔗 JOIN CO-OP MISSION (CLIENT)`, enter your friend's IP address (use `127.0.0.1` for local machine testing), and click `CONNECT TO SQUAD`.
* **Squad Mech Avatars**:
  * **Player 1 (Host)**: Clad in sleek gunmetal cyber-armor with glowing **Neon Cyan** visor and chest reactor.
  * **Player 2 (Ally)**: Fitted with matching cyber-armor with glowing **Neon Orange/Amber** visor and chest reactor.
  * Real-time 3D overhead tags display your teammate's name (`P1 [HOST]` or `P2 [ALLY]`) and live HP bar.
* **Squad Upgrades & Shared Economy**: XP crystals and Scrap harvested by any player advance the squad's level up bar. When leveling up in co-op, players select upgrade cards in real-time with an active **Aegis Stasis** protective shield!
* **Downed & Revive Mechanic**: When a squadmate runs out of health, they enter a downed crawling state emitting an emergency beacon light. Rush over and **hold `E` for 2 seconds** to revive them back to full combat readiness with **50% HP and 3s invulnerability**!
* **Multi-Targeting Horde AI**: Swarmers, Spitters, and Brutes dynamically seek out and split up to attack the nearest non-downed squadmate.

---

## 🕹️ Controls

| Action | Key / Input | Notes |
| :--- | :--- | :--- |
| **Move** | `W`, `A`, `S`, `D` | Smooth acceleration & deceleration |
| **Look / Aim** | `Mouse` | First-person camera with pitch clamping and weapon sway |
| **Jump** | `Spacebar` | Includes Coyote time (150ms) & jump buffering |
| **Sprint** | `Shift` (hold) | 1.4× movement speed boost |
| **Primary Fire** | `Left Mouse Button` | Recoil kickback, screen shake, and muzzle flash |
| **Reload** | `R` | Manual reload (or automatic when empty) |
| **Switch Weapons** | `1`, `2`, `3` or `Mouse Wheel` | Instant cycle between Rifle, Shotgun, and Plasma |
| **Open Loot Cache** | `E` | Opens floating caches for bonus loot & free upgrade pick |
| **Revive Teammate** | `E` (hold) | Stand within 3m of downed squadmate to revive them! |
| **Select Upgrade Card** | `1`, `2`, `3` or `Click` | Select 1 of 3 cards on Level Up or Cache open |
| **Pause Menu** | `Escape` | Pause mission, adjust Master Sound, SFX Volume, Mouse Sensitivity, toggle Window/Fullscreen, or restart |
| **Toggle Window / Fullscreen** | `F11`, `Alt + Enter`, `M` (in menus), or Menu Button | Instantly toggle between Windowed and Borderless Fullscreen display modes |

---

## 🖥️ Display & Window Mode System

CyberHorde supports seamless switching between **Windowed** and **Fullscreen** modes:

* **Main Lobby Menu**:
  * Easily toggle display mode with the `🖥️ WINDOW MODE` button in the main menu before starting or joining a squad.
* **In-Game Pause Menu**:
  * Press `Escape` during gameplay to access settings and toggle window mode without quitting or interrupting your run.
* **Global Keyboard Shortcuts**:
  * **`F11`** or **`Alt + Enter`**: Universal PC toggle at any time during menus or active missions.
  * **`M`**: Quick toggle hotkey when viewing the Lobby Menu or Pause Menu.
* **Automatic Preference Saving**:
  * Display choices are saved to `user://settings.cfg` and remembered across sessions.
  * *Smart bypass*: If launching multi-instance co-op tests via `Test_Coop_2Players.bat`, command-line position and resolution arguments are preserved automatically.

---

## 🔫 Weapons Arsenal

| Weapon | Key | Fire Mode | Base Damage | Pellets | Fire Rate | Mag Size | Reload Time | Base Crit | AoE / Effect |
| :--- | :---: | :--- | :--- | :---: | :--- | :---: | :---: | :---: | :--- |
| **Pulse Carbine** | `1` | Automatic | 22.0 | 1 | 0.12s (8.33/s) | 32 | 1.2s | 10% | High-velocity kinetic rifle |
| **Scatter Cannon** | `2` | Semi-Auto | 18.0 / pellet (180 total) | 10 | 0.65s (1.54/s) | 8 | 1.6s | 15% | Close-quarters shotgun spread |
| **Plasma Core** | `3` | Semi-Auto (Charge) | 150.0 direct + 150.0 AoE | 1 | 0.50s (0.18s charge + 0.32s cd) | 5 | 2.0s | 25% | 5.0m blast radius (10.0m with *Explosive Payload*), high recoil & concussive kick |

1. **Pulse Carbine (`Key 1`)**:
   - High-velocity kinetic automatic assault rifle.
   - 32-round magazine, 0.12s fire rate (8.3 shots/sec), 22.0 base damage, 10% base crit chance, crisp suppressive fire.
2. **Scatter Cannon (`Key 2`)**:
   - Heavy close-quarters shotgun blasting 10 pellets simultaneously with punchy recoil and screen kick.
   - 18.0 damage per pellet (180 base burst damage), 8-round magazine, 0.65s fire rate, 15% base crit chance.
3. **Plasma Core (`Key 3`)**:
   - High-yield heavy energy launcher firing concentrated plasma orbs.
   - **Charge Delay Mechanic**: Features a brief 0.18s magnetic capacitor spin-up delay on trigger pull with pulsing core glow, coil whine synth SFX, and weapon vibration before discharging.
   - **High Concussive Recoil**: Unleashes massive gun kickback, +13° muzzle pitch lift, camera vertical recoil, screen trauma shake (0.38 intensity), and a backward propulsion impulse.
   - Deals 150 direct impact damage and 150 Area-of-Effect detonation damage in a 5.0m blast radius (10.0m with *Explosive Payload*), 0.5s total shot cycle, 2.0s reload time, 25% base crit chance.

---

## 🧬 Roguelike Upgrades System

> [!IMPORTANT]
> ### 📍 Where to Add or Modify Perks
> * **Perk Catalog & Definitions**: [`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd) — Edit the `upgrade_database` dictionary to change names, descriptions, max stacks, rarities, or add new perk entries.
> * **Perk Application & Stats**: [`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd) — Handle stat increases and unlock flags inside `apply_upgrade()` and `reset_game()`.
> * **Defensive & Player Perks**: [`scripts/player/player.gd`](scripts/player/player.gd) — Implements health, shields, invulnerability, and defensive cooldowns (e.g. *Null Barrier*, *Reactive Phase-Shield*, *Emergency Defibrillator*).
> * **Projectile & Weapon Perks**: [`scripts/projectiles/bullet.gd`](scripts/projectiles/bullet.gd) — Implements bullet modifications (e.g. *Explosive Payload*, *Ricochet*, *Tesla Arc Emitter*, *Hyper-Penetrator*, *Cryo Rounds*).
> * **Loot & Economy Perks**: [`scripts/loot/loot_pickup.gd`](scripts/loot/loot_pickup.gd) — Implements pickup mechanics (e.g. *Nanite Magnet* radius, *Nanite Scavenger* drops).
> * See the [Perk Developer Guide](#2-how-to-add-or-modify-perks-upgrades) below for step-by-step instructions.

Whenever your **Nanite XP bar** fills up or you open a **Loot Cache**, you are offered **3 holographic upgrade cards**.
Upgrade rarity tiers roll with authentic 1/4 drop rates: **Common** (~75.3%), **Rare** (~18.8%), **Epic** (~4.7%), and **Legendary** (~1.2%), giving a **57.3% chance** of offering at least one Rare or higher card on every level-up.

| Upgrade | Rarity | Effect |
| :--- | :--- | :--- |
| **Heavy Caliber** | `Common` (Cyan) | +25% Projectile Damage across all weapons (**Stacks Infinitely**). |
| **Vital Plating** | `Common` (Cyan) | +25 Maximum Health (**Stacks Infinitely**). Proactively heals upon selection. |
| **Precision Optics** | `Common` (Cyan) | +10% Critical Strike Chance (stacks up to 4x). |
| **Overclock Trigger** | `Common` (Cyan) | +25% Fire Rate for continuous suppression (stacks up to 6x). |
| **Rapid Loader** | `Common` (Cyan) | +25% Reload Speed across all weapons (stacks up to 6x). |
| **Extended Mag** | `Common` (Cyan) | +30% Magazine Capacity across all weapons (stacks up to 6x). |
| **Kinetic Thrusters** | `Common` (Cyan) | +18% Movement Speed and +15% Jump Power. |
| **Nanite Magnet** | `Common` (Cyan) | +60% XP & Loot collection radius (Max 2 stacks). |
| **Hardened Alloy** | `Rare` (Purple) | +10% Damage Reduction against all incoming damage (Max 5 stacks: 50% Reduction). |
| **Hollow-Point Rounds** | `Rare` (Purple) | +0.5x Critical Hit Damage Multiplier (**Stacks Infinitely**). |
| **Hyper-Penetrator** | `Rare` (Purple) | Projectiles pierce through +1 enemy (stacks up to 2x). |
| **Aegis Energy Shield** | `Rare` (Purple) | Grants +25 Regenerating Shield capacity (**Stacks Infinitely**). Proactively grants shield upon selection. |
| **Vampiric Siphon** | `Rare` (Purple) | Instantly restores +4 HP whenever an enemy is slain. |
| **Cryo Rounds** | `Rare` (Purple) | Bullets chill targets, slowing them by 40% for 3 seconds. |
| **Nanite Scavenger** | `Rare` (Purple) | +40% XP and Scrap drops from all defeated enemies. |
| **Explosive Payload** | `Epic` (Orange) | Bullets explode on impact. **Plasma Core gains +100% AoE radius** (5.0m → 10.0m). |
| **Reactive Phase-Shield** | `Epic` (Orange) | When you take damage, gain 1s of invulnerability (Max 2 stacks: 2s). |
| **Null Barrier** | `Epic` (Orange) | Every 5s, nullifies the next instance of damage taken (**Triggers invulnerability perks**). Only 1 stack. |
| **Multi-Barrel Splitter** | `Epic` (Orange) | +100% Projectiles per shot (Doubles shot count — e.g., Shotgun fires 20 pellets). |
| **Tesla Arc Emitter** | `Epic` (Orange) | Hits arc chain lightning to 2 nearby enemies. |
| **Smart Bouncing Core** | `Epic` (Orange) | Bullets ricochet with on-hit explosion & chain lightning per bounce. |
| **Assault Drone Unit** | `Epic` (Orange) | Deploys autonomous companion drone randomly equipped with 1 of 3 arsenal weapons (1/4 fire rate, same mag & reload speed, all weapon perks). Color-coded rings (Cyan/Orange/Magenta) distinguish weapon type. +1 drone per pick. |
| **Emergency Defibrillator** | `Legendary` (Gold) | Survive fatal damage, gaining **5s of invulnerability**. Automatically **recharges after surviving 10 waves**! |

---

## 🎯 Critical Hit & Explosive Mechanics

* **Direct Hit Crits**: Every projectile rolls against its weapon's **Critical Strike Chance** (10% for Pulse Carbine, 15% for Scatter Cannon, 25% for Plasma Core, augmented by +10% per stack of *Precision Optics*). A successful crit multiplies damage by your **Critical Damage Multiplier** (base 2.0x, augmented indefinitely by *Hollow-Point Rounds*).
* **Explosive Damage**: Explosive damage is **calculated from the initial hit damage** (100% of hit damage for Plasma Core: 150 base direct + 150 base AoE; 80% for perk-granted bullet explosions).
* **No Double-Dipping**: Explosions do not trigger critical rolls independently, preventing unintended exponential double-crit scaling while ensuring explosions from a critical bullet strike pack massive punch!

---

## 👾 Enemy Horde Scaling & Final Boss

### Wave Progression & Scaling
Hordes scale progressively to challenge late-game builds:
* **Every Wave**: Enemies gain **+10% Compounding Health** ($\text{Base} \times 1.10^{\text{Wave} - 1}$) and **+5% Compounding Damage** ($\text{Base} \times 1.05^{\text{Wave} - 1}$).
* **Every 10 Waves**: Enemies gain **+5% Movement Speed and +5% Attack Speed** ($\text{Attack Interval} / \text{Speed Multiplier}$).
* **Every 10 Waves**: Enemies gain **+10% Damage Reduction** (capped at **90%** max reduction). Floating damage indicators accurately reflect reduced damage values.

### Enemy Types
1. **Cyber Swarmers**: Fast neon-red crawler insect mechs that swarm in packs and rush players for melee bites.
2. **Plasma Spitters**: Hovering purple combat drones that strafe at a distance and fire homing plasma bolts.
3. **Armored Goliaths (Brutes)**: Giant armored cyber crushers that charge in and slam the ground creating shockwaves and knockback!

### 👑 Wave 100 Final Boss: Apex Overlord
**Wave 100 is the climactic Final Wave**. Reaching Wave 100 spawns the ultimate mechanical juggernaut—the **Apex Overlord**:
* **Dedicated HUD Boss Bar**: Displays live HP and health percentage at the top of the screen.
* **Phase 1 (100% – 60% HP)**: Alternates dual heavy plasma cannon volleys with massive 10m-radius **Tremor Stomps** that launch players into the air.
* **Phase 2 (60% – 30% HP)**: Enters **Overcharge** with a radiant orange core; fires 3-way spread plasma bursts and summons escort reinforcements.
* **Phase 3 (< 30% HP - Meltdown)**: Blazing violet reactor berserk state with increased movement speed, continuous 5-way barrages, and frequent tremor stomps!
* **Victory Protocol**: Defeating the Apex Overlord clears Wave 100 and achieves **MISSION ACCOMPLISHED** victory!

---

## 💎 Loot & Arena Mechanics

* **Nanite XP Crystals** *(Green/Cyan)*: Magnetize to the player and fill the squad Level Up bar.
* **Medical Stims** *(Red)*: Instantly restores 25 Health (drops more often when HP is low).
* **Scrap Currency** *(Gold)*: Collect currency to build your high score.
* **Loot Caches (Chests)**: Dropped every 2 waves with an aerial beacon light beam. Press `E` to open for bonus loot and a **free upgrade pick**!
* **4 Aerial Jump Pads**: Step on any glowing pad to launch high above the arena for aerial combat.
* **Floating 3D Damage Numbers**: Billboarding damage indicators popping up above hit enemies with yellow/red styling for critical hits.
* **Procedural Sound Engine**: 100% self-contained 16-bit PCM audio synthesizer generated in GDScript at startup with zero external audio assets required.

---

## 📂 Project Architecture

```
Game/
├── project.godot                     # Core Godot 4.7 project configuration & autoloads
├── Play_Game.bat                     # 1-click launcher for single game window
├── Test_Coop_2Players.bat            # 1-click launcher for 2-player local co-op test
├── Open_In_Godot_Editor.bat          # 1-click launcher for Godot Editor
├── Push_To_GitHub.bat                # 1-click sync to GitHub main branch
├── README.md                         # Comprehensive documentation & developer guide
├── icon.svg                          # Vector cyber reticle icon
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd           # ★ PRIMARY PERK CATALOG: `upgrade_database`, stat variables, apply_upgrade()
│   │   ├── network_manager.gd        # ENet high-level multiplayer squad manager
│   │   └── sound_manager.gd          # Pure synthesized 16-bit PCM audio engine
│   ├── player/
│   │   ├── player.gd                 # ★ DEFENSIVE & COMBAT PERKS: Null Barrier, Shields, Invulnerability, HP
│   │   └── drone.gd                  # Companion drone perk AI
│   ├── enemies/
│   │   ├── enemy_base.gd             # Base enemy class (health, multi-target, damage)
│   │   ├── swarmer.gd                # Fast swarm insect AI
│   │   ├── spitter.gd                # Ranged hovering drone AI
│   │   ├── brute.gd                  # Ground-slamming heavy golem AI
│   │   └── boss.gd                   # Wave 100 Apex Overlord multi-phase boss AI
│   ├── projectiles/
│   │   ├── bullet.gd                 # ★ PROJECTILE PERKS: Explosions, pierce, ricochet, chain lightning, cryo
│   │   ├── enemy_projectile.gd       # Spitter plasma orb
│   │   └── explosion.gd              # Area-of-effect blast & particle emitter
│   ├── loot/
│   │   ├── loot_pickup.gd            # ★ LOOT PERKS: Nanite Magnet collection radius, magnetized pickups
│   │   └── chest.gd                  # Interactive Loot Cache with beacon
│   ├── ui/
│   │   ├── upgrade_menu.gd           # ★ UPGRADE CARD UI: Generates 3 cards dynamically from `upgrade_database`
│   │   ├── hud.gd                    # HUD: Reticle, hitmarker, health, shield, Null Barrier status, waves
│   │   ├── lobby_menu.gd             # Cyberpunk multiplayer Host & Join lobby
│   │   ├── pause_menu.gd             # Pause screen with sensitivity & audio sliders
│   │   └── game_over.gd              # Stats summary & retry screen
│   └── world/
│       ├── spawner.gd                # Wave director & horde scaling
│       ├── spawn_indicator.gd        # 3D holographic telegraph rings & emergence
│       └── jump_pad.gd               # Aerial launch pads
└── scenes/
    ├── main.tscn                     # Main game scene combining arena, squad, HUD
    ├── player/player.tscn            # Player scene with 1st-person & 3rd-person armor
    ├── enemies/                      # Swarmer, Spitter, Brute, Boss scenes
    ├── projectiles/                  # Bullet, Plasma, Explosion scenes
    ├── loot/                         # Pickup & Chest scenes
    ├── ui/                           # Lobby, HUD, Upgrade, Pause, GameOver scenes
    └── world/                        # Arena, JumpPad, SpawnIndicator scenes
```

---

## 🛠️ Developer Guide: Architecture & Extending the Game

If you are continuing development on **CyberHorde**, this section gives you the exact blueprint of how systems connect and how to add new features safely.

### 1. Multiplayer Networking Architecture
* **Autoload**: [`scripts/autoload/network_manager.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/autoload/network_manager.gd) handles `ENetMultiplayerPeer`, hosting, client joining, and connection signals.
* **Squad Launch Pipeline**:
  1. Players connect in [`lobby_menu.tscn`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scenes/ui/lobby_menu.tscn).
  2. Host clicks **`LAUNCH SQUAD MISSION`** $\rightarrow$ calls `rpc_start_mission.rpc(NetworkManager.connected_peers)`.
  3. Both Host and Client receive `rpc_start_mission` and spawn each squad member into the `$Players` container in [`scripts/main.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/main.gd).
* **Player Authority & Avatars** ([`scripts/player/player.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/player/player.gd)):
  * Each player node is named `"Player_%d" % peer_id`.
  * `set_multiplayer_authority(id)` assigns ownership.
  * **Local Player** (`id == multiplayer.get_unique_id()`):
    * `camera.make_current()` activates the first-person view.
    * First-person `WeaponRig` is visible.
    * `ThirdPersonModel` cyber-suit is hidden to prevent camera clipping.
  * **Remote Player** (`id != multiplayer.get_unique_id()`):
    * `camera.current = false` deactivates camera.
    * `ThirdPersonModel` cyber-suit is visible with color accent (**Cyan** for Host, **Orange** for Client).
    * `OverheadUI` shows `P1 [HOST]` or `P2 [ALLY]` and live HP.
* **RPC Best Practices**:
  * Any RPC called from a client to the server **must** include `"any_peer"` (e.g. `@rpc("any_peer", "unreliable_ordered") func rpc_sync_state(...)`).
  * Otherwise, Godot 4 will discard the packet with an authority violation error.

---

### 2. How to Add or Modify Perks (Upgrades)

All perks are driven by a centralized data structure in [`scripts/autoload/game_manager.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/autoload/game_manager.gd) and executed across specific gameplay scripts.

#### 📍 Which Files to Modify

| Perk Category | Primary File(s) to Modify | What to Implement |
| :--- | :--- | :--- |
| **All Perks (Registration & Stats)** | [`scripts/autoload/game_manager.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/autoload/game_manager.gd) | Add/modify entries in `upgrade_database`, declare stat variables, reset in `reset_game()`, and apply values in `apply_upgrade()`. |
| **Defensive & Player Perks** (Shields, Invulnerability, Nullify, HP, Speed, Jumps) | [`scripts/player/player.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/player/player.gd) | Check stats inside `take_damage()`, `_physics_process()`, `_handle_movement()`, or `_update_stats()`. |
| **Weapon & Projectile Perks** (Explosions, Ricochet, Piercing, Chain Lightning, Cryo) | [`scripts/projectiles/bullet.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/projectiles/bullet.gd) | Check stats during collisions (`_on_body_entered()`, `_handle_ricochet()`, `_handle_pierce()`, `_handle_lightning()`). |
| **Loot & Economy Perks** (Pickup Radius, Extra Scrap/XP) | [`scripts/loot/loot_pickup.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/loot/loot_pickup.gd) & [`scripts/autoload/game_manager.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/autoload/game_manager.gd) | `GameManager.magnet_radius` in `loot_pickup.gd`, and `GameManager.greed_mult` in `add_xp()` / `add_scrap()`. |
| **Card Selector UI** | [`scripts/ui/upgrade_menu.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/ui/upgrade_menu.gd) | *Automatic*: Reads directly from `GameManager.upgrade_database` and handles stack counts automatically. |
| **HUD Status Display** | [`scripts/ui/hud.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/ui/hud.gd) | Add HUD widgets for perks that need real-time feedback (like Shield Bar or Null Barrier cooldown). |

---

#### ✏️ How to Modify an Existing Perk
1. Open [`scripts/autoload/game_manager.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/autoload/game_manager.gd).
2. Locate the perk entry in `upgrade_database`:
   - Change `max_stacks` to adjust the maximum rank (e.g. `max_stacks: 2`).
   - Change `desc` to update the description shown on the holographic upgrade card.
   - Change `rarity` (`"Common"`, `"Rare"`, `"Epic"`, or `"Legendary"`) and `color` (`Color(0.4, 0.8, 1.0)` for Common, `Color(0.8, 0.3, 1.0)` for Rare, `Color(1.0, 0.6, 0.1)` for Epic, `Color(1.0, 0.9, 0.2)` for Legendary).
3. Update the perk's bonus values in `apply_upgrade()` (e.g., adjust stat multipliers or flat bonuses).
4. Synchronize the perk table in [`README.md`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/README.md) to match.

---

#### ➕ Step-by-Step: How to Add a New Perk
1. **Define in `upgrade_database`** ([`scripts/autoload/game_manager.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/autoload/game_manager.gd)):
   ```gdscript
   "plasma_shield": {
       "id": "plasma_shield",
       "name": "Plasma Ward",
       "desc": "Grants +25 Overcharge Shield capacity.",
       "rarity": "Rare",
       "color": Color(0.8, 0.3, 1.0),
       "max_stacks": 3
   },
   ```
2. **Add tracking variable & reset in `reset_game()`** ([`scripts/autoload/game_manager.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/autoload/game_manager.gd)):
   ```gdscript
   var plasma_shield_bonus: float = 0.0
   
   func reset_game() -> void:
       ...
       plasma_shield_bonus = 0.0
   ```
3. **Handle in `apply_upgrade(upgrade_id: String)`** ([`scripts/autoload/game_manager.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/autoload/game_manager.gd)):
   ```gdscript
   "plasma_shield":
       plasma_shield_bonus += 25.0
   ```
4. **Hook up the gameplay effect** in the target script:
   - For player stats: read `GameManager.plasma_shield_bonus` in [`scripts/player/player.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/player/player.gd) inside `_update_stats()`.
   - For projectile effects: read `GameManager` flags in [`scripts/projectiles/bullet.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/projectiles/bullet.gd).
5. **Update documentation & push**: Update the [Roguelike Upgrades Catalog](#-roguelike-upgrades-system) in `README.md` and push changes to GitHub.

---

### 3. How to Add a New Weapon
1. Open [`scripts/player/player.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/player/player.gd).
2. In `_setup_weapons()`, create a new `Weapon` instance and append it to `weapons`:
   ```gdscript
   var smg = Weapon.new()
   smg.name = "Hyper SMG"
   smg.fire_rate = 0.08
   smg.damage = 12.0
   smg.base_max_ammo = 45
   smg.max_ammo = 45
   smg.current_ammo = 45
   smg.base_reload_time = 1.0
   smg.reload_time = 1.0
   smg.is_auto = true
   smg.pellets = 1
   smg.spread = 0.035
   smg.is_explosive = false
   smg.sound_name = "shoot_rifle"
   weapons.append(smg)
   ```
3. Add a corresponding 3D gun mesh under `Head/Camera3D/WeaponRig` in [`scenes/player/player.tscn`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scenes/player/player.tscn).
4. Update `_switch_weapon(new_idx)` and `_update_third_person_weapon(idx)` to toggle your new gun model's visibility.

---

### 4. How to Add a New Enemy Type
1. Create a new script in `scripts/enemies/` inheriting from [`scripts/enemies/enemy_base.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/enemies/enemy_base.gd).
2. Override `_behave(delta)` with your custom movement and attack pattern (e.g. charging, dodging, sniping).
   * `target_player` automatically updates to the nearest active, non-downed squadmate!
3. Create a corresponding `.tscn` scene in `scenes/enemies/` with a `CharacterBody3D`, `CollisionShape3D`, and visual meshes.
4. Open [`scripts/world/spawner.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/world/spawner.gd):
   * Preload the scene: `const MY_ENEMY_SCENE = preload("res://scenes/enemies/my_enemy.tscn")`.
   * Add a type ID condition in `_spawn_one_enemy()` and `_instantiate_enemy()`.

---

### 5. Future Web Export Roadmap (Notes for Porting to Web)
If you ever want to port the game to play inside a web browser:
1. **Switch Renderer**: Change from `Forward Plus` to `Compatibility` (WebGL2) in `project.godot`:
   ```ini
   rendering/renderer/rendering_method="gl_compatibility"
   ```
2. **Web Browser Sockets**: Web browsers cannot open raw UDP sockets used by `ENetMultiplayerPeer`. For web multiplayer, switch to:
   * **`WebSocketMultiplayerPeer`** connected to a dedicated cloud relay server (e.g., hosted on Fly.io or Render).
   * Or **`WebRTCMultiplayerPeer`** with a signaling broker.
3. **HTTP Security Headers**: Ensure your web host serves the game with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` for multi-threaded `SharedArrayBuffer` support.
