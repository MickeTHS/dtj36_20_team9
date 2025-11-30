class_name Game
extends Node

@export var platform_generator : PlatformGenerator
@export var player_character : PlayerCharacter
@export var level: Level
@export var ui: UI

func game_over() -> void:
	player_character.visible = false
	player_character.set_active(false)
	ui.show_main_menu()
	level.visible = false


func start_game() -> void:
	player_character.set_health(8)
	player_character.visible = true
	player_character.set_active(true)
	ui.start_game()
	level.visible = true
	level.restart_level()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	ui.visible = true
	player_character.visible = false
	player_character.set_active(false)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_restart_button_pressed() -> void:
	if level != null:
		level.restart_level()
