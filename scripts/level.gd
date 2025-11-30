class_name Level
extends Node2D

@export var player_character: PlayerCharacter
@export var platform_generator: PlatformGenerator
@export var level_root: CanvasItem        # Usually a Node2D that is parent of the whole level
@export var ui: UI

@export var initial_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var red_step_per_level: float = 0.08         # How much more red each level becomes
@export var desaturate_step_per_level: float = 0.04  # How much G/B shrink each level

# Enemy setup
@export var enemy_types: Array[PackedScene] = []  # 0 = type1, 1 = type2, ...
@export var min_enemies_per_type: int = 2
@export var max_enemies_per_type: int = 4

var current_level: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _enemies: Array[EnemyCharacter] = []

func restart_level() -> void:
	# Optional: reset to level 1, or keep current_level if you prefer
	current_level = 1
	
	_update_level_tint()
	_generate_level()
	
	if ui:
		ui.set_level(current_level)


func _ready() -> void:
	if level_root != null:
		level_root.modulate = initial_tint

	_rng.randomize()
	_generate_level()
	if ui:
		ui.set_level(current_level)


func _generate_level() -> void:
	if platform_generator == null:
		return

	platform_generator.generate_level()

	# Place player at a safe spawn point between floor and roof
	if player_character != null:
		var player_spawn: Vector2 = platform_generator.get_player_spawn_position()
		
		if player_spawn != Vector2.ZERO:
			player_character.global_position = player_spawn

	_clear_enemies()
	_spawn_enemies_for_level(current_level)


func on_door_reached() -> void:
	# Next level
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
		# Defer to avoid modifying physics state while queries are flushing
		call_deferred("on_door_reached")


func _clear_enemies() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()


func _spawn_enemies_for_level(level: int) -> void:
	if enemy_types.is_empty():
		return
	if platform_generator == null:
		return

	# How many enemy types are available for this level?
	var available_types: int = min(level, enemy_types.size())
	if available_types <= 0:
		return

	# Decide how many enemies per type and total
	var counts: Array[int] = []
	var total_enemies: int = 0

	for type_index in range(available_types):
		var c: int = _rng.randi_range(min_enemies_per_type, max_enemies_per_type)
		counts.append(c)
		total_enemies += c

	if total_enemies <= 0:
		return

	# Ask the platform generator for safe, evenly spaced spawn positions
	var spawn_positions: Array[Vector2] = platform_generator.get_enemy_spawn_positions(total_enemies)
	if spawn_positions.is_empty():
		return

	var pos_index: int = 0

	for type_index in range(available_types):
		var scene: PackedScene = enemy_types[type_index]
		if scene == null:
			continue

		var count_for_type: int = counts[type_index]

		for i in range(count_for_type):
			if pos_index >= spawn_positions.size():
				return

			var enemy_pos: Vector2 = spawn_positions[pos_index]
			pos_index += 1

			var enemy := scene.instantiate() as EnemyCharacter
			if enemy == null:
				continue

			enemy.global_position = enemy_pos
			enemy.player = player_character

			call_deferred("_deferred_add_enemy", enemy)


func _deferred_add_enemy(enemy: EnemyCharacter) -> void:
	if not is_instance_valid(enemy):
		return

	add_child(enemy)
	_enemies.append(enemy)
