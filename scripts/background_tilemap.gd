extends TileMapLayer

@export var target_camera: Camera2D
@export var parallax_factor := Vector2(0.3, 0.0) # X slower, no vertical parallax by default

var _base_offset: Vector2


func _ready() -> void:
	if target_camera == null:
		push_error("Parallax: target_camera is not assigned!")
		return

	# Remember the initial offset so background stays visually in place
	_base_offset = global_position - (target_camera.global_position * parallax_factor)


func _process(delta: float) -> void:
	if target_camera == null:
		return

	global_position = _base_offset + target_camera.global_position * parallax_factor
