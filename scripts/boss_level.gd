class_name BossLevel
extends Node2D

@export var player_spawn : Vector2
@export var boss_music : AudioStreamPlayer
@export var main_music : AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func start_boss_level() -> void:
	boss_music.play()
	main_music.stop()
