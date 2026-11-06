# 3D Asset Pipeline (AI-generated → Godot)

Read this instead of re-deriving the pipeline. Prompts for every asset: [`ASSET_PROMPTS.md`](ASSET_PROMPTS.md).
Asset list, sizes and targets: [`tools/asset_pipeline/assets_manifest.csv`](../tools/asset_pipeline/assets_manifest.csv).

## Flow

1. **Concept image (user, Gemini Nano Banana Pro).** Paste the style primer from `ASSET_PROMPTS.md`, then the asset's prompt, in the same chat. Save it as `Reference/AssetGen/<name>.png` (`Reference/` is git-ignored). An optional back view goes in `<name>_back.png`.
2. **Build (one command, local GPU, no Claude needed).**
   - All new images: `powershell -ExecutionPolicy Bypass -File tools\asset_pipeline\batch.ps1`
   - One asset: `...\make_asset.ps1 -Name <name> -Height <m> -Tris <n> [-Tex 1024] [-Yaw 0] [-Back <png>]`
   - The build runs: Hunyuan3D-2 (`D:\AI\Hunyuan3D-2\make_model.py`) → `D:\AI\gen\<name>\raw.glb` → Blender `tools/asset_pipeline/prep_prop.py` → `assets/models/<name>/<name>.glb` → Godot `--import`.
   - Previews are written to `D:\AI\gen\<name>\preview_front.png` and `preview_q34.png`. Look at them before integrating.
   - To redo only the cheap Blender step (e.g. a different size or triangle count), keep `raw.glb`. To regenerate the shape, delete it.
3. **Integrate into the game (cheap-ag task, one per asset).** See the recipe below.
4. **Update README + commit + push**, as CLAUDE.md requires.

## What prep_prop.py does

It welds the UV-split Hunyuan mesh, removes floaters smaller than 0.5% of the vertices, and decimates to `max_tris`. Edges sharper than 35° stay hard; the rest is smooth-shaded. It scales the model so its height (Z) is `height_m`, puts the origin at the bottom centre, and turns it to face Godot −Z. Weapons drawn in side profile with the barrel pointing right use `yaw -90` (`90` points the muzzle backwards). It sets every material to Metallic 0.2 / Roughness 0.5: Hunyuan's glb omits `metallicFactor`, which glTF reads as fully metallic, and the model renders black. The optional manifest column `desat` (0–1, weapons use 0.85) removes colour tint from the non-glowing texels; Hunyuan often paints gunmetal maroon. Optional manifest columns `octree` and `max_faces` raise Hunyuan's shape resolution and face cap (defaults 380 / 40000, read by `make_model.py` via the `OCTREE`/`MAXFACES` env vars). First-person weapons fill a quarter of the screen, so build them as hero assets: Pulse Carbine uses octree 512, max_faces 150000, max_tris 80000, tex 2048. Finally it resizes the texture to `tex_px` and builds an **emission map from bright, saturated texels**, so neon parts and eyes glow in Godot.

## Tiers (manifest column `tier`)

| Tier | What | Integration |
|---|---|---|
| 1 | Static props, weapons, pickups, arena pieces, trees | Swap the visual mesh only |
| 2 | Rigid enemies and drones that the code moves as one block (bob, spin, fly) | Swap the visual mesh only. **First check** whether the script animates named child nodes; if it does, the asset is tier 3 |
| 3 | Creatures whose code animates limbs | Needs a rig and a retarget (Blood Ghoul recipe below). Expensive: do one at a time |
| — | Bog Slime (translucent ooze), projectiles, VFX, portals | Keep procedural or shader-based. AI meshes don't fit |

## Integration recipe (tier 1/2), for a cheap-ag task

- Add `[ext_resource type="PackedScene" path="res://assets/models/<name>/<name>.glb" id="..."]` to the target `.tscn`. Instance it as `Model` under the node that holds the old visual meshes (enemies: `MeshRoot`; weapons: `WeaponRig/<Weapon>`; pickups and the chest: the visual root).
- Delete the old `MeshInstance3D` visual nodes **only if** no script reads them (grep the node names in `scripts/`). Otherwise hide them in `_ready` with a `shortcut:` comment, as `blood_ghoul.gd` does.
- **Never touch collision shapes or gameplay code.** Tune only the `Model` transform (scale/rotation/offset) so the mesh fits the collider.
- Weapons: put scale, offset and a small inward yaw on `WeaponRig/<Weapon>/Model` only; `HIP_POSITION`/`ADS_POSITION` in `player.gd` are shared by all weapons. When aiming, the sight lens must sit at eye level and the whole gun must stay in front of the camera's 0.05 m near plane, or the stock clips open (Pulse Carbine: scale 1.3, yaw 3°, offset (0, -0.13, -0.12)). First-person weapons render through `Head/Camera3D/ViewmodelRoot` at a fixed 55° viewmodel FOV; tune hip poses with that in mind.
- Colour or emission effects the code used to set on the old materials (hit flash, class colour, glow): reapply them to the model's `StandardMaterial3D`. Find it with `find_children("*", "MeshInstance3D")` and `get_active_material(0)`. Hit flash already works, because it scales `MeshRoot`.
- Done-when: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit` prints no `SCRIPT ERROR` or `Parse Error`, and the user checks it in-game.

## Tier 3 recipe (rigged): proven on the Blood Ghoul

Scripts are in `D:\AI\BloodGhoul_work\scripts`. Run with `blender -b --python X.py -- args`.
1. `clean.py`: weld, cut stray geometry (e.g. blood strands), recolour bad texture areas.
2. `rig.py`: joint guesses from **grid renders** (`closeup.py`), each snapped to the limb's cross-section centroid, then an armature with auto-weights. Bone names must match what the game code drives.
3. Optional: `merge_head.py` swaps in a separately generated high-detail head.
4. `export.py`: adds claw-tip leaf bones, scales, turns the model to face −Z, puts the feet at 0, validates all meshes, exports glb.
5. Godot: keep the old procedural joints as **invisible drivers**. Each frame, copy their MeshRoot-space rotation deltas onto the matching bones; see `_retarget_skeleton()` in `scripts/enemies/blood_ghoul.gd`, which includes leg IK. This leaves the gameplay and animation code untouched.
6. Visual test: `tools/asset_pipeline/ghoul_pose_harness.gd` forces each animation state and saves screenshots, and prints `ARM <shot> <L|R> upper=… fore=… roll=…` (degrees between each arm bone and its driver joint's −Y, should be ~0; roll = elbow-hinge twist from the body's left-right axis, natural within ~±55°; `back` / `across` = upper arm behind the shoulder / across the chest in torso space, pin limits 25° / 45°; `elbow=(x,z,twist)` / `wrist=(x,z,twist)` = bone-local swing-twist from rest, must stay inside `JOINT_LIMITS`). Copy and adapt it for other creatures.

## Lessons (don't relearn these)

- **Images must look 3D** (render or sculpt style, soft shadows). Inked or flat 2D drawings, or tight crops with straight cut edges, generate as **flat cards**.
- One object per image: centred, fully in frame, plain light-grey background, even lighting, no ground shadow, no text. Creatures in a neutral A-pose with limbs apart from the body.
- Detail scales with the share of the image an object fills. A face in a full-body shot is about 60 px and comes out a blob. For a hero face, generate a separate bust (Blood Ghoul head).
- Multi-view (front + back) only works when both images come from the same Gemini chat and line up. A misaligned back image wrecks the shape.
- Hunyuan paints only what the images show. Hidden areas (the back, between legs) come out dark. Recolour them in Blender if they're visible.
- Glow baked into the texture isn't emission. `prep_prop.py` extracts it; check `emission_px` in the `PREP` line.
- Thin dripping things (blood strands, hair) become solid geometry. Prompt them away, or cut them in Blender.
- Godot glb import: on Windows, a headless `--import` sometimes logs "invalid UID" warnings for extracted textures. Re-running the import clears them.
- Python venv pins: `transformers==4.48.3`, `diffusers==0.32.2`, torch 2.7.1+cu128. Newer `transformers` breaks weight loading.
- Real-gun words in a prompt (bullpup, rail, holographic sight, magazine) make Gemini draw a real-world gun. Describe sci-fi parts instead and say it must not look like a real firearm.
- If Gemini's image has ink outlines, reply asking for the same design as a photo of a physical 3D model with no outlines; check the edges before generating.
- `make_asset.ps1` must run native tools with `$ErrorActionPreference = "Continue"`: under Windows PowerShell 5.1, `2>&1` with `Stop` aborts on the first stderr log line.

## Budgets

Many enemies can be on screen at once (Fever S: 80), so keep swarm units at 2–5k triangles with 512 px textures. Bosses can go to 40–60k with 2048 px textures. Per-asset numbers are in the manifest.

## Known issues / next tasks

- The old procedural Ghoul meshes are still in `blood_ghoul.tscn` (hidden). Deleting them shrinks the scene but needs rewiring of `skin_mat`, `ClawL00` (drip material) and the `PupilL` references.
