class_name PlatformGenerator
extends Node2D

@export var door_area: Area2D   # The Area2D door instance to move

@export var ground_tilemap: TileMapLayer
@export var background_tilemap: TileMapLayer

# ====== LEVEL SHAPE SETTINGS ======
@export var level_width: int = 200
@export var min_ground_y: int = 8
@export var max_ground_y: int = 14
@export var solid_depth: int = 6     # We will use: surface + subsurface + deep soil

@export var max_jump_gap: int = 3
@export var max_pit_width: int = 10
@export var max_step_height: int = 2

@export_range(0.0, 1.0, 0.01)
var uneven_chance: float = 0.4

@export_range(0.0, 1.0, 0.01)
var gap_chance: float = 0.25


# ====== NEW STRUCTURED TERRAIN TILE SETTINGS ======
@export var ground_source_id: int = 0

# Visible top of ground (floor)
@export var surface_tiles: Array[Vector2i] = []     # 2–3 different floor variants
@export var surface_min_run: int = 2
@export var surface_max_run: int = 4

# The row directly under the floor
@export var subsurface_tiles: Array[Vector2i] = []  # typically "edge" dirt visuals

# Deep soil tiles (base)
@export var soil_tile: Vector2i = Vector2i.ZERO
@export var soil_tiles: Array[Vector2i] = []

# Rare "special" soil tiles
@export var rare_soil_tiles: Array[Vector2i] = []
@export_range(0.0, 1.0, 0.01)
var rare_soil_chance: float = 0.05


# ====== BACKGROUND SETTINGS ======
@export var background_source_id: int = 0
@export var background_tiles: Array[Vector2i] = []

@export var background_band_height: int = 8
@export_range(0.0, 1.0, 0.01)
var background_fill_chance: float = 0.6

@export var door_offset_from_end: int = 5


# ====== INTERNAL ======
var rng := RandomNumberGenerator.new()
var last_ground_heights: Array = []

# Surface tile run state
var _surface_run_remaining: int = 0
var _current_surface_tile: Vector2i = Vector2i.ZERO


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
	last_ground_heights = ground_heights

	_paint_ground(ground_heights)
	_add_rescue_platforms(ground_heights)
	_paint_background(ground_heights)
	_place_exit_door(ground_heights)



# ------------------------------------------------------------
# HEIGHT PROFILE (SLOPES, GAPS)
# ------------------------------------------------------------
func _generate_ground_profile() -> Array:
	var heights: Array = []
	var current_y: int = rng.randi_range(min_ground_y, max_ground_y)
	var gap_len := 0

	for x in range(level_width):
		var try_gap := rng.randf() < gap_chance

		if try_gap and gap_len < max_pit_width:
			heights.append(null)
			gap_len += 1
		else:
			gap_len = 0

			var delta := 0
			if rng.randf() < uneven_chance:
				delta = rng.randi_range(-max_step_height, max_step_height)
				if delta == 0:
					delta = 1 if rng.randf() < 0.5 else -1

			current_y = clamp(current_y + delta, min_ground_y, max_ground_y)
			heights.append(current_y)

	return heights



# ------------------------------------------------------------
# STRUCTURED TERRAIN PAINTING
# ------------------------------------------------------------
func _paint_ground(heights: Array) -> void:
	_surface_run_remaining = 0
	_current_surface_tile = Vector2i.ZERO

	for x in range(heights.size()):
		var h = heights[x]
		if h == null:
			continue

		var surface_y := int(h)

		# --- SURFACE / FLOOR ---
		var surface_pos := Vector2i(x, surface_y)
		var surf_tile := _next_surface_tile()
		ground_tilemap.set_cell(surface_pos, ground_source_id, surf_tile)

		# --- SUBSURFACE ---
		if solid_depth > 1:
			var sub_pos := Vector2i(x, surface_y + 1)
			var sub_tile := _get_subsurface_tile()
			ground_tilemap.set_cell(sub_pos, ground_source_id, sub_tile)

		# --- DEEP SOIL ---
		for d in range(2, solid_depth):
			var pos := Vector2i(x, surface_y + d)
			var soil := _get_deep_soil_tile()
			ground_tilemap.set_cell(pos, ground_source_id, soil)



