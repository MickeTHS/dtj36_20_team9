class_name AttackArea
extends Area2D

@export var hit_audio : AudioStreamPlayer
@export var is_player : bool = false
@export var sprite : Sprite2D
@export var speed: float = 120.0
@export var lifetime: float = 0.3

var direction: Vector2 = Vector2.LEFT
var _life_timer: float = 0.0
var _disabled: bool = false

func _ready() -> void:
	_life_timer = lifetime


func _process(delta: float) -> void:
	if _disabled:
		return

	_life_timer -= delta
	if _life_timer <= 0.0:
		disable()

func disable() -> void:
	if _disabled:
		return
	_disabled = true

	# turn off collision
	monitoring = false
	monitorable = false

	# hide visuals
	if sprite:
		sprite.visible = false
	visible = false

	# stop movement & updates
	set_process(false)
	set_physics_process(false)


func enable():
	_disabled = false
	_life_timer = lifetime
	monitoring = true
	monitorable = true
	visible = true
	set_process(true)
	set_physics_process(true)


# Optional if you want collision behavior
func _on_area_entered(area: Area2D) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	print("attack_area body enter")
	if body is EnemyCharacter:
		hit_audio.play()
		body.on_hit(global_position)
	if body is RigidProp:
		hit_audio.play()
		body.on_hit(global_position)
	if not is_player and body is PlayerCharacter:
		body.add_health(-1, "Sword")
