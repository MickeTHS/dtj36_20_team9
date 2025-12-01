# -------
# became too complex due to our ideas of making 
# "random" enemies with random properties
# in the end this became quite a mess
# -------

class_name EnemyCharacter
extends CharacterBody2D

@export var knockback_force: float = 220.0
@export var hit_flash_color: Color = Color(1.0, 0.0, 0.0, 1.0) # reddish
@export var hit_flash_time: float = 0.25


@export var player: PlayerCharacter
@export var is_boss : bool = false
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
@export var attack_area : AttackArea

const JUMP_VELOCITY := -150.0

@export var stuck_time_before_jump: float = 0.4
@export var stuck_distance_threshold: float = 2.0
@export var is_flying: bool = false
@export var hp: int = 1

@export var crush_horizontal_threshold: float = 12.0
@export var crush_vertical_threshold: float = 8.0
@export var crush_jump_velocity: float = -220.0
@export var crush_escape_cooldown: float = 0.6
@export var crush_horizontal_boost: float = 80.0

@export var max_move_distance: float = 400.0
@export var max_shoot_distance: float = 500.0

var _crush_timer: float = 0.0

var move_speed: float = 60.0

var just_attacked: bool = false
var attacking: bool = false
var is_dying: bool = false

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var _last_x: float = 0.0
var _stuck_timer: float = 0.0
var _projectile_timer: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var magic_audio: AudioStreamPlayer = $MagicAttackAudio


func _randomize() -> void:
	move_to_player = false
	keep_distance_player = false

	move_speed = base_speed + randf_range(-speed_variation, speed_variation)
	if move_speed < 10.0:
		move_speed = 10.0

	preferred_distance += randf_range(-preferred_distance_variation, preferred_distance_variation)
	if preferred_distance < 10.0:
		preferred_distance = 10.0

	if is_boss:
		move_to_player = true
		preferred_distance = max(attack_range * 0.8, 16.0)
		preferred_distance_tolerance = 8.0
		return

	var mode: int = randi() % 2
	match mode:
		0:
			move_to_player = true
			print("move_to_player")
		1:
			keep_distance_player = true
			print("keep_distance_player")


func _ready() -> void:
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
		var min_t: float = max(min_projectile_interval, 0.1)
		var max_t: float = max(max_projectile_interval, min_t)
		_projectile_timer = randf_range(min_t, max_t)


func death() -> void:
	queue_free()


func _physics_process(delta: float) -> void:
	if is_dying:
		if not is_flying and not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return
		
	if _crush_timer > 0.0:
		_crush_timer -= delta

	if not is_flying:
		if not is_on_floor():
			velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	var direction: float = _get_ai_direction()

	if not attacking:
		if direction != 0.0:
			velocity.x = direction * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
	else:
		velocity.x = 0.0

	if not is_flying:
		_handle_stuck_and_jump(delta, direction)

	_handle_crush_escape()
	_check_attack()
	_handle_spawn_projectile(delta)

	move_and_slide()

	if is_flying:
		if abs(velocity.x) > 10.0:
			anim_sprite.play("walk")
		else:
			anim_sprite.play("idle")
	else:
		if not is_on_floor():
			if velocity.y < 0.0:
				anim_sprite.play("jump")
		elif attacking:
			anim_sprite.play("attack")
			print("play attack " + self.name)
			if attack_area:
				print("enable attack " + self.name)
				attack_area.enable()
		
		else:
			if abs(velocity.x) > 10.0:
				anim_sprite.play("walk")
			else:
				anim_sprite.play("idle")

	if direction != 0.0:
		anim_sprite.flip_h = direction < 0.0
		if attack_area:
			attack_area.scale.x = direction
		

