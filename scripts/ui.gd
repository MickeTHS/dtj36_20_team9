class_name UI extends Node

@export var restart_button : TextureButton
@export var level_label : Label
@export var heart0 : UIHeart
@export var heart1 : UIHeart
@export var heart2 : UIHeart
@export var heart3 : UIHeart


func set_health(health: int) -> void:
	heart0.set_point(0)
	heart1.set_point(0)
	heart2.set_point(0)
	heart3.set_point(0)
	
	if health >= 2:
		heart0.set_point(2)
	if health >= 4:
		heart1.set_point(2)
	if health >= 6:
		heart2.set_point(2)
	if health == 8:
		heart3.set_point(2)
		
	if health == 1:
		heart0.set_point(1)
	if health == 3:
		heart1.set_point(1)
	if health == 5:
		heart2.set_point(1)
	if health == 7:
		heart3.set_point(1)
	
	
func set_level(level: int) -> void:
	level_label.text = "Level " + str(level)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	restart_button.focus_mode = Control.FOCUS_NONE
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
