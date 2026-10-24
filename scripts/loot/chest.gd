extends Area3D

@onready var prompt_label: Label3D = $PromptLabel
@onready var chest_lid: Node3D = $Lid
@onready var beacon: MeshInstance3D = $Beacon

var is_player_nearby: bool = false
var is_opened: bool = false
const LOOT_SCENE = preload("res://scenes/loot/loot_pickup.tscn")

func _ready() -> void:
	prompt_label.visible = false

func _process(_delta: float) -> void:
	if is_player_nearby and not is_opened:
		if Input.is_action_just_pressed("interact"):
			open_chest()

func open_chest() -> void:
	if is_opened:
		return
	is_opened = true
	prompt_label.visible = false
	if beacon:
		beacon.visible = false
	
	SoundManager.play("chest_open")
	
	# Open animation
	var tw = create_tween()
	tw.tween_property(chest_lid, "rotation_degrees:x", -65.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Spawn loot fountain
	for i in range(5):
		var p = LOOT_SCENE.instantiate()
		get_parent().add_child(p)
		p.global_position = global_position + Vector3(0, 0.6, 0)
		p.setup(0 if i % 2 == 0 else 2, randi_range(20, 40)) # XP or Scrap
	
	# Award free upgrade card!
	await get_tree().create_timer(0.4).timeout
	GameManager.prompt_upgrade_menu()
	
	# Fade out chest after 5 seconds
	await get_tree().create_timer(4.0).timeout
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and not is_opened:
		is_player_nearby = true
		prompt_label.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		prompt_label.visible = false
