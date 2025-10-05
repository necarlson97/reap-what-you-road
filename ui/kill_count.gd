extends Panel
class_name KillCount

signal stage_changed(new_stage: int)

@onready var kill_count_label: Label = %KillsCount
@onready var needed_label: Label = %KillsNeeded
@onready var stage_label: Label = %StageLabel

# --- Config -------------------------------------------------------------------
# Cumulative kill targets. If a stage isn't listed, we scale from the highest
# defined stage using either a linear increment or a multiplier.
@export var stage_kill_table: Dictionary = {
	1: 1,
	2: 2,
	3: 4,
	4: 7,
	5: 10,
	6: 14,
	7: 19,
	8: 25,
	9: 30,
	10: 40,
}

enum ScaleMode { LINEAR, MULTIPLIER }
@export var scale_mode: ScaleMode = ScaleMode.MULTIPLIER
@export var linear_increment: int = 5          # used if LINEAR
@export var multiplier: float = 1.35           # used if MULTIPLIER

@export var poll_hz: float = 4.0               # how often we re-derive kills

# Optional hook you can assign in the editor to fire when stage changes
@export var on_stage_advanced: Callable

# --- State --------------------------------------------------------------------
var stage: int = 1
var _poll_timer: Timer
var max_stage := 10 # Can be set to -1 for inf

func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.one_shot = false
	_poll_timer.wait_time = 1.0 / max(0.1, poll_hz)
	_poll_timer.timeout.connect(_tick)
	add_child(_poll_timer)
	_poll_timer.start()
	_update_ui()

# --- Core loop ----------------------------------------------------------------

func _tick() -> void:
	# Advance stages as long as we meet/exceed the current requirement.
	# (Requirements are cumulative kills.)
	while _total_kills() >= _required_kills_for(stage):
		stage += 1
		if on_stage_advanced.is_valid():
			on_stage_advanced.call(stage)
		emit_signal("stage_changed", stage)
	# Update display of remaining kills for current stage
	_update_ui()

func _update_ui() -> void:
	var req := _required_kills_for(stage)
	var have := _total_kills()
	var remaining := max(0, req - have) as int
	
	needed_label.text = "of %s"%req
	kill_count_label.text = str(have)
	stage_label.text = "stage %s of %s"%[stage, max_stage if max_stage >= 0 else "?"]

# --- Requirements --------------------------------------------------------------

func _required_kills_for(s: int) -> int:
	if stage_kill_table.has(s):
		return int(stage_kill_table[s])

	# Find highest defined stage and its value, then scale forward.
	var max_defined := 0
	var base := 0
	for k in stage_kill_table.keys():
		var ki := int(k)
		if ki > max_defined:
			max_defined = ki
			base = int(stage_kill_table[k])

	if s <= max_defined:
		return base  # should not happen, but safe

	var steps := s - max_defined
	match scale_mode:
		ScaleMode.LINEAR:
			return int(base + steps * linear_increment)
		ScaleMode.MULTIPLIER:
			return int(ceil(float(base) * pow(multiplier, steps)))
	return base

# --- Kill derivation -----------------------------------------------------------

func _total_kills() -> int:
	return get_tree().get_nodes_in_group("dead").size()
