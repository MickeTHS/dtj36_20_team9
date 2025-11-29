class_name Level extends Node2D

@export var player_character : PlayerCharacter
@export var platform_generator: PlatformGenerator
@export var level_root: CanvasItem        # Usually a Node2D that is parent of the whole level
@export var ui: UI

@export var initial_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var red_step_per_level: float = 0.08         # How much more red each level becomes
@export var desaturate_step_per_level: float = 0.04  # How much G/B shrink each level

var current_level: int = 1


func _ready() -> void:
	if level_root != null:
		level_root.modulate = initial_tint
	
	_generate_level()


func _generate_level() -> void:
	if platform_generator != null:
		platform_generator.generate_level()


func on_door_reached() -> void:
	# Call this from the door collision callback
	player_character.position = Vector2(107, -29)
	current_level += 1
	_generate_level()
	_update_level_tint()
	if ui:
		ui.set_level(current_level)


func _update_level_tint() -> void:
	if level_root == null:
		return
	
	var level_factor: float = float(current_level - 1)

	var new_r: float = clamp(initial_tint.r + red_step_per_level * level_factor, 0.0, 1.0)
	var new_g: float = clamp(initial_tint.g - desaturate_step_per_level * level_factor, 0.0, 1.0)
	var new_b: float = clamp(initial_tint.b - desaturate_step_per_level * level_factor, 0.0, 1.0)

	level_root.modulate = Color(new_r, new_g, new_b, initial_tint.a)


func _on_door_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "PlayerCharacter":
		on_door_reached()
