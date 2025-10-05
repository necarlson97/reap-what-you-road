extends Node2D
class_name RoadTile

var cell: Vector2i
var path_nodes: Array[TilePath] = []
@onready var grid: Grid = $"/root/Main/Grid"

static func create(_cell: Vector2i, parent: Node) -> RoadTile:
	var rt = RoadTile.new()
	rt.cell = _cell
	parent.add_child(rt)
	return rt

func clear_nodes() -> void:
	for tp in path_nodes:
		if is_instance_valid(tp):
			tp.queue_free()
	path_nodes.clear()
	
func get_paths(type: int) -> Array[TilePath]:
	rebuild()
	return path_nodes.filter(func(tp): return tp.agent_type == type)

func rebuild() -> void:
	# Kill prior nodes, then (re)spawn if this cell is a road.
	clear_nodes()

	var tps: Array[TilePath] = TilePath.create_from_tile(grid.roads, cell)
	for tp in tps:
		add_child(tp)
		var half := Vector2(Grid.CELL.x * 0.5, Grid.CELL.y * 0.5)
		tp.position = grid.cell_to_world_center(cell) - half
		path_nodes.append(tp)
	
func _to_string():
	return "RoadTile %s %s"%[self.cell, self.path_nodes]
