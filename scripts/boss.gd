class_name BossCharacter
extends CharacterBody2D

@export var game : Game

# --- HIT FEEDBACK ---
@export var knockback_force: float = 220.0
@export var hit_flash_color: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var hit_flash_time: float = 0.25

# --- BASIC SETUP ---
@export var player: PlayerCharacter
@export var has_projectile: bool = true
@export var attack_area: AttackArea

@export var base_speed: float = 50.0
@export var preferred_distance: float = 60.0
@export var preferred_distance_tolerance: float = 8.0
@export var attack_range: float = 25.0
@export var attack_duration: float = 0.5

# --- PROJECTILES ---
@export var projectile_scene: PackedScene
@export var min_projectile_interval: float = 1.0
@export var max_projectile_interval: float = 3.0
@export var projectile_spawn_offset: Vector2 = Vector2(8, 16)

const JUMP_VELOCITY := -150.0
@export var hp: int = 12

# --- CRUSH ESCAPE (boss standing on player) ---
@export var crush_horizontal_threshold: float = 12.0
@export var crush_vertical_threshold: float = 8.0
@export var crush_jump_velocity: float = -220.0
@export var crush_escape_cooldown: float = 0.6
@export var crush_horizontal_boost: float = 80.0

# --- LIMIT ENGAGEMENT RANGE ---
@export var max_move_distance: float = 400.0
@export var max_shoot_distance: float = 500.0

var _crush_timer: float = 0.0
var move_speed: float = 60.0

var attacking: bool = false
var is_dying: bool = false

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _projectile_timer: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var magic_audio: AudioStreamPlayer = $MagicAttackAudio


func _ready() -> void:
	move_speed = base_speed

	if preferred_distance < 10.0:
		preferred_distance = 10.0

	attack_timer.one_shot = true
	anim_sprite.play("idle")

	_reset_projectile_timer()


func _reset_projectile_timer() -> void:
	var min_t : float = max(min_projectile_interval, 0.1)
	var max_t : float = max(max_projectile_interval, min_t)
	_projectile_timer = randf_range(min_t, max_t)


func death() -> void:
	game.game_end()
	hp = 12
	position = Vector2(839, 18)
	is_dying = false

# =============================================================
# MAIN TICK
# =============================================================
func _physics_process(delta: float) -> void:
	if is_dying:
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	if _crush_timer > 0.0:
		_crush_timer -= delta

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Movement AI
	var direction := _get_ai_direction()

	if not attacking:
		if direction != 0.0:
			velocity.x = direction * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
	else:
		velocity.x = 0.0

	_handle_crush_escape()
	_check_attack()
	_handle_spawn_projectile(delta)

	move_and_slide()

	# Animation
	if not is_on_floor():
		if velocity.y < 0.0:
			anim_sprite.play("jump")
	elif attacking:
		anim_sprite.play("attack")
		if attack_area:
			attack_area.enable()
	else:
		if abs(velocity.x) > 10.0:
			anim_sprite.play("walk")
		else:
			anim_sprite.play("idle")

	# Direction face
	if direction != 0.0:
		anim_sprite.flip_h = direction < 0.0
		if attack_area:
			attack_area.scale.x = direction


# =============================================================
# POSITIONING — stay in melee bubble
# =============================================================
func _get_ai_direction() -> float:
	if player == null:
		return 0.0

	var dx := player.global_position.x - global_position.x
	var dist : float = abs(dx)

	if max_move_distance > 0.0 and dist > max_move_distance:
		return 0.0

	var sign_x := 1.0
	if dx < 0.0:
		sign_x = -1.0

	var target := preferred_distance
	var tol := preferred_distance_tolerance

	if dist < target - tol:
		return -sign_x  # too close
	elif dist > target + tol:
		return sign_x   # too far
	else:
		return 0.0      # perfect distance


# =============================================================
# ESCAPE IF STANDING ON PLAYER
# =============================================================
func _handle_crush_escape() -> void:
	if player == null:
		return
	if _crush_timer > 0.0:
		return

	var dx := player.global_position.x - global_position.x
	var dy := player.global_position.y - global_position.y

	if abs(dx) <= crush_horizontal_threshold \
	and dy > 0.0 and dy <= crush_vertical_threshold \
	and is_on_floor():

		# Random escape direction
		var sign := -1.0
		if randf() < 0.5:
			sign = 1.0

		velocity.y = crush_jump_velocity
		velocity.x = sign * (move_speed + crush_horizontal_boost)

		attacking = false
		_crush_timer = crush_escape_cooldown


# =============================================================
# PROJECTILE SHOOTING
# =============================================================
func _handle_spawn_projectile(delta: float) -> void:
	if not has_projectile or is_dying:
		return
	if projectile_scene == null or player == null:
		return

	_projectile_timer -= delta
	if _projectile_timer > 0.0:
		return

	var dx := player.global_position.x - global_position.x
	var dist : float = abs(dx)

	if max_shoot_distance > 0.0 and dist > max_shoot_distance:
		_reset_projectile_timer()
		return

	var dir_sign := 1.0
	if dx < 0.0:
		dir_sign = -1.0

	var spawn_pos := global_position
	spawn_pos.x += projectile_spawn_offset.x * dir_sign
	spawn_pos.y += projectile_spawn_offset.y

	var proj := projectile_scene.instantiate()
	if magic_audio:
		magic_audio.play()

	var proj_node := proj as Node2D
	proj_node.global_position = spawn_pos
	proj_node.set_direction(Vector2(dir_sign, 0.0))

	get_tree().current_scene.add_child(proj)

	_reset_projectile_timer()


# =============================================================
# MELEE ATTACK
# =============================================================
func _check_attack() -> void:
	if player == null or is_dying or attacking:
		return

	var dx := player.global_position.x - global_position.x
	var dist : float = abs(dx)

	if dist <= attack_range and is_on_floor():
		attacking = true
		attack_timer.start(attack_duration)


func _on_attack_timer_timeout() -> void:
	attacking = false
	if attack_area:
		attack_area.disable()


# =============================================================
# HIT REACTION
# =============================================================
func on_hit(hit_position: Vector2) -> void:
	if is_dying:
		return

	# Knockback
	var dir := (global_position - hit_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	velocity.x = dir.x * knockback_force

	if is_on_floor():
		velocity.y = JUMP_VELOCITY * 0.4

	# flash
	anim_sprite.modulate = hit_flash_color
	var tween := create_tween()
	tween.tween_property(anim_sprite, "modulate", Color.WHITE, hit_flash_time)

	hp -= 1
	if hp <= 0 and not is_dying:
		is_dying = true
		has_projectile = false
		attacking = false

		var t := get_tree().create_timer(1.0)
		t.timeout.connect(death)
