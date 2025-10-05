extends Node2D
class_name Grid

const TILESIZE := TilePath.TILESIZE
const CELL := Vector2i(TILESIZE, TILESIZE)

@onready var roads : TileMapLayer = $Roads
@onready var roads_preview : TileMapLayer = $GhostRoads

@export var terrain_set: int = 0        # Tileset terrain set index (NOT source id)
@export var road_terrain: int = 0       # Terrain id inside that set

# --- runtime path overlay & cache ---
@onready var paths_overlay := Node2D.new()
var road_tiles: Dictionary[Vector2i, RoadTile] = {}

func _ready() -> void:
	add_to_group("grid")
	add_child(paths_overlay)
	_resync_from_scene()

func _resync_from_scene() -> void:
	# Recreate road_tiles dictionary from what's already painted in the editor.
	road_tiles.clear()

	# Gather all roads currently present on the layer
	var used: Array[Vector2i] = roads.get_used_cells()
	for cell in used:
		place_road(cell)

	# Make sure every Building has a driveway (and include it in used set)
	for b: Building in get_tree().get_nodes_in_group("buildings"):
		place_road(b.get_grid_cell())
	
func mouse_cell() -> Vector2i:
	return world_to_cell(get_global_mouse_position())

func world_to_cell(p_world: Vector2) -> Vector2i:
	return roads.local_to_map(to_local(p_world))

func cell_to_world_center(cell: Vector2i) -> Vector2:
	return roads.to_global(roads.map_to_local(cell))

func snap_world_to_cell_center(p_world: Vector2) -> Vector2:
	return cell_to_world_center(world_to_cell(p_world))

func is_cell_blocked(cell: Vector2i) -> bool:
	return has_road(cell)

func has_road(cell: Vector2i) -> bool:
	# On a dedicated road layer, "non-empty" == road
	return roads.get_cell_source_id(cell) != -1

func place_road(cell: Vector2i) -> void:
	roads.set_cells_terrain_connect([cell], terrain_set, road_terrain)
	road_tiles[cell] = RoadTile.create(cell, self)
	_update_neighbors(roads, cell)

func remove_road(cell: Vector2i, force=false) -> void:
	var buildings = get_tree().get_nodes_in_group("buildings")
	if !force and buildings.any(func(b: Building): return b.get_grid_cell() == cell):
		# Don't erase driveways
		return
	road_tiles.erase(cell)
	roads.set_cells_terrain_connect([cell], terrain_set, -1)
	_update_neighbors(roads, cell)
	for rt in road_tiles.values():
		rt.rebuild()
		
func clear_road():
	road_tiles.clear()
	roads.clear()
	var buildings = get_tree().get_nodes_in_group("buildings")
	for b: Building in buildings:
		place_driveway(b.get_grid_cell())
	_update_neighbors(roads, Vector2i.ZERO)

func place_driveway(cell: Vector2i) -> void:
	# Place a special ending road tile, for under buildings
	# TODO for now - just use the same set
	place_road(cell)

func toggle_road_at_cell(cell: Vector2i) -> void:
	if has_road(cell): remove_road(cell)
	else: place_road(cell)

const ORTHO := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
func _update_neighbors(layer: TileMapLayer, center: Vector2i) -> void:
	# Re-run terrain connect on all already-road neighbors + the center.
	# (Center is included so add/remove re-evaluates shape if needed.)
	var retouch := PackedVector2Array()
	for d in ORTHO:
		var n :Vector2i= center + d
		if layer.get_cell_source_id(n) != -1:
			retouch.append(n)
		if n in road_tiles:
			road_tiles[n].rebuild()
	if retouch.size() > 0:
		layer.set_cells_terrain_connect(retouch, terrain_set, road_terrain)

# --- preview (ghost) ---
func preview_clear() -> void:
	# wipe the whole preview layer
	roads_preview.clear()

func preview(cell: Vector2i) -> void:
	# Rebuild preview to match the real network + the hovered cell.
	# This ensures the hovered cell autoconnects/orients exactly as if placed.
	
	# First add all the real roads
	var ghost_refresh : Array[Vector2i]
	for d in ORTHO:
		var n:Vector2i = cell + d
		if has_road(n):
			ghost_refresh.append(n)
	# Lastly, add the titular preview that is hovered
	ghost_refresh.append(cell)

	roads_preview.clear()
	roads_preview.set_cells_terrain_connect(ghost_refresh, terrain_set, road_terrain)

func spawn_near_center(parent: Node2D, packed: PackedScene, max_radius: int = 128) -> Node2D:
	var radius := 5
	while radius <= max_radius:
		for i in range(5):
			var cell := Vector2i(
				randi_range(-radius, radius),
				randi_range(-radius/2, radius/2)
			)
			if !is_cell_blocked(cell):
				var node := packed.instantiate() as Node2D
				parent.add_child(node)
				node.global_position = cell_to_world_center(cell)
				if node is Building:
					place_driveway(cell)
				
				return node
		radius += 1

	push_warning("Building.spawn_near_center: no free cell found up to radius %d" % max_radius)
	return null
