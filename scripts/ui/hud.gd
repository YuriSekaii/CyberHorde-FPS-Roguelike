extends CanvasLayer

@onready var crosshair: Control = $Crosshair
@onready var hitmarker: Control = $Hitmarker
@onready var health_bar: ProgressBar = $BottomLeft/HealthBar
@onready var health_label: Label = $BottomLeft/HealthBar/HealthLabel
@onready var shield_bar: ProgressBar = $BottomLeft/ShieldBar
@onready var shield_label: Label = $BottomLeft/ShieldBar/ShieldLabel
@onready var ammo_label: Label = $BottomRight/AmmoContainer/AmmoLabel
@onready var reload_label: Label = $BottomRight/AmmoContainer/ReloadLabel
@onready var weapon_label: Label = $BottomRight/WeaponLabel
@onready var wave_label: Label = $TopCenter/WaveLabel
@onready var enemies_label: Label = $TopCenter/EnemiesLabel
@onready var intermission_label: Label = $TopCenter/IntermissionLabel
@onready var xp_bar: ProgressBar = $TopCenter/XPBar
@onready var level_label: Label = $TopCenter/XPBar/LevelLabel
@onready var scrap_label: Label = $TopRight/ScrapLabel
@onready var boss_container: VBoxContainer = $BossContainer
@onready var boss_name_label: Label = $BossContainer/BossNameLabel
@onready var boss_bar: ProgressBar = $BossContainer/BossBar
@onready var boss_hp_label: Label = $BossContainer/BossBar/BossHPLabel
@onready var fever_panel: Control = get_node_or_null("FeverPanel")
@onready var fever_letter = get_node_or_null("FeverPanel/FeverLetter")
@onready var fever_bonus_label: Label = get_node_or_null("FeverPanel/FeverInfo/FeverBonusLabel")
@onready var fever_timer_label: Label = get_node_or_null("FeverPanel/FeverInfo/FeverTimerLabel")
@onready var fever_promote_label: Label = get_node_or_null("FeverPanel/FeverPromoteLabel")
@onready var null_barrier_label: Label = get_node_or_null("BottomLeft/NullBarrierLabel")
@onready var dash_label: Label = get_node_or_null("BottomLeft/DashLabel")
@onready var skill_container: Control = get_node_or_null("BottomLeft/SkillContainer")
@onready var skill_icon: TextureRect = get_node_or_null("BottomLeft/SkillContainer/IconFrame/SkillIcon")
@onready var skill_icon_border: Panel = get_node_or_null("BottomLeft/SkillContainer/IconFrame/IconBorder")
@onready var skill_cooldown_label: Label = get_node_or_null("BottomLeft/SkillContainer/IconFrame/CooldownLabel")
@onready var skill_name_label: Label = get_node_or_null("BottomLeft/SkillContainer/SkillDetails/SkillNameLabel")
@onready var skill_status_label: Label = get_node_or_null("BottomLeft/SkillContainer/SkillDetails/SkillStatusLabel")

const ICON_MEDIC = preload("res://assets/icons/skills/medic_restore.svg")
const ICON_ROGUE = preload("res://assets/icons/skills/rogue_dash.svg")
const ICON_GUNNER = preload("res://assets/icons/skills/gunner_berserk.svg")

const FEVER_COLORS: Dictionary = {
	"D": Color(0.65, 0.65, 0.65),
	"C": Color(0.2, 0.85, 1.0),
	"B": Color(0.25, 1.0, 0.45),
	"A": Color(1.0, 0.65, 0.15),
	"S": Color(1.0, 0.15, 0.55)
}

const FEVER_BONUS_TEXTS: Dictionary = {
	"D": "NO BONUS",
	"C": "+25% XP/SCRAP/SPAWNS",
	"B": "+50% XP/SCRAP/SPAWNS",
	"A": "+75% XP/SCRAP/SPAWNS",
	"S": "★ +100% XP/SCRAP/SPAWNS ★"
}

