class_name PlatformGenerator
extends Node2D

@export var door_area: Area2D   # The Area2D door instance to move

@export var ground_tilemap: TileMapLayer
@export var background_tilemap: TileMapLayer

# ====== LEVEL SHAPE SETTINGS ======
@export var level_width: int = 200
@export var min_ground_y: int = 8
@export var max_ground_y: int = 14
@export var solid_depth: int = 6     # surface + subsurface + deep soil

@export var max_jump_gap: int = 3
@export var max_pit_width: int = 10
@export var max_step_height: int = 2

@export_range(0.0, 1.0, 0.01)
var uneven_chance: float = 0.4

@export_range(0.0, 1.0, 0.01)
var gap_chance: float = 0.25


# ====== GROUND TILE SETTINGS ======
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


# ====== ROOF SETTINGS ======
@export var roof_source_id: int = 0
@export var roof_tiles: Array[Vector2i] = []       # roof surface variants
@export var roof_min_run: int = 2
@export var roof_max_run: int = 4
@export var roof_thickness: int = 10


# Approximate vertical range for roof (smaller y = higher up)
@export var roof_min_y: int = 2
@export var roof_max_y: int = 5

@export_range(0.0, 1.0, 0.01)
var roof_uneven_chance: float = 0.3
@export var roof_max_step_height: int = 1

# Minimum vertical gap between roof and ground to consider it "safe"
@export var min_vertical_clearance: int = 4


# ====== PROPS (stalactites, crates, bushes, etc) ======
# Generic environment prop scene. Typically class_name LevelProp extends Node2D.
@export var prop_scene: PackedScene
@export_range(0.0, 1.0, 0.01)
var stalactite_chance: float = 0.12    # probability per roof column to spawn a stalactite


# ====== BACKGROUND SETTINGS ======
@export var background_source_id: int = 0
@export var background_tiles: Array[Vector2i] = []

@export var background_band_height: int = 8
@export_range(0.0, 1.0, 0.01)
var background_fill_chance: float = 0.6

@export var door_offset_from_end: int = 5


# ====== SPAWN SETTINGS (for player & enemies) ======
@export var spawn_min_x: int = 3          # tiles from left edge
@export var spawn_max_x_margin: int = 8   # tiles from right edge to avoid door


# ====== INTERNAL ======
var rng := RandomNumberGenerator.new()

var last_ground_heights: Array = []
var last_roof_heights: Array = []

# Surface tile run state
var _surface_run_remaining: int = 0
var _current_surface_tile: Vector2i = Vector2i.ZERO

# Roof tile run state
var _roof_run_remaining: int = 0
var _current_roof_tile: Vector2i = Vector2i.ZERO

var _spawned_props: Array[Node2D] = []


func _ready() -> void:
	rng.randomize()
	generate_level()


func generate_level() -> void:
	if ground_tilemap == null:
		push_error("ground_tilemap is not assigned!")
		return

	# Clear tiles
	ground_tilemap.clear()
	if background_tilemap:
		background_tilemap.clear()

	# Clear old props
	for p in _spawned_props:
		if is_instance_valid(p):
			p.queue_free()
	_spawned_props.clear()

	var ground_heights := _generate_ground_profile()
	last_ground_heights = ground_heights

	var roof_heights := _generate_roof_profile(ground_heights)
	last_roof_heights = roof_heights

	_paint_ground(ground_heights)
	_paint_roof(roof_heights)
	_paint_walls(ground_heights, roof_heights)
	_add_rescue_platforms(ground_heights)
	_paint_background(ground_heights)
	_place_exit_door(ground_heights)

func _paint_walls(ground_heights: Array, roof_heights: Array) -> void:
	if ground_tilemap == null:
		return

	# Find highest roof underside (smallest y) and lowest ground (largest y)
	var has_ground := false
	var has_roof := false
	var max_ground_y: int = -100000
	var min_roof_y: int = 100000

	for x in range(level_width):
		if x < ground_heights.size():
			var gy = ground_heights[x]
			if gy != null:
				has_ground = true
				if int(gy) > max_ground_y:
					max_ground_y = int(gy)

		if x < roof_heights.size():
			var ry = roof_heights[x]
			if ry != null:
				has_roof = true
				if int(ry) < min_roof_y:
					min_roof_y = int(ry)

	if not has_ground or not has_roof:
		return

	# Top of walls should reach top of thick roof
	var top_y: int = min_roof_y - (roof_thickness - 1)
	# Bottom of walls should reach bottom of solid ground
	var bottom_y: int = max_ground_y + (solid_depth - 1)

	# Choose a roof tile to use for walls
	var wall_tile: Vector2i
	if roof_tiles.is_empty():
		wall_tile = _fallback_ground()
	else:
		wall_tile = roof_tiles[rng.randi() % roof_tiles.size()]

	# Left wall at x = 0
	var left_x: int = 0
	for y in range(top_y, bottom_y + 1):
		ground_tilemap.set_cell(Vector2i(left_x, y), roof_source_id, wall_tile)

	# Right wall at x = level_width - 1
	var right_x: int = level_width - 1
	for y in range(top_y, bottom_y + 1):
		ground_tilemap.set_cell(Vector2i(right_x, y), roof_source_id, wall_tile)


