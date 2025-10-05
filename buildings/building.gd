extends Node2D
class_name Building

var color := Color.WHITE

@onready var grid_pathing :GridPathing = $"/root/Main/Grid"
@onready var drag := $Draggable

@onready var area := drag

func get_grid_cell() -> Vector2i:
	return grid_pathing.world_to_cell(global_position)

func _ready() -> void:
	# random pleasant color
	add_to_group("buildings")
	color = _rand_color()
	$Icon.self_modulate = color
	grid_pathing.rebuild()
	
	area.mouse_entered.connect(_on_mouse_enter)
	area.mouse_exited.connect(_on_mouse_exit)
	area.input_pickable = true

func _exit_tree() -> void:
	grid_pathing.rebuild()

func _on_drag_ended(cell: Vector2i, _world: Vector2) -> void:
	grid_pathing.rebuild()

var hue_base := 0.2
func _rand_color() -> Color:
	var h := hue_base + randf_range(-0.2, 0.2)
	var s := randf_range(0.1, 0.2)
	return Color.from_hsv(h, s, 1.1)
	
func get_description() -> String:
	# Subclasses will shadow this
	return "A building"

func _on_mouse_enter() -> void:
	# Show at mouse position (screen space). You can also convert world->screen if you prefer pinning near the building.
	var pos := get_viewport().get_mouse_position()
	HoverInfo.show_info(self, get_description(), pos)

func _on_mouse_exit() -> void:
	HoverInfo.hide_info(self)

func _input(event: InputEvent) -> void:
	# If the cursor moves while hovering this building, keep the tooltip tracking the pointer.
	if event is InputEventMouseMotion and HoverInfo:
		HoverInfo.update_pos(self, event.position)