# Quick fade text shown on promotion, describing what the new tier grants
const FEVER_PROMOTE_TEXTS: Dictionary = {
	"C": "FEVER C!\n+25% XP & SCRAP · +25% SPAWNS\nENEMY CAP 50 · RARER PERKS",
	"B": "FEVER B!\n+50% XP & SCRAP · +50% SPAWNS\nENEMY CAP 60 · RARER PERKS",
	"A": "FEVER A!\n+75% XP & SCRAP · +75% SPAWNS\nENEMY CAP 70 · RARER PERKS",
	"S": "★ FEVER S — MAX! ★\n+100% XP & SCRAP · 2× SPAWNS\nENEMY CAP 80 · RAREST PERKS"
}

var fever_promote_tween: Tween = null

var current_displayed_class: String = ""
var skill_pulse_timer: float = 0.0
var class_label: Label = null

var local_player: Node = null
var fps_label: Label = null
var fps_update_timer: float = 0.0
var hitmarker_timer: float = 0.0
# Boss HP arrives once per hit (thousands/s under Berserk); the bar is redrawn at most once per frame
var _boss_hp_dirty: bool = false
var _boss_hp_cur: float = 0.0
var _boss_hp_max: float = 1.0

# Stage 2 status overlay (built in code)
var status_tint: ColorRect = null
var trap_panel: VBoxContainer = null
var trap_label: Label = null
var trap_bar: ProgressBar = null
var status_effects_label: Label = null
var stage_banner: Label = null
var stage_banner_tween: Tween = null
var status_pulse: float = 0.0

func _ready() -> void:
	hitmarker.visible = false
	reload_label.visible = false
	intermission_label.visible = false
	boss_container.visible = false
	
	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_up.connect(_on_level_up)
	GameManager.scrap_changed.connect(_on_scrap_changed)
	GameManager.hitmarker_triggered.connect(_on_hitmarker)
	GameManager.wave_started.connect(_on_wave_started)
	GameManager.boss_spawned.connect(_on_boss_spawned)
	GameManager.boss_health_updated.connect(_on_boss_health_updated)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	GameManager.fever_updated.connect(_on_fever_updated)
	GameManager.fever_tier_promoted.connect(_on_fever_tier_promoted)
	GameManager.fever_tier_demoted.connect(_on_fever_tier_demoted)
	GameManager.stage_changed.connect(_on_stage_changed)
	GameManager.progression_reset.connect(_on_progression_reset)
	_build_stage_ui()
	
	_update_fever_display(GameManager.get_fever_tier_name(), GameManager.fever_tier_index, GameManager.fever_duration, GameManager.FEVER_MAX_DURATION)
	
	_update_xp_display(GameManager.player_xp, GameManager.xp_to_next_level)
	_update_level_display(GameManager.player_level)
	_update_scrap_display(GameManager.scrap)
	
	if skill_icon and skill_icon.material:
		skill_icon.material = skill_icon.material.duplicate()
	_update_skill_display_class(GameManager.player_class)
	
	var bottom_left = get_node_or_null("BottomLeft")
	if bottom_left:
		class_label = Label.new()
		class_label.name = "ClassLabel"
		class_label.set("theme_override_font_sizes/font_size", 13)
		class_label.text = "[CLASS: %s]" % GameManager.player_class.to_upper()
		bottom_left.add_child(class_label)
		bottom_left.move_child(class_label, 0)
	
	# F3 FPS counter
	fps_label = Label.new()
	fps_label.name = "FpsLabel"
	fps_label.position = Vector2(12, 8)
	fps_label.set("theme_override_font_sizes/font_size", 14)
	fps_label.modulate = Color(0.4, 1.0, 0.6)
	fps_label.visible = false
	add_child(fps_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3 or event.physical_keycode == KEY_F3:
			fps_label.visible = not fps_label.visible
			fps_update_timer = 0.0
			RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), fps_label.visible)
			get_viewport().set_input_as_handled()

