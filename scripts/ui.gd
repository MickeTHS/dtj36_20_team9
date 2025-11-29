extends Node

@export var restart_button : TextureButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	restart_button.focus_mode = Control.FOCUS_NONE
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
