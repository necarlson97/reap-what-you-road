# Draggable2D.gd
extends Area2D
class_name Draggable2D

signal drag_started()
signal drag_ended(cell: Vector2i, world_pos: Vector2)
signal drag_canceled()

@export var snap_to_grid := true
@export var block_on_solid := true
@export var lives_on_road := true

var _grid: Grid
var _dragging := false
var _start_pos := Vector2.ZERO
var _hovering := false

func _ready() -> void:
	_grid = get_node("/root/Main/Grid")
	input_pickable = true
	_start_pos = get_parent().global_position
	if snap_to_grid and _grid:
		place(_grid.world_to_cell(_start_pos))
	mouse_entered.connect(func(): _hovering = true)
	mouse_exited.connect(func(): _hovering = false)

func _unhandled_input(event: InputEvent) -> void:
	if ToolState.is_disabled:
		if _dragging: _end_drag()
		return
		
	if event is InputEventMouseButton:
		# start
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _hovering and !_dragging and !ToolState.is_dragging:
			_start_drag()
		# end
		if event.button_index == MOUSE_BUTTON_LEFT and !event.pressed and _dragging:
			_end_drag()
		# cancel (right or esc)
		if _dragging and ((event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or Input.is_action_just_pressed("drag_cancel")):
			_cancel_drag()

func _process(_dt: float) -> void:
	# soft highlight when hoverable & not dragging
	get_parent().modulate = Color(1,1,1,0.8) if _hovering and !_dragging and !ToolState.is_dragging else Color.WHITE

	if !_dragging: return
	get_parent().modulate = Color(1,1,1,0.5)

	var target := get_global_mouse_position()
	if snap_to_grid and _grid:
		var cell := _grid.world_to_cell(target)
		if block_on_solid and _grid.is_cell_blocked(cell):
			# show invalid tint but still snap (or you can keep last valid)
			get_parent().modulate = Color(1,0.7,0.7,0.9)
		target = _grid.cell_to_world_center(cell)
	get_parent().global_position = target

func _start_drag() -> void:
	_dragging = true
	ToolState.is_dragging = true
	z_index = 10
	emit_signal("drag_started")
	var cell := _grid.world_to_cell(get_parent().global_position)
	if lives_on_road: _grid.remove_road(cell, true)

func _end_drag() -> void:
	_dragging = false
	ToolState.is_dragging = false
	z_index = 0

	var pos:Vector2 = get_parent().global_position
	if snap_to_grid and _grid:
		var cell := _grid.world_to_cell(pos)
		if block_on_solid and _grid.is_cell_blocked(cell):
			_cancel_drag()
			return
		place(cell)
		emit_signal("drag_ended", cell, pos)
	else:
		emit_signal("drag_ended", Vector2i(pos), pos)

func _cancel_drag() -> void:
	_dragging = false
	ToolState.is_dragging = false
	z_index = 0
	place(_grid.world_to_cell(_start_pos))
	emit_signal("drag_canceled")

func place(cell: Vector2i) -> void:
	get_parent().global_position = _grid.cell_to_world_center(cell)
	_start_pos = get_parent().global_position
	if lives_on_road:
		_grid.place_driveway(cell)