func connect_player(player: Node) -> void:
	local_player = player
	if is_instance_valid(player):
		var p_cls_val = player.get("player_class")
		if p_cls_val != null:
			_update_skill_display_class(String(p_cls_val))
	if class_label and is_instance_valid(player):
		var p_cls_val = player.get("player_class")
		var c_name = String(p_cls_val if p_cls_val != null else "medic").to_upper()
		class_label.text = "[CLASS: %s]" % c_name
		if c_name == "MEDIC":
			class_label.modulate = Color(0.2, 1.0, 0.7)
		elif c_name == "ROGUE":
			class_label.modulate = Color(1.0, 0.85, 0.2)
		elif c_name == "GUNNER" or c_name == "SLAYER":
			class_label.modulate = Color(1.0, 0.3, 0.35)
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if player.has_signal("shield_changed"):
		player.shield_changed.connect(_on_shield_changed)
	if player.has_signal("ammo_changed"):
		player.ammo_changed.connect(_on_ammo_changed)
	if player.has_signal("weapon_changed"):
		player.weapon_changed.connect(_on_weapon_changed)
	if player.has_signal("charge_changed"):
		player.charge_changed.connect(_on_charge_changed)
	
	if "current_health" in player and "max_health" in player:
		_on_health_changed(player.current_health, player.max_health)
	if "current_shield" in player:
		_on_shield_changed(player.current_shield, GameManager.shield_max)
	if "weapons" in player and "active_weapon_idx" in player:
		if player.weapons.size() > player.active_weapon_idx:
			var cur_w = player.weapons[player.active_weapon_idx]
			_on_weapon_changed(player.active_weapon_idx, cur_w.name)
			_on_ammo_changed(cur_w.current_ammo, cur_w.max_ammo, player.is_reloading)

func connect_spawner(spawner: Node) -> void:
	if spawner.has_signal("wave_progress"):
		spawner.wave_progress.connect(_on_wave_progress)
	if spawner.has_signal("intermission_tick"):
		spawner.intermission_tick.connect(_on_intermission_tick)

func _process(delta: float) -> void:
	if fps_label and fps_label.visible:
		fps_update_timer -= delta
		if fps_update_timer <= 0.0:
			fps_update_timer = 0.5
			var limit = "UNLIMITED" if Engine.max_fps == 0 else str(Engine.max_fps)
			var gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
			fps_label.text = "FPS: %d  (limit %s)  |  GPU: %.2f ms / frame" % [Engine.get_frames_per_second(), limit, gpu_ms]
	
	if _boss_hp_dirty:
		_boss_hp_dirty = false
		_refresh_boss_bar()
	
	if hitmarker.visible:
		hitmarker_timer -= delta
		if hitmarker_timer <= 0.0:
			hitmarker.visible = false
	
	if null_barrier_label:
		if GameManager.null_barrier_unlocked:
			null_barrier_label.visible = true
			if local_player and is_instance_valid(local_player):
				if local_player.get("null_barrier_ready") == true:
					null_barrier_label.text = "[NULL BARRIER: READY]"
					null_barrier_label.modulate = Color(0.3, 0.9, 1.0, 1.0)
				else:
					var timer_val = local_player.get("null_barrier_timer")
					var sec_left: float = float(timer_val) if timer_val != null else 0.0
					null_barrier_label.text = "[NULL BARRIER: %.1fs]" % sec_left
					null_barrier_label.modulate = Color(0.7, 0.7, 0.7, 0.6)
		else:
			null_barrier_label.visible = false
	
	if dash_label:
		dash_label.visible = false
	
	# Smooth live countdown update
	_update_fever_fill(GameManager.get_fever_tier_name(), GameManager.fever_duration, GameManager.FEVER_MAX_DURATION)

	skill_pulse_timer += delta
	_update_skill_hud()
	_update_status_effects(delta)

func _on_fever_updated(tier_name: String, tier_idx: int, duration: float, max_duration: float) -> void:
	_update_fever_display(tier_name, tier_idx, duration, max_duration)

