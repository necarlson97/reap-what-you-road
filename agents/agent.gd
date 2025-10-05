extends CharacterBody2D
class_name Agent

signal reached_destination(agent: Agent)
signal knocked_out(agent: Agent)
signal died(agent: Agent)

enum Mode { CONTROLLED, KNOCKED_OUT, DEAD }
var AgentType = TilePath.AgentType

@export var agent_type: int = AgentType.PED
@export var max_speed: float = 180.0
@export var accel: float = 400.0
@export var decel: float = 1.0
@export var max_turn_rate_rad: float = 3.3   # how fast velocity can rotate (rad/s)
@export var arrive_radius: float = 18.0      # slow near waypoint
@export var waypoint_advance: float = 12.0   # how close to “consume” a waypoint

# hit thresholds (pixels/sec relative speed)
@export var hit_ko_threshold: float = 120
@export var hit_death_threshold: float = 150

# Just for ragdoll
@export var mass: float = 10.0
@export var damp: float = 0.8

var mode: Mode = Mode.CONTROLLED
var waypoints: Array[Vector2] = []
var wp_i: int = 0
var destination_cell: Vector2i

@onready var grid_pathing: GridPathing = $"/root/Main/Grid"
@onready var icon: Sprite2D = $Icon
@onready var outline: Sprite2D = $Outline

var color: Color
func _ready() -> void:
	# random pleasant color
	add_to_group("agents")
	tweak_color(Color.WHEAT)
		
static func get_packed() -> PackedScene:
	# TODO must be shadowed by child
	return null

static func create_async(parent: Node, from_cell: Vector2i, to_cell: Vector2i, klass) -> Agent:
	var agent = klass.get_packed().instantiate() as Agent
	parent.add_child(agent)
	agent.spawn_at_cell(from_cell)
	agent.set_destination_cell(to_cell)
	# Rotate towards start
	if agent.waypoints.size() > 0:
		var first_point = agent.waypoints[0]
		agent.rotation = agent._rotate_toward(
			agent.rotation,
			(first_point - agent.global_position).angle(),
			TAU # rotate as much as you want
		)
	return agent

func tweak_color(base_color: Color) -> Color:
	var h := base_color.h + randf_range(-0.04, 0.04)
	var s := base_color.s + randf_range(-0.04, 0.04)
	color = Color.from_hsv(h, s, base_color.v)
	icon.modulate = color
	return color

func spawn_at_cell(cell: Vector2i) -> void:
	global_position = grid_pathing.cell_to_world_center(cell)

func set_destination_cell(cell: Vector2i) -> void:
	destination_cell = cell
	_request_path()

func _request_path() -> void:
	var start_cell := grid_pathing.world_to_cell(global_position)
	var cells := grid_pathing.path_between_cells(start_cell, destination_cell)
	if cells.is_empty():
		waypoints = []
		return
	waypoints = grid_pathing.grid_path_to_waypoints(cells, agent_type).duplicate()
	# start at nearest point along the path (helps if spawned slightly off-center)
	wp_i = 0
	if waypoints.size() > 1:
		var best := 0; var best_d := INF
		for i in waypoints.size():
			var d := global_position.distance_squared_to(waypoints[i])
			if d < best_d: best_d = d; best = i
		wp_i = clamp(best, 0, max(0, waypoints.size() - 2))

func _physics_process(dt: float) -> void:
	if mode != Mode.CONTROLLED: return

	if waypoints.is_empty():
		velocity = Vector2.ZERO
		return

	# consume waypoints
	while wp_i < waypoints.size() and global_position.distance_to(waypoints[wp_i]) <= waypoint_advance:
		wp_i += 1

	# reached?
	if wp_i >= waypoints.size():
		velocity = Vector2.ZERO
		reached_destination.emit(self)
		finished()
		return

	var next_target := waypoints[wp_i]

	# sloppy steering — limited turn rate & accel/decel
	var to_target := (next_target - global_position)
	var dist := to_target.length()
	var desired_dir := to_target / dist if dist > 0.001 else Vector2.ZERO
	
	var target_speed := max_speed
	
	# Slow down when approaching final
	var is_final := (wp_i == waypoints.size() - 1)
	if is_final and dist < arrive_radius * 4.0:
		target_speed = lerp(0.0, max_speed, clamp(dist / (arrive_radius * 4.0), 0.0, 1.0))
	
	if is_final and dist < arrive_radius:
		# Start to dissapear
		($CollisionShape2D as CollisionShape2D).disabled = true
		finished()
	
	var desired_vel := desired_dir * target_speed
	desired_vel = _behavior_update(desired_vel, dt)

	velocity = _steer_and_throttle(desired_vel, target_speed, dt)
	
	move_and_slide()
	
	_score_impacts()