# ------------------------------------------------------------
# HEIGHT PROFILE (GROUND)
# ------------------------------------------------------------
func _generate_ground_profile() -> Array:
	var heights: Array = []
	var current_y: int = rng.randi_range(min_ground_y, max_ground_y)
	var gap_len: int = 0

	for x in range(level_width):
		var try_gap: bool = rng.randf() < gap_chance

		if try_gap and gap_len < max_pit_width:
			heights.append(null)
			gap_len += 1
		else:
			gap_len = 0

			var delta: int = 0
			if rng.randf() < uneven_chance:
				delta = rng.randi_range(-max_step_height, max_step_height)
				if delta == 0:
					delta = 1 if rng.randf() < 0.5 else -1

			current_y = clamp(current_y + delta, min_ground_y, max_ground_y)
			heights.append(current_y)

	return heights



# ------------------------------------------------------------
# HEIGHT PROFILE (ROOF)
# ------------------------------------------------------------
func _generate_roof_profile(ground_heights: Array) -> Array:
	var heights: Array = []
	var current_y: int = rng.randi_range(roof_min_y, roof_max_y)

	for x in range(level_width):
		var delta: int = 0
		if rng.randf() < roof_uneven_chance and roof_max_step_height > 0:
			delta = rng.randi_range(-roof_max_step_height, roof_max_step_height)

		current_y = clamp(current_y + delta, roof_min_y, roof_max_y)

		# Make sure the roof is always at least min_vertical_clearance above the ground if ground exists
		var gy = ground_heights[x] if x < ground_heights.size() else null
		if gy != null:
			var max_roof_y_allowed: int = int(gy) - min_vertical_clearance
			current_y = min(current_y, max_roof_y_allowed)

		heights.append(current_y)

	return heights



# ------------------------------------------------------------
# STRUCTURED TERRAIN PAINTING (GROUND)
# ------------------------------------------------------------
func _paint_ground(heights: Array) -> void:
	_surface_run_remaining = 0
	_current_surface_tile = Vector2i.ZERO

	for x in range(heights.size()):
		var h = heights[x]
		if h == null:
			continue

		var surface_y: int = int(h)

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
# ROOF PAINTING + STALACTITES
# ------------------------------------------------------------
func _paint_roof(heights: Array) -> void:
	_roof_run_remaining = 0
	_current_roof_tile = Vector2i.ZERO

	if ground_tilemap == null:
		return

	for x in range(heights.size()):
		var h = heights[x]
		if h == null:
			continue

		var roof_y: int = int(h)

		# --- ROOF COLUMN (thick roof) ---
		var roof_tile := _next_roof_tile()

		# roof_y is the underside; build upward (towards smaller y)
		var thickness: int = max(roof_thickness, 1)
		for d in range(thickness):
			var pos := Vector2i(x, roof_y - d)
			ground_tilemap.set_cell(pos, roof_source_id, roof_tile)

		# --- STALACTITE PROP (hanging from underside) ---
		if prop_scene != null and rng.randf() < stalactite_chance:
			var cell_below := Vector2i(x, roof_y + 1)
			var local: Vector2 = ground_tilemap.map_to_local(cell_below)
			var global: Vector2 = ground_tilemap.to_global(local)

			var prop := prop_scene.instantiate() as Node2D
			if prop != null:
				prop.global_position = global
				add_child(prop)
				_spawned_props.append(prop)




# ------------------------------------------------------------
# SURFACE / SUBSURFACE / SOIL TILE HELPERS
# ------------------------------------------------------------
func _next_surface_tile() -> Vector2i:
	if surface_tiles.is_empty():
		return _fallback_ground()

	if _surface_run_remaining <= 0:
		_current_surface_tile = surface_tiles[rng.randi() % surface_tiles.size()]
		var min_run: int = max(surface_min_run, 1)
		var max_run: int = max(surface_max_run, min_run)
		_surface_run_remaining = rng.randi_range(min_run, max_run)

	_surface_run_remaining -= 1
	return _current_surface_tile


func _next_roof_tile() -> Vector2i:
	if roof_tiles.is_empty():
		return _fallback_ground()

	if _roof_run_remaining <= 0:
		_current_roof_tile = roof_tiles[rng.randi() % roof_tiles.size()]
		var min_run: int = max(roof_min_run, 1)
		var max_run: int = max(roof_max_run, min_run)
		_roof_run_remaining = rng.randi_range(min_run, max_run)

	_roof_run_remaining -= 1
	return _current_roof_tile


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
	var x: int = 0
	while x < heights.size():
		if heights[x] == null:
			var start: int = x
			while x < heights.size() and heights[x] == null:
				x += 1
			var end: int = x - 1

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

	var platform_y: int = base_y - 3
	var px: int = start + max_jump_gap

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

	var last_y: int = min_ground_y

	for x in range(heights.size()):
		if heights[x] != null:
			last_y = heights[x]

		var top_y: int = last_y - background_band_height
		var bottom_y: int = last_y - 2

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

	var x: int = clamp(level_width - door_offset_from_end, 0, heights.size() - 1)
	var ground_y: int = -1

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
# API FOR SPAWNING (GROUND / ROOF / SAFE SPOTS)
# ------------------------------------------------------------
func get_ground_y_at(x: int) -> int:
	if x < 0 or x >= last_ground_heights.size():
		return -1
	if last_ground_heights[x] == null:
		return -1
	return int(last_ground_heights[x])


func get_roof_y_at(x: int) -> int:
	if x < 0 or x >= last_roof_heights.size():
		return -1
	return int(last_roof_heights[x])


func _get_safe_spawn_columns() -> Array[int]:
	var cols: Array[int] = []
	var max_x: int = level_width - spawn_max_x_margin
	for x in range(spawn_min_x, max_x):
		var gy: int = get_ground_y_at(x)
		var ry: int = get_roof_y_at(x)
		if gy == -1 or ry == -1:
			continue
		if gy - ry >= min_vertical_clearance:
			cols.append(x)
	return cols


func get_player_spawn_position() -> Vector2:
	if ground_tilemap == null or ground_tilemap.tile_set == null:
		return Vector2.ZERO

	# Start at 4th column from the left (index 3), but also respect spawn_min_x
	var start_x: int = max(3, spawn_min_x)
	var end_x: int = level_width - spawn_max_x_margin

	for x in range(start_x, end_x):
		var ground_y: int = get_ground_y_at(x)
		if ground_y == -1:
			continue  # no floor here, try next column

		var roof_y: int = get_roof_y_at(x)  # underside of the roof
		# If there is a roof, make sure we have enough space:
		# spawn will be at ground_y - 3, so we need spawn_y > roof_y
		# -> ground_y - 3 > roof_y  => ground_y - roof_y >= 4
		if roof_y != -1:
			if ground_y - roof_y < 4:
				continue  # not enough vertical space, try next column

		# Place player 3 tiles above the floor
		var spawn_cell := Vector2i(x, ground_y - 3)
		var local := ground_tilemap.map_to_local(spawn_cell)
		var global := ground_tilemap.to_global(local)
		global.y -= 16 * 3
		return global

	# Fallback if no column was valid
	return Vector2.ZERO


# Evenly spaced enemy spawn positions on ground (world coords)
func get_enemy_spawn_positions(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if count <= 0:
		return result
	if ground_tilemap == null or ground_tilemap.tile_set == null:
		return result

	var cols := _get_safe_spawn_columns()
	if cols.is_empty():
		return result

	var n: int = min(count, cols.size())
	for i in range(n):
		var t: float = float(i + 1) / float(n + 1)
		var idx: int = int(t * float(cols.size()))
		if idx < 0:
			idx = 0
		if idx >= cols.size():
			idx = cols.size() - 1

		var x: int = cols[idx]
		var gy: int = get_ground_y_at(x)
		if gy == -1:
			continue

		var cell := Vector2i(x, gy - 1)
		var local := ground_tilemap.map_to_local(cell)
		var global := ground_tilemap.to_global(local)
		result.append(global)

	return result
