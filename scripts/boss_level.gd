class_name BossLevel
extends Node2D

@export var player_spawn : Vector2
@export var boss_music : AudioStreamPlayer
@export var main_music : AudioStreamPlayer

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass

func start_boss_level() -> void:
	boss_music.play()
	main_music.stop()


func end_boss_level() -> void:
	boss_music.stop()
	main_music.play()