func _behavior_update(desired_vel: Vector2, dt: float) -> Vector2:
	# Can be implemented by subclasses
	return desired_vel

func _steer_and_throttle(desired_vel: Vector2, target_speed: float, dt: float) -> Vector2:
	# 1) steer the whole body toward desired heading
	var desired_heading := desired_vel.angle() if desired_vel.length() > 0.001 else rotation
	rotation = _rotate_toward(rotation, desired_heading, max_turn_rate_rad * dt)

	# 2) accelerate / decelerate scalar speed
	var cur_speed := velocity.length()
	var speed_delta := target_speed - cur_speed
	# Accelerate harder when waypoint is ahead; softer when not
	var fwd := _forward_dir()
	var desired_dir := (desired_vel.normalized() if desired_vel.length() > 0.001 else fwd)
	var ahead := maxf(0.0, fwd.dot(desired_dir))   # 0..1
	var ahead_accel := lerpf(0.3, 1.0, ahead)
	# For now, braking is the same
	
	var step := ahead_accel * accel * dt if speed_delta > 0.0 else decel * dt
	var new_speed := clamp(cur_speed + clamp(speed_delta, -step, step), 0.0, max_speed) as float

	# 3) project along facing; blend a bit toward desired_vel for “skid”
	var forward := Vector2.RIGHT.rotated(rotation)
	var forward_vel := forward * new_speed
	var skid := 0.15  # 0..1 (0 = pure forward, 1 = pure desired)
	return forward_vel.lerp(desired_vel, skid)

func _rotate_toward(current: float, target: float, max_delta: float) -> float:
	var diff := wrapf(target - current, -PI, PI)
	return current + clamp(diff, -max_delta, max_delta)

func _forward_dir() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)

func _is_ahead(world_point: Vector2) -> bool:
	# positive dot with forward means in front
	var f := _forward_dir()
	return f.dot((world_point - global_position).normalized()) > 0.15

func _skip_waypoints_behind() -> void:
	while wp_i < waypoints.size() - 2  and not _is_ahead(waypoints[wp_i]):
		wp_i += 1

func finished() -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, .8)
	t.finished.connect(queue_free)

func _score_impacts() -> void:
	var my_v := velocity
	for i in range(get_slide_collision_count()):
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other == null: continue

		var other_v := _effective_velocity(other)

		# relative velocity *into me* (other minus me)
		var rel_to_me := other_v - my_v
		apply_hit(rel_to_me)  # score hit on self

		# If the other thing is also an Agent, score them too (symmetrical)
		if other is Agent:
			var rel_to_other := my_v - other_v
			(other as Agent).apply_hit(rel_to_other)

func _effective_velocity(n: Node) -> Vector2:
	if n is Agent:
		return (n as Agent).velocity
	elif n is RigidBody2D:
		return (n as RigidBody2D).linear_velocity
	elif n.has_method("get_linear_velocity"):
		return n.get_linear_velocity()
	elif "velocity" in n:
		return n.velocity
	return Vector2.ZERO
	
func apply_hit(relative_velocity: Vector2) -> void:
	var v := relative_velocity.length()

	if v < hit_ko_threshold:
		return # ignore

	if v < hit_death_threshold:
		_become_ragdoll(v * 0.6, relative_velocity, Mode.KNOCKED_OUT)
		knocked_out.emit(self)
	else:
		_become_ragdoll(v, relative_velocity, Mode.DEAD)
		died.emit(self)

func _become_ragdoll(hit_speed: float, hit_dir: Vector2, new_mode: Mode) -> RigidBody2D:
	mode = new_mode

	# 1) Build a rigid on the fly
	var rb := RigidBody2D.new()
	rb.global_position = global_position
	rb.rotation = rotation
	rb.collision_layer = collision_layer
	rb.collision_mask  = collision_mask
	rb.mass = mass
	rb.linear_damp = damp
	rb.angular_damp = damp
	rb.add_to_group("dead" if mode == Mode.DEAD else "knocked out")
	get_parent().add_child(rb)
	
	icon.modulate = Color(1, 0.9, 0.2) if new_mode == Mode.KNOCKED_OUT else Color(1, 0.25, 0.25)
	outline.modulate = Color.BLACK

	# 2) Move (reparent) visuals & collider to the rigid
	for c in get_children():
		remove_child(c)
		if c.name != "Vision":
			rb.add_child(c)

	# 3) Impart motion from the hit
	var dir := hit_dir.normalized() if hit_dir.length() > 0.01 else Vector2.RIGHT.rotated(rotation)
	rb.linear_velocity = dir * hit_speed
	rb.angular_velocity = randf_range(-6.0, 6.0)

	# 4) Make this agent inert (no self-movement, no visuals left)
	set_physics_process(false)
	visible = false
	# If you fully reparented everything, you can free the agent node:
	queue_free()
	return rb
