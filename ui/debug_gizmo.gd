extends Node2D
class_name DebugGizmo

var points: Array[Vector2] = []
var colors: Array[Color] = []

func _ready():
	top_level = true        # draw in world space
	z_as_relative = false
	z_index = 2000

func set_points(ws_points: Array[Vector2], cols: Array[Color]) -> void:
	points = ws_points
	colors = cols
	queue_redraw()

func _draw():
	for i in points.size():
		draw_circle(points[i], 6.0, (colors[i] if i < colors.size() else Color.WHITE))

static func make(parent: Node, points: Array[Vector2], colors: Array[Color], name := "Gizmo") -> DebugGizmo:
	# Create or use existing gizmo for this obj
	var giz:DebugGizmo = parent.get_node_or_null(name)
	if not giz:
		giz = load("res://ui/debug_gizmo.gd").new()
		giz.name = name
		parent.add_child(giz)
	giz.set_points(points, colors)
	return giz
