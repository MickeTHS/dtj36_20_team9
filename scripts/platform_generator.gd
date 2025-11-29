class_name PlatformGenerator extends Node2D

@export var ground_tilemap: TileMapLayer
@export var background_tilemap: TileMapLayer

# ====== LEVEL SHAPE SETTINGS ======
@export var level_width: int = 200
@export var min_ground_y: int = 8
@export var max_ground_y: int = 14
@export var solid_depth: int = 4

@export var max_jump_gap: int = 3
@export var max_pit_width: int = 10
@export var max_step_height: int = 2

@export_range(0.0, 1.0, 0.01)
var uneven_chance: float = 0.4 # How often to make height changes (slopes)

@export_range(0.0, 1.0, 0.01)
var gap_chance: float = 0.25

# ====== TILESET SETTINGS ======
@export var ground_source_id: int = 0
@export var ground_tiles: Array[Vector2i] = []

@export var background_source_id: int = 0
@export var background_tiles: Array[Vector2i] = []

@export var door_tile: Vector2i = Vector2i.ZERO
@export var door_source_id: int = 0
@export var door_offset_from_end: int = 5


# Background generation settings
@export var background_band_height: int = 8        # tiles above ground to consider
@export_range(0.0, 1.0, 0.01)
var background_fill_chance: float = 0.6           # how full the background is


var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	generate_level()


func generate_level() -> void:
	if ground_tilemap == null:
		push_error("ground_tilemap is not assigned!")
		return

	ground_tilemap.clear()
	if background_tilemap:
		background_tilemap.clear()

	var ground_heights := _generate_ground_profile()
	_paint_ground(ground_heights)
	_add_rescue_platforms(ground_heights)
	_paint_background(ground_heights)
	_place_exit_door(ground_heights)


func _generate_ground_profile() -> Array:
	var heights: Array = []
	var current_y: int = rng.randi_range(min_ground_y, max_ground_y)
	var gap_len := 0

	for x in range(level_width):
		var try_gap := rng.randf() < gap_chance

		# Try to make a gap
		if try_gap and gap_len < max_pit_width:
			heights.append(null)
			gap_len += 1
		else:
			gap_len = 0

			# Decide whether to change height or stay flat
			var delta := 0
			if rng.randf() < uneven_chance and max_step_height > 0:
				delta = rng.randi_range(-max_step_height, max_step_height)
				# Make sure we actually change, not always 0
				if delta == 0:
					delta = 1 if rng.randf() < 0.5 else -1

			current_y = clamp(current_y + delta, min_ground_y, max_ground_y)
			heights.append(current_y)

	return heights


func _paint_ground(heights: Array) -> void:
	for x in range(heights.size()):
		var h = heights[x]
		if h == null:
			continue

		for d in range(solid_depth):
			var pos := Vector2i(x, h + d)
			var atlas := _get_random_ground_tile()
			ground_tilemap.set_cell(pos, ground_source_id, atlas)


func _add_rescue_platforms(heights: Array) -> void:
	var x := 0
	while x < heights.size():
		if heights[x] == null:
			var start := x
			while x < heights.size() and heights[x] == null:
				x += 1
			var end := x - 1
			var width := end - start + 1

			if width > max_jump_gap:
				_place_platforms_in_gap(heights, start, end)
		else:
			x += 1


func _place_platforms_in_gap(heights: Array, start: int, end: int) -> void:
	var left_y = heights[start - 1] if start > 0 else null
	var right_y = heights[end + 1] if end < heights.size() - 1 else null

	var base_y: int
	if left_y != null and right_y != null:
		base_y = min(left_y, right_y)
	elif left_y != null:
		base_y = left_y
	elif right_y != null:
		base_y = right_y
	else:
		base_y = (min_ground_y + max_ground_y) / 2

	var platform_y: int = base_y - 3
	var px := start + max_jump_gap

	while px <= end - max_jump_gap:
		_place_platform_column(px, platform_y)
		px += max_jump_gap


func _place_platform_column(x: int, y: int) -> void:
	if x < 0 or x >= level_width:
		return

	var atlas := _get_random_ground_tile()
	ground_tilemap.set_cell(Vector2i(x, y), ground_source_id, atlas)

func _paint_background(heights: Array) -> void:
	if background_tilemap == null or background_tiles.is_empty():
		return

	var last_ground_y: int = min_ground_y

	for x in range(heights.size()):
		var h = heights[x]
		if h != null:
			last_ground_y = h

		var ground_y := last_ground_y

		# Fill a band above the ground with background tiles
		var top_y := ground_y - background_band_height
		var bottom_y := ground_y - 2  # leave a little air gap above the ground

		for y in range(top_y, bottom_y + 1):
			if rng.randf() < background_fill_chance:
				var pos := Vector2i(x, y)
				var atlas := _get_random_background_tile()
				background_tilemap.set_cell(pos, background_source_id, atlas)


func _get_random_ground_tile() -> Vector2i:
	if ground_tiles.is_empty():
		return Vector2i.ZERO
	return ground_tiles[rng.randi() % ground_tiles.size()]


func _get_random_background_tile() -> Vector2i:
	if background_tiles.is_empty():
		return Vector2i.ZERO
	return background_tiles[rng.randi() % background_tiles.size()]

func _place_exit_door(heights: Array) -> void:
	if ground_tilemap == null:
		return

	# Door must be defined
	if door_tile == Vector2i.ZERO:
		return

	# Target X position for door
	var target_x: int = level_width - door_offset_from_end
	target_x = clamp(target_x, 0, heights.size() - 1)

	# Find first ground tile at or before target_x
	var x: int = target_x
	var ground_y: int = -1  # sentinel meaning "not found yet"

	while x >= 0:
		var h = heights[x]
		if h != null:
			ground_y = int(h)
			break
		x -= 1

	if ground_y == -1:
		# No ground near the end (rare but safe to guard)
		return

	# 2-tile high door:
	# bottom tile sits on top of ground, top tile is one tile above in the tileset
	var bottom_pos := Vector2i(x, ground_y - 1)
	var top_pos := Vector2i(x, ground_y - 2)

	var bottom_atlas := door_tile
	var top_atlas := Vector2i(door_tile.x, door_tile.y - 1)

	ground_tilemap.set_cell(bottom_pos, door_source_id, bottom_atlas)
	ground_tilemap.set_cell(top_pos, door_source_id, top_atlas)
