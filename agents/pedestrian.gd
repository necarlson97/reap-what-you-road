extends Agent
class_name Pedestrian
	
func _ready():
	agent_type = AgentType.PED
	max_speed = 50.0
	accel = 220.0
	decel = 320.0
	max_turn_rate_rad = 10.0
	arrive_radius = 12.0
	# lighter hit thresholds
	hit_ko_threshold = 50
	hit_death_threshold = 80
	mass = 1
	super()

func _to_string() -> String:
	return "Ped: %s"%self.global_position

static func get_packed() -> PackedScene:
	return preload("res://agents/pedestrian.tscn")

static func create(parent: Node, from_cell: Vector2i, to_cell: Vector2i) -> Pedestrian:
	var p := Agent.create_async(parent, from_cell, to_cell, Pedestrian)
	p.tweak_color(Color.html("#ff8066ff"))
	return p

static func create_slow(parent: Node, from_cell: Vector2i, to_cell: Vector2i) -> Pedestrian:
	var p := Agent.create_async(parent, from_cell, to_cell, Pedestrian)
	p.max_speed *= 0.5
	p.tweak_color(Color.html("#ff9671ff"))
	return p

static func create_runner(parent: Node, from_cell: Vector2i, to_cell: Vector2i) -> Pedestrian:
	var p := Agent.create_async(parent, from_cell, to_cell, Pedestrian)
	p.max_speed *= 2
	p.tweak_color(Color.html("#ffc75fff"))
	return p
