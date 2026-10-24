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
| **Pause Menu** | `Escape` | Pause mission, adjust Master Sound, SFX Volume, Mouse Sensitivity, or restart |

---

## 🔫 Weapons Arsenal

1. **Pulse Carbine (`Key 1`)**:
   - High-velocity kinetic automatic assault rifle.
   - 32-round magazine, 0.12s fire rate (8.3 shots/sec), crisp suppressive fire.
2. **Scatter Cannon (`Key 2`)**:
   - Heavy close-quarters shotgun blasting 7 pellets simultaneously with punchy recoil and screen kick.
   - 8-round magazine, 0.65s fire rate.
3. **Plasma Core (`Key 3`)**:
   - High-yield energy launcher firing concentrated plasma orbs.
   - Detonates on impact in an Area-of-Effect blast (65 base damage).

---

## 🧬 Roguelike Upgrades System

Whenever your **Nanite XP bar** fills up or you open a **Loot Cache**, you are offered **3 holographic upgrade cards**.
Upgrade rarity tiers roll with authentic 1/4 drop rates: **Common** (~75.3%), **Rare** (~18.8%), **Epic** (~4.7%), and **Legendary** (~1.2%), giving a **57.3% chance** of offering at least one Rare or higher card on every level-up.

| Upgrade | Rarity | Effect |
| :--- | :--- | :--- |
| **Heavy Caliber** | `Common` (Cyan) | +25% Projectile Damage across all weapons (**Stacks Infinitely**). |
| **Overclock Trigger** | `Common` (Cyan) | +25% Fire Rate for continuous suppression (stacks up to 6x). |
| **Rapid Loader** | `Common` (Cyan) | +25% Reload Speed across all weapons (stacks up to 6x). |
| **Extended Mag** | `Common` (Cyan) | +30% Magazine Capacity across all weapons (stacks up to 6x). |
| **Kinetic Thrusters** | `Common` (Cyan) | +18% Movement Speed and +15% Jump Power. |
| **Nanite Magnet** | `Common` (Cyan) | +60% XP & Loot collection radius. |
| **Hyper-Penetrator** | `Rare` (Purple) | Projectiles pierce through +1 enemy (stacks up to 2x). |
| **Explosive Payload** | `Rare` (Purple) | Bullets explode on impact. **Plasma Core gains +100% AoE radius** (4.5m → 9.0m). |
| **Aegis Energy Shield** | `Rare` (Purple) | Grants +50 Regenerating Shield capacity. |
| **Vampiric Siphon** | `Rare` (Purple) | Instantly restores +4 HP whenever an enemy is slain. |
| **Cryo Rounds** | `Rare` (Purple) | Bullets chill targets, slowing them by 40% for 3 seconds. |
| **Nanite Scavenger** | `Rare` (Purple) | +40% XP and Scrap drops from all defeated enemies. |
| **Multi-Barrel Splitter** | `Epic` (Orange) | +100% Projectiles per shot (Doubles shot count — e.g., Shotgun fires 14 pellets). |
| **Tesla Arc Emitter** | `Epic` (Orange) | Hits arc chain lightning to 2 nearby enemies. |
| **Smart Bouncing Core** | `Epic` (Orange) | Bullets ricochet with on-hit explosion & chain lightning per bounce. |
| **Assault Drone Unit** | `Epic` (Orange) | Deploys companion drone using your Pulse Carbine (1/10 fire rate, no ammo, all weapon perks). +1 drone per pick. |
| **Emergency Defibrillator** | `Legendary` (Gold) | Survive fatal damage once with 3 seconds of invulnerability. |

---

## 👾 Enemy Horde Types

Enemies scale with compounding health: $\text{Base HP} \times 1.05^n$ (where $n$ is the wave number).

1. **Cyber Swarmers**: Fast neon-red crawler insect mechs that swarm in packs and rush players for melee bites.
2. **Plasma Spitters**: Hovering purple combat drones that strafe at a distance and fire homing plasma bolts.
3. **Armored Goliaths (Brutes)**: Giant high-HP armored cyber crushers that charge in and slam the ground creating shockwaves and knockback!

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
│   │   ├── network_manager.gd        # ENet high-level multiplayer squad manager
│   │   ├── game_manager.gd           # Stats, upgrades catalog, wave director, XP
│   │   └── sound_manager.gd          # Pure synthesized 16-bit PCM audio engine
│   ├── player/
│   │   ├── player.gd                 # FPS controller, co-op sync, 3D armor, revives
│   │   └── drone.gd                  # Companion drone AI and carbine firing
│   ├── enemies/
│   │   ├── enemy_base.gd             # Base enemy class (health, multi-target, damage)
│   │   ├── swarmer.gd                # Fast swarm insect AI
│   │   ├── spitter.gd                # Ranged hovering drone AI
│   │   └── brute.gd                  # Ground-slamming heavy golem AI
│   ├── projectiles/
│   │   ├── bullet.gd                 # Projectiles with ricochet, pierce, lightning, AOE
│   │   ├── enemy_projectile.gd       # Spitter plasma orb
│   │   └── explosion.gd              # Area-of-effect blast & particle emitter
│   ├── loot/
│   │   ├── loot_pickup.gd            # Magnetized XP, Health, and Scrap items
│   │   └── chest.gd                  # Interactive Loot Cache with beacon
│   ├── ui/
│   │   ├── lobby_menu.gd             # Cyberpunk multiplayer Host & Join lobby
│   │   ├── hud.gd                    # Reticle, hitmarker, health, shield, ammo, waves
│   │   ├── upgrade_menu.gd           # 3-card holographic roguelike selector
│   │   ├── pause_menu.gd             # Pause screen with sensitivity & audio sliders
│   │   └── game_over.gd              # Stats summary & retry screen
│   └── world/
│       ├── spawner.gd                # Wave director & horde scaling
│       └── jump_pad.gd               # Aerial launch pads
└── scenes/
    ├── main.tscn                     # Main game scene combining arena, squad, HUD
    ├── player/player.tscn            # Player scene with 1st-person & 3rd-person armor
    ├── enemies/                      # Swarmer, Spitter, Brute scenes
    ├── projectiles/                  # Bullet, Plasma, Explosion scenes
    ├── loot/                         # Pickup & Chest scenes
    ├── ui/                           # Lobby, HUD, Upgrade, Pause, GameOver scenes
    └── world/                        # Arena & JumpPad scenes
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

### 2. How to Add a New Roguelike Upgrade
1. Open [`scripts/autoload/game_manager.gd`](file:///c:/Users/Admin/Desktop/Code/SelfMadeProduct/Game/scripts/autoload/game_manager.gd).
2. Add your upgrade dictionary to `UPGRADE_CATALOG`:
   ```gdscript
   "laser_sights": {
       "id": "laser_sights",
       "name": "Precision Optics",
       "desc": "+30% Critical Hit Chance and +50% Crit Damage.",
       "rarity": "Rare",
       "color": Color(0.8, 0.3, 1.0),
       "max_stacks": 3
   },
   ```
3. Add any necessary stat tracking variable in `GameManager` (e.g. `var crit_chance: float = 0.15`).
4. In `apply_upgrade(id: String)`, handle the stat increase:
   ```gdscript
   "laser_sights":
       crit_chance += 0.30
       crit_damage += 0.50
   ```
5. `stats_updated.emit()` automatically triggers updates in player weapons and HUD.

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