func _on_fever_tier_promoted(tier_name: String, tier_idx: int) -> void:
	_update_fever_display(tier_name, tier_idx, GameManager.fever_duration, GameManager.FEVER_MAX_DURATION)
	if fever_letter:
		var tw = create_tween()
		fever_letter.scale = Vector2(1.45, 1.45)
		tw.tween_property(fever_letter, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_fever_promote_text(tier_name)

func _on_fever_tier_demoted(tier_name: String, tier_idx: int) -> void:
	_update_fever_display(tier_name, tier_idx, GameManager.fever_duration, GameManager.FEVER_MAX_DURATION)
	if fever_letter:
		var tw = create_tween()
		fever_letter.modulate = Color(1.0, 0.2, 0.2)
		tw.tween_property(fever_letter, "modulate", Color.WHITE, 0.35)

func _show_fever_promote_text(tier_name: String) -> void:
	if not fever_promote_label or not FEVER_PROMOTE_TEXTS.has(tier_name):
		return
	if fever_promote_tween and fever_promote_tween.is_valid():
		fever_promote_tween.kill()
	fever_promote_label.text = FEVER_PROMOTE_TEXTS[tier_name]
	fever_promote_label.add_theme_color_override("font_color", FEVER_COLORS.get(tier_name, Color.WHITE))
	var base_y: float = 104.0
	fever_promote_label.position.y = base_y - 10.0
	fever_promote_label.modulate.a = 0.0
	fever_promote_tween = create_tween()
	fever_promote_tween.set_parallel(true)
	fever_promote_tween.tween_property(fever_promote_label, "modulate:a", 1.0, 0.15)
	fever_promote_tween.tween_property(fever_promote_label, "position:y", base_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fever_promote_tween.chain().tween_property(fever_promote_label, "modulate:a", 0.0, 0.6).set_delay(1.8)

func _update_fever_display(tier_name: String, _tier_idx: int, duration: float, max_duration: float) -> void:
	if not fever_panel:
		return

	var col: Color = FEVER_COLORS.get(tier_name, Color.WHITE)
	if fever_bonus_label:
		fever_bonus_label.text = FEVER_BONUS_TEXTS.get(tier_name, "")
		fever_bonus_label.modulate = col if tier_name != "D" else Color(0.55, 0.55, 0.55, 0.8)

	if fever_timer_label:
		fever_timer_label.modulate = col

	_update_fever_fill(tier_name, duration, max_duration)

func _update_fever_fill(tier_name: String, duration: float, max_duration: float) -> void:
	if fever_letter:
		fever_letter.set_state(tier_name, FEVER_COLORS.get(tier_name, Color.WHITE), duration / maxf(0.01, max_duration))
	if fever_timer_label:
		if tier_name == "S" and duration >= max_duration:
			fever_timer_label.text = "MAX"
		else:
			fever_timer_label.text = "%.1fs" % maxf(0.0, duration)

func _update_skill_display_class(p_class: String) -> void:
	var c = p_class.to_lower()
	if c == current_displayed_class and skill_icon and skill_icon.texture != null:
		return
	current_displayed_class = c
	
	if not skill_container:
		return
		
	var theme_col = Color(0.2, 1.0, 0.7)
	var icon_tex = ICON_MEDIC
	var s_name = "CELLULAR RESTORE"
	
	match c:
		"medic":
			theme_col = Color(0.2, 1.0, 0.7)
			icon_tex = ICON_MEDIC
			s_name = "CELLULAR RESTORE"
		"rogue":
			theme_col = Color(1.0, 0.85, 0.2)
			icon_tex = ICON_ROGUE
			s_name = "QUANTUM DASH"
		"gunner", "slayer":
			theme_col = Color(1.0, 0.3, 0.35)
			icon_tex = ICON_GUNNER
			s_name = "BERSERK PROTOCOL"
	
	if skill_icon:
		skill_icon.texture = icon_tex
		if skill_icon.material is ShaderMaterial:
			skill_icon.material.set_shader_parameter("border_color", theme_col)
	if skill_name_label:
		skill_name_label.text = s_name
		skill_name_label.modulate = theme_col

func _update_skill_hud() -> void:
	if not skill_container:
		return
	
	var p_class = GameManager.player_class.to_lower()
	var sec_left: float = 0.0
	var max_cd: float = 10.0
	var is_ready: bool = true
	var is_active: bool = false
	var active_dur: float = 0.0
	
	if local_player and is_instance_valid(local_player):
		var p_cls_val = local_player.get("player_class")
		if p_cls_val != null:
			p_class = String(p_cls_val).to_lower()
		
		var timer_val = local_player.get("skill_cooldown_timer")
		sec_left = float(timer_val) if timer_val != null else 0.0
		is_ready = (local_player.get("skill_ready") == true) and (sec_left <= 0.0)
		
		if local_player.has_method("get_skill_max_cooldown"):
			max_cd = local_player.get_skill_max_cooldown()
		else:
			var m_cd_val = local_player.get("skill_max_cooldown")
			max_cd = float(m_cd_val) if m_cd_val != null else 10.0
		if max_cd <= 0.01:
			max_cd = 10.0
		
		match p_class:
			"medic":
				if local_player.get("is_medic_active") == true:
					is_active = true
					var dur_val = local_player.get("medic_timer")
					active_dur = float(dur_val) if dur_val != null else 0.0
			"rogue":
				if local_player.get("is_dashing") == true:
					is_active = true
					var d_dur = local_player.get("dash_timer")
					active_dur = float(d_dur) if d_dur != null else 0.15
			"gunner", "slayer":
				if local_player.get("is_gunner_active") == true or local_player.get("is_slayer_active") == true:
					is_active = true
					var dur_val = local_player.get("gunner_timer")
					if dur_val == null:
						dur_val = local_player.get("slayer_timer")
					active_dur = float(dur_val) if dur_val != null else 0.0
	
	_update_skill_display_class(p_class)
	
	var theme_col = Color(0.2, 1.0, 0.7)
	match p_class:
		"medic": theme_col = Color(0.2, 1.0, 0.7)
		"rogue": theme_col = Color(1.0, 0.85, 0.2)
		"gunner", "slayer": theme_col = Color(1.0, 0.3, 0.35)
	
	var mat = skill_icon.material as ShaderMaterial if skill_icon else null
	
	if is_active:
		if mat:
			mat.set_shader_parameter("is_active", true)
			mat.set_shader_parameter("pulse_time", skill_pulse_timer)
			mat.set_shader_parameter("progress", 1.0)
			mat.set_shader_parameter("border_color", theme_col)
		
		if skill_cooldown_label:
			skill_cooldown_label.visible = true
			skill_cooldown_label.text = "%.1fs" % maxf(0.0, active_dur)
			skill_cooldown_label.modulate = theme_col if (p_class == "medic" or p_class == "rogue") else Color(1.0, 0.35, 0.35)
		
		if skill_status_label:
			skill_status_label.text = "[ACTIVE: %.1fs]" % maxf(0.0, active_dur)
			skill_status_label.modulate = theme_col if (p_class == "medic" or p_class == "rogue") else Color(1.0, 0.35, 0.35)
		
		_set_icon_border_color(theme_col, true)
	elif is_ready:
		if mat:
			mat.set_shader_parameter("is_active", false)
			mat.set_shader_parameter("progress", 1.0)
			mat.set_shader_parameter("border_color", theme_col)
		
		if skill_cooldown_label:
			skill_cooldown_label.visible = false
			skill_cooldown_label.text = ""
		
		if skill_status_label:
			skill_status_label.text = "[READY]"
			skill_status_label.modulate = theme_col
		
		_set_icon_border_color(theme_col, false)
	else:
		# Cooldown in progress:
		# progress: 0.0 (just started, whole black) -> 1.0 (recovering color clockwise)
		var progress: float = clampf(1.0 - (sec_left / max_cd), 0.0, 1.0)
		if mat:
			mat.set_shader_parameter("is_active", false)
			mat.set_shader_parameter("progress", progress)
			mat.set_shader_parameter("border_color", theme_col)
		
		if skill_cooldown_label:
			skill_cooldown_label.visible = true
			if sec_left >= 10.0:
				skill_cooldown_label.text = "%.0fs" % sec_left
			else:
				skill_cooldown_label.text = "%.1fs" % sec_left
			skill_cooldown_label.modulate = Color(1.0, 1.0, 1.0, 0.95)
		
		if skill_status_label:
			skill_status_label.text = "[COOLDOWN: %.1fs]" % sec_left
			skill_status_label.modulate = Color(0.7, 0.7, 0.75, 0.7)
		
		_set_icon_border_color(Color(0.25, 0.28, 0.35, 0.5), false)

func _set_icon_border_color(color: Color, pulsing: bool) -> void:
	if not skill_icon_border:
		return
	var sb = skill_icon_border.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		if not skill_icon_border.has_meta("unique_style"):
			sb = sb.duplicate()
			skill_icon_border.add_theme_stylebox_override("panel", sb)
			skill_icon_border.set_meta("unique_style", true)
		if pulsing:
			var pulse_val = 0.65 + 0.35 * sin(skill_pulse_timer * 12.0)
			sb.border_color = Color(color.r, color.g, color.b, pulse_val)
		else:
			sb.border_color = color

func _on_health_changed(current: float, max_hp: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current
	health_label.text = "HP: %d / %d" % [int(current), int(max_hp)]

func _on_shield_changed(current: float, max_shield: float) -> void:
	shield_bar.visible = (max_shield > 0.0)
	shield_bar.max_value = max_shield
	shield_bar.value = current
	shield_label.text = "SHIELD: %d / %d" % [int(current), int(max_shield)]

func _on_ammo_changed(current: int, max_mag: int, is_reloading: bool) -> void:
	if local_player and is_instance_valid(local_player) and (local_player.get("is_gunner_active") == true or local_player.get("is_slayer_active") == true):
		ammo_label.text = "∞ / ∞"
		ammo_label.modulate = Color(1.0, 0.3, 0.3)
		reload_label.visible = false
		return
	ammo_label.text = "%d / %d" % [current, max_mag]
	reload_label.visible = is_reloading
	if is_reloading:
		ammo_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		ammo_label.modulate = Color.WHITE

func _on_weapon_changed(idx: int, w_name: String) -> void:
	weapon_label.text = "[%d] %s" % [idx + 1, w_name.to_upper()]
	_on_charge_changed(0.0)

func _on_charge_changed(ratio: float) -> void:
	if not crosshair:
		return
	if ratio > 0.0:
		if ratio >= 1.0:
			crosshair.modulate = Color(1.2, 0.35, 1.3, 1.0)
			crosshair.scale = Vector2(0.85, 0.85)
		else:
			crosshair.modulate = Color(1.0, 1.0 - ratio * 0.65, 1.0, 0.9)
			crosshair.scale = Vector2.ONE.lerp(Vector2(0.85, 0.85), ratio)
	else:
		crosshair.modulate = Color.WHITE
		crosshair.scale = Vector2.ONE

func _on_hitmarker(is_crit: bool) -> void:
	hitmarker.visible = true
	hitmarker_timer = 0.08
	hitmarker.modulate = Color(1.0, 0.2, 0.2) if is_crit else Color(1.0, 1.0, 1.0)
	hitmarker.scale = Vector2(1.4, 1.4) if is_crit else Vector2.ONE

func _on_wave_started(wave_num: int) -> void:
	var is_night = GameManager.current_stage >= 2
	var phase = "NIGHT" if is_night else "DAY"
	if wave_num >= 50:
		wave_label.text = "%s — WAVE 50 [%s]" % [phase, "BLOOD MOON" if is_night else "FINAL BOSS"]
		wave_label.modulate = Color(1.0, 0.25, 0.25)
		if is_night:
			_show_stage_banner("THE BLOOD MOON RISES", Color(0.85, 0.08, 0.06))
	else:
		wave_label.text = "%s — WAVE %d" % [phase, wave_num]
		wave_label.modulate = Color(0.7, 0.8, 1.0) if is_night else Color.WHITE
	intermission_label.visible = false

func _on_boss_spawned(boss_node: Node) -> void:
	boss_container.visible = true
	if boss_node and "enemy_name" in boss_node:
		boss_name_label.text = "[FINAL BOSS] %s" % boss_node.enemy_name.to_upper()
	else:
		boss_name_label.text = "[FINAL BOSS] APEX OVERLORD"

func _on_boss_health_updated(cur_hp: float, max_hp: float) -> void:
	_boss_hp_cur = cur_hp
	_boss_hp_max = max_hp
	if not boss_container.visible:
		boss_container.visible = true
		_refresh_boss_bar()
	else:
		_boss_hp_dirty = true

func _refresh_boss_bar() -> void:
	boss_bar.max_value = _boss_hp_max
	boss_bar.value = _boss_hp_cur
	var pct = (_boss_hp_cur / maxf(1.0, _boss_hp_max)) * 100.0
	boss_hp_label.text = "%d / %d (%.0f%%)" % [int(_boss_hp_cur), int(_boss_hp_max), pct]

func _on_boss_defeated() -> void:
	boss_container.visible = false

func _on_wave_progress(alive_count: int, _total: int) -> void:
	if GameManager.current_wave >= 50:
		enemies_label.text = "ENEMIES: %d (∞)" % alive_count
	else:
		enemies_label.text = "ENEMIES: %d" % alive_count

func _on_intermission_tick(sec_left: int) -> void:
	intermission_label.visible = true
	if GameManager.current_stage >= 2 and GameManager.current_wave == 1:
		intermission_label.text = "NIGHT FALLS IN: %ds" % sec_left
		intermission_label.modulate = Color(0.6, 0.7, 1.0)
	elif GameManager.is_boss_battle_mode:
		intermission_label.text = "BOSS ENGAGEMENT IN: %ds" % sec_left
		intermission_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		intermission_label.text = "NEXT WAVE IN: %ds" % sec_left
		intermission_label.modulate = Color.WHITE

func _on_xp_changed(cur_xp: int, needed_xp: int) -> void:
	_update_xp_display(cur_xp, needed_xp)

func _on_level_up(lvl: int) -> void:
	_update_level_display(lvl)

func _on_scrap_changed(new_scrap: int) -> void:
	_update_scrap_display(new_scrap)

func _update_xp_display(cur_xp: int, needed_xp: int) -> void:
	xp_bar.max_value = needed_xp
	xp_bar.value = cur_xp

func _update_level_display(lvl: int) -> void:
	level_label.text = "LVL %d" % lvl

func _update_scrap_display(amount: int) -> void:
	scrap_label.text = "SCRAP: %d" % amount

# ==============================================================================
# STAGES & STAGE 2 STATUS EFFECTS (POISON / BLEED / TRAPS)
# ==============================================================================

func _build_stage_ui() -> void:
	status_tint = ColorRect.new()
	status_tint.name = "StatusTint"
	status_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	status_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_tint.color = Color(0, 0, 0, 0)
	add_child(status_tint)
	move_child(status_tint, 0)

	trap_panel = VBoxContainer.new()
	trap_panel.name = "TrapPanel"
	trap_panel.set_anchors_preset(Control.PRESET_CENTER)
	trap_panel.offset_left = -220
	trap_panel.offset_right = 220
	trap_panel.offset_top = 70
	trap_panel.offset_bottom = 140
	trap_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	trap_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trap_panel.visible = false
	add_child(trap_panel)
	trap_label = Label.new()
	trap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trap_label.add_theme_font_size_override("font_size", 22)
	trap_label.add_theme_constant_override("outline_size", 6)
	trap_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	trap_panel.add_child(trap_label)
	trap_bar = ProgressBar.new()
	trap_bar.custom_minimum_size = Vector2(360, 14)
	trap_bar.show_percentage = false
	trap_bar.max_value = 1.0
	trap_bar.step = 0.001
	trap_panel.add_child(trap_bar)

	status_effects_label = Label.new()
	status_effects_label.name = "StatusEffectsLabel"
	status_effects_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	status_effects_label.offset_left = -260
	status_effects_label.offset_right = 260
	status_effects_label.offset_top = -150
	status_effects_label.offset_bottom = -100
	status_effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_effects_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	status_effects_label.add_theme_font_size_override("font_size", 16)
	status_effects_label.add_theme_constant_override("outline_size", 5)
	status_effects_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	status_effects_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_effects_label)

	stage_banner = Label.new()
	stage_banner.name = "StageBanner"
	stage_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stage_banner.offset_left = -500
	stage_banner.offset_right = 500
	stage_banner.offset_top = 150
	stage_banner.offset_bottom = 230
	stage_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_banner.add_theme_font_size_override("font_size", 40)
	stage_banner.add_theme_constant_override("outline_size", 10)
	stage_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	stage_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_banner.modulate.a = 0.0
	add_child(stage_banner)

func _on_progression_reset() -> void:
	refresh_progression()

## Level / XP / Scrap readout from GameManager (mission start, new stage)
func refresh_progression() -> void:
	_update_level_display(GameManager.player_level)
	_update_xp_display(GameManager.player_xp, GameManager.xp_to_next_level)
	_update_scrap_display(GameManager.scrap)

func _on_stage_changed(stage: int) -> void:
	if stage >= 2:
		_show_stage_banner("STAGE 2 — NIGHTFALL JUNGLE\nOnly the Moon lights the way...", Color(0.6, 0.72, 1.0))

func _show_stage_banner(text: String, color: Color) -> void:
	if not stage_banner:
		return
	if stage_banner_tween and stage_banner_tween.is_valid():
		stage_banner_tween.kill()
	stage_banner.text = text
	stage_banner.add_theme_color_override("font_color", color)
	stage_banner.modulate.a = 0.0
	stage_banner_tween = create_tween()
	stage_banner_tween.tween_property(stage_banner, "modulate:a", 1.0, 0.6)
	stage_banner_tween.tween_property(stage_banner, "modulate:a", 0.0, 1.2).set_delay(3.5)

func _update_status_effects(delta: float) -> void:
	if not status_tint:
		return
	status_pulse += delta
	var p = local_player if is_instance_valid(local_player) else null
	var trapped = p != null and p.get("is_trapped") == true
	var poison_t: float = float(p.get("poison_timer")) if p else 0.0
	var bleed_t: float = float(p.get("bleed_timer")) if p else 0.0
	var immune_t: float = float(p.get("trap_immunity_timer")) if p else 0.0
	var status_immune_t: float = float(p.get("status_immunity_timer")) if p else 0.0
	var suppression_t: float = float(p.get("gunner_timer")) if p and p.get("is_gunner_active") == true else 0.0

	trap_panel.visible = trapped
	var tint = Color(0, 0, 0, 0)
	if trapped:
		var pulse = 0.5 + 0.5 * sin(status_pulse * 8.0)
		var presses_needed: int = int(p.get("trap_presses_needed"))
		if presses_needed > 0:
			trap_label.text = "PINNED! MASH [A] [D] TO ESCAPE  (%d/%d)" % [int(p.get("trap_presses_done")), presses_needed]
			trap_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
			tint = Color(0.45, 0.0, 0.0, 0.28 + pulse * 0.1)
		else:
			trap_label.text = "ENGULFED! MASH [A] [D] TO ESCAPE  (%.1fs)" % maxf(0.0, float(p.get("trap_timer")))
			trap_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.3))
			tint = Color(0.15, 0.6, 0.08, 0.3 + pulse * 0.06)
		trap_bar.value = p.get_trap_progress()
	elif bleed_t > 0.0:
		tint = Color(0.4, 0.0, 0.0, 0.08 + 0.05 * sin(status_pulse * 6.0))
	elif poison_t > 0.0:
		tint = Color(0.2, 0.55, 0.05, 0.08)
	status_tint.color = tint

	var lines: PackedStringArray = []
	if bleed_t > 0.0:
		lines.append("BLEEDING %.1fs — HP DRAIN (x5 WHILE MOVING), -75%% HEALING" % bleed_t)
	if poison_t > 0.0:
		lines.append("POISONED %.1fs — SLOWED 25%%" % poison_t)
	if status_immune_t > 0.0:
		lines.append("STATUS IMMUNE %.1fs" % status_immune_t)
	if suppression_t > 0.0:
		lines.append("SUPPRESSION IMMUNE %.1fs" % suppression_t)
	elif immune_t > 0.0 and not trapped:
		lines.append("TRAP IMMUNE %.1fs" % immune_t)
	status_effects_label.text = "\n".join(lines)
	if bleed_t > 0.0:
		status_effects_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	elif poison_t > 0.0:
		status_effects_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.3))
	else:
		status_effects_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