func _handle_crush_escape() -> void:
	if player == null:
		return
	if is_flying:
		return
	if _crush_timer > 0.0:
		return

	var dx: float = player.global_position.x - global_position.x
	var dy: float = player.global_position.y - global_position.y

	if abs(dx) <= crush_horizontal_threshold \
		and dy > 0.0 and dy <= crush_vertical_threshold \
		and is_on_floor():

		var sign: float = -1.0
		if randf() < 0.5:
			sign = 1.0

		velocity.y = crush_jump_velocity
		velocity.x = sign * (move_speed + crush_horizontal_boost)

		attacking = false
		_crush_timer = crush_escape_cooldown


func _get_ai_direction() -> float:
	if player == null:
		return 0.0

	var dx: float = player.global_position.x - global_position.x
	var dist: float = abs(dx)

	if max_move_distance > 0.0 and dist > max_move_distance:
		return 0.0

	var dir: float = 0.0
	var sign_x: float = 0.0
	if dx > 0.0:
		sign_x = 1.0
	elif dx < 0.0:
		sign_x = -1.0

	var target_distance: float = preferred_distance
	var tolerance: float = preferred_distance_tolerance

	if move_to_player:
		if dist < target_distance - tolerance:
			dir = -sign_x
		elif dist > target_distance + tolerance:
			dir = sign_x
		else:
			dir = 0.0
	elif keep_distance_player:
		if dist < target_distance - tolerance:
			dir = -sign_x
		elif dist > target_distance + tolerance:
			dir = sign_x
		else:
			dir = 0.0

	return dir


func _handle_spawn_projectile(delta: float) -> void:
	if not has_projectile:
		return
	if projectile_scene == null:
		return
	if player == null:
		return
	if is_dying:
		return

	_projectile_timer -= delta
	if _projectile_timer > 0.0:
		return

	var dx: float = player.global_position.x - global_position.x
	var dist: float = abs(dx)

	if max_shoot_distance > 0.0 and dist > max_shoot_distance:
		_reset_projectile_timer()
		return

	var dir_sign: float = 0.0
	if dx > 0.0:
		dir_sign = 1.0
	elif dx < 0.0:
		dir_sign = -1.0

	if dir_sign == 0.0:
		_reset_projectile_timer()
		return

	var spawn_pos: Vector2 = global_position
	spawn_pos.x += projectile_spawn_offset.x * dir_sign
	spawn_pos.y += projectile_spawn_offset.y

	var proj := projectile_scene.instantiate()
	magic_audio.play()
	var proj_node := proj as Node2D
	if proj_node:
		proj_node.global_position = spawn_pos
		proj_node.set_direction(Vector2(dir_sign, 0.0))

	get_tree().current_scene.add_child(proj)

	_reset_projectile_timer()


func _handle_stuck_and_jump(delta: float, direction: float) -> void:
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
	if player == null or attacking or is_dying:
		return

	var dx: float = player.global_position.x - global_position.x
	var dist: float = abs(dx)

	if dist <= attack_range and is_on_floor():
		attacking = true
		if attack_timer:
			attack_timer.start(attack_duration)


func _on_attack_timer_timeout() -> void:
	attacking = false


func on_hit(hit_position: Vector2) -> void:
	if is_dying:
		return

	# --- KNOCKBACK ---
	var dir := (global_position - hit_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	velocity.x = dir.x * knockback_force

	
	if not is_flying and is_on_floor():
		velocity.y = JUMP_VELOCITY * 0.4

	# --- HIT FLASH ---
	if anim_sprite:
		
		anim_sprite.modulate = hit_flash_color

		var tween := create_tween()
		tween.tween_property(
			anim_sprite,
			"modulate",
			Color.WHITE,
			hit_flash_time
		)

	# --- HP LOGIC ---
	hp -= 1
	print("enemy hit, hp: ", hp)

	if hp <= 0 and not is_dying:
		is_dying = true
		has_projectile = false
		attacking = false
		
		anim_sprite.play("death")

		var timer := get_tree().create_timer(1.0)
		timer.timeout.connect(death)
