extends Tutorial

const BUILDING_NAMES = [
	"house", "mansion", "appartment",
	"school", "bar", # start with
	"court", # ~1
	"resturant", # ~3 
	"gas_station", # ~5
	"hospital", # ~7
	"nightclub", # ~9
]
var building_types: Dictionary[String, PackedScene] = {}

var stage_spawns: Dictionary[int, Array]  = {
	0: [[2, "appartment"], [2, "house"], [1, "school"], [1, "bar"]],
	1: [[1, "mansion"], [1, "court"]],
	2: [[1, "house"], [1, "mansion"]],
	3: [[1, "appartment"], [1, "resturant"]],
	4: [[2, "mansion"]],
	5: [[1, "house"], [1, "gas_station"]],
	6: [[1, "house"], [1, "appartment"]],
	7: [[1, "mansion"], [1, "hospital"]],
	8: [[1, "house"], [1, "mansion"], [1, "appartment"]],
	9: [[1, "appartment"], [1, "nightclub"]],
	10: [[1, "house"], [1, "mansion"], [1, "appartment"]],
	# After stage 10 - done!
}

func _ready() -> void:
	for n in BUILDING_NAMES:
		var path := "res://buildings/types/%s.tscn" % n
		var scene := ResourceLoader.load(path) as PackedScene  # or just: load(path)
		assert(scene != null, "Missing scene at: %s" % path)
		building_types[n] = scene

	# Initial helper text for the campaign overlay
	steps = [
		"This is your trial - young reaper.\nCollect enough sould to advance the stages.",
		"If you make it to 10 - you will have graduated, and eared this town to reap all your own.",
		"Remember: yellow is just a fender-bender. You need to have them hit harder.",
		"Teal is speedy, purples are the drunks and distracted - you got this, kid.",
		func(): _close_button(),
		"Can you make it all the way to 10?\nGood luck young reaper."
	]

	# Hook KillCount stage changes
	kill_count.stage_changed.connect(_on_stage_changed)
	
	_on_stage_changed(1)
	
	next_btn.pressed.connect(_on_next_pressed)
	_show_next_string()  # show the first one immediately

# Called whenever KillCount advances to stage `s`.
func _on_stage_changed(s: int) -> void:
	print("Starting stage %s"%s)
	# Spawn package for the wave just completed/entered (0-based key)
	var key := s - 1
	if stage_spawns.has(key):
		_spawn_stage_package(key)

	# Milestone helper pops
	match s:
		3:
			_popup([
				"Nice momentum.\nTry spacing roads so cars really [i]wind up[/i].",
				func(): _spawn_box(),
				"Here - take this - pileups can be good.",
				func(): _close_button()
			])
		7:
			_popup([
				"Ambulances might save... but speed always kills. Good work.",
				func(): _spawn_box(),
				"Take another one of these - really pile those bodies up!",
				func(): _close_button()
			])
		11:
			# After stage 10 requirements met (stage becomes 11)
			_popup([
				"Congradulations! You have graduated.",
				"How many kills can you get with this setup?",
				#"Or - advance to endless mode! (esc)",
				func(): _close_button()
			])

# Resets the tutorial overlay with new content and shows it now.
func _popup(arr: Array) -> void:
	steps = arr
	_step = -1
	self.visible = true
	_show_next_string()

func _spawn_stage_package(key: int) -> void:
	var pkg: Array = stage_spawns[key]
	
	for item in pkg:
		var count := int(item[0])
		var name  := String(item[1])
		var scene: PackedScene = building_types[name]
		for i in count:
			var inst := grid.spawn_near_center(buildings, scene)
			Arrow.spawn_arrow_tip_at(inst.global_position, PI/2, inst)
