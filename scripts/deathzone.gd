class_name DeathZone
extends Node2D

@export var player: PlayerCharacter
@export var spikes_sprite: PackedScene

@export var row_length: int = 200        # how many spikes in the row
@export var sprite_spacing: float = 16.0 # pixels between spikes
@export var kill_distance: float = 8.0   # how close to this Y before we kill the player


func _ready() -> void:
	# Spawn a long row of spike sprites centered on this node's position
	if spikes_sprite == null:
		return

	for i in range(row_length):
		var spike := spikes_sprite.instantiate() as Node2D
		if spike == null:
			continue

		# Lay them out from left to right in local space
		var x_offset: float = float(i) * sprite_spacing
		spike.position = Vector2(x_offset, 0.0)
		add_child(spike)


func _process(delta: float) -> void:
	if player == null:
		return

	# Compare global Y positions
	var zone_y: float = global_position.y
	var player_y: float = player.global_position.y

	# "Near my Y coordinate" – you can adjust kill_distance
	if abs(player_y - zone_y) <= kill_distance or player_y > zone_y:
		_kill_player()


func _kill_player() -> void:
	if player == null:
		return

	# Use your existing health system
	player.add_health(-9999, "DeathZone")
