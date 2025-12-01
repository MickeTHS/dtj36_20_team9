# -----
# really fast and dirty UI due to severe time constraints
# -----

class_name UI
extends Node

@export var game : Game
@export var restart_button : TextureButton

@export var lifebar : Node2D
@export var heart0 : UIHeart
@export var heart1 : UIHeart
@export var heart2 : UIHeart
@export var heart3 : UIHeart
@export var main_menu_content : Control
@export var credits : Control
@export var start_button : TextureButton
@export var credits_button : TextureButton
@export var exit_button : TextureButton

@export var game_over_text : TextureRect
@export var title_text : TextureRect
@export var the_end_text : TextureRect

func show_game_over() -> void:
	game_over_text.visible = true
	title_text.visible = false
	the_end_text.visible = false
	main_menu_content.visible = true
	lifebar.visible = false
	
	

func show_the_end() -> void:
	game_over_text.visible = false
	title_text.visible = false
	the_end_text.visible = true
	
	main_menu_content.visible = true
	lifebar.visible = false
	

func show_main_menu() -> void:
	main_menu_content.visible = true
	lifebar.visible = false
	game_over_text.visible = false
	title_text.visible = true
	the_end_text.visible = false
	

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
	lifebar.visible = false
	restart_button.focus_mode = Control.FOCUS_NONE
	start_button.focus_mode = Control.FOCUS_NONE
	credits_button.focus_mode = Control.FOCUS_NONE
	exit_button.focus_mode = Control.FOCUS_NONE

	main_menu_content.visible = true
	if credits:
		credits.visible = false



func _process(delta: float) -> void:
	pass

func start_game() -> void:
	lifebar.visible = true

func _on_start_button_pressed() -> void:
	main_menu_content.visible = false
	if credits:
		credits.visible = false
	
	game.start_game()


func _on_credits_button_pressed() -> void:
	if credits == null:
		return

	
	if credits.visible:
		credits.visible = false
		main_menu_content.visible = true
	else:
		credits.visible = true
		main_menu_content.visible = false


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_credits_back_button_pressed() -> void:
	credits.visible = false
	main_menu_content.visible = true
