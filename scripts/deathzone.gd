class_name DeathZone
extends Node2D

@export var player: PlayerCharacter
@export var spikes_sprite: PackedScene

@export var row_length: int = 200
@export var sprite_spacing: float = 16.0
@export var kill_distance: float = 8.0


func _ready() -> void:
	if spikes_sprite == null:
		return

	for i in range(row_length):
		var spike := spikes_sprite.instantiate() as Node2D
		if spike == null:
			continue

		var x_offset: float = float(i) * sprite_spacing
		spike.position = Vector2(x_offset, 0.0)
		add_child(spike)


func _process(delta: float) -> void:
	if player == null:
		return

	var zone_y: float = global_position.y
	var player_y: float = player.global_position.y


	if abs(player_y - zone_y) <= kill_distance or player_y > zone_y:
		_kill_player()


func _kill_player() -> void:
	if player == null:
		return

	player.add_health(-9999, "DeathZone")
