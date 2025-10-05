extends Node2D
class_name Arrow

const LIFETIME := 2.2      # seconds
const FADE_IN  := 0.08
const START_A  := 0.0
const END_A    := 1.0
const JITTER   := 2.0      # subtle nudge
const SCALE_IN := 1.0
const SCALE_OUT:= 0.92

func _ready() -> void:
	# Start transparent and slightly scaled up so the fade feels snappy
	#modulate.a = START_A
	scale = Vector2(SCALE_IN, SCALE_IN)

	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# quick pop-in
	t.tween_property(self, "modulate:a", END_A, FADE_IN)

	# gentle drift + shrink + fade out over remaining time
	var remain = max(0.0, LIFETIME - FADE_IN)
	t.parallel().tween_property(self, "position", position + Vector2(-JITTER, 0).rotated(rotation), LIFETIME)
	t.parallel().tween_property(self, "scale", Vector2(SCALE_OUT, SCALE_OUT), LIFETIME)
	t.parallel().tween_property(self, "modulate:a", 0.0, LIFETIME)

	t.finished.connect(queue_free)

func setup(tip_global: Vector2, angle_rad: float) -> void:
	# TIP is the node origin; put it exactly where you want the arrow to point.
	global_position = tip_global
	rotation = angle_rad

# Preload once (top of the script that will spawn them):
const ArrowHintScene := preload("res://ui/reaper/arrow.tscn")
static func spawn_arrow_tip_at(tip_global: Vector2, angle_rad: float, parent: Node) -> Arrow:
	var arrow := ArrowHintScene.instantiate()
	parent.add_child(arrow)
	(arrow as Node2D).setup(tip_global, angle_rad)
	return arrow
