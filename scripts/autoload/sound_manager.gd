extends Node

## Procedural Sound Manager
## Generates clean 16-bit PCM audio effects at runtime with zero external dependencies.

var sounds: Dictionary = {}
var sfx_pool: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS: int = 24

var master_volume: float = 0.8
var sfx_volume: float = 0.8

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_sfx_pool()
	_generate_all_sounds()
	set_master_volume(0.8)
	set_sfx_volume(0.8)

func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	if master_volume <= 0.01:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)
		AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)

func _init_sfx_pool() -> void:
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		sfx_pool.append(player)

func play(sound_name: String, pitch_range: float = 0.05, volume_db: float = 0.0) -> void:
	if not sounds.has(sound_name) or sfx_volume <= 0.01:
		return
	var target_player: AudioStreamPlayer = null
	for p in sfx_pool:
		if not p.playing:
			target_player = p
			break
	if target_player == null:
		target_player = sfx_pool[0]
	
	target_player.stream = sounds[sound_name]
	var pitch = 1.0 + (randf() * 2.0 - 1.0) * pitch_range
	target_player.pitch_scale = maxf(0.1, pitch)
	target_player.volume_db = volume_db + linear_to_db(sfx_volume)
	target_player.play()

func play_pitch(sound_name: String, pitch: float, volume_db: float = 0.0) -> void:
	if not sounds.has(sound_name) or sfx_volume <= 0.01:
		return
	var target_player: AudioStreamPlayer = null
	for p in sfx_pool:
		if not p.playing:
			target_player = p
			break
	if target_player == null:
		target_player = sfx_pool[0]
	
	target_player.stream = sounds[sound_name]
	target_player.pitch_scale = maxf(0.1, pitch)
	target_player.volume_db = volume_db + linear_to_db(sfx_volume)
	target_player.play()

# ----------------- SOUND SYNTHESIS -----------------

