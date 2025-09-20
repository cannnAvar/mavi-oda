extends Control



func _on_start_pressed() -> void:
	ChangeScene.change_scene("res://control.tscn")


func _on_options_pressed() -> void:
	ChangeScene.change_scene("res://options.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
