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
@onready var null_barrier_label: Label = get_node_or_null("BottomLeft/NullBarrierLabel")

var local_player: Node = null
var hitmarker_timer: float = 0.0

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
	
	_update_xp_display(GameManager.player_xp, GameManager.xp_to_next_level)
	_update_level_display(GameManager.player_level)
	_update_scrap_display(GameManager.scrap)

func connect_player(player: Node) -> void:
	local_player = player
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

func connect_spawner(spawner: Node) -> void:
	if spawner.has_signal("wave_progress"):
		spawner.wave_progress.connect(_on_wave_progress)
	if spawner.has_signal("intermission_tick"):
		spawner.intermission_tick.connect(_on_intermission_tick)

func _process(delta: float) -> void:
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
	if wave_num >= 100:
		wave_label.text = "WAVE 100 [FINAL BOSS]"
		wave_label.modulate = Color(1.0, 0.25, 0.25)
	else:
		wave_label.text = "WAVE %d" % wave_num
		wave_label.modulate = Color.WHITE
	intermission_label.visible = false

func _on_boss_spawned(boss_node: Node) -> void:
	boss_container.visible = true
	if boss_node and "enemy_name" in boss_node:
		boss_name_label.text = "[FINAL BOSS] %s" % boss_node.enemy_name.to_upper()
	else:
		boss_name_label.text = "[FINAL BOSS] APEX OVERLORD"

func _on_boss_health_updated(cur_hp: float, max_hp: float) -> void:
	boss_container.visible = true
	boss_bar.max_value = max_hp
	boss_bar.value = cur_hp
	var pct = (cur_hp / maxf(1.0, max_hp)) * 100.0
	boss_hp_label.text = "%d / %d (%.0f%%)" % [int(cur_hp), int(max_hp), pct]

func _on_boss_defeated() -> void:
	boss_container.visible = false

func _on_wave_progress(alive_count: int, _total: int) -> void:
	enemies_label.text = "ENEMIES: %d" % alive_count

func _on_intermission_tick(sec_left: int) -> void:
	intermission_label.visible = true
	intermission_label.text = "NEXT WAVE IN: %ds" % sec_left

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
