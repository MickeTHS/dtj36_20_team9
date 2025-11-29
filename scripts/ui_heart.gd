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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
