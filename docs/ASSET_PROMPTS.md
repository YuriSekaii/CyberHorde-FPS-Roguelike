# Gemini Concept Prompts (for Hunyuan3D-2)

How to use this, in Gemini (Nano Banana Pro):
1. Open a **new chat per group** (A, B, C below) and send that group's **style primer** first.
2. Then send one asset prompt per message in the same chat, so the style stays consistent.
3. Save each image as `Reference/AssetGen/<name>.png`, using the exact name in the heading.
4. Optional back view: reply *"Same exact object, same pose, viewed from directly behind, same background and lighting."* and save it as `<name>_back.png`. Use this only for creatures whose back you'll see.
5. Run `tools\asset_pipeline\batch.ps1`. See [`ASSET_PIPELINE.md`](ASSET_PIPELINE.md).

If an image comes out drawn or inked, reply: *"Make it look like a photo of a physical 3D game model/sculpture: real volume, soft shadows, no outlines."*

---

## A. Stage 1 — Cyber arena (day). Robots, weapons, pickups, arena props

**Style primer A** (send first):
```
For every image I ask for in this chat, follow these rules exactly:
- Show ONE object only, as a high-quality 3D game asset render (like a product shot of a physical model), NOT a drawing: real volume, soft studio lighting with gentle shadows, no ink outlines, no cel shading.
- The object is centered, fully inside the frame with a margin, on a plain flat light-grey background. No floor, no cast shadow on the ground, no text, no logos, no extra props.
- Art style: stylized-realistic sci-fi cyberpunk. Hard-surface armor panels in matte dark gunmetal and graphite, clean panel lines, with glowing neon accents (energy lines, cores, eyes, vents). Readable silhouette from far away, chunky proportions, few tiny details.
- Robots and creatures: front view, symmetrical, neutral standing pose with limbs clearly separated from the body.
- Weapons: side profile, barrel pointing right, slightly tilted toward the camera so the top is also visible.
- Small props: three-quarter view from slightly above.
Reply "ready".
```

### pulse_carbine
```
Pulse Carbine: a sleek high-velocity automatic kinetic rifle for a first-person shooter. Compact bullpup body, long slim barrel with cooling rings, top rail with a small holographic sight, curved magazine. Gunmetal with glowing cyan energy lines along the barrel and a cyan ammo counter strip.
```
### scatter_cannon
```
Scatter Cannon: a heavy close-quarters energy shotgun. Short wide body, three stacked thick barrels, pump grip, chunky shell drum. Gunmetal with glowing orange-amber vents around the muzzle and along the sides.
```
### plasma_core
```
Plasma Core: a charge-up plasma launcher. Bulky body with a big exposed glowing spherical energy core in the middle held by clamps, wide flared emitter muzzle, capacitor coils. Gunmetal with an intense violet-magenta glowing core and violet coil lights.
```
### nanite_xp_crystal
```
Nanite XP Crystal: a floating cluster of three sharp hexagonal energy crystals fused at the base, translucent-looking cyan-to-green, bright glowing inner core, small metal ring clamp around the base.
```
### medical_stim
```
Medical Stim: a small chunky auto-injector canister, metal end caps, a thick glass middle tube filled with glowing red fluid, a white medical cross panel on the side.
```
### scrap_currency
```
Scrap Currency: a small stack of three rough-cut chunky gold metal coins/plates bolted together with a glowing gold data chip on top, slightly scuffed.
```
### loot_cache
```
Loot Cache: a floating sci-fi supply crate, wide and rugged, armored lid with a glowing cyan seam all around, side handles, small hover thruster pads underneath with soft cyan glow, a holographic emblem panel on the front.
```
### jump_pad
```
Jump Pad: a round flat launch pad platform 3 meters wide, thick metal ring frame with bolts, a recessed center plate with concentric glowing cyan rings and an upward arrow chevron pattern. Seen from three-quarter above.
```
### cover_wall_low
```
Low Cover Wall: a waist-high armored barrier block, wide and thick, angled top edge, reinforced corners, a glowing cyan trim strip along the top edge. Matte slate grey.
```
### cover_barricade
```
Tall Barricade: a tall armored defensive barricade panel, thick heavy slab with buttress supports on the back, angled armor plates, a glowing cyan trim strip along the edges. Matte slate grey.
```
### arena_pillar
```
Arena Pillar: a tall square sci-fi pillar, thick base and capital, recessed vertical panel grooves, thin glowing cyan light strips running up the corners. Matte slate grey. Full height visible.
```
### assault_drone
```
Assault Drone: a small hovering combat drone the size of a basketball, rounded armored shell, one central glowing cyan eye lens, two short side gun pods, four small downward thruster vents glowing cyan. Friendly look.
```
### photon_hornet
```
Photon Hornet: a hostile flying robot wasp, slim segmented armored body, four thin glowing magenta energy wings spread wide, a long stinger-like laser emitter under the abdomen, two glowing magenta eyes.
```
### cyber_spawnling
```
Cyber Spawnling: a small vicious drilling robot, cone-shaped spinning drill head in front, compact armored body, six short spiky legs, glowing red-orange eyes and vents. Menacing despite its small size.
```
### void_spawner
```
Void Spawner: a large flying alien-tech carrier pod, heavy armored oval hull, a big glowing purple portal hatch on its underside, four downward stabilizer fins, rows of small purple lights along the hull.
```
### volt_bomber
```
Volt Bomber: a fast suicide robot, small runner on two thin legs carrying an oversized round explosive battery on its back, the battery crackling with glowing yellow electric arcs, warning stripes on the casing.
```
### cyber_swarmer
```
Cyber Swarmer: a fast four-legged robot hound the size of a large dog, lean armored body, oversized jaw with metal fangs, glowing red eyes and red energy lines along the spine. Standing neutral, all four legs straight and separated.
```
### plasma_spitter
```
Plasma Spitter: a squat robot artillery creature on four sturdy legs, a big bulbous glowing green plasma sac on its back, a wide tube-like mouth cannon in front, armored head plate, glowing green vents.
```
### armored_goliath
```
Armored Goliath: a huge hulking heavy brute robot, very wide shoulders, massive armored fists the size of its torso, short thick legs, small head sunk into the chest, glowing orange core in the chest and orange vents on the forearms. Neutral standing pose, arms slightly away from the body.
```
### cyber_charger
```
Cyber Charger: a heavy four-legged robot rhino, long armored body built for ramming, a huge reinforced battering-ram horn plate on the head, thick legs, glowing red vents along the flanks. Standing neutral, legs straight.
```
### apex_overlord
```
Apex Overlord: the final boss, a towering armored cyber-titan, crowned angular helmet with a glowing white-red visor, massive layered shoulder armor, long arms ending in plasma cannon gauntlets, folded mechanical angel wings made of blade-like metal feathers on its back (folded closed), glowing red energy veins across the armor. Neutral standing pose, arms slightly away from the body. Epic and intimidating.
```
### operative_avatar
```
Operative: a player soldier in a sleek full-body cyber combat suit, armored helmet with a glowing visor, chest rig, backpack power unit, NEON MINT glowing accent lines on the suit (the accent color will be recolored per class), no weapon in hands. Neutral A-pose, arms angled away from the body.
```

---

## B. Stage 2 — Nightfall jungle (night horror). Creatures and plants

**Style primer B** (send first):
```
For every image I ask for in this chat, follow these rules exactly:
- Show ONE creature or object only, as a high-quality 3D game asset render (like a photo of a physical sculpted model), NOT a drawing: real volume, soft studio lighting with gentle shadows, no ink outlines.
- Centered, fully inside the frame with a margin, plain flat light-grey background, no floor, no ground shadow, no text.
- Art style: dark fantasy jungle horror, stylized-realistic. Dark desaturated organic textures (black, deep green, bruise purple, dried brown) with small glowing accents (red or toxic green eyes, sacs, spores). Readable silhouette, few tiny details, no thin dangling strands or hair.
- Creatures: front view, symmetrical, neutral standing pose with limbs clearly separated from the body.
- Plants and props: three-quarter view.
Reply "ready".
```

### shadow_spider
```
Shadow Spider: a large jungle spider the size of a big dog, pitch-black chitin body with a faint oily sheen, eight long jointed legs spread out evenly, small cluster of glowing red eyes, big curved fangs. Front view, legs fully visible and separated.
```
### venom_wyvern
```
Venom Wyvern: a small flying jungle wyvern, lean reptile body with dark green scales, two leathery wings spread wide open, long tail, a throat sac glowing toxic green, glowing green eyes, venom dripping fangs kept short. Front view, wings fully spread.
```
### mantis_stalker
```
Mantis Stalker: a tall brown void-mantis, thin upright segmented body, two huge serrated scythe forearms held slightly forward and apart, small triangular head with two large glowing purple-black eyes, thin legs. Neutral standing pose, scythes clearly separated from the body.
```
### spore_pit
```
Spore Pit: a giant rooted fungal mortar plant, a thick bulbous base sunk into twisted roots, a tall wide trumpet-shaped mouth on top filled with glowing toxic-green spores, pulsing green veins over a dark purple-brown fleshy skin, small spore pods around the rim. Three-quarter view.
```
### jungle_tree_a
```
Jungle Tree: a tall dark tropical jungle tree, thick straight trunk with buttress roots at the base, dark mossy bark, a wide dense canopy of large dark-green leaves at the top only. Full tree visible from roots to crown, three-quarter view.
```
### jungle_tree_b
```
Jungle Tree (variant): a tall twisted jungle tree, trunk wrapped by thick vines, gnarled roots, slightly leaning, a dense umbrella-shaped canopy of dark leaves. Full tree visible from roots to crown, three-quarter view.
```

Not in this list on purpose: **Bog Slime** (a translucent ooze works better as a shader) and **Blood Ghoul** (already done: `Reference/BloodGhoul/`).

---

## C. Redo an existing asset

Send in the chat that made it: *"Same exact design, but <change>. Same view, background and lighting."* Save over the old `<name>.png`, delete `D:\AI\gen\<name>\raw.glb`, and rerun the batch with `-Only <name> -Force`.