# ------------------------------------------------------------
# SURFACE / SUBSURFACE / SOIL TILE HELPERS
# ------------------------------------------------------------
func _next_surface_tile() -> Vector2i:
	if surface_tiles.is_empty():
		return _fallback_ground()

	if _surface_run_remaining <= 0:
		_current_surface_tile = surface_tiles[rng.randi() % surface_tiles.size()]
		var min_run : int = max(surface_min_run, 1)
		var max_run : int = max(surface_max_run, min_run)
		_surface_run_remaining = rng.randi_range(min_run, max_run)

	_surface_run_remaining -= 1
	return _current_surface_tile


func _get_subsurface_tile() -> Vector2i:
	if not subsurface_tiles.is_empty():
		return subsurface_tiles[rng.randi() % subsurface_tiles.size()]
	return _get_soil_tile()


func _get_soil_tile() -> Vector2i:
	if not soil_tiles.is_empty():
		return soil_tiles[rng.randi() % soil_tiles.size()]
	if soil_tile != Vector2i.ZERO:
		return soil_tile
	return _fallback_ground()


func _get_deep_soil_tile() -> Vector2i:
	if not rare_soil_tiles.is_empty() and rng.randf() < rare_soil_chance:
		return rare_soil_tiles[rng.randi() % rare_soil_tiles.size()]
	return _get_soil_tile()


func _fallback_ground() -> Vector2i:
	return Vector2i.ZERO



# ------------------------------------------------------------
# rescue platforms for large pits
# ------------------------------------------------------------
func _add_rescue_platforms(heights: Array) -> void:
	var x := 0
	while x < heights.size():
		if heights[x] == null:
			var start := x
			while x < heights.size() and heights[x] == null:
				x += 1
			var end := x - 1

			if end - start + 1 > max_jump_gap:
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

	var platform_y := base_y - 3
	var px := start + max_jump_gap

	while px <= end - max_jump_gap:
		var pos := Vector2i(px, platform_y)
		var tile := _next_surface_tile()
		ground_tilemap.set_cell(pos, ground_source_id, tile)
		px += max_jump_gap



# ------------------------------------------------------------
# BACKGROUND
# ------------------------------------------------------------
func _paint_background(heights: Array) -> void:
	if background_tilemap == null or background_tiles.is_empty():
		return

	var last_y := min_ground_y

	for x in range(heights.size()):
		if heights[x] != null:
			last_y = heights[x]

		var top_y := last_y - background_band_height
		var bottom_y := last_y - 2

		for y in range(top_y, bottom_y + 1):
			if rng.randf() < background_fill_chance:
				var pos := Vector2i(x, y)
				var tile := background_tiles[rng.randi() % background_tiles.size()]
				background_tilemap.set_cell(pos, background_source_id, tile)



# ------------------------------------------------------------
# PLACE EXIT DOOR AREA2D
# ------------------------------------------------------------
func _place_exit_door(heights: Array) -> void:
	if door_area == null:
		return

	var x : int = clamp(level_width - door_offset_from_end, 0, heights.size() - 1)
	var ground_y := -1

	while x >= 0:
		if heights[x] != null:
			ground_y = heights[x]
			break
		x -= 1

	if ground_y == -1:
		door_area.visible = false
		return

	var cell := Vector2i(x, ground_y - 1)
	var local := ground_tilemap.map_to_local(cell)
	var global := ground_tilemap.to_global(local)

	door_area.global_position = global
	door_area.visible = true



# ------------------------------------------------------------
# API FOR SPAWNING ENEMIES
# ------------------------------------------------------------
func get_ground_y_at(x: int) -> int:
	if x < 0 or x >= last_ground_heights.size():
		return -1
	if last_ground_heights[x] == null:
		return -1
	return int(last_ground_heights[x])
