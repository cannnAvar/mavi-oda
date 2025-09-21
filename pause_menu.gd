extends Control

func _ready() -> void:
	$AnimationPlayer.play("RESET")

func pause():
	get_tree().paused = true
	$AnimationPlayer.play("blur")


func resume():
	get_tree().paused = false
	$AnimationPlayer.play_backwards("blur")

func on_escape_pressed():
	if Input.is_action_just_pressed("Escape") and get_tree().paused == false:
		pause()
	elif Input.is_action_just_pressed("Escape") and get_tree().paused == true:
		resume()


func _on_continue_pressed() -> void:
	resume()

func _on_main_menu_pressed() -> void:
	ChangeScene.change_scene("res://main_menu.tscn")
	resume()

func _on_options_pressed() -> void:
	ChangeScene.change_scene("res://options.tscn")
	resume()


func _on_exit_pressed() -> void:
	get_tree().quit()

func _process(_delta: float) -> void:
	on_escape_pressed()
