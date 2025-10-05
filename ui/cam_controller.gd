# res://utils/cam_controller.gd
extends Camera2D

@export var pan_speed_px: float = 1000.0        # base screen-space pan speed (px/s)
@export var edge_margin_px: int = 16           # hover margin from screen edges
@export var edge_enabled: bool = false
@export var keys_enabled: bool = true

@export var zoom_step: float = -0.12             # per wheel tick (10%)
@export var min_zoom: float = 0.01              # smaller = farther out
@export var max_zoom: float = 3.0              # larger  = closer in

func _process(dt: float) -> void:
	var dir := Vector2.ZERO
	var vp_size := get_viewport().get_visible_rect().size
	var mpos := get_viewport().get_mouse_position()
	
	# Reset to center + default zoom
	if Input.is_action_just_pressed("cam_reset"):
		global_position = Vector2.ZERO
		zoom = Vector2(1.0, 1.0)

	if keys_enabled:
		var speed = 1.0 if Input.is_action_pressed("cam_boost") else 0.5
		if Input.is_action_pressed("cam_left"):  dir.x -= speed
		if Input.is_action_pressed("cam_right"): dir.x += speed
		if Input.is_action_pressed("cam_up"):    dir.y -= speed
		if Input.is_action_pressed("cam_down"):  dir.y += speed

	if edge_enabled and _is_mouse_in_window():
		# Little slower when edge navigating
		if mpos.x <= edge_margin_px:               dir.x -= 0.3
		if mpos.x >= vp_size.x - edge_margin_px:   dir.x += 0.3
		if mpos.y <= edge_margin_px:               dir.y -= 0.3
		if mpos.y >= vp_size.y - edge_margin_px:   dir.y += 0.3

	if dir != Vector2.ZERO:
		# Clamp the speed, but can be slower
		dir = min(dir.length(), 1.0) * dir.normalized()
		# keep perceived pan speed consistent regardless of zoom:
		var zoom_scalar := zoom.x  # zoom is uniform; x == y
		global_position += dir * (pan_speed_px / max(zoom_scalar, 0.001)) * dt

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(+zoom_step)

func _apply_zoom(delta_step: float) -> void:
	var z :float= clamp(zoom.x * (1.0 + delta_step), min_zoom, max_zoom)
	zoom = Vector2(z, z)
	
func _is_mouse_in_window() -> bool:
	# Uses OS/global mouse position against the current window rect.
	var win := get_window()
	var mp_global := DisplayServer.mouse_get_position()
	var rect := Rect2i(win.position, win.size)
	return rect.has_point(Vector2i(mp_global))
