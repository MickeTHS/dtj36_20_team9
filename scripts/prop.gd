# -----
# standard prop 
# -----

class_name Prop extends Area2D

@export var take_damage : int = 0
@export var hp : int = 999999


func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	if body.name == "PlayerCharacter":
		if take_damage > 0 and body is PlayerCharacter:
			body.add_health(-abs(take_damage), "Stalactite")
