extends Building
class_name Destination

@onready var hover: Area2D = drag
var lines_root: Node2D
var ped_lines: Dictionary[Home, Line2D] = {}
var car_lines: Dictionary[Home, Line2D] = {}

var AgentType = TilePath.AgentType

func _ready() -> void:
	add_to_group("destinations")
	super._ready()
	lines_root = Node2D.new()
	lines_root.name = "Lines"
	add_child(lines_root)
	
	drag.drag_ended.connect(on_moved_to)

	if hover:
		hover.mouse_entered.connect(_show_all_paths)
		hover.mouse_exited.connect(_hide_all_paths)

	# Build once at ready; will rebuild again when any building calls grid_pathing.rebuild()
	_refresh_all_paths()

func spawn_agents(_parent: Node2D) -> Array[Agent]:
	# What things this destination spawns, and set where they are to go
	# shadowed by subclass
	return []

func on_moved_to(_cell: Vector2i, _pos: Vector2) -> void:
	grid_pathing.rebuild()
	_refresh_all_paths()
	print("Moved to: %s"%self)

func _refresh_all_paths() -> void:
	_clear_lines()

	var homes := _get_homes()
	if homes.is_empty():
		return

	var my_cell := get_grid_cell()
	for h in homes:
		var start_cell :Vector2i= h.get_grid_cell()
		var cells := grid_pathing.path_between_cells(start_cell, my_cell)
		
		if cells.is_empty():
			continue
		
		ped_lines[h] = _line_for_type(cells, h, AgentType.PED)
		car_lines[h] = _line_for_type(cells, h, AgentType.CAR)

	_hide_all_paths() # default hidden until hover

func request_refresh() -> void:
	# Slow - and don't need it instantly
	StaggerQueue.add_owner(self, "_refresh_all_paths")
	
func _line_for_type(cells: Array[Vector2i], h: Home, type: int) -> Line2D:
	var wpts := grid_pathing.grid_path_to_waypoints(cells, type)
		
	# Some nice saturated colors based on building
	var start_color := h.color
	var end_color := color
	var saturation :float= {0: 0.9, 1: 0.6}.get(type)
	start_color.s = saturation
	end_color.s = saturation
	start_color.v = 1.2
	end_color.v = 1.2
	var line := _make_line(start_color, end_color, wpts)
	get_tree().root.add_child.call_deferred(line)
	return line

func _get_homes() -> Array[Home]:
	var homes: Array[Home] = []
	if not get_tree():
		return []
	for n in get_tree().get_nodes_in_group("homes"):
		if n is Home:
			homes.append(n as Home)
	return homes

func _make_line(c0: Color, c1: Color, points_world: PackedVector2Array) -> Line2D:
	var line := Line2D.new()
	line.top_level = true
	line.z_as_relative = false
	line.z_index = 3
	line.width = 4.0
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

	# Godot 4: set gradient points explicitly
	var grad := Gradient.new()
	grad.colors  = PackedColorArray([c0, c1])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	line.gradient = grad

	line.points = points_world
	return line

func all_lines() -> Array[Line2D]:
	return car_lines.values() + ped_lines.values()

func _clear_lines() -> void:
	for l in all_lines():
		if is_instance_valid(l):
			l.queue_free()
	car_lines.clear()
	ped_lines.clear()

func _show_all_paths() -> void:
	for l in all_lines():
		if is_instance_valid(l):
			l.visible = true

func _hide_all_paths() -> void:
	for l in all_lines():
		if is_instance_valid(l):
			l.visible = false
			
func _to_string() -> String:
	return "%s: %s"%[self.name, self.get_grid_cell()]

func _sleep(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

# TODO funny - we don't use the cached lines. We should - make it part of
# spawning that agents are given their line, rather than calculating it
func get_houses() -> Array[Home]:
	return ped_lines.keys().filter(func(h: Home): return h.is_in_group("house"))

func get_mansions() -> Array[Home]:
	return ped_lines.keys().filter(func(h: Home): return h.is_in_group("mansion"))
	
func get_appartments() -> Array[Home]:
	return ped_lines.keys().filter(func(h: Home): return h.is_in_group("appartment"))

func all_homes() -> Array[Home]:
	return ped_lines.keys()
	
