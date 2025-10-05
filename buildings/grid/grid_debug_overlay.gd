# res://utils/grid_debug_overlay.gd
extends Node2D

@onready var grid_pathing : GridPathing = get_node("/root/Main/Grid")
@onready var roads: TileMapLayer = grid_pathing.roads

var cell_a: Vector2i
var cell_b: Vector2i
var have_a := false
var have_b := false
var path_cells := PackedVector2Array()

@export var show_region := true
@export var show_cells := true
@export var show_roads := true
@export var show_path := true
@export var cell_alpha := 0.1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world := get_global_mouse_position()
		var c := grid_pathing.world_to_cell(world)
		if !have_a:
			cell_a = c; have_a = true; have_b = false; path_cells = PackedVector2Array()
		elif !have_b:
			cell_b = c; have_b = true
			_try_path()
		else:
			# reset selection
			have_a = false; have_b = false; path_cells = PackedVector2Array()
		
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			# force recompute (useful after changing solids/region)
			_try_path()
			
	queue_redraw()

func _try_path() -> void:
	path_cells = PackedVector2Array()
	if !(have_a and have_b):
		return
	# quick diagnostics
	var r := grid_pathing.astar.region
	var a_ok := grid_pathing.astar.is_in_boundsv(cell_a)
	var b_ok := grid_pathing.astar.is_in_boundsv(cell_b)
	var a_solid := a_ok and grid_pathing.astar.is_point_solid(cell_a)
	var b_solid := b_ok and grid_pathing.astar.is_point_solid(cell_b)
	print("[A*] A=", cell_a, " in=", a_ok, " solid=", a_solid, " | B=", cell_b, " in=", b_ok, " solid=", b_solid, " | region P:", r.position, " S:", r.size)

	if a_ok and b_ok and !a_solid and !b_solid:
		path_cells = grid_pathing.path_between_cells(cell_a, cell_b)
		print("[A*] path len cells = ", path_cells.size())
	else:
		print("[A*] no path; endpoint invalid")

func _draw() -> void:
	var ts := roads.tile_set.tile_size
	var half := ts * 0.5

	# Region outline
	if show_region:
		var r := grid_pathing.astar.region
		# draw rect in world space
		var p0 := grid_pathing.cell_to_world_center(r.position) - half
		var size := Vector2(r.size.x * ts.x, r.size.y * ts.y)
		draw_rect(Rect2(p0, size), Color.TRANSPARENT, false, 2.0, true)

	# Per-cell fill
	if show_cells:
		var r := grid_pathing.astar.region
		for y in range(r.position.y, r.position.y + r.size.y):
			for x in range(r.position.x, r.position.x + r.size.x):
				var c := Vector2i(x, y)
				var wp := grid_pathing.cell_to_world_center(c) - half
				var col := Color(0.2, 0.8, 0.3, cell_alpha)  # walkable = green
				if grid_pathing.astar.is_point_solid(c):
					col = Color(0.9, 0.2, 0.2, cell_alpha)   # solid = red
				draw_rect(Rect2(wp, ts), col, true)

	# Roads (used cells) overlay
	if show_roads:
		for c in roads.get_used_cells():
			var wp := grid_pathing.cell_to_world_center(c) - half
			draw_rect(Rect2(wp, ts), Color(0.2, 0.5, 1.0, 0.35), true)

	# Path
	if show_path and path_cells.size() > 1:
		var pts := PackedVector2Array()
		for v in path_cells:
			pts.append(grid_pathing.cell_to_world_center(Vector2i(v)))
		draw_polyline(pts, Color.WHITE, 3.0, true)

	# A/B markers
	if have_a:
		_draw_marker(cell_a, Color.YELLOW)
	if have_b:
		_draw_marker(cell_b, Color(1, 0.5, 0, 1))

func _draw_marker(c: Vector2i, col: Color) -> void:
	var ts := roads.tile_set.tile_size
	var center := grid_pathing.cell_to_world_center(c)
	draw_circle(center, min(ts.x, ts.y) * 0.25, col)
