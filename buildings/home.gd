extends Building
class_name Home

@export var home_name := "House"

func _ready() -> void:
	hue_base = 0.6
	add_to_group("homes")
	add_to_group(home_name.to_lower())
	super()

func _to_string() -> String:
	return "Home %s"%get_grid_cell()

func get_description() -> String:
	return """
%s
Can be summoned-from or sent-to by other buildings.
""".strip_edges() % [home_name]
