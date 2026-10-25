# ⚡ CyberHorde: Rogue Protocol

[![Engine](https://img.shields.io/badge/Engine-Godot%204.7-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Renderer](https://img.shields.io/badge/Renderer-Vulkan%20Forward%2B-red)](https://vulkan.org)
[![Multiplayer](https://img.shields.io/badge/Networking-ENet%20Co--op%20Multiplayer-brightgreen)](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html)
[![Repository](https://img.shields.io/badge/GitHub-YuriSekaii%2FCyberHorde--FPS--Roguelike-181717?logo=github)](https://github.com/YuriSekaii/CyberHorde-FPS-Roguelike)

A fast-paced 3D First-Person Horde Roguelike Shooter featuring **Online Co-op Multiplayer** built with **Godot 4.7**.

Survive escalating cybernetic hordes, harvest magnetized Nanite XP crystals and scrap, crack open holographic loot caches, and craft overpowered character builds through dynamic roguelike upgrades—either solo or side-by-side with your squad!

---

## 🎮 How to Play

### 🚀 Zero-Setup "Clone & Play":
The matching Godot 4.7.2 Engine is bundled directly in the repository (`engine.zip`, 82 MB). When you or a friend clones the repository and double-clicks `Play_Game.bat`, it automatically unpacks the engine in seconds on first run—**no manual downloads, installations, or external dependencies required!**

### 1-Click Launchers:
* **`Play_Game.bat`**: Launches the game window immediately with the cyberpunk Main Lobby (`Single Player`, `Host Co-op`, `Join Co-op`, `Boss Battle`, or `Check for Updates`). Auto-unpacks the bundled engine if needed.
* **`Update_Game.bat`**: 1-click update script to automatically run `git pull` from Windows Explorer.
* **`Test_Coop_2Players.bat`**: Instantly launches two game windows side-by-side on your desktop so you can test 2-player co-op locally with zero setup!
* **`Open_In_Godot_Editor.bat`**: Opens the project directly inside the Godot 4.7 Editor for inspecting scenes, tweaking stats, or modifying scripts.
* **`Push_To_GitHub.bat`**: Automatically stages, commits, and pushes any local modifications to your remote GitHub repository (`main` branch).

### 🕹️ Game Modes:
* **Single Player (Solo)**: Classic solo horde survival starting at Wave 1. Build your loadout card-by-card.
* **Host Co-op Mission (Server)**: Host an online squad co-op lobby using ENet networking (default port: `7777`).
* **Join Co-op Mission (Client)**: Connect to a teammate's host using their local or public IP address.
* **⚔️ Boss Battle (Wave 50 Test Protocol)**:
  * Direct testing mode to immediately fight the **Wave 50 Apex Overlord** without grinding through earlier waves.
  * **Authorization Key**: Requires entering `HereComeTheChallenger` to authorize deployment.
  * **Fully Stacked Perk Arsenal**: You are automatically outfitted with every single perk in the game fully maxed out (infinite-stacking perks—*Heavy Caliber*, *Aegis Energy Shield*, *Vital Plating*, and *Hollow-Point Rounds*—are granted **10 stacks** each).
  * **Deployment Flexibility**: Playable either **Solo** or **Hosted as a Co-op Squad** session.

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
| **Reroll Upgrade Cards** | `Click` | Reroll 3 cards using Scrap (starts at 500 Scrap, doubling with each reroll) |
| **Pause Menu** | `Escape` | Pause mission, adjust Master Sound, SFX Volume, Mouse Sensitivity, toggle Window/Fullscreen, toggle Damage Numbers, or restart |
| **Toggle Window / Fullscreen** | `F11`, `Alt + Enter`, `M` (in menus), or Menu Button | Instantly toggle between Windowed and Borderless Fullscreen display modes |
| **Toggle Damage Numbers** | `F8` or Pause Menu Button | Instantly toggle floating damage numbers ON/OFF to maximize FPS |

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

## ⚡ Performance Optimization & Visual Capping Systems

To guarantee silky-smooth frame rates even during chaotic late-game waves with dozens of bouncing pellets, drones, explosions, and swarming enemies, CyberHorde employs several high-efficiency optimization systems:

### 1. Dynamic Bullet Visual Capping
* **Threshold Management**: Caps the active rendered bullets on screen to a balanced threshold (`40`).
* **Non-Visual Bullet Simulation**: If the total active bullets exceed the threshold (e.g. from shotgun volleys, multi-barrel perks, multiple companion drones, and bouncing ricochets), excess bullets dynamically toggle off their `MeshInstance3D` tracer and `OmniLight3D` point lights.
* **100% Gameplay & DPS Integrity**: Non-visual bullets continue calculating high-speed raycasts, hits, damage calculations, piercing, ricochets, and status effects behind the scenes without dropping any damage.
* **Fair Visual Allocation**: Newly fired shots have a fair random chance to take visual priority over older ricocheting bullets, ensuring the player always sees tracer fire exiting their weapon.

### 2. Streamlined Explosion & GPU Particle Pipeline
* **GPU Particle Offloading**: Converted explosions to `GPUParticles3D` with `ParticleProcessMaterial` and GPU compute shaders, transferring particle simulation off the CPU directly to the graphics hardware.
* **Static Explosion & Lightning Pooling**: Replaced runtime dynamic scene tree instantiations with a static pre-allocated pool (24 reusable explosions and 48 reusable beam meshes), eliminating heap allocation stalls and node garbage collection spikes during dense combat volleys.
* **Instantaneous Single-Pass AoE**: Replaced redundant physics Area3D collision sweeps and overlapping body queries with an instant synchronous calculation pass using static spatial caches (`EnemyBase.all_enemies`).
* **Rapid AABB Pre-Filtering**: Checks 2D horizontal bounding box distance (`absf(dx) > r or absf(dz) > r`) to instantly discard ~95% of non-applicable enemies before computing squared distance, completely eliminating expensive `sqrt()` operations.
* **Disabled Physics Area Monitoring**: Explosions and Bullets set `monitoring = false` and `monitorable = false`, removing hundreds of broadphase collision pairs from Godot's PhysicsServer.
* **Clustered Forward+ Light Capping**: Active explosion `OmniLight3D` instances are capped to a maximum of 4 concurrent lights, and bullet lights are capped to 8, preventing multi-light overlap bottlenecks.
* **Audio Throttling & Volume Balancing**: Sound playback for hits, explosions, and ricochets is throttled to prevent audio bus saturation, with ricochet impact volume balanced to -8.0 dB (1/4 of previous volume) to prevent audio fatigue during dense multi-bullet bouncing.

### 3. Scalable Engine Optimization
* **Static Entity Caching**: Replaced frequent `get_tree().get_nodes_in_group("enemies")` calls with `EnemyBase.all_enemies` static registry, saving hundreds of heap array allocations per second.
* **Concurrent Horde Limiter**: Capped concurrent active enemies on the arena to 40 (`MAX_CONCURRENT_ENEMIES`), replenishing immediately on enemy kills while preserving full wave quotas (e.g. all 310 enemies in Wave 50).
* **Frictionless Enemy Physics**: Set enemy `collision_mask = 5` (world + player), eliminating expensive pairwise enemy-on-enemy collision solving loops.

### 4. Damage Number Toggle & Concurrency Limiting
* **In-Game Toggle**: Toggle floating damage numbers on or off at any time via the **Pause Menu** (`💥 VISIBLE [ON]` / `🚫 HIDDEN [OFF]`) or the **`F8`** hotkey.
* **Active Counter Throttling**: When damage numbers are enabled, a safety cap (max 35 active) suppresses non-critical spam numbers during mass AoE detonations, keeping label draw calls minimal.
* **Persistent Setting**: Your preference is saved to `user://settings.cfg` across runs.

---

## 🔫 Weapons Arsenal

| Weapon | Key | Fire Mode | Base Damage | Pellets | Fire Rate | Mag Size | Reload Time | Base Crit | AoE / Effect |
| :--- | :---: | :--- | :--- | :---: | :--- | :---: | :---: | :---: | :--- |
| **Pulse Carbine** | `1` | Automatic | 22.0 | 1 | 0.12s (8.33/s) | 32 | 1.2s | 10% | High-velocity kinetic rifle |
| **Scatter Cannon** | `2` | Semi-Auto | 18.0 / pellet (180 total) | 10 | 0.65s (1.54/s) | 8 | 1.6s | 5% | Wide close-quarters shotgun spread (0.103125 spread) |
| **Plasma Core** | `3` | Hold-to-Charge (Release to Fire) | 150.0 direct + 150.0 AoE | 1 | 0.30 shot/s (3.33s cd + 0.18s charge) | 5 | 2.0s | 25% | Slow-moving giant plasma orb (~23.3 m/s, 1/3 speed), generous 1.5m+ hitbox, 5.0m blast radius (7.5m with *Explosive Payload*), high recoil & concussive kick |

1. **Pulse Carbine (`Key 1`)**:
   - High-velocity kinetic automatic assault rifle.
   - 32-round magazine, 0.12s fire rate (8.3 shots/sec), 22.0 base damage, 10% base crit chance, crisp suppressive fire.
2. **Scatter Cannon (`Key 2`)**:
   - Heavy close-quarters shotgun blasting 10 pellets simultaneously with punchy recoil and screen kick.
   - 18.0 damage per pellet (180 base burst damage), 8-round magazine, 0.65s fire rate, 5% base crit chance, wide 0.103125 spread cone (+25% wider dispersion).
3. **Plasma Core (`Key 3`)**:
   - High-yield heavy energy launcher firing concentrated plasma orbs.
   - **0.30 shot/s Fire Rate with Hold-to-Charge & Release-to-Fire Mechanic**:
     - Operates at a heavy artillery cadence of **0.3 shots/second** (3.33s post-fire cooldown).
     - **Charge Windup**: Requires holding `LMB` for at least the charge delay time (**0.18s base**, accelerated by fire rate perks) before releasing to fire. The 0.3 shot/s interval does not include this 0.18s charge delay.
     - **Charge Retention**: If held longer than the charge delay without releasing, the weapon stays charged and **will not fire until released**.
     - **Shot Cancellation**: Releasing `LMB` before reaching the required charge delay cancels the shot completely without consuming ammo or triggering cooldown. To shoot, you must charge from scratch again.
     - Dynamic visual & HUD feedback:
       - **Dynamic Core Chamber Status Illumination**: The plasma chamber ball on the weapon model shifts to **Warning Red** whenever the weapon cannot shoot (during the 3.33s cooldown, during reload, or when out of ammo), and immediately transitions back to **Radiant Neon Purple** with an energy pop animation the moment it is ready to fire.
       - Pulsing plasma core chamber (expands to 135% while charging), radiant purple muzzle illumination, focused crosshair reticle contraction with neon magenta glow, and capacitor whine audio.
   - **Slow-Moving Heavy Plasma Projectile with Massive Hitbox**:
     - Fires a giant, layered plasma orb traveling at **~23.3 m/s** (exactly 1/3 of standard bullet speed).
     - Features multi-layered visual geometry: outer pulsing translucent magenta plasma sphere (0.9m diameter), electric cyan containment ring, and blinding white-hot dense energy core.
     - Equipped with an expansive **hitbox (0.75m radius + enemy collision radius = ~2.5m effective capture width)** with continuous swept-volume detection, effortlessly plowing through and impacting enemies even on near-misses while safely passing terrain corners without snagging.
   - **High Concussive Recoil**: Unleashes massive gun kickback, +13° muzzle pitch lift, camera vertical recoil, screen trauma shake (0.38 intensity), and a backward propulsion impulse.
   - Deals 150 direct impact damage and 150 Area-of-Effect detonation damage in a 5.0m blast radius (7.5m with *Explosive Payload*), 3.33s cooldown (+ 0.18s charge windup), 2.0s reload time, 25% base crit chance.
   - **Exclusive Tesla Arc Synergy**: When paired with **Tesla Arc Emitter**, strikes *every* enemy in its explosive radius before detonating, and each arc chains outward to alive enemies within 8.5m!

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

### ⟳ Scrap Card Reroll System
Don't like the 3 cards offered? Spend accumulated **Scrap** to reshuffle a fresh set of upgrades!
* **Base Cost**: Initial reroll starts at **500 Scrap**.
* **Exponential Scaling**: The cost doubles every time a reroll is used during your run (**500 → 1,000 → 2,000 → 4,000 → 8,000...**), resetting back to 500 on a new run.
* **Smart Pool Protection**: Rerolling excludes currently presented cards whenever alternative eligible perks remain in the pool.
* **Controls**: Click the gold **`⟳ REROLL`** button at the bottom of the card panel (keyboard hotkey `R` removed to prevent accidental rerolls during combat).
* **Shared Squad Economy**: In co-op multiplayer, rerolls synchronize with the squad's shared Scrap pool.

| Upgrade | Rarity | Effect |
| :--- | :--- | :--- |
| **Heavy Caliber** | `Common` (Cyan) | +25% Projectile Damage across all weapons (**Stacks Infinitely**). |
| **Vital Plating** | `Common` (Cyan) | +25 Maximum Health (**Stacks Infinitely**). Proactively heals upon selection. |
| **Precision Optics** | `Common` (Cyan) | +10% Critical Strike Chance (stacks up to 5x). |
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
| **Explosive Payload** | `Epic` (Orange) | Bullets explode on impact. **Plasma Core gains +50% AoE radius** (5.0m → 7.5m). |
| **Reactive Phase-Shield** | `Epic` (Orange) | When you take damage, gain 1s of invulnerability (Max 2 stacks: 2s). |
| **Null Barrier** | `Epic` (Orange) | Every 5s, nullifies the next instance of damage taken (**Triggers invulnerability perks**). Only 1 stack. |
| **Multi-Barrel Splitter** | `Epic` (Orange) | +100% Projectiles per shot (Doubles shot count — e.g., Shotgun fires 20 pellets) (Max 2 stacks). |
| **Tesla Arc Emitter** | `Epic` (Orange) | Hits arc chain lightning to 2 targets (+2 targets per stack, max 4 stacks: up to 8 targets). Chains sequentially between enemies within 8.5m and can bounce back and forth between previously chained targets! **Exclusive Plasma Core synergy**: Shoots lightning to *every* enemy in explosive radius before detonating, which then chain outward to alive enemies! |
| **Smart Bouncing Core** | `Epic` (Orange) | Bullets ricochet with on-hit explosion & chain lightning per bounce (Max 2 stacks). |
| **Assault Drone Unit** | `Epic` (Orange) | Deploys autonomous companion drone randomly equipped with 1 of 3 arsenal weapons (1/4 fire rate, same mag & reload speed, all weapon perks). Color-coded rings (Cyan/Orange/Magenta) distinguish weapon type. +1 drone per pick (Max 3 stacks). |
| **Emergency Defibrillator** | `Legendary` (Gold) | Survive fatal damage, gaining **5s of invulnerability**. Automatically **recharges after surviving 10 waves**! |

---

## 🎯 Critical Hit & Explosive Mechanics

* **Direct Hit Crits**: Every projectile rolls against its weapon's **Critical Strike Chance** (10% for Pulse Carbine, 5% for Scatter Cannon, 25% for Plasma Core, augmented by +10% per stack of *Precision Optics*). A successful crit multiplies damage by your **Critical Damage Multiplier** (base 2.0x, augmented indefinitely by *Hollow-Point Rounds*).
* **Explosive Damage**: Explosive damage is **calculated from the initial hit damage** (100% of hit damage for Plasma Core: 150 base direct + 150 base AoE; 80% for perk-granted bullet explosions).
* **No Double-Dipping**: Explosions do not trigger critical rolls independently, preventing unintended exponential double-crit scaling while ensuring explosions from a critical bullet strike pack massive punch!
* **No Enemy Stunlock**: All player weapon, projectile, explosion, and lightning knockback on enemies has been removed. Enemies maintain their momentum and pursuit trajectories when damaged, preventing infinite stunlock exploits.

### ⚡ Sequential Chain Lightning & Ping-Pong Bouncing
With the **Tesla Arc Emitter** perk:
* **Perk Stacking (Max 4 Stacks)**: Starts with 2 chain targets at Stack 1, adding +2 targets per stack up to a maximum of **8 chain targets** at Stack 4.
* **Sequential Node-to-Node Arcs**: Lightning arcs sequentially from target to target within 8.5m rather than spreading as a flat radial fork.
* **Must Chain to Another Enemy**: At every hop, the lightning bolt must target a different alive enemy (it cannot strike the current host twice consecutively).
* **Previous Target Ping-Pong Bouncing**: The lightning is explicitly capable of arcing back to previously chained targets. If only 2 enemies (e.g. Boss and Minion, or two tough elites) are present, the lightning will bounce back and forth between them (A → B → A → B...) for the full target count!
* **Crowd Prioritization**: In dense hordes, candidates with fewer chain hits are prioritized first before bouncing back to previously hit targets, ensuring optimal crowd dispersal while retaining focused single-target damage against small groups.

### ⚡ Plasma Core Exclusive: Tesla Supercharge Sequence
When wielding the **Slot 3 Plasma Core** with the **Tesla Arc Emitter** perk active, the weapon enhances lightning chaining with a unique 4-phase detonation sequence:
1. **Plasma Impact**: The orb strikes a target or surface environment.
2. **Radial Lightning Burst**: One lightning bolt is fired from the impact center to **EVERY** enemy inside the explosive blast radius (**5.0m base**, **7.5m with *Explosive Payload***). If 10 enemies are inside the radius, 10 lightning bolts fire simultaneously! This triggers **before** explosive AoE damage to maximize initial lightning targets.
3. **Plasma AoE Detonation**: Direct hit and full Area-of-Effect explosive damage are dealt to the impact point and surrounding blast radius, eliminating weaker horde units.
4. **Outward Secondary Chain**: Each of the lightning bolts from Step 2 chains outward to another **alive enemy within 8.5m**! Against tough survivors or bosses, multiple arcs focus onto remaining threats. (Inherits *Cryo Rounds* chills and independent crit checks).

---

## 👾 Enemy Horde Scaling & Final Boss

### Wave Progression & Scaling
Hordes scale progressively to challenge late-game builds:
* **Wave Spawn Budget**: Total enemies per wave scales by **$10 + \text{Wave} \times 6$** (Wave 1 = 16 enemies, Wave 10 = 70 enemies, Wave 50 = 310 enemies).
* **Spawn Interval Acceleration**: Time between enemy spawns accelerates from 1.9s down to a rapid 0.4s cap ($\text{clamp}(2.0 - \text{Wave} \times 0.1, 0.4, 2.0)$).
* **Every Wave**: Enemies gain **+10% Compounding Health** ($\text{Base} \times 1.10^{\text{Wave} - 1}$) and **+5% Compounding Damage** ($\text{Base} \times 1.05^{\text{Wave} - 1}$).
* **Every 10 Waves**: Enemies gain **+5% Movement Speed and +5% Attack Speed** ($\text{Attack Interval} / \text{Speed Multiplier}$).
* **Every 10 Waves**: Enemies gain **+10% Damage Reduction** (capped at **50%** max reduction in Wave 50). Floating damage indicators accurately reflect reduced damage values.
* **Every 5 Waves (Basic Enemy Multiplicative Decay)**: The spawn weights of the first and second basic enemies (**Cyber Swarmer** and **Plasma Spitter**) reduce by **5%**, compounding multiplicatively ($\text{Weight} \times 0.95^{\lfloor\text{Wave} / 5\rfloor}$).
* **Reduced Heavy & Mini-Boss Enemy Weights**: Base spawn weights for **Armored Goliath (Brute)** (7.2%), **Cyber Charger** (~4.0% – 4.25%), and **Void Spawner** (reduced to **0.25%** / 0.0025, halving then reducing to another 1/4) keep early appearances scarce while dynamically scaling into threatening late-wave compositions as basic enemies decay.

### Enemy Catalog & Base Stats

| Enemy Type | Base Health | Move Speed | Base Damage | Attack Rate / Cooldown | Attack Type & Range | Spawn Weight / Availability |
| :--- | :---: | :---: | :---: | :---: | :--- | :---: |
| **Cyber Swarmer** | 35.0 | 7.0 m/s | 10.0 | 0.8s | Melee bite (1.6m) | Base ~45% – 55% ($\times 0.95^{\lfloor\text{Wave}/5\rfloor}$) |
| **Plasma Spitter** | 75.0 | 4.5 m/s | 18.0 | 2.4s | Homing plasma orb (25.0m) | Base 30.0% (Wave 3+, $\times 0.95^{\lfloor\text{Wave}/5\rfloor}$) |
| **Armored Goliath (Brute)** | **500.0** | 3.6 m/s | 35.0 | 3.5s | Shockwave Ground Slam (4.8m) + 10.0 Knockup | **7.2%** (Wave 6+, Halved from 14.4%) |
| **Cyber Charger** | **220.0** | 3.2 m/s (24 m/s Charge) | **48.0** | 2.5s | Red Lock-On straightline rush, Wall Crash & **3.5s Stun** | **~4.0% – 4.25%** (Wave 11+, Halved from ~8.0% – 8.5%) |
| **Void Spawner** | **2,000.0** | 2.8 m/s | 0.0 (Spawner) | 4.5s Spawn | Portal Mouth Ejection (Spawns Spawnlings), **Drops Upgrade Box** | **0.25%** (Wave 20+, Reduced by 1/2 then 1/4) |
| **Cyber Spawnling** | **14.0** (Lowest HP) | 8.5 m/s | 2.5 | 0.15s | High-speed spinning drill contact (Continuous rapid tick) | Spawned by Void Spawner Portal |
| **Apex Overlord (Final Boss)** | **4,444,444.0** (Cute Fixed HP) | 3.2 – 105.0 m/s (Dive) | 40.0 → 180.0 (Cap) | Dynamic Multi-Stage Attack Loops | Multi-Stage Flight, Slam AoE, Red Aura Lock-On, Hyper Dive, Machine Gun & Mega Orb | Wave 50 Exclusive |

### Enemy Types
1. **Cyber Swarmers**: Fast neon-red crawler insect mechs that swarm in packs and rush players for melee bites. Weight decays by 5% multiplicatively every 5 waves ($\times 0.95^{\lfloor\text{Wave}/5\rfloor}$).
2. **Plasma Spitters**: Hovering purple combat drones that strafe at a distance and fire homing plasma bolts. Weight decays by 5% multiplicatively every 5 waves ($\times 0.95^{\lfloor\text{Wave}/5\rfloor}$).
3. **Armored Goliaths (Brutes)**: Giant armored cyber crushers boasting **500 base HP**. Spawns with halved base frequency (7.2% weight) to serve as imposing threats that charge in and slam the ground creating shockwaves and knockback on players!
4. **Cyber Chargers**: Four-legged cybernetic bull beasts introduced after **Wave 10** (halved base weight ~4.0% – 4.25%, rarer than Brutes). Stalks slowly toward players until within 14m, winds up while pawing the ground, flashes bright red as it locks your location, and rockets forward in a straight line at 24 m/s! Deals 48 heavy damage on contact and travels until impacting an arena wall/pillar, triggering a heavy collision and stunning itself for 3.5 seconds with dizzy sparks.
5. **Void Spawners**: Colossal floating behemoths with massive biomechanical wings and a giant agape mouth housing an active cosmic portal, introduced in **Wave 20** as chaotic tank mini-bosses (**2,000 base HP**, base weight **0.25%**). Has no concurrent spawn limit, allowing multiple spawners to create high-intensity aerial swarms simultaneously! Has no direct attack; instead, periodically ejects Cyber Spawnlings out of its portal mouth. When defeated, drops an interactive **Loot Cache (Upgrade Box)** with free upgrade card rewards!
6. **Cyber Spawnlings**: Fragile aerial interceptors with fluttering wings, a rear flaming thruster booster, and two hanging talons. Its body is a high-speed spinning drill bit. Possessing the **lowest health in the game (14 base HP)**, it homes directly onto players and deals small rapid continuous damage (2.5 damage every 0.15s) with intense grinding sparks when connected.

### 👑 Wave 50 Final Boss: Apex Overlord & Multi-Stage Escalation
**Wave 50 is the climactic Final Wave**. Reaching Wave 50 spawns the ultimate mechanical juggernaut—the **Apex Overlord** (featuring a fixed, unscaled **4,444,444 HP**)—commanding a full escalation horde of Swarmers, Spitters, and Armored Goliaths with dynamic 3-stage combat mechanics:
* **Dedicated HUD Boss Bar**: Displays live HP and health percentage at the top of the screen.
* **Dual Threat Battlefield**: Players face simultaneous pressure from surrounding horde spawns (enabling on-kill perks like *Vampiric Siphon* and Nanite XP replenishment) while evading the Apex Overlord's evolving aerial and ground attacks.
* **Stage 1 (100% – 66% HP) — Armored Ground Juggernaut**:
  * **Movement**: Heavy, lumbering ground pursuit.
  * **Near Attack (Close Range ≤ 8.5m)**: Winds up and executes a devastating **Slam AoE** that hits nearby players with high damage (`attack_damage × 1.6`) and launches them skyward with vertical knockup!
  * **Far Attack (Long Range > 8.5m)**: Alternates firing dual plasma cannons for low damage (`attack_damage × 0.45`) to pressure players from afar.
  * Patterns loop continuously until the boss drops below 66% HP.
* **Stage 2 (66% – 33% HP) — Aerial Bombardier & Hyper Dive**:
  * **Transformation**: The armor shifts and unfolds into massive mechanical wings with glowing amber energy blades; thrusters ignite as the boss ascends into the sky (Y ≈ 14m).
  * **Aerial Bombardment**: Hovers stationary in the air, firing slow-moving plasma bomb projectiles that detonate upon hitting the ground or player, causing medium AoE explosive damage (`attack_damage × 0.85`).
  * **Energy Charge & Red Aura Lock-On**: After several shots, halts and charges energy as its core flares. Upon full charge, **flashes a brilliant Red Aura** and locks onto your exact position (0.7s telegraph), dropping a holographic red impact zone warning beacon. Players must sprint and evacuate the zone immediately!
  * **Extreme Speed Dive**: Plunges from the sky at extreme speed (60 m/s) straight into the locked position, causing a massive 10.5m **AoE Shockwave** (`attack_damage × 2.2` massive damage + knockup).
  * **Loop**: Recovers on the ground, rockets back into the sky, and repeats the pattern until 33% HP.
* **Stage 3 (< 33% HP) — Solid Metal Fallen Angel (Massive Wings & Bullet Hell)**:
  * **Transformation**: Detonates its entire outer armor shell to reveal a terrifying **Solid Metal Fallen Angel with massive spread wings**—featuring a solid sculpted dark steel cuirass, metallic legs, dark halo crown, and giant metallic feathered wings spreading over 12m wide!
  * **Simultaneous Hands & Wings Bullet Hell**: Sweeps across the sky at high speed (32 m/s) while firing simultaneously from **both hands and both massive wings** (6 muzzles active at once), unleashing an intense, dense bullet-hell curtain of ~550 crimson needles over 6.0s with huge lateral and vertical spread (65 m/s, `attack_damage × 0.09` per needle).
  * **Cataclysmic Mega Projectile**: Halts and channels catastrophic power into its exposed heart, launching a giant, slow-moving mega sphere that causes a gargantuan 12m explosion on impact with massive damage (`attack_damage × 2.8`).
  * **Exhaustion Cooldown**: The boss visibly weakens and sags in the sky as its core dims and flickers, entering an exhaustion cooldown for 3 seconds—providing a prime vulnerability window for players to lay down massive DPS!
  * **Post-Exhaustion Supersonic Dive**: Surges back to life, flashes its crimson red aura, locks your position with the exact same 0.70s warning window as Stage 2, and dives with supersonic hyper speed (105 m/s) into the ground, causing an 11.5m shockwave (`attack_damage × 2.5` massive damage).
  * **Loop**: Rockets back into the sky and loops the Stage 3 pattern until defeated.
* **Victory Protocol**: Defeating the Apex Overlord causes its unstable reactor to detonate in a cascading EMP meltdown, clearing any remaining horde units and achieving **MISSION ACCOMPLISHED** victory!
* **Direct Boss Battle Testing**: Need to test boss attack patterns, phases, audio, or balance without grinding waves 1 through 49? Select **⚔️ BOSS BATTLE** in the main lobby, enter authorization key `HereComeTheChallenger`, and immediately deploy into Wave 50 with every perk fully stacked (10 stacks for infinite perks)! Accessible in both Solo and Co-op Host modes.

---

## 💎 Loot & Arena Mechanics

* **Nanite XP Crystals** *(Green/Cyan)*: Magnetize to the player and fill the squad Level Up bar.
* **Medical Stims** *(Red)*: Instantly restores 25 Health (drops more often when HP is low).
* **Scrap Currency** *(Gold)*: Collect golden currency from kills, chests, and wave bonuses to fund Upgrade Card Rerolls (starts at 500 Scrap, doubling every use).
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
│   │   ├── game_manager.gd           # ★ PRIMARY PERK CATALOG: `upgrade_database`, stats, apply_upgrade(), Boss Battle mode setup
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
│   │   ├── charger.gd                # 4-legged bull rushing & wall-stun AI
│   │   ├── spawner.gd                # Void Spawner aerial portal minion carrier AI
│   │   ├── spawnling.gd              # Fast spinning drill minion AI
│   │   └── boss.gd                   # Wave 50 Apex Overlord multi-phase boss AI
│   ├── projectiles/
│   │   ├── bullet.gd                 # ★ PROJECTILE PERKS: Explosions, pierce, ricochet, chain lightning, cryo
│   │   ├── enemy_projectile.gd       # Spitter plasma orb
│   │   └── explosion.gd              # Area-of-effect blast & particle emitter
│   ├── loot/
│   │   ├── loot_pickup.gd            # ★ LOOT PERKS: Nanite Magnet collection radius, magnetized pickups
│   │   └── chest.gd                  # Interactive Loot Cache with beacon
│   ├── ui/
│   │   ├── upgrade_menu.gd           # ★ UPGRADE CARD UI: Generates 3 cards dynamically from `upgrade_database`
│   │   ├── hud.gd                    # HUD: Reticle, hitmarker, health, shield, Null Barrier status, waves, boss health bar
│   │   ├── lobby_menu.gd             # Main Lobby: Solo, Host, Join, Boss Battle (key auth), Updates
│   │   ├── pause_menu.gd             # Pause screen with sensitivity & audio sliders
│   │   └── game_over.gd              # Stats summary & retry screen
│   └── world/
│       ├── wave_spawner.gd           # Wave director, Wave 50 Boss Battle spawning & horde scaling
│       ├── spawn_indicator.gd        # 3D holographic telegraph rings & emergence
│       └── jump_pad.gd               # Aerial launch pads
└── scenes/
    ├── main.tscn                     # Main game scene combining arena, squad, HUD
    ├── player/player.tscn            # Player scene with 1st-person & 3rd-person armor
    ├── enemies/                      # Swarmer, Spitter, Brute, Charger, Spawner, Spawnling, Boss scenes
    ├── projectiles/                  # Bullet, Plasma, Explosion scenes
    ├── loot/                         # Pickup & Chest scenes
    ├── ui/                           # Lobby, HUD, Upgrade, Pause, GameOver scenes
    └── world/                        # Arena, JumpPad, SpawnIndicator scenes
```

---

## 🛠️ Developer Guide: Architecture & Extending the Game

If you are continuing development on **CyberHorde**, this section gives you the exact blueprint of how systems connect and how to add new features safely.

### 1. Multiplayer Networking Architecture
* **Autoload**: [`scripts/autoload/network_manager.gd`](scripts/autoload/network_manager.gd) handles `ENetMultiplayerPeer`, hosting, client joining, and connection signals.
* **Squad Launch Pipeline**:
  1. Players connect in [`lobby_menu.tscn`](scenes/ui/lobby_menu.tscn).
  2. Host clicks **`LAUNCH SQUAD MISSION`** $\rightarrow$ calls `rpc_start_mission.rpc(NetworkManager.connected_peers)`.
  3. Both Host and Client receive `rpc_start_mission` and spawn each squad member into the `$Players` container in [`scripts/main.gd`](scripts/main.gd).
* **Player Authority & Avatars** ([`scripts/player/player.gd`](scripts/player/player.gd)):
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

All perks are driven by a centralized data structure in [`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd) and executed across specific gameplay scripts.

#### 📍 Which Files to Modify

| Perk Category | Primary File(s) to Modify | What to Implement |
| :--- | :--- | :--- |
| **All Perks (Registration & Stats)** | [`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd) | Add/modify entries in `upgrade_database`, declare stat variables, reset in `reset_game()`, and apply values in `apply_upgrade()`. |
| **Defensive & Player Perks** (Shields, Invulnerability, Nullify, HP, Speed, Jumps) | [`scripts/player/player.gd`](scripts/player/player.gd) | Check stats inside `take_damage()`, `_physics_process()`, `_handle_movement()`, or `_update_stats()`. |
| **Weapon & Projectile Perks** (Explosions, Ricochet, Piercing, Chain Lightning, Cryo) | [`scripts/projectiles/bullet.gd`](scripts/projectiles/bullet.gd) | Check stats during collisions (`_on_body_entered()`, `_handle_ricochet()`, `_handle_pierce()`, `_handle_lightning()`). |
| **Loot & Economy Perks** (Pickup Radius, Extra Scrap/XP) | [`scripts/loot/loot_pickup.gd`](scripts/loot/loot_pickup.gd) & [`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd) | `GameManager.magnet_radius` in `loot_pickup.gd`, and `GameManager.greed_mult` in `add_xp()` / `add_scrap()`. |
| **Card Selector UI** | [`scripts/ui/upgrade_menu.gd`](scripts/ui/upgrade_menu.gd) | *Automatic*: Reads directly from `GameManager.upgrade_database` and handles stack counts automatically. |
| **HUD Status Display** | [`scripts/ui/hud.gd`](scripts/ui/hud.gd) | Add HUD widgets for perks that need real-time feedback (like Shield Bar or Null Barrier cooldown). |

---

#### ✏️ How to Modify an Existing Perk
1. Open [`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd).
2. Locate the perk entry in `upgrade_database`:
   - Change `max_stacks` to adjust the maximum rank (e.g. `max_stacks: 2`).
   - Change `desc` to update the description shown on the holographic upgrade card.
   - Change `rarity` (`"Common"`, `"Rare"`, `"Epic"`, or `"Legendary"`) and `color` (`Color(0.4, 0.8, 1.0)` for Common, `Color(0.8, 0.3, 1.0)` for Rare, `Color(1.0, 0.6, 0.1)` for Epic, `Color(1.0, 0.9, 0.2)` for Legendary).
3. Update the perk's bonus values in `apply_upgrade()` (e.g., adjust stat multipliers or flat bonuses).
4. Synchronize the perk table in [`README.md`](README.md) to match.

---

#### ➕ Step-by-Step: How to Add a New Perk
1. **Define in `upgrade_database`** ([`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd)):
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
2. **Add tracking variable & reset in `reset_game()`** ([`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd)):
   ```gdscript
   var plasma_shield_bonus: float = 0.0
   
   func reset_game() -> void:
       ...
       plasma_shield_bonus = 0.0
   ```
3. **Handle in `apply_upgrade(upgrade_id: String)`** ([`scripts/autoload/game_manager.gd`](scripts/autoload/game_manager.gd)):
   ```gdscript
   "plasma_shield":
       plasma_shield_bonus += 25.0
   ```
4. **Hook up the gameplay effect** in the target script:
   - For player stats: read `GameManager.plasma_shield_bonus` in [`scripts/player/player.gd`](scripts/player/player.gd) inside `_update_stats()`.
   - For projectile effects: read `GameManager` flags in [`scripts/projectiles/bullet.gd`](scripts/projectiles/bullet.gd).
5. **Update documentation & push**: Update the [Roguelike Upgrades Catalog](#-roguelike-upgrades-system) in `README.md` and push changes to GitHub.

---

### 3. How to Add a New Weapon
1. Open [`scripts/player/player.gd`](scripts/player/player.gd).
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
3. Add a corresponding 3D gun mesh under `Head/Camera3D/WeaponRig` in [`scenes/player/player.tscn`](scenes/player/player.tscn).
4. Update `_switch_weapon(new_idx)` and `_update_third_person_weapon(idx)` to toggle your new gun model's visibility.

---

### 4. How to Add a New Enemy Type
1. Create a new script in `scripts/enemies/` inheriting from [`scripts/enemies/enemy_base.gd`](scripts/enemies/enemy_base.gd).
2. Override `_behave(delta)` with your custom movement and attack pattern (e.g. charging, dodging, sniping).
   * `target_player` automatically updates to the nearest active, non-downed squadmate!
3. Create a corresponding `.tscn` scene in `scenes/enemies/` with a `CharacterBody3D`, `CollisionShape3D`, and visual meshes.
4. Open [`scripts/world/wave_spawner.gd`](scripts/world/wave_spawner.gd):
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
