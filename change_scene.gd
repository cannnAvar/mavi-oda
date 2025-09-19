extends CanvasLayer



func change_scene(scene_path : String) -> void:
	$AnimationPlayer.play("Fade")
	await $AnimationPlayer.animation_finished
	
	
	get_tree().change_scene_to_file(scene_path)
	
	$AnimationPlayer.play_backwards("Fade")
