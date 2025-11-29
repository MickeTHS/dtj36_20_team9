class_name UI extends Node

@export var restart_button : TextureButton
@export var level_label : Label

func set_level(level: int) -> void:
	level_label.text = "Level " + str(level)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	restart_button.focus_mode = Control.FOCUS_NONE
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
