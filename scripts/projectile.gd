class_name Projectile
extends Area2D

@export var sprite : Sprite2D
@export var speed: float = 120.0
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.LEFT
var _life_timer: float = 0.0

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	
	if direction.x < 0:
		sprite.scale.y = 1
	else:
		sprite.scale.y = -1
	

func _ready() -> void:
	_life_timer = lifetime
	

func _process(delta: float) -> void:
	# Move in the chosen direction
	position += direction * speed * delta

	# Auto-despawn after lifetime
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()


# Optional if you want collision behavior
func _on_area_entered(area: Area2D) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.name == "PlayerCharacter":
		queue_free()
		if body is PlayerCharacter:
			body.add_health(-1)