func _create_wav(duration: float, gen_func: Callable, sample_rate: int = 22050) -> AudioStreamWAV:
	var num_samples = int(duration * sample_rate)
	var byte_array = PackedByteArray()
	byte_array.resize(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / float(sample_rate)
		var val: float = clampf(gen_func.call(t, duration), -1.0, 1.0)
		var int_val: int = int(val * 32767.0)
		var u_val: int = int_val if int_val >= 0 else 65536 + int_val
		byte_array[i * 2] = u_val & 0xFF
		byte_array[i * 2 + 1] = (u_val >> 8) & 0xFF
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = byte_array
	return wav

func _generate_all_sounds() -> void:
	# 1. Rifle shot (punchy snap + fast decay)
	sounds["shoot_rifle"] = _create_wav(0.12, func(t, d):
		var env = exp(-t * 28.0)
		var freq = 550.0 * exp(-t * 18.0)
		var tone = sin(TAU * freq * t)
		var noise = (randf() * 2.0 - 1.0)
		return (tone * 0.5 + noise * 0.5) * env
	)
	
	# 2. Shotgun blast (deep boom + heavy spread)
	sounds["shoot_shotgun"] = _create_wav(0.24, func(t, d):
		var env = exp(-t * 15.0)
		var freq = 160.0 * exp(-t * 12.0)
		var bass = sin(TAU * freq * t)
		var noise = (randf() * 2.0 - 1.0)
		return (bass * 0.6 + noise * 0.7) * env
	)
	
	# 3. Plasma blast (heavy sub-bass concussive blast + energy sweep)
	sounds["shoot_plasma"] = _create_wav(0.26, func(t, d):
		var env = exp(-t * 14.0)
		var freq = 1400.0 * (1.0 - (t / d) * 0.85)
		var tone = sin(TAU * freq * t + sin(t * 70.0) * 0.5)
		var sub_bass = sin(TAU * (90.0 * exp(-t * 8.0)) * t) * exp(-t * 9.0) * 0.65
		return (tone * 0.7 + sub_bass) * env * 0.85
	)
	
	# 3b. Plasma charge windup (rising energy coil chirp)
	sounds["plasma_charge"] = _create_wav(0.22, func(t, d):
		var p = t / d
		var freq = 220.0 + (p * p * 1250.0)
		var env = clampf(t * 15.0, 0.0, 1.0) * (0.5 + p * 0.5)
		var tone = sin(TAU * freq * t + sin(t * 60.0) * 0.4)
		var buzz = (randf() * 2.0 - 1.0) * 0.08 * p
		return (tone * 0.7 + buzz) * env * 0.75
	)
	
	# 4. Hitmarker (high crisp tick)
	sounds["hitmarker"] = _create_wav(0.035, func(t, d):
		var env = exp(-t * 110.0)
		return sin(TAU * 2200.0 * t) * env * 0.7
	)
	
	# 5. Critical hitmarker (bell strike)
	sounds["crit_hit"] = _create_wav(0.06, func(t, d):
		var env = exp(-t * 60.0)
		var tone = (sin(TAU * 2600.0 * t) + sin(TAU * 3400.0 * t)) * 0.5
		return tone * env * 0.9
	)
	
	# 6. Enemy hurt (thud + crunch)
	sounds["enemy_hit"] = _create_wav(0.09, func(t, d):
		var env = exp(-t * 40.0)
		var noise = (randf() * 2.0 - 1.0)
		var thud = sin(TAU * 120.0 * exp(-t * 20.0) * t)
		return (noise * 0.5 + thud * 0.5) * env * 0.7
	)
	
	# 6b. Flesh tearing (Blood Ghoul claw: sharp swipe, crackling fibrous rip, wet squelch)
	var tear_lp = [0.0, 0.0] # One-pole filter states (captured by reference)
	sounds["flesh_tear"] = _create_wav(0.4, func(t, d):
		var n = randf() * 2.0 - 1.0
		tear_lp[0] = lerpf(tear_lp[0], n, 0.12) # Muffled, wet body
		tear_lp[1] = lerpf(tear_lp[1], n, 0.5) # Fibrous crackle
		var swipe = (n - tear_lp[1]) * exp(-t * 55.0) * 0.9
		var rip_rate = lerpf(46.0, 13.0, t / d)
		var rip = pow(absf(sin(TAU * rip_rate * t + sin(t * 37.0) * 2.0)), 6.0)
		var tear = tear_lp[1] * rip * smoothstep(0.015, 0.05, t) * exp(-t * 6.5) * 1.8
		var squelch = tear_lp[0] * exp(-t * 8.0) * 1.6 + sin(TAU * 80.0 * exp(-t * 5.0) * t) * exp(-t * 14.0) * 0.45
		return (swipe + tear + squelch) * 0.95
	)
	
	# 7. Enemy die / explosion (deep rumble + noise crackle)
	sounds["enemy_die"] = _create_wav(0.35, func(t, d):
		var env = exp(-t * 10.0)
		var freq = 90.0 * exp(-t * 6.0)
		var sub = sin(TAU * freq * t)
		var noise = (randf() * 2.0 - 1.0) * (0.8 if t < 0.08 else 0.4)
		return (sub * 0.5 + noise * 0.6) * env
	)
	
	# 8. Explosion AoE
	sounds["explosion"] = _create_wav(0.45, func(t, d):
		var env = exp(-t * 8.0)
		var freq = 140.0 * exp(-t * 9.0)
		var sub = sin(TAU * freq * t)
		var noise = (randf() * 2.0 - 1.0)
		return (sub * 0.7 + noise * 0.8) * env * (1.0 / 3.0)
	)
	
	# 9. Player hurt (alarm pulse)
	sounds["player_hurt"] = _create_wav(0.20, func(t, d):
		var env = exp(-t * 15.0)
		var tone = sin(TAU * 220.0 * t) + sin(TAU * 180.0 * t)
		return tone * 0.6 * env
	)
	
	# 10. Shield hit
	sounds["shield_hit"] = _create_wav(0.12, func(t, d):
		var env = exp(-t * 25.0)
		var tone = sin(TAU * 880.0 * (1.0 - t * 4.0) * t)
		return tone * 0.5 * env
	)
	
	# 11. XP Gem pickup (crystal chime)
	sounds["pickup_xp"] = _create_wav(0.09, func(t, d):
		var env = exp(-t * 30.0)
		return sin(TAU * 1320.0 * t) * env * 0.6
	)
	
	# 12. Health / buff pickup
	sounds["pickup_health"] = _create_wav(0.25, func(t, d):
		var env = exp(-t * 12.0)
		var note = 523.25 if t < 0.1 else 659.25
		return sin(TAU * note * t) * env * 0.7
	)
	
	# 13. Level up fanfare (triumphant chords)
	sounds["level_up"] = _create_wav(0.65, func(t, d):
		var env = exp(-t * 4.0)
		var note = 523.25
		if t > 0.15: note = 659.25
		if t > 0.30: note = 783.99
		if t > 0.45: note = 1046.50
		return sin(TAU * note * t) * env * 0.8
	)
	
	# 14. Upgrade card select
	sounds["upgrade_select"] = _create_wav(0.15, func(t, d):
		var env = exp(-t * 20.0)
		var freq = 800.0 + (t / d) * 600.0
		return sin(TAU * freq * t) * env * 0.7
	)
	
	# 15. Jump pad whoosh
	sounds["jump_pad"] = _create_wav(0.30, func(t, d):
		var env = sin(PI * (t / d))
		var freq = 200.0 + (t / d) * 700.0
		return sin(TAU * freq * t) * env * 0.7
	)
	
	# 16. Reload click
	sounds["reload"] = _create_wav(0.15, func(t, d):
		var env = exp(-fmod(t, 0.075) * 60.0)
		return (randf() * 2.0 - 1.0) * env * 0.5
	)
	
	# 17. Empty click
	sounds["empty_ammo"] = _create_wav(0.05, func(t, d):
		var env = exp(-t * 80.0)
		return sin(TAU * 900.0 * t) * env * 0.4
	)

	# 18. Chest open
	sounds["chest_open"] = _create_wav(0.35, func(t, d):
		var env = exp(-t * 9.0)
		var note = 440.0 + (t / d) * 660.0
		var harmonic = sin(TAU * note * t) + 0.5 * sin(TAU * note * 2.0 * t)
		return harmonic * env * 0.7
	)
	
	# 19. Spawn telegraph (subtle cyber warning ping)
	sounds["spawn_telegraph"] = _create_wav(0.28, func(t, d):
		var env = exp(-t * 9.0)
		var freq = 680.0 + sin(TAU * 14.0 * t) * 70.0
		var tone = sin(TAU * freq * t)
		return tone * env * 0.35
	)
	
	# 20. Spawn emerge (cyber warp materialization burst)
	sounds["spawn_emerge"] = _create_wav(0.22, func(t, d):
		var env = exp(-t * 12.0)
		var freq = 720.0 * exp(-t * 13.0) + 120.0
		var tone = sin(TAU * freq * t)
		var noise = (randf() * 2.0 - 1.0) * 0.35
		return (tone * 0.6 + noise * 0.4) * env * 0.55
	)
	
	# 21. Charger windup (heavy revving mechanical bull turbine)
	sounds["charger_windup"] = _create_wav(0.75, func(t, d):
		var p = t / d
		var freq = 90.0 + (p * p * 380.0)
		var sub = sin(TAU * freq * t + sin(t * 80.0) * 0.4)
		var rumble = (randf() * 2.0 - 1.0) * 0.25 * (1.0 + p)
		var env = clampf(t * 8.0, 0.0, 1.0) * (0.4 + p * 0.6)
		return (sub * 0.75 + rumble) * env * 0.8
	)
	
	# 22. Charger crash (violent metallic collision impact)
	sounds["charger_crash"] = _create_wav(0.50, func(t, d):
		var env = exp(-t * 7.5)
		var bass = sin(TAU * (85.0 * exp(-t * 9.0)) * t) * 0.8
		var clang = sin(TAU * 740.0 * exp(-t * 15.0) * t) * 0.4
		var crunch = (randf() * 2.0 - 1.0) * exp(-t * 12.0) * 0.9
		return (bass + clang + crunch) * env * 0.85
	)
	
	# 23. Spawnling drill (continuous high-speed serrated buzz saw)
	sounds["spawnling_drill"] = _create_wav(0.18, func(t, d):
		var env = exp(-t * 14.0)
		var f = 880.0 + sin(TAU * 45.0 * t) * 220.0
		var wave = sin(TAU * f * t)
		var rasp = (randf() * 2.0 - 1.0) * 0.45
		return (wave * 0.6 + rasp) * env * 0.65
	)
	
	# 24. Spawner portal (ethereal deep cosmic warp pulse)
	sounds["spawner_portal"] = _create_wav(0.40, func(t, d):
		var env = sin(PI * (t / d))
		var sweep = 180.0 + sin(TAU * 5.0 * t) * 60.0 + (t / d) * 320.0
		var tone = sin(TAU * sweep * t)
		var harmonic = sin(TAU * (sweep * 1.5) * t) * 0.4
		return (tone + harmonic) * env * 0.7
	)
	
	# 25. Upgrade card reroll (cybernetic electronic shimmer shuffle)
	sounds["reroll"] = _create_wav(0.22, func(t, d):
		var env = exp(-t * 9.0)
		var sweep = 350.0 + (t / d) * 750.0 + sin(TAU * 40.0 * t) * 60.0
		var tone = sin(TAU * sweep * t)
		var sparkle = sin(TAU * sweep * 2.0 * t) * 0.35
		var glitch = (randf() * 2.0 - 1.0) * exp(-t * 25.0) * 0.3
		return (tone * 0.65 + sparkle + glitch) * env * 0.8
	)
	
	# 26. Dash / Quantum Warp whoosh
	sounds["dash"] = _create_wav(0.24, func(t, d):
		var env = exp(-t * 12.0)
		var freq = 320.0 + (1.0 - (t / d)) * 1100.0
		var tone = sin(TAU * freq * t + sin(t * 80.0) * 0.3)
		var whoosh = (randf() * 2.0 - 1.0) * 0.5 * exp(-t * 8.0)
		return (tone * 0.6 + whoosh) * env * 0.85
	)
