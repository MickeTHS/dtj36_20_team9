# ----- 
# rigid prop, destructible
# -----

class_name RigidProp
extends RigidBody2D

@export var sprite : Sprite2D
@export var destroy_animation : AnimatedSprite2D
@export var take_damage: int = 0
@export var hp: int = 999999
@export var hit_impulse: float = 400

var is_dying: bool = false

func _ready() -> void:
	pass


func on_hit(from_position: Vector2) -> void:
	
	var dir := (global_position - from_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT

	apply_impulse(dir * hit_impulse)

	hp -= 1
	
	if hp <= 0 and not is_dying:
		destroy_animation.visible = true
		destroy_animation.frame = 0
		destroy_animation.play("default")
		sprite.visible = false
		is_dying = true
		
		var timer := get_tree().create_timer(1.0)
		timer.timeout.connect(death)

func death() -> void:
	queue_free()


func _on_body_entered(body: Node) -> void:
	if body is PlayerCharacter:
		if take_damage > 0:
			(body as PlayerCharacter).add_health(-abs(take_damage), "Prop")
