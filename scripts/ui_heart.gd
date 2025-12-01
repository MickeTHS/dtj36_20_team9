# ------
# shows full, half or empty heart
# ------

class_name UIHeart extends Sprite2D

var points : int = 2

func set_point(point: int) -> void:
	points = point
	if point == 2:
		frame = 0
	elif point == 1:
		frame = 2
	elif point == 0:
		frame = 4

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass
