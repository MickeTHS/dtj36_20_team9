class_name EnemyCharacter
extends CharacterBody2D

@export var player: PlayerCharacter

@export var has_projectile: bool = true
@export var has_sword: bool = false
@export var has_magic: bool = false

@export var move_to_player: bool = false
@export var keep_distance_player: bool = false

@export var base_speed: float = 50.0
@export var speed_variation: float = 30.0
@export var preferred_distance: float = 80.0
@export var preferred_distance_variation: float = 40.0
@export var preferred_distance_tolerance: float = 10.0
@export var attack_range: float = 25.0
@export var attack_duration: float = 0.5

@export var projectile_scene: PackedScene
@export var min_projectile_interval: float = 1.0
@export var max_projectile_interval: float = 3.0
@export var projectile_spawn_offset: Vector2 = Vector2(8, -8)

const JUMP_VELOCITY := -150.0

@export var stuck_time_before_jump: float = 0.4
@export var stuck_distance_threshold: float = 2.0

var move_speed: float = 60.0

var just_attacked: bool = false
var attacking: bool = false

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var _last_x: float = 0.0
var _stuck_timer: float = 0.0
var _projectile_timer: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer


func _randomize() -> void:
	# Randomize behavior and stats for this enemy
	
	move_to_player = false
	keep_distance_player = false

	var mode: int = randi() % 2
	match mode:
		0:
			move_to_player = true
			print("move_to_player")
		1:
			keep_distance_player = true
			print("keep_distance_player")

	# Randomize speed a bit
	move_speed = base_speed + randf_range(-speed_variation, speed_variation)
	if move_speed < 10.0:
		move_speed = 10.0

	# Randomize preferred distance if using distance-based AI
	preferred_distance += randf_range(-preferred_distance_variation, preferred_distance_variation)
	if preferred_distance < 10.0:
		preferred_distance = 10.0
	

func _ready() -> void:
	# Each enemy gets its own random behavior/stats
	_randomize()

	anim_sprite.play("idle")
	if attack_timer:
		attack_timer.one_shot = true

	_last_x = global_position.x
	_reset_projectile_timer()
	
func _reset_projectile_timer() -> void:
	if min_projectile_interval <= 0.0 and max_projectile_interval <= 0.0:
		_projectile_timer = 0.0
	else:
		var min_t : float = max(min_projectile_interval, 0.1)
		var max_t : float = max(max_projectile_interval, min_t)
		_projectile_timer = randf_range(min_t, max_t)


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction: float = _get_ai_direction()

	# Horizontal movement
	if not attacking:
		if direction != 0.0:
			velocity.x = direction * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
	else:
		# During attack, optionally stop moving
		velocity.x = 0.0

	# Check if stuck and maybe jump
	_handle_stuck_and_jump(delta, direction)

	# Simple attack check
	_check_attack()
	
	# Projectile shooting
	_handle_spawn_projectile(delta)

	# Move the character
	move_and_slide()

	# --- ANIMATION STATE ---
	if not is_on_floor():
		if velocity.y < 0.0:
			anim_sprite.play("jump")
	elif attacking:
		anim_sprite.play("attack")
	else:
		if abs(velocity.x) > 10.0:
			anim_sprite.play("walk")
		else:
			anim_sprite.play("idle")

	# Flip sprite based on movement direction
	if direction != 0.0:
		anim_sprite.flip_h = direction < 0.0


func _get_ai_direction() -> float:
	if player == null:
		return 0.0

	var dx: float = player.global_position.x - global_position.x
	var dist: float = abs(dx)

	var dir: float = 0.0
	var sign_x: float = 0.0
	if dx > 0.0:
		sign_x = 1.0
	elif dx < 0.0:
		sign_x = -1.0

	if move_to_player:
		dir = sign_x
	elif keep_distance_player:
		if dist < preferred_distance - preferred_distance_tolerance:
			dir = -sign_x # too close, back away
		elif dist > preferred_distance + preferred_distance_tolerance:
			dir = sign_x  # too far, approach
		else:
			dir = 0.0     # good distance

	return dir


func _handle_spawn_projectile(delta: float) -> void:
	if not has_projectile:
		return
	if projectile_scene == null:
		return
	if player == null:
		return

	_projectile_timer -= delta
	if _projectile_timer > 0.0:
		return

	# Only shoot if roughly facing the player horizontally
	var dx: float = player.global_position.x - global_position.x
	var dir_sign: float = 0.0
	if dx > 0.0:
		dir_sign = 1.0
	elif dx < 0.0:
		dir_sign = -1.0

	if dir_sign == 0.0:
		_reset_projectile_timer()
		return

	# Spawn projectile slightly in front of the enemy
	var spawn_pos: Vector2 = global_position
	spawn_pos.x += projectile_spawn_offset.x * dir_sign
	spawn_pos.y += projectile_spawn_offset.y

	var proj := projectile_scene.instantiate()
	var proj_node := proj as Node2D
	if proj_node:
		proj_node.global_position = spawn_pos

		# Flip or set direction on projectile if it supports it
		# (optional; depends on your Projectile script)
		if "direction" in proj_node:
			proj_node.direction = Vector2(dir_sign, 0.0)

	get_tree().current_scene.add_child(proj)

	_reset_projectile_timer()

func _handle_stuck_and_jump(delta: float, direction: float) -> void:
	# Only care about being stuck if trying to move on the floor and not attacking
	if is_on_floor() and not attacking and abs(direction) > 0.0:
		var moved_x: float = abs(global_position.x - _last_x)

		if moved_x < stuck_distance_threshold:
			_stuck_timer += delta
			if _stuck_timer >= stuck_time_before_jump:
				velocity.y = JUMP_VELOCITY
				_stuck_timer = 0.0
		else:
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

	_last_x = global_position.x


func _check_attack() -> void:
	if player == null or attacking:
		return

	var dx: float = player.global_position.x - global_position.x
	var dist: float = abs(dx)

	if dist <= attack_range and is_on_floor():
		attacking = true
		if attack_timer:
			attack_timer.start(attack_duration)


func _on_attack_timer_timeout() -> void:
	attacking = false
