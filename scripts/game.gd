extends Node

@export var platform_generator : PlatformGenerator
@export var player_character : PlayerCharacter

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_restart_button_pressed() -> void:
	
	platform_generator.generate_level()
	player_character.position = Vector2(107, -29)
