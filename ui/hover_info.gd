extends CanvasLayer

@onready var panel: Control        = $Panel
@onready var label: RichTextLabel  = $Panel/Text

var _fade: Tween
var _source_id: int = -1  # which building 'owns' the tooltip right now

func _ready() -> void:
	panel.visible = false
	panel.modulate.a = 0.0
	# optional: keep panel near mouse each frame if desired
	set_process(false)

func show_info(source: Object, text: String, screen_pos: Vector2) -> void:
	_source_id = source.get_instance_id()
	label.text = text
	_move_to(screen_pos)
	_fade_in()
	set_process(true)
	await get_tree().process_frame    # let layout/metrics update
	panel.reset_size()     

func update_pos(source: Object, screen_pos: Vector2) -> void:
	# Only update if the same source is still hovering
	if _source_id == source.get_instance_id():
		_move_to(screen_pos)

func hide_info(source: Object) -> void:
	if _source_id == source.get_instance_id():
		_fade_out()
		set_process(false)
		_source_id = -1

func _move_to(screen_pos: Vector2) -> void:
	# offset a bit so we don’t cover the pointer
	var p := screen_pos + Vector2(14, 10)
	# keep inside viewport
	var vp := get_viewport().get_visible_rect().size
	var sz := panel.size
	p.x = clamp(p.x, 0.0, vp.x - sz.x)
	p.y = clamp(p.y, 0.0, vp.y - sz.y)
	panel.position = p

func _fade_in() -> void:
	if _fade and _fade.is_running(): _fade.kill()
	panel.visible = true
	_fade = create_tween()
	_fade.tween_property(panel, "modulate:a", 1.0, 0.12)

func _fade_out() -> void:
	if _fade and _fade.is_running(): _fade.kill()
	_fade = create_tween()
	_fade.tween_property(panel, "modulate:a", 0.0, 0.10).finished.connect(
		func(): panel.visible = false
	)

func _process(_dt: float) -> void:
	# optional: if you prefer it to follow the mouse while hovering
	if panel.visible:
		_move_to(get_viewport().get_mouse_position())
