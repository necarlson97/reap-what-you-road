extends Panel

@onready var agent_parent: Node2D = $"/root/Main/Agents"
@onready var building_parent: Node2D = $"/root/Main/Buildings"
@onready var road_panel: Control = $"../../RoadPanel"

@onready var day_progress: ProgressBar = %DayProgress
@onready var button: Button = %DayStart

var _total_dests := 0
var _done_dests  := 0

func _ready() -> void:
	_update_progress()

func start_day() -> void:
	button.text = "Spawning…"
	button.disabled = true
	road_panel.visible = false
	ToolState.is_disabled = true

	day_progress.value = 0.0
	_done_dests = 0

	# Release any active tools
	for t: RoadTool in get_tree().get_nodes_in_group("tools"):
		t._release_tool()

	# Collect destinations and run them SERIALY
	var destinations: Array = get_tree().get_nodes_in_group("destinations")
	_total_dests = max(1, destinations.size())

	await _spawn_all_serial(destinations)

	# Finished
	button.text = "End Day"
	button.disabled = false

func _spawn_all_serial(dests: Array) -> void:
	for d: Destination in dests:
		# Run each destination to completion before starting the next
		await d.spawn_agents(agent_parent)
		_done_dests += 1
		_update_progress()
		# Give physics a frame to settle to avoid overlaps from the next building
		await get_tree().process_frame

func _update_progress() -> void:
	day_progress.value = float(_done_dests) / float(_total_dests) * 100.0

func end_day() -> void:
	button.text = "Start Day"
	button.disabled = false
	road_panel.visible = true
	ToolState.is_disabled = false

	# Cleanup: remove all currently spawned agents
	for n in agent_parent.get_children():
		n.queue_free()

	# Reset counters & progress
	_total_dests = 0
	_done_dests  = 0
	day_progress.value = 0.0

func restart_day() -> void:
	if button.text == "Start Day":
		start_day()
	else:
		end_day()
