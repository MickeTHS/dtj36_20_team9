class_name UI
extends Node

@export var restart_button : TextureButton

@export var heart0 : UIHeart
@export var heart1 : UIHeart
@export var heart2 : UIHeart
@export var heart3 : UIHeart
@export var main_menu_content : Control
@export var credits : Control
@export var start_button : TextureButton
@export var credits_button : TextureButton
@export var exit_button : TextureButton


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
	pass


func _ready() -> void:
	restart_button.focus_mode = Control.FOCUS_NONE
	start_button.focus_mode = Control.FOCUS_NONE
	credits_button.focus_mode = Control.FOCUS_NONE
	exit_button.focus_mode = Control.FOCUS_NONE

	# Start with main menu visible, credits hidden
	main_menu_content.visible = true
	if credits:
		credits.visible = false



func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	print("start")
	# Hide main menu & credits, unpause game
	main_menu_content.visible = false
	if credits:
		credits.visible = false



func _on_credits_button_pressed() -> void:
	if credits == null:
		return

	# Toggle between main menu and credits
	if credits.visible:
		# Go back to main menu
		credits.visible = false
		main_menu_content.visible = true
	else:
		# Show credits, hide main menu buttons
		credits.visible = true
		main_menu_content.visible = false


func _on_exit_button_pressed() -> void:
	# On desktop this quits the game.
	# On web it just stops the Godot instance.
	get_tree().quit()


func _on_credits_back_button_pressed() -> void:
	credits.visible = false
	main_menu_content.visible = true
