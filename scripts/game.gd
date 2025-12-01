# -------
# keep track of the current game state
# -------

class_name Game
extends Node

@export var platform_generator : PlatformGenerator
@export var player_character : PlayerCharacter
@export var level: Level
@export var ui: UI
@export var boss_level: BossLevel
@export var enemy_boss : BossCharacter

@export var game_over_audio : AudioStreamPlayer
@export var victory_audio : AudioStreamPlayer

func game_over() -> void:
	game_over_audio.play()
	player_character.visible = false
	player_character.set_active(false)
	ui.show_game_over()
	level.visible = false
	boss_level.end_boss_level()

func game_end() -> void:
	victory_audio.play()
	player_character.visible = false
	player_character.set_active(false)
	ui.show_the_end()
	level.visible = false
	boss_level.end_boss_level()


func start_game() -> void:
	player_character.set_health(8)
	player_character.visible = true
	player_character.set_active(true)
	ui.start_game()
	level.visible = true
	level.restart_level()

func _ready() -> void:
	ui.visible = true
	ui.show_main_menu()
	player_character.visible = false
	player_character.set_active(false)


func _process(delta: float) -> void:
	pass


func _on_restart_button_pressed() -> void:
	if level != null:
		level.restart_level()
