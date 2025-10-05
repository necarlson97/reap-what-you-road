extends CanvasLayer

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_hide"): visible = !visible
