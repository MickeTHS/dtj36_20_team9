extends Node

@export var platform_generator : PlatformGenerator
@export var player_character : PlayerCharacter
@export var level: Level

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_restart_button_pressed() -> void:
	if level != null:
		level.restart_level()
