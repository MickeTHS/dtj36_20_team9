class_name PlayerCharacter extends CharacterBody2D

const SPEED := 90.0
const JUMP_VELOCITY := -250.0

var just_attacked = false
var attacking = false

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	anim_sprite.play("idle")

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Horizontal input: ui_left / ui_right
	var direction := Input.get_action_strength("right") - Input.get_action_strength("left")

	if direction != 0:
		velocity.x = direction * SPEED
	else:
		# Smoothly slow down when no input
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Jump: ui_accept (usually Space / A button)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("attack") and is_on_floor():
		just_attacked = true


	# Move the character
	move_and_slide()

	# --- ANIMATION STATE ---
	if not is_on_floor():
		if velocity.y < 0:
			anim_sprite.play("jump")
		#else:
		#	anim_sprite.play("fall")
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

	# Flip sprite based on movement direction
	if direction != 0:
		anim_sprite.flip_h = direction < 0


func _on_attack_timer_timeout() -> void:
	print("timeout")
	attacking = false
