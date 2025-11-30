class_name PlayerCharacter
extends CharacterBody2D

@export var hit_audio : AudioStreamPlayer
@export var hit_on_spike_audio : AudioStreamPlayer
@export var sword_attack_audio : AudioStreamPlayer
@export var jump_audio : AudioStreamPlayer
@export var magic_audio : AudioStreamPlayer
@export var level_up_audio : AudioStreamPlayer
@export var game_over_audio : AudioStreamPlayer

@export var ui: UI
@export var iframe_duration: float = 1.0   # seconds of invulnerability
@export var jump_cut_factor: float = 0.5   # 0–1: tap = short jump, hold = full
@export var attack_area : AttackArea

const SPEED := 90.0
const JUMP_VELOCITY := -250.0

var just_attacked: bool = false
var attacking: bool = false
var health: int = 8

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var is_invulnerable: bool = false
var _blink_accum: float = 0.0
var _blink_interval: float = 0.1  # how fast the sprite blinks

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var iframe_timer: Timer = $IFrameTimer

func set_health(h: int) -> void:
	
	health = h
	if ui:
		ui.set_health(health)

func add_health(change: int, source: String) -> void:
	
	# If taking damage while invulnerable, ignore it
	if change < 0:
		if is_invulnerable:
			return
		
		if source == "Stalactite" or source == "DeathZone" or source == "Projectile":
			hit_on_spike_audio.play()
		
		start_iframe()

	health += change
	if health < 0:
		health = 0

	if ui:
		ui.set_health(health)


func start_iframe() -> void:
	
	is_invulnerable = true
	_blink_accum = 0.0
	anim_sprite.visible = true  # start from visible
	if iframe_timer:
		iframe_timer.start(iframe_duration)


func _ready() -> void:
	anim_sprite.play("idle")
	if ui:
		ui.set_health(health)


func _process(delta: float) -> void:
	# Handle blinking during invulnerability
	if is_invulnerable:
		_blink_accum += delta
		if _blink_accum >= _blink_interval:
			anim_sprite.visible = not anim_sprite.visible
			_blink_accum = 0.0
	else:
		# Ensure visible when not invulnerable
		anim_sprite.visible = true


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Horizontal input
	var direction := Input.get_action_strength("right") - Input.get_action_strength("left")

	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Jump start
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_audio.play()

	# Variable jump height: cut jump when button is released while going up
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_factor

	# Attack
	if Input.is_action_just_pressed("attack"):
		just_attacked = true
		attack_area.enable()
		sword_attack_audio.play()

	# Move the character
	move_and_slide()

# Flip sprite based on movement direction
	if direction != 0:
		anim_sprite.flip_h = direction < 0
		attack_area.scale.x = direction
	
	# --- ANIMATION STATE ---
	if not is_on_floor():
		if velocity.y < 0:
			anim_sprite.play("jump")
	elif just_attacked:
		attacking = true
		anim_sprite.play("attack")
		$AttackTimer.start(0.5)
		just_attacked = false
	elif not attacking:
		if abs(velocity.x) > 10:
			anim_sprite.play("walk")
		else:
			anim_sprite.play("idle")


func _on_attack_timer_timeout() -> void:
	attacking = false


func _on_i_frame_timer_timeout() -> void:
	is_invulnerable = false
	anim_sprite.visible = true
