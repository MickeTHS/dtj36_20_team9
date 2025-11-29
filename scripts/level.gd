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

@export var min_enemy_x: int = 5              # tiles from the start before enemies start appearing
@export var max_enemy_x_margin: int = 10      # tiles from the end where enemies won't spawn

var current_level: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _enemies: Array[EnemyCharacter] = []


func _ready() -> void:
	if level_root != null:
		level_root.modulate = initial_tint
	
	_rng.randomize()
	_generate_level()


func _generate_level() -> void:
	if platform_generator != null:
		platform_generator.generate_level()
		_clear_enemies()
		_spawn_enemies_for_level(current_level)


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


func _clear_enemies() -> void:
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()


func _spawn_enemies_for_level(level: int) -> void:
	if enemy_types.is_empty():
		return
	if platform_generator == null or platform_generator.ground_tilemap == null:
		return

	var tilemap := platform_generator.ground_tilemap
	if tilemap.tile_set == null:
		return

	# How many enemy types are available for this level?
	var available_types: int = min(level, enemy_types.size())

	var max_x: int = platform_generator.level_width - max_enemy_x_margin
	if max_x <= min_enemy_x:
		return

	for type_index in range(available_types):
		var scene: PackedScene = enemy_types[type_index]
		if scene == null:
			continue

		var count: int = _rng.randi_range(min_enemies_per_type, max_enemies_per_type)

		for i in range(count):
			var attempts: int = 0
			while attempts < 10:
				var tile_x: int = _rng.randi_range(min_enemy_x, max_x)
				var ground_y: int = platform_generator.get_ground_y_at(tile_x)
				if ground_y != -1:
					var cell_pos: Vector2i = Vector2i(tile_x, ground_y - 1)
					var local_pos: Vector2 = tilemap.map_to_local(cell_pos)
					var global_pos: Vector2 = tilemap.to_global(local_pos)

					var enemy := scene.instantiate() as EnemyCharacter
					if enemy == null:
						break

					enemy.global_position = global_pos
					enemy.player = player_character

					call_deferred("_deferred_add_enemy", enemy)
					break


				attempts += 1


func _deferred_add_enemy(enemy: EnemyCharacter) -> void:
	if not is_instance_valid(enemy):
		return
	
	add_child(enemy)
	_enemies.append(enemy)
