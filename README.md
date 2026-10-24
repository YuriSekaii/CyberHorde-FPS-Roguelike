# ⚡ CyberHorde: Rogue Protocol

[![Engine](https://img.shields.io/badge/Engine-Godot%204.7-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Renderer](https://img.shields.io/badge/Renderer-Vulkan%20Forward%2B-red)](https://vulkan.org)
[![Repository](https://img.shields.io/badge/GitHub-YuriSekaii%2FCyberHorde--FPS--Roguelike-181717?logo=github)](https://github.com/YuriSekaii/CyberHorde-FPS-Roguelike)

A fast-paced 3D First-Person Horde Roguelike Upgrade Looter built in **Godot 4.7**.

Survive escalating cybernetic hordes, harvest magnetized Nanite XP crystals and scrap, crack open holographic loot caches, and craft overpowered character builds through dynamic roguelike upgrades.

---

## 🎮 How to Play

### 1-Click Launchers:
* **`Play_Game.bat`**: Launches the game window immediately using Godot's console runtime with full error-reporting safeguards.
* **`Open_In_Godot_Editor.bat`**: Opens the project directly inside the Godot 4.7 Editor for inspecting scenes, tweaking stats, or modifying scripts.
* **`Push_To_GitHub.bat`**: Automatically stages, commits, and pushes any local modifications to your remote GitHub repository (`main` branch).

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
| **Select Upgrade Card** | `1`, `2`, `3` or `Click` | Select 1 of 3 cards on Level Up or Cache open |
| **Pause Menu** | `Escape` | Pause mission, adjust mouse sensitivity slider, or restart |

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

Whenever your **Nanite XP bar** fills up or you open a **Loot Cache**, time freezes and you are offered **3 holographic upgrade cards**.
Upgrade rarity tiers roll with authentic 1/5 drop rates: **Common** (~80.1%), **Rare** (~16.0%), **Epic** (~3.2%), and **Legendary** (~0.64%).

| Upgrade | Rarity | Effect |
| :--- | :--- | :--- |
| **Heavy Caliber** | `Common` (Cyan) | +25% Projectile Damage across all weapons (**Stacks Infinitely**). |
| **Overclock Trigger** | `Common` (Cyan) | +25% Fire Rate for continuous suppression (stacks up to 6x). |
| **Rapid Loader** | `Common` (Cyan) | +25% Reload Speed across all weapons (stacks up to 6x). |
| **Extended Mag** | `Common` (Cyan) | +30% Magazine Capacity across all weapons (stacks up to 6x). |
| **Kinetic Thrusters** | `Common` (Cyan) | +18% Movement Speed and +15% Jump Power. |
| **Nanite Magnet** | `Common` (Cyan) | +60% XP & Loot collection radius. |
| **Multi-Barrel Splitter** | `Rare` (Purple) | +100% Projectiles per shot (Doubles shot count — e.g., Shotgun fires 14 pellets). |
| **Hyper-Penetrator** | `Rare` (Purple) | Projectiles pierce through +1 enemy. |
| **Explosive Payload** | `Rare` (Purple) | Bullets explode on impact. **Plasma Core gains +100% AoE radius** (4.5m → 9.0m). |
| **Aegis Energy Shield** | `Rare` (Purple) | Grants +50 Regenerating Shield capacity. |
| **Vampiric Siphon** | `Rare` (Purple) | Instantly restores +4 HP whenever an enemy is slain. |
| **Cryo Rounds** | `Rare` (Purple) | Bullets chill targets, slowing them by 40% for 3 seconds. |
| **Nanite Scavenger** | `Rare` (Purple) | +40% XP and Scrap drops from all defeated enemies. |
| **Tesla Arc Emitter** | `Epic` (Orange) | Hits arc chain lightning to 2 nearby enemies. |
| **Smart Bouncing Core** | `Epic` (Orange) | Bullets ricochet with on-hit explosion & chain lightning per bounce. |
| **Assault Drone Unit** | `Epic` (Orange) | Deploys companion drone using your Pulse Carbine (1/10 fire rate, no ammo, all weapon perks). +1 drone per pick. |
| **Emergency Defibrillator** | `Legendary` (Gold) | Survive fatal damage once with 3 seconds of invulnerability. |

---

## 👾 Enemy Horde Types

Enemies scale with compounding health: $\text{Base HP} \times 1.05^n$ (where $n$ is the wave number).

1. **Cyber Swarmers**: Fast neon-red crawler insect mechs that swarm in packs and rush you for melee bites.
2. **Plasma Spitters**: Hovering purple combat drones that strafe at a distance and fire homing plasma bolts.
3. **Armored Goliaths (Brutes)**: Giant high-HP armored cyber crushers that charge in and slam the ground creating shockwaves and knockback!

---

## 💎 Loot & Arena Mechanics

* **Nanite XP Crystals** *(Green/Cyan)*: Magnetize to the player and fill the Level Up bar.
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
├── project.godot                     # Core Godot 4.7 project configuration
├── Play_Game.bat                     # 1-click game launcher with error protection
├── Open_In_Godot_Editor.bat          # 1-click editor launcher
├── Push_To_GitHub.bat                # 1-click GitHub sync launcher
├── README.md                         # Comprehensive documentation
├── icon.svg                          # Vector cyber reticle icon
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd           # Stats, upgrades catalog, wave director, XP
│   │   └── sound_manager.gd          # Pure synthesized 16-bit PCM audio engine
│   ├── player/
│   │   └── player.gd                 # FPS controller, recoil, viewmodels, weapons, drone
│   ├── enemies/
│   │   ├── enemy_base.gd             # Base enemy class (health, damage numbers, loot)
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
│   │   ├── hud.gd                    # Reticle, hitmarker, health, shield, ammo, waves
│   │   ├── upgrade_menu.gd           # 3-card holographic roguelike selector
│   │   ├── pause_menu.gd             # Pause screen with sensitivity slider
│   │   └── game_over.gd              # Stats summary & retry screen
│   └── world/
│       ├── spawner.gd                # Wave director & horde scaling
│       └── jump_pad.gd               # Aerial launch pads
└── scenes/
    ├── main.tscn                     # Main game scene combining arena, player, HUD
    ├── player/player.tscn
    ├── enemies/                      # Swarmer, Spitter, Brute scenes
    ├── projectiles/                  # Bullet, Plasma, Explosion scenes
    ├── loot/                         # Pickup & Chest scenes
    ├── ui/                           # HUD, Upgrade, Pause, GameOver scenes
    └── world/                        # Arena & JumpPad scenes
```

---

## 🛠️ Beginner Tweaks to Try in Godot

Double-click `Open_In_Godot_Editor.bat` to modify the game:
1. **Change Weapon Stats**:
   - Open `scripts/player/player.gd` and adjust `rifle.fire_rate`, `shotgun.pellets`, or `plasma.damage` inside `_setup_weapons()`.
2. **Tweak Enemy Scaling**:
   - Open `scripts/world/spawner.gd` and change `total_enemies_in_wave` or `spawn_interval`.
3. **Change Arena Lighting & Bloom**:
   - Open `scenes/world/arena.tscn` -> select `WorldEnvironment` -> adjust `Glow Intensity` and `Bloom` in the Inspector!
