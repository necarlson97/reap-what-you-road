extends Agent
class_name Car
	
@onready var vision: Area2D = $Vision
@onready var patience: Timer = ($PatienceTimer if has_node("PatienceTimer") else _make_timer())

@export var patience_time := 1.0    # seconds to wait before detour
@export var detour_offset := 50.0   # how far to the side to go around
@export var max_detours := 20        # avoid infinite zigzags

var _ahead_count := 0               # bodies currently sensed ahead
var _detours_made := 0
var _blocker_pos := Vector2.ZERO

func _ready():
	agent_type = AgentType.CAR
	vision.body_entered.connect(_on_vision_enter)
	vision.body_exited.connect(_on_vision_exit)
	super()

func _make_timer() -> Timer:
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	return t

func _on_vision_enter(b: Node) -> void:
	if b == self: return
	_ahead_count += 1
	_blocker_pos = (b as Node2D).global_position if b is Node2D else global_position
	if patience.is_stopped():
		patience.start(patience_time)
	_sense_begin(b)

func _on_vision_exit(b: Node) -> void:
	_ahead_count = max(0, _ahead_count - 1)
	if _ahead_count == 0:
		patience.stop()
	_sense_end(b)

func _sense_begin(body: Node) -> void:
	# (optional: mark who blocked us)
	pass

func _sense_end(body: Node) -> void:
	# TODO is this right?
	_skip_waypoints_behind()

func _behavior_update(desired_vel: Vector2, dt: float) -> Vector2:
	# Slow down if anything is ahead
	if _ahead_count > 0 and patience.time_left > 0:
		return desired_vel.normalized() * desired_vel.length() * 0.3

	# If patience expired and still blocked, try a detour
	if patience.time_left == 0.0 and _ahead_count > 0 and _detours_made < max_detours:
		_insert_detour()
		_detours_made += 1
		# restart patience so we don’t spam detours
		patience.start(patience_time)
	return desired_vel

func _insert_detour() -> void:
	if waypoints.is_empty() or wp_i > waypoints.size() - 2:
		return

	# Choose a side: bias to the side with more clearance by sampling left/right
	var forward := _forward_dir()
	var right := Vector2(forward.y, -forward.x)
	var side := right

	# if blocker is left of us, go right; if right of us, go left
	if right.dot(_blocker_pos - global_position) > 0.0:
		side = -right

	var detour := global_position + side * detour_offset
	# Jump forward to next waypoint
	wp_i += 1
	# Insert detour just before current target index
	waypoints.insert(wp_i, detour)

func _to_string() -> String:
	return "Car: %s"%self.global_position
	

func _become_ragdoll(hit_speed: float, hit_dir: Vector2, new_mode: Mode) -> RigidBody2D:
	var rb: RigidBody2D = super._become_ragdoll(hit_speed, hit_dir, new_mode)
	# TODO play sound, particle effects, instantiate our skid mark creators or w/e
	if new_mode == Mode.KNOCKED_OUT:
		# Fender bender
		pass
	else:
		# Fatal crash
		pass
	return rb

static func get_packed() -> PackedScene:
	return preload("res://agents/car.tscn")

static func create(parent: Node, from_cell: Vector2i, to_cell: Vector2i) -> Car:
	var p := Agent.create_async(parent, from_cell, to_cell, Car)
	p.tweak_color(Color.html("#008f7aff"))
	return p
	
static func create_slow(parent: Node, from_cell: Vector2i, to_cell: Vector2i) -> Car:
	var p := Agent.create_async(parent, from_cell, to_cell, Car)
	p.max_speed *= .6
	p.tweak_color(Color.html("#4e8397ff"))
	return p

static func create_fast(parent: Node, from_cell: Vector2i, to_cell: Vector2i) -> Car:
	var p := Agent.create_async(parent, from_cell, to_cell, Car)
	p.max_speed *= 1.6
	p.tweak_color(Color.html("#67c6eaff"))
	return p
	
static func create_drunk(parent: Node, from_cell: Vector2i, to_cell: Vector2i) -> Car:
	var p := Agent.create_async(parent, from_cell, to_cell, Car)
	p.max_speed *= 1.1
	p.max_turn_rate_rad *= 0.8
	p.tweak_color(Color.html("#845ec2ff"))
	return p
	
static func create_distracted(parent: Node, from_cell: Vector2i, to_cell: Vector2i) -> Car:
	var p := Agent.create_async(parent, from_cell, to_cell, Car)
	var vis: Area2D = p.get_node("Vision")
	vis.monitoring = false
	vis.visible = false
	p.tweak_color(Color.html("#634595ff"))
	return p
