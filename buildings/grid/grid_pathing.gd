extends Grid
class_name GridPathing

signal index_rebuilt()

var astar := AStarGrid2D.new()
var AgentType = TilePath.AgentType

func rebuild() -> void:
	# 1) Collect walkable cells (roads + building cells)
	var road_cells: Array[Vector2i] = roads.get_used_cells()
	var building_cells: Array[Vector2i] = _collect_building_cells()

	# 2) Resize A* region to cover all relevant cells (with padding)
	var all := road_cells.duplicate()
	all.append_array(building_cells)
	if all.is_empty():
		return

	var rect: Rect2i = roads.get_used_rect()
	rect.expand(rect.position + Vector2i(-20, -20))
	rect.expand(rect.end + Vector2i(20, 20))
	astar.cell_size = Vector2(TilePath.TILESIZE, TilePath.TILESIZE)
	astar.region = rect
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	# 3) Default block everything, then unblock walkables
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			astar.set_point_solid(Vector2i(x, y), true)

	for c in road_cells:
		astar.set_point_solid(c, false)

	for c in building_cells:
		astar.set_point_solid(c, false)
		
	for dest in get_tree().get_nodes_in_group("destinations"):
		(dest as Destination).request_refresh()

func path_between_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var world_points = astar.get_point_path(from_cell, to_cell)
	var cells: Array[Vector2i] 
	for wp in world_points:
		cells.append(world_to_cell(wp))
	return cells

func get_good_start(cells: Array[Vector2i]) -> Vector2:
	# The current closest point to the 'head' of the path, allowing us to
	# string along sidewalks while not crossing randomly
	var start_pt = cell_to_world_center(cells[0])
	# Nudge it towards the final destination - that way, it might choose
	# a smarter side of the road to start with
	var dest_point := cell_to_world_center(cells[cells.size() - 1])
	var dir :Vector2= dest_point - start_pt
	
	if dir.length() > 0.001:
		# tweak 0.2..0.35 depending on how strong you want the bias
		var nudge := float(TilePath.TILESIZE) * 0.5
		start_pt += dir.normalized() * nudge
	
	return start_pt

func grid_path_to_waypoints(cells: Array[Vector2i], path_type: int = AgentType.PED) -> Array[Vector2]:
	var pts: Array[Vector2]
	if cells.is_empty():
		return pts
	
	var closest_point := get_good_start(cells)
	var dest_point := cell_to_world_center(cells[cells.size() - 1])
	for i in range(cells.size()):
		var cell := cells[i]
		if !road_tiles.has(cell):
			continue
		
		# Get all the sidewalk/road paths for this cell
		var rt := road_tiles[cell]
		var paths := rt.get_paths(path_type)
		
		# (remove any empty ones)
		var candidates: Array[TilePath]= paths.filter(
			func(tp: TilePath): return tp.local_points.size() > 0
		)
		var cell_world := cell_to_world_center(cell) - (CELL * 0.5)
		
		# The best path is: close to where we are 'now' (start/working-end of path)
		# and takes us 'where we need to be next' (or the end)
		var next_center := dest_point
		if i + 1 < cells.size():
			next_center = cell_to_world_center(cells[i + 1])
		candidates.sort_custom(func(a: TilePath, b: TilePath) -> bool:
			var a_in  := cell_world + a.local_points[0]
			var b_in  := cell_world + b.local_points[0]
			var a_out := cell_world + a.local_points[a.local_points.size()-1]
			var b_out := cell_world + b.local_points[b.local_points.size()-1]
			var a_score := closest_point.distance_squared_to(a_in)  + a_out.distance_squared_to(next_center)
			var b_score := closest_point.distance_squared_to(b_in)  + b_out.distance_squared_to(next_center)
			return a_score < b_score
		)

		var best_path: Array[Vector2]= [CELL * 0.5]
		if !candidates.is_empty():
			best_path = candidates[0].local_points
		for p in best_path:
			pts.append(cell_world + p)
		closest_point = pts[-1]

	# Drop inline points for simplicity
	#return _simplify_collinear(pts)
	# For now, allows cars to 'get back on path'
	return pts

# Remove interior points that lie on straight segments (collinear).
func _simplify_collinear(points_world: Array[Vector2]) -> Array[Vector2]:
	if points_world.size() <= 2:
		return points_world

	var out: Array[Vector2]
	out.append(points_world[0])

	for i in range(1, points_world.size() - 1):
		var a := points_world[i - 1]
		var b := points_world[i]
		var c := points_world[i + 1]
		var ab := (b - a)
		var bc := (c - b)
		# If nearly collinear, drop b
		if ab.length() == 0.0 or bc.length() == 0.0:
			continue
		var cross = abs(ab.x * bc.y - ab.y * bc.x)
		if cross > 0.001: # keep corners
			out.append(b)

	out.append(points_world[points_world.size() - 1])
	return out

func _collect_building_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var nodes := _gather_buildings()
	for b in nodes:
		if b.has_method("get_grid_cell"):
			out.append(b.get_grid_cell())
	return out

func _gather_buildings() -> Array:
	return get_tree().get_nodes_in_group("buildings")

func _in_bounds_walkable(c: Vector2i) -> bool:
	return astar.is_in_boundsv(c) and !astar.is_point_solid(c)

func _update_neighbors(layer: TileMapLayer, center: Vector2i) -> void:
	# TODO but sloppy, but hey
	super._update_neighbors(layer, center)
	rebuild()
