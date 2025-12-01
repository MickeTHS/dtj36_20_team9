# ------
# level controller
# make sure player is in correct place
# exit ladder/door
# spawn enemies
# spawn crates
# call the level generator or teleport to boss room
# ------

class_name Level
extends Node2D

@export var boss_level : BossLevel
@export var level_up_audio : AudioStreamPlayer
@export var game_over_audio : AudioStreamPlayer

@export var player_character: PlayerCharacter
@export var platform_generator: PlatformGenerator
@export var level_root: CanvasItem
@export var ui: UI

@export var initial_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var red_step_per_level: float = 0.08
@export var desaturate_step_per_level: float = 0.04

@export var enemy_types: Array[PackedScene] = []
@export var min_enemies_per_type: int = 2
@export var max_enemies_per_type: int = 4

@export var crate_scene: PackedScene
@export var min_crate_groups: int = 2
@export var max_crate_groups: int = 6
@export_range(0.0, 1.0, 0.01)
var crate_pyramid_chance: float = 0.4


var current_level: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _enemies: Array[EnemyCharacter] = []
var _crates: Array[Node2D] = []


func restart_level() -> void:
	current_level = 1
	
	_update_level_tint()
	_generate_level()
	
	if ui:
		ui.set_level(current_level)


func _ready() -> void:
	if level_root != null:
		level_root.modulate = initial_tint

	_rng.randomize()

func teleport_to_boss_level() -> void:
	player_character.reparent(boss_level)
	player_character.position = Vector2.ZERO
	boss_level.start_boss_level()

func _generate_level() -> void:
	if platform_generator == null:
		return

	platform_generator.level_width = 80 + (current_level * 25)
	platform_generator.generate_level()

	if player_character != null:
		var player_spawn: Vector2 = platform_generator.get_player_spawn_position()
		
		if player_spawn != Vector2.ZERO:
			player_character.global_position = player_spawn

	_clear_enemies()
	_spawn_enemies_for_level(current_level)
	_spawn_crates_for_level(current_level)


func on_door_reached() -> void:
	level_up_audio.play()
	
	current_level += 1
	_generate_level()
	_update_level_tint()
	if ui:
		ui.set_level(current_level)
		
	if current_level > 4:
		teleport_to_boss_level()


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

	var available_types: int = min(level, enemy_types.size())
	if available_types <= 0:
		return

	var counts: Array[int] = []
	var total_enemies: int = 0

	for type_index in range(available_types):
		var c: int = _rng.randi_range(min_enemies_per_type, max_enemies_per_type)
		counts.append(c)
		total_enemies += c

	if total_enemies <= 0:
		return

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
	
# ------------------------------------------------------------
# CRATES / FLOOR PROPS
# ------------------------------------------------------------
func _clear_crates() -> void:
	for c in _crates:
		if is_instance_valid(c):
			c.queue_free()
	_crates.clear()


func _spawn_crates_for_level(level: int) -> void:
	if crate_scene == null:
		return
	if platform_generator == null or platform_generator.ground_tilemap == null:
		return

	var tilemap := platform_generator.ground_tilemap

	var groups: int = 2 + level
	groups = clamp(groups, min_crate_groups, max_crate_groups)

	var min_x: int = max(platform_generator.spawn_min_x, 4)
	var max_x: int = platform_generator.level_width - max(platform_generator.spawn_max_x_margin, 10)
	if max_x <= min_x:
		return

	var used_columns: Array[int] = []

	for g in range(groups):
		var attempts: int = 0
		var center_x: int = -1

		while attempts < 10:
			var candidate_x: int = _rng.randi_range(min_x, max_x)
			if candidate_x in used_columns:
				attempts += 1
				continue
			center_x = candidate_x
			break

		if center_x == -1:
			continue

		used_columns.append(center_x)

		if _rng.randf() < crate_pyramid_chance:
			_spawn_crate_pyramid(tilemap, center_x)
		else:
			_spawn_crate_stack(tilemap, center_x)


func _spawn_crate_stack(tilemap: TileMapLayer, x: int) -> void:
	var ground_y: int = platform_generator.get_ground_y_at(x)
	if ground_y == -1:
		return

	# 1–3 crates tall
	var height: int = _rng.randi_range(1, 3)
	for i in range(height):
		var cell_y: int = ground_y - 1 - i
		_spawn_crate_at_cell(tilemap, x, cell_y)


func _spawn_crate_pyramid(tilemap: TileMapLayer, center_x: int) -> void:
	var x_left: int = center_x - 1
	var x_mid: int = center_x
	var x_right: int = center_x + 1

	if x_left < 0 or x_right >= platform_generator.level_width:
		_spawn_crate_stack(tilemap, center_x)
		return

	var gy_left: int = platform_generator.get_ground_y_at(x_left)
	var gy_mid: int = platform_generator.get_ground_y_at(x_mid)
	var gy_right: int = platform_generator.get_ground_y_at(x_right)

	if gy_left == -1 or gy_mid == -1 or gy_right == -1:
		_spawn_crate_stack(tilemap, center_x)
		return

	var base_y: int = min(gy_left, min(gy_mid, gy_right))

	_spawn_crate_at_cell(tilemap, x_left,  base_y - 1)
	_spawn_crate_at_cell(tilemap, x_mid,   base_y - 1)
	_spawn_crate_at_cell(tilemap, x_right, base_y - 1)

	_spawn_crate_at_cell(tilemap, x_mid, base_y - 2)


func _spawn_crate_at_cell(tilemap: TileMapLayer, x: int, y: int) -> void:
	var cell := Vector2i(x, y)
	var local := tilemap.map_to_local(cell)
	var global := tilemap.to_global(local)

	var crate := crate_scene.instantiate() as Node2D
	if crate == null:
		return

	crate.global_position = global
	add_child(crate)
	_crates.append(crate)
