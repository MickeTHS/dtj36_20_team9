class_name Prop extends Area2D

@export var take_damage : int = 0
@export var hp : int = 999999

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.name == "PlayerCharacter":
		
		queue_free()
		if take_damage > 0 and body is PlayerCharacter:
			body.add_health(-abs(take_damage))
