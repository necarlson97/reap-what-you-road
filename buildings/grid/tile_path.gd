extends Node2D
class_name TilePath

const TILESIZE: float = 100.0
@export var sidewalk_offset: float = 10.0  # distance in from tile edge for pedestrians
@export var passing_offset: float = 2.0   # distance from sidewalk center for passing pedestrials
@export var lane_offset: float = 35.0      # distance in from tile edge for car centerline
@export var turn_inset: float = 12.0       # how far into the tile the arc pivot sits

enum Dir { N, E, S, W }
var from_dir: int
var to_dir: int

# The grass is on my left when I walk (not sreenspace left)
var on_left: bool = true
# Final array of tile_space points this route will take
var local_points: Array[Vector2]

var agent_type: int
enum AgentType { CAR, PED }

# debug draw
@export var debug_draw: bool = false
@export var debug_thickness: float = 2.0

# ===================== lifecycle =====================

func _draw() -> void:
	if !debug_draw or local_points.size() < 2:
		return
	var col := _debug_color()
	for i in range(local_points.size() - 1):
		draw_line(local_points[i], local_points[i+1], col, debug_thickness)
	# endpoints
	draw_circle(local_points[local_points.size()-1], 3.0, col.lightened(0.5))
	
	# label
	var s := _to_string()
	var where := local_points[0]
	var font := Control.new().get_theme_default_font()
	var size := 10
	var text_size := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pad := Vector2(1, 1)
	var rect := Rect2(where - text_size * 0.5 - pad, text_size + pad * 2.0)
	draw_rect(rect, Color.from_hsv(0.0, 0.0, 0.0, 0.8), true)
	draw_string(font, where - text_size * 0.5 + Vector2(0, text_size.y * 0.8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _debug_color() -> Color:
	var base := Color(0.2, 0.8, 1.0, 0.9) if agent_type == AgentType.CAR else Color(0.6, 1.0, 0.4, 0.9)
	# tint a bit by from/to
	var t := float((from_dir * 4 + to_dir) % 16) / 15.0
	return base.blend(Color.from_hsv(t, 0.7, 1.0, 0.6))

func _to_string() -> String:
	var left_s = "L" if on_left else "R"
	return "%s>%s %s"%[Dir.keys()[from_dir], Dir.keys()[to_dir], left_s]

# ===================== factories =====================

static func create(_type: int, _from: int, _to: int, _left: bool) -> TilePath:
	var tp := TilePath.new()
	tp.agent_type = _type
	tp.from_dir = _from
	tp.to_dir = _to
	tp.on_left = _left
	tp._make_path()   # builds local_points
	return tp

static func create_from_tile(tilemap: TileMapLayer, cell: Vector2i) -> Array[TilePath]:
	# Build paths for a TileMap cell by looking what neighbors we need to connect to
	var sides := _open_sides(tilemap, cell)
	return create_ped_paths(sides) + create_car_paths(sides)
	
static func create_ped_paths(sides) -> Array[TilePath]:
	var out: Array[TilePath] = []
	
	for a in sides:
		for b in sides:
			if a == b: continue
			out.append(create(AgentType.PED, a, b, true))
			out.append(create(AgentType.PED, a, b, false))

	return out

static func create_car_paths(sides: Array[int]):
	var out: Array[TilePath] = []
	
	for a in sides:
		for b in sides:
			if a == b: continue
			out.append(create(AgentType.CAR, a, b, false))

	return out

static func _open_sides(tm: TileMapLayer, cell: Vector2i) -> Array[int]:
	# Fallback predicate if none provided
	var pred: Callable = func(_tm: TileMapLayer, _c: Vector2i) -> bool:
		return _tm.get_cell_source_id(_c) != -1  # layer 0 non-empty == road

	var res: Array[int] = []
	if pred.call(tm, cell + Vector2i(0, -1)): res.append(Dir.N)
	if pred.call(tm, cell + Vector2i(1,  0)): res.append(Dir.E)
	if pred.call(tm, cell + Vector2i(0,  1)): res.append(Dir.S)
	if pred.call(tm, cell + Vector2i(-1, 0)): res.append(Dir.W)
	return res

# ===================== path construction =====================

func _make_path() -> void:
	if agent_type == AgentType.PED: local_points = _ped_points()
	else: local_points = _car_points()
	queue_redraw()

func _ped_points() -> Array[Vector2]:
	if _straight(from_dir, to_dir):
		return _straight_line(from_dir, to_dir, sidewalk_offset, passing_offset, on_left)
	return _simple_corner(from_dir, to_dir, sidewalk_offset, passing_offset, on_left, 0.0)

func _car_points() -> Array[Vector2]:
	# Straights: two points on the same lane centerline
	if _straight(from_dir, to_dir):
		return _straight_line(from_dir, to_dir, lane_offset)
	return _simple_corner(from_dir, to_dir, lane_offset, 0, false, turn_inset)

# -------- helpers --------

static func _straight_line(from:int, to:int, path_offset:float, passing_offset:=0.0, on_left:=false) -> Array[Vector2]:
	var leg_dir := _opp(from)  # direction of travel on the leg
	var pts: Array[Vector2]
	if _is_h(from):
		var y := _h_y(leg_dir, on_left, path_offset)
		y = _apply_po_h(y, leg_dir, passing_offset)
		pts.append(_border_xy(from, y))
		pts.append(_border_xy(to,   y))
	else:
		var x := _v_x(leg_dir, on_left, path_offset)
		x = _apply_po_v(x, leg_dir, passing_offset)
		pts.append(_border_xy(from, x))
		pts.append(_border_xy(to,   x))
	return pts

static func _simple_corner(from:int, to:int, path_offset:float, passing_offset:float, on_left:=false, inset:=0.0) -> Array[Vector2]:
	var in_dir  := _opp(from)  # first leg travel direction
	var out_dir := to          # second leg travel direction

	# Compute the lane/sidewalk center for each leg, then apply keep-right passing offsets
	var x_lane: float
	var y_lane: float
	if _is_h(from):
		# horizontal first, vertical second
		y_lane = _h_y(in_dir,  on_left, path_offset)
		y_lane = _apply_po_h(y_lane, in_dir,  passing_offset)
		x_lane = _v_x(out_dir, on_left, path_offset)
		x_lane = _apply_po_v(x_lane, out_dir, passing_offset)
	else:
		# vertical first, horizontal second
		x_lane = _v_x(in_dir,  on_left, path_offset)
		x_lane = _apply_po_v(x_lane, in_dir,  passing_offset)
		y_lane = _h_y(out_dir, on_left, path_offset)
		y_lane = _apply_po_h(y_lane, out_dir, passing_offset)

	var start_pt: Vector2 = (_border_xy(from, y_lane) if _is_h(from) else _border_xy(from, x_lane))
	var end_pt  : Vector2 = (_border_xy(to,   x_lane) if _is_h(from) else _border_xy(to,   y_lane))
	var K := Vector2(x_lane, y_lane)  # sharp corner (intersection of leg centerlines)

	if inset <= 0.0:
		return [start_pt, K, end_pt] as Array[Vector2]

	# Inset samples: BEFORE corner on incoming, AFTER corner on outgoing
	var u_in  := _vec(in_dir)
	var u_out := _vec(out_dir)
	var P1 := K - u_in  * inset
	var P2 := K + u_out * inset
	return [start_pt, P1, P2, end_pt] as Array[Vector2]

static func _opp(d:int) -> int:
	return [Dir.S, Dir.W, Dir.N, Dir.E][d]  # N->S, E->W, S->N, W->E

static func _right_of(d:int) -> int:
	return [Dir.E, Dir.S, Dir.W, Dir.N][d]  # clockwise

static func _is_h(d:int) -> bool:
	return d == Dir.E or d == Dir.W

static func _vec(d:int) -> Vector2:
	match d:
		Dir.N: return Vector2(0, -1)
		Dir.E: return Vector2(1, 0)
		Dir.S: return Vector2(0, 1)
		Dir.W: return Vector2(-1, 0)
	return Vector2(-1, 0)

static func _h_y(moving:int, on_left:bool, offset: float) -> float:
	# Facing E: right is south; facing W: right is north
	if moving == Dir.E: return (TILESIZE - offset) if not on_left else offset
	else: return offset if not on_left else (TILESIZE - offset)

static func _v_x(moving:int, on_left:bool, offset: float) -> float:
	# Facing S: right is west; facing N: right is east
	if moving == Dir.S: return offset if not on_left else (TILESIZE - offset)
	else: return (TILESIZE - offset) if not on_left else offset

static func _apply_po_h(y:float, moving:int, po:float) -> float:
	return y + (po if moving == Dir.E else -po)

static func _apply_po_v(x:float, moving:int, po:float) -> float:
	return x + (po if moving == Dir.N else -po)

static func _border_xy(d:int, const_coord:float) -> Vector2:
	# Point on tile border along the lane line (with passing offset already applied)
	match d:
		Dir.N: return Vector2(const_coord, 0.0)
		Dir.E: return Vector2(TILESIZE, const_coord)
		Dir.S: return Vector2(const_coord, TILESIZE)
		_:     return Vector2(0.0, const_coord) # W

func _left_of(d:int) -> int:
	return [Dir.W, Dir.N, Dir.E, Dir.S][d]  # counter-clockwise
	
static func _orthogonal(a: int, b: int) -> bool:
	return a != b && int(abs(a - b)) % 2 == 1
	
static func _straight(a: int, b: int) -> bool:
	return a !=b && !_orthogonal(a, b)
