extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var spawner: Node3D = $Spawner
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	if hud and player:
		hud.connect_player(player)
	if hud and spawner:
		hud.connect_spawner(spawner)
