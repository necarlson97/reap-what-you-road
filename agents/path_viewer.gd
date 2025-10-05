extends Line2D
class_name PathViewer

@export var enabled_view: bool = true
var width_px: float = 4
var alpha: float = 0.4
var refresh_hz: float = 10.0

var _agent: Agent
var _time_acc := 0.0

func _ready() -> void:
	set_as_top_level(true) 
	# Validate parent
	_agent = get_parent() as Agent
	if _agent == null:
		push_warning("PathViewer must be a child of an Agent. Disabling.")
		set_process(false)
		visible = false
		return

	# Adopt color & style
	width = width_px
	set_process(true)
	
	await get_tree().process_frame
	default_color = _agent.color
	default_color.a = alpha
	var g := Gradient.new()
	g.colors = PackedColorArray([default_color, Color(default_color, 0)])
	gradient = g

func _process(dt: float) -> void:
	if not enabled_view or _agent == null:
		points = PackedVector2Array()
		return
		
	_time_acc += dt
	var refresh_interval := 1.0 / maxf(1.0, refresh_hz)
	if _time_acc < refresh_interval:
		return
	_time_acc = 0.0

	_update_points()

func _update_points() -> void:
	# Build a polyline from agent's *current* position to remaining waypoints
	# Convert world positions to this node's local space using to_local()
	var pts := PackedVector2Array()

	# If the agent hides itself at the end, still draw nothing gracefully
	if _agent.waypoints.is_empty():
		points = pts
		return

	# Start at agent's current position
	pts.append(to_local(_agent.global_position))

	# Remaining waypoints
	for i in range(_agent.wp_i, _agent.waypoints.size()):
		pts.append(to_local(_agent.waypoints[i]))

	points = pts
