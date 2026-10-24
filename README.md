# ⚡ CyberHorde: Rogue Protocol

A 3D First-Person Horde Roguelike Upgrade Looter built in **Godot 4.7**.

Survive escalating cybernetic hordes, harvest nanite XP and scrap, crack open holographic loot caches, and craft overpowered character builds through dynamic roguelike upgrades.

---

## 🎮 How to Play

### Instant 1-Click Launch:
- Double-click **`Play_Game.bat`** in the game folder to launch and play immediately!
- Double-click **`Open_In_Godot_Editor.bat`** to open and edit the project inside the Godot Engine Editor.

---

## 🕹️ Controls

| Action | Key / Input |
| :--- | :--- |
| **Move** | `W`, `A`, `S`, `D` |
| **Look / Aim** | `Mouse` |
| **Jump** | `Spacebar` (supports Coyote time & jump buffering) |
| **Sprint** | `Shift` (hold) |
| **Primary Fire** | `Left Mouse Button` |
| **Reload** | `R` (or automatic when empty) |
| **Switch Weapons** | `1`, `2`, `3` or `Mouse Wheel` |
| **Interact / Open Cache** | `E` |
| **Select Upgrade Card** | `1`, `2`, `3` or `Click` on card |
| **Pause Menu** | `Escape` |

---

## 🔫 Weapons Arsenal

1. **Pulse Carbine (`Key 1`)**:
   - High-velocity kinetic automatic rifle with tight spread and high rate-of-fire.
2. **Scatter Cannon (`Key 2`)**:
   - Devastating close-range shotgun firing 7 pellets simultaneously with heavy stopping power and screen recoil.
3. **Plasma Core (`Key 3`)**:
   - Fires concentrated explosive plasma orbs that detonate on impact for massive area-of-effect damage.

---

## 🧬 Roguelike Upgrades System

Whenever your **Nanite XP bar** fills up or you open a **Loot Cache**, time freezes and you are offered **3 holographic upgrade cards** drawn from common, rare, epic, and legendary pools:

* **Heavy Caliber** *(Common)*: +25% Projectile Damage.
* **Overclock Trigger** *(Common)*: +25% Fire Rate.
* **Kinetic Thrusters** *(Common)*: +18% Move Speed & +15% Jump Power.
* **Nanite Magnet** *(Common)*: +60% XP & Loot attraction distance.
* **Multi-Barrel Splitter** *(Rare)*: +1 extra projectile per shot with spread.
* **Hyper-Penetrator** *(Rare)*: Shots pierce through +1 enemy.
* **Explosive Payload** *(Rare)*: Bullets explode on impact for AoE blast.
* **Aegis Energy Shield** *(Rare)*: Regenerating 50 HP energy shield.
* **Vampiric Siphon** *(Rare)*: Restores +4 HP on every enemy kill.
* **Cryo Rounds** *(Rare)*: Shots slow enemies by 40%.
* **Tesla Arc Emitter** *(Epic)*: Bullet hits arc lightning to 2 nearby enemies.
* **Smart Bouncing Core** *(Epic)*: Bullets ricochet off walls toward targets.
* **Assault Drone Unit** *(Epic)*: Deploys an autonomous companion drone that flies beside you and lasers enemies.
* **Emergency Defibrillator** *(Legendary)*: Survive fatal damage once with 3s of invulnerability.
* **Nanite Scavenger** *(Rare)*: +40% XP and Scrap drops.

---

## 👾 Enemy Horde Types

1. **Cyber Swarmers**:
   - Fast neon-red crawler bugs that swarm in packs and rush you for melee bites.
2. **Plasma Spitters**:
   - Hovering purple combat drones that strafe at a distance and fire homing plasma bolts.
3. **Armored Goliaths (Brutes)**:
   - Giant high-HP armored cyber crushers that charge in and slam the ground creating shockwaves!

---

## 💎 Loot & Economy

* **Nanite XP Crystals** *(Green/Cyan)*: Magnetize to you and grant XP to level up.
* **Medical Stims** *(Red)*: Restores 25 Health.
* **Scrap Currency** *(Gold)*: Collect currency to build your high score.
* **Loot Caches (Chests)**: Dropped every 2 waves with a beacon light beam pointing to the sky. Press `E` to open for bonus loot and a **free upgrade choice**!
* **Jump Pads**: 4 glowing launch pads around the arena that blast you high into the air for aerial combat!

---

## 📂 Project Architecture (For Beginners)

If you're curious how games are structured in Godot, here is the tour:

```
Game/
├── project.godot                     # Core Godot project configuration
├── Play_Game.bat                     # 1-click game launcher
├── Open_In_Godot_Editor.bat          # 1-click editor launcher
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd           # Stats, upgrades pool, wave director, XP
│   │   └── sound_manager.gd          # Pure synthesized 16-bit PCM sound engine
│   ├── player/
│   │   └── player.gd                 # First-person controller, viewmodels, weapons
│   ├── enemies/
│   │   ├── enemy_base.gd             # Base enemy class (health, damage numbers, loot)
│   │   ├── swarmer.gd                # Fast swarm insect AI
│   │   ├── spitter.gd                # Ranged hovering drone AI
│   │   └── brute.gd                  # Ground-slamming heavy golem AI
│   ├── projectiles/
│   │   ├── bullet.gd                 # Bullets with ricochet, pierce, lightning, AOE
│   │   ├── enemy_projectile.gd       # Spitter plasma orb
│   │   └── explosion.gd              # Area-of-effect blast & particles
│   ├── loot/
│   │   ├── loot_pickup.gd            # Magnetized XP, Health, Scrap items
│   │   └── chest.gd                  # Interactive Loot Cache
│   ├── ui/
│   │   ├── hud.gd                    # Reticle, hitmarker, health, ammo, wave info
│   │   ├── upgrade_menu.gd           # 3-card holographic roguelike selector
│   │   ├── pause_menu.gd             # Pause screen with sensitivity settings
│   │   └── game_over.gd              # Stats summary & retry screen
│   └── world/
│       ├── spawner.gd                # Wave director & horde scaling
│       └── jump_pad.gd               # Aerial launch pads
└── scenes/
    ├── main.tscn                     # Main game scene combining everything
    ├── player/player.tscn
    ├── enemies/                      # Swarmer, Spitter, Brute scenes
    ├── projectiles/                  # Bullet, Plasma, Explosion scenes
    ├── loot/                         # Pickup & Chest scenes
    ├── ui/                           # HUD, Upgrade, Pause, GameOver scenes
    └── world/                        # Arena & JumpPad scenes
```

---

## 🛠️ Fun Tweaks to Try in Godot

Once you open `Open_In_Godot_Editor.bat`:
1. **Change Weapon Fire Rate or Damage**:
   - Open `scripts/player/player.gd` and adjust `rifle.fire_rate` or `shotgun.pellets` in `_setup_weapons()`.
2. **Tweak Enemy Health & Speed**:
   - Open `scenes/enemies/swarmer.tscn` or `scenes/enemies/brute.tscn` and edit the `@export` numbers in the Inspector.
3. **Change Arena Lighting / Glow**:
   - Open `scenes/world/arena.tscn` -> select `WorldEnvironment` -> adjust `Glow Intensity` and `Bloom`!
