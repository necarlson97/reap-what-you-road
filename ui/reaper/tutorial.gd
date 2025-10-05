extends CanvasLayer
class_name Tutorial

@onready var reaper: TextureRect = %Reaper
@onready var text: RichTextLabel = %TutorialText
@onready var next_btn: Button = %NextButton
@onready var dialogue: AudioStreamPlayer2D = $Dialogue

@onready var buildings: Node2D = $"/root/Main/Buildings"

@export var kill_count: KillCount
@export var start_btn: Button

@onready var grid: Grid = $"/root/Main/Grid"

var _step := -1
var _t := 0.0

# Steps can be Strings OR Callables.
# Callables can spawn things, toggle UI, etc. They will be executed
# and the tutorial immediately advances to the next step that is a String.
var steps: Array = [
	"Welcome, young reaper.\n\n(WASD to move your view, scrollwheel to zoom.)",
	"You're looking to make mass casualties? You've come to the right place.",
	"They love to drive, nothing can make them stop.\nSo let's build them a road!",
	"Left click to draw new roads,\nand right click to destroy.",
	func(): _arrow_all_buildings(),
	"Let's link up these buildings.\nOnce you do, you can hover over each to see what it does.",
	"If you want to move the buildings, left-click to pick them up and drag them.",
	func(): Arrow.spawn_arrow_tip_at(start_btn.global_position + start_btn.size * 0.5, -1, start_btn),
	"You learn well - let's use the 'Start Day' button to watch them go.",
	"(End the day to be able to edit the town again).",
	"Excellent.\nBut you're not here to babysit. You're here to collect.\nAnd for that, we need to make some fresh souls.",
	func(): _spawn_more_buildings(),
	"Great - let's link these up, move them around, and see what kind of carnage we can cause.",
	func(): Arrow.spawn_arrow_tip_at(start_btn.global_position + start_btn.size * 0.5, -1, start_btn),
	"Feel free to end / start next day whenever.",
	"Did you crash any cars? Knock any people down? Kill any?\nMy eyes ain't so good...",
	"If not - you can feel free to try again -\nstart the next day, as many times as you like, to get things right.",
	"If you harvest well - you'll be rewarded.",
	func(): _spawn_box(),
	"Here - try throwing this on a road.\nDrivers will slow down, try to go around - but as they do, they'll get pissed. Reckless.",
	"And 'Reckless' is good reaping.",
	func(): _spawn_last_buildings(),
	"Keep playing around - see what kinds of pedestrians there are, what sorts of deviant drivers.",
	"Don't hesitate to space things out - really let the cars get up to speed.",
	func(): _show_kill_count(),
	"Out there in the real world, you'll need kills to move on to the next round.\nBumps and scrapes won't do it, you need high-velocity lethality.",
	"But you can spend all the time you want in tutorial-land with me. Learn the ropes.\n",
	func(): _close_button(),
	"Cause chaos, collect souls. simple as that.\n Good luck, young reaper.\n\n(escape to choose next)",
]

func _ready() -> void:
	next_btn.pressed.connect(_on_next_pressed)
	_show_next_string()  # show the first one immediately
	await get_tree().process_frame
	kill_count.visible = false

# --- Flow --------------------------------------------------------------------

func _on_next_pressed() -> void:
	_show_next_string()

func _show_next_string() -> void:
	# Advance until we land on a string (executing any callables we hit).
	while true:
		_step += 1
		if _step >= steps.size():
			next_btn.disabled = true
			return

		var item = steps[_step]
		if item is Callable:
			item.call()
			continue  # keep advancing until a String
		elif item is String:
			_reveal_text(item)
			break
		else:
			push_warning("Unsupported tutorial step type at index %d" % _step)
			continue

# --- Text FX -----------------------------------------------------------------

var _reveal_tween: Tween

func _reveal_text(s: String) -> void:
	# Stop any previous tween
	if _reveal_tween and _reveal_tween.is_running():
		_reveal_tween.kill()

	# Fade out current text quickly
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(text, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _reveal_tween.finished

	# Apply new text & play blip
	text.text = s
	text.visible_characters = 0
	text.scroll_to_paragraph(0) # keep it tidy
	_play_bip()

	# Fade in while typewriter reveals characters
	var total := max(1, text.get_total_character_count()) as int
	_reveal_tween = create_tween()
	_reveal_tween.parallel().tween_property(text, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Animate visible_characters from 0..total over ~0.65s (feel free to tweak)
	_reveal_tween.parallel().tween_property(text, "visible_characters", total, 0.65).set_trans(Tween.TRANS_SINE)

func _play_bip() -> void:
	dialogue.play()

func _spawn_more_buildings() -> void:
	var parent = $"/root/Main/Buildings"
	var school = grid.spawn_near_center(parent, preload("res://buildings/types/school.tscn"))
	Arrow.spawn_arrow_tip_at(school.global_position, PI/2, school)
	
	for i in range(3):
		grid.spawn_near_center(parent, preload("res://buildings/types/house.tscn"))
	
func _spawn_box() -> void:
	var parent = $"/root/Main"
	var box = grid.spawn_near_center(parent, preload("res://agents/obstruction.tscn"))
	Arrow.spawn_arrow_tip_at(box.global_position, PI/2, box)

func _spawn_last_buildings() -> void:
	var parent = $"/root/Main/Buildings"
	var bar = grid.spawn_near_center(parent, preload("res://buildings/types/bar.tscn"))
	Arrow.spawn_arrow_tip_at(bar.global_position, PI/2, bar)
	
	for i in range(2):
		grid.spawn_near_center(parent, preload("res://buildings/types/mansion.tscn"))
	for i in range(2):
		grid.spawn_near_center(parent, preload("res://buildings/types/appartment.tscn"))
	
func _show_kill_count() -> void:
	kill_count.visible = true
	Arrow.spawn_arrow_tip_at(kill_count.global_position, 0, kill_count)


func _arrow_all_buildings() -> void:
	for b: Building in buildings.get_children():
		Arrow.spawn_arrow_tip_at(b.global_position, PI/2 + randf_range(-0.2, 0.2), b)

func _close_button() -> void:
	next_btn.pressed.disconnect(_on_next_pressed)
	next_btn.pressed.connect(func(): self.visible = false)
	next_btn.text = "Close"

# --- Reaper wiggle ------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	# Gentle bob + rotate. Set pivot to center so it looks nice.
	reaper.pivot_offset = reaper.size * 0.5
	reaper.rotation = 0.03 * sin(_t * 2.5)
	var base_pos := Vector2()  # TextureRect uses anchors/margins; we only offset visually
	var wobble := Vector2(3.0 * sin(_t * 1.6), 2.0 * sin(_t * 3.1))
	reaper.position = base_pos + wobble
