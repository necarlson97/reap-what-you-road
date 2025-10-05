extends Control
class_name RoadTool

var _grid: Grid
var _last_paint_cell: Vector2i = Vector2i(-9999, -9999)
var _last_erase_cell: Vector2i = Vector2i(-9999, -9999)

func _ready() -> void:
	_grid = get_node("/root/Main/Grid")

func _process(_dt: float) -> void:
	# Always clear and maybe draw preview (ghost)
	_grid.preview_clear()

	# If UI hovered or dragging, no world actions/preview
	if _ui_hovered() or ToolState.is_dragging or ToolState.is_disabled:
		_reset_last_cells()
		return

	var cell := _grid.mouse_cell()
	if cell == null:
		_reset_last_cells()
		return

	# Preview only when not holding either button and the tile is placeable
	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if !left_down and !right_down:
		if !_grid.is_cell_blocked(cell) and !_grid.has_road(cell):
			_grid.preview(cell)
		_reset_last_cells()
		return

	# Painting logic on hold (no interpolation—just act per hovered cell)
	# If both held, prioritize erase (feel free to flip this rule)
	if right_down:
		_erase_at(cell)
	elif left_down:
		_paint_at(cell)

func _paint_at(cell: Vector2i) -> void:
	# Avoid re-placing on the same cell every frame
	if cell == _last_paint_cell:
		return
	_last_paint_cell = cell
	_last_erase_cell = Vector2i(-9999, -9999)

	if _grid.is_cell_blocked(cell):
		return
	if !_grid.has_road(cell):
		_grid.place_road(cell)

func _erase_at(cell: Vector2i) -> void:
	# Avoid re-erasing on the same cell every frame
	if cell == _last_erase_cell:
		return
	_last_erase_cell = cell
	_last_paint_cell = Vector2i(-9999, -9999)

	if _grid.has_road(cell):
		_grid.remove_road(cell)

func _reset_last_cells() -> void:
	_last_paint_cell = Vector2i(-9999, -9999)
	_last_erase_cell = Vector2i(-9999, -9999)

func _ui_hovered() -> bool:
	return get_viewport().gui_get_hovered_control() != null

func _on_clear_pressed() -> void:
	_grid.clear_road()
	_reset_last_cells()
