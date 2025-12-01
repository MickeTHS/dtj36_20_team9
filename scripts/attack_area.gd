# ------------
# An attack that uses an Area2D
# Can be the player or npc making the attack
# When hitting a body or another area will call on_hit()
# ------------
class_name AttackArea
extends Area2D

@export var player_character : PlayerCharacter
@export var hit_audio : AudioStreamPlayer
@export var is_player : bool = false
@export var sprite : Sprite2D
@export var speed: float = 120.0
@export var lifetime: float = 0.3
@export var damage : int = 1

var rng = RandomNumberGenerator.new()

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

	monitoring = false
	monitorable = false

	if sprite:
		sprite.visible = false
	visible = false

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


func _on_area_entered(area: Area2D) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	print("attack_area body enter")
	if is_player and body is EnemyCharacter:
		body.on_hit(global_position)
	if is_player and body is BossCharacter:
		body.on_hit(global_position)
	if is_player and body is RigidProp:
		hit_audio.play()
		body.on_hit(global_position)
		
		if player_character:
			if rng.randi() % 3 == 2:
				player_character.add_health(1, "Heart")
	if not is_player and body is PlayerCharacter:
		body.add_health(abs(damage) * -1, "Sword")
