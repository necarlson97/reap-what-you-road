extends CanvasLayer

@export_file("*.tscn") var MAIN_MENU_SCENE: String = "res://MainMenu.tscn"
@export_file("*.tscn") var TUTORIAL_SCENE:  String = "res://Tutorial.tscn"
@export_file("*.tscn") var CAMPAIGN_SCENE:  String = "res://Campaign.tscn"
@export_file("*.tscn") var ENDLESS_SCENE:  String = "res://ENDLESS.tscn"

@onready var music: HSlider = %MusicSlider
@onready var sfx: HSlider = %SfxSlider
@onready var btn_resume: Button = %ResumeButton
@onready var btn_tutorial: Button = %TutorialButton
@onready var btn_start: Button = %StartButton
@onready var btn_endless: Button = %EndlessButton
@onready var btn_menu: Button = %MainMenuButton

const BUS_MUSIC := "Music"
const BUS_SFX   := "SFX"

@onready var visuals: Control = $MarginContainer

var _open := false

var _music_vol = 0.6
var _sfx_vol = 0.6

func _ready() -> void:
	layer = 100
	
	close()
	# Sliders 0..1
	music.min_value = 0.0; music.max_value = 1.0; music.step = 0.01
	sfx.min_value   = 0.0; sfx.max_value   = 1.0; sfx.step   = 0.01
	music.value = _music_vol
	sfx.value   = _sfx_vol

	music.value_changed.connect(set_music)
	sfx.value_changed.connect(set_sfx)

	btn_resume.pressed.connect(toggle)
	btn_tutorial.pressed.connect(func(): _goto(TUTORIAL_SCENE))
	btn_menu.pressed.connect(func(): _goto(MAIN_MENU_SCENE))
	btn_start.pressed.connect(func(): _goto(CAMPAIGN_SCENE))
	btn_endless.pressed.connect(func(): _goto(ENDLESS_SCENE))

func toggle() -> void:
	if _open: close()
	else: open()

var _tween: Tween

func open() -> void:
	print("Menu open")
	_open = true
	_set_input_block(true)
	
	# make visuals visible and start from transparent
	visuals.visible = true
	visuals.modulate.a = 0.0

	if _tween and _tween.is_running(): _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(visuals, "modulate:a", 1.0, 0.15)

	btn_resume.grab_focus()

func close() -> void:
	print("Menu close")
	_open = false
	_set_input_block(false)
	
	if _tween and _tween.is_running(): _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(visuals, "modulate:a", 0.0, 0.12)
	_tween.finished.connect(func ():
		# Only hide if we haven’t reopened during the tween
		if !_open:
			visuals.visible = false
	)

func _fade(visible_in: bool) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if visible_in:
		t.parallel().tween_property(visuals, "modulate:a", 0.0, 1.0)
	else:
		t.parallel().tween_property(visuals, "modulate:a", 1.0, 0.0)
		t.finished.connect(func(): visuals.visible = false)

func _goto(scene_path: String) -> void:
	if scene_path.is_empty(): return
	close()
	ToolState.is_dragging = false
	ToolState.is_disabled = false
	Menu.btn_menu.visible = true
	Menu.btn_resume.visible = true
	get_tree().change_scene_to_file(scene_path)

func _set_input_block(on: bool) -> void:
	# stop mouse/keyboard from reaching gameplay while open
	visuals.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # Map Esc to ui_cancel in Input Map
		toggle()

func set_music(v: float) -> void:
	_apply_bus_linear(BUS_MUSIC, v)

func set_sfx(v: float) -> void:
	_apply_bus_linear(BUS_SFX, v)

# Helpers: linear(0..1) <-> dB (Godot uses dB on busses)
static func _linear_to_db(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	if x <= 0.00001: return -80.0  # effectively silent
	return 20.0 * log(x) / log(10.0)

func _apply_bus_linear(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0: return
	AudioServer.set_bus_volume_db(idx, _linear_to_db(v))
