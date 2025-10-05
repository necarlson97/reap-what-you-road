extends Node2D

@onready var grid: GridPathing = $Grid
@onready var building_parent: Node2D = $Buildings
@onready var agent_parent: Node2D = $Agents

func _ready() -> void:
	Menu.open()
	Menu.btn_menu.visible = false
	Menu.btn_resume.visible = false
	
	for d: Destination in get_tree().get_nodes_in_group("destinations"):
		await d.spawn_agents(agent_parent)
	
