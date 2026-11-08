class_name LevelBuilder
extends RefCounted
## ASCII haritadan hastane geometrisini, çarpışmaları ve yol ızgarasını üretir.
## '#' duvar, bölge harfleri zemin, DOOR_CHARS kapı hücreleridir.

const CELL := 2.0
const HEIGHT := 3.2
const DOOR_W := 1.3
const DOOR_H := 2.35
const DOOR_CHARS := "DMOBE"
const LOCKED_CHARS := "MOBE"

const ZONES := {
	".": {"floor": "floor_hall", "wall": "wall_hall", "ceil": "ceiling", "surface": "tile"},
	"l": {"floor": "floor_hall", "wall": "wall_hall", "ceil": "ceiling", "surface": "tile"},
	"w": {"floor": "floor_ward", "wall": "wall_ward", "ceil": "ceiling", "surface": "soft"},
	"n": {"floor": "floor_ward", "wall": "wall_hall", "ceil": "ceiling", "surface": "soft"},
	"o": {"floor": "floor_office", "wall": "wall_office", "ceil": "ceiling", "surface": "wood"},
	"k": {"floor": "floor_base", "wall": "wall_base", "ceil": "wall_base", "surface": "concrete"},
	"s": {"floor": "floor_hall", "wall": "wall_tile", "ceil": "ceiling", "surface": "tile"},
	"m": {"floor": "floor_base", "wall": "wall_tile", "ceil": "wall_base", "surface": "concrete"},
	"b": {"floor": "floor_base", "wall": "wall_base", "ceil": "wall_base", "surface": "concrete"},
}

var rows: PackedStringArray
var width := 0
var depth := 0
var doors: Array[Dictionary] = []

## Geometri CHUNK x CHUNK hücrelik parçalara bölünür: Mobile renderer bir mesh'i en fazla
## 8 omni + 8 spot ışıkla aydınlatır, tek parça seviyede ışıkların çoğu kaybolurdu.
const CHUNK := 4

var _tools: Dictionary = {}  # Vector2i chunk -> { malzeme id -> SurfaceTool }
var _chunk := Vector2i.ZERO
var _body: StaticBody3D


func _init(map_rows: PackedStringArray) -> void:
	rows = map_rows
	depth = rows.size()
	for r in rows:
		width = maxi(width, r.length())


# ---------------------------------------------------------------- sorgular

func at(x: int, z: int) -> String:
	if z < 0 or z >= depth or x < 0:
		return "#"
	var r := rows[z]
	if x >= r.length():
		return "#"
	return r[x]


func is_walk(x: int, z: int) -> bool:
	var c := at(x, z)
	return c != "#" and c != " "


func is_door(x: int, z: int) -> bool:
	return DOOR_CHARS.contains(at(x, z))


func zone_char(x: int, z: int) -> String:
	var c := at(x, z)
	if ZONES.has(c):
		return c
	if is_door(x, z):
		var best := ""
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := at(x + d.x, z + d.y)
			if n == ".":
				return n
			if ZONES.has(n) and best == "":
				best = n
		return best if best != "" else "."
	return "."


func surface_at(pos: Vector3) -> String:
	var c := world_to_cell(pos)
	return ZONES[zone_char(c.x, c.y)]["surface"]


static func cell_center(x: int, z: int) -> Vector3:
	return Vector3((x + 0.5) * CELL, 0.0, (z + 0.5) * CELL)


static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


# ---------------------------------------------------------------- inşa

func build(parent: Node3D) -> void:
	_body = StaticBody3D.new()
	_body.name = "LevelCollision"
	_body.collision_layer = 1
	_body.collision_mask = 0
	parent.add_child(_body)

	for z in depth:
		for x in width:
			if not is_walk(x, z):
				continue
			_chunk = Vector2i(x / CHUNK, z / CHUNK)
			if is_door(x, z):
				_door_cell(x, z)
				continue
			var zn: Dictionary = ZONES[at(x, z)]
			var x0 := x * CELL
			var z0 := z * CELL
			var x1 := x0 + CELL
			var z1 := z0 + CELL
			_quad(zn.floor, [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)], Vector3.UP, false)
			_quad(zn.ceil, [Vector3(x0, HEIGHT, z0), Vector3(x1, HEIGHT, z0), Vector3(x1, HEIGHT, z1), Vector3(x0, HEIGHT, z1)], Vector3.DOWN, false)
			if not is_walk(x, z - 1):
				_wall(zn.wall, Vector3(x0, 0, z0), Vector3(x1, 0, z0), 0.0, HEIGHT, Vector3.BACK)
			if not is_walk(x, z + 1):
				_wall(zn.wall, Vector3(x0, 0, z1), Vector3(x1, 0, z1), 0.0, HEIGHT, Vector3.FORWARD)
			if not is_walk(x - 1, z):
				_wall(zn.wall, Vector3(x0, 0, z0), Vector3(x0, 0, z1), 0.0, HEIGHT, Vector3.RIGHT)
			if not is_walk(x + 1, z):
				_wall(zn.wall, Vector3(x1, 0, z0), Vector3(x1, 0, z1), 0.0, HEIGHT, Vector3.LEFT)

	for z in range(-1, depth + 1):
		for x in range(-1, width + 1):
			if not is_walk(x, z) and _near_walk(x, z):
				_box(Vector3((x + 0.5) * CELL, HEIGHT * 0.5, (z + 0.5) * CELL), Vector3(CELL, HEIGHT, CELL))
	var span := Vector3(width * CELL + 8.0, 1.0, depth * CELL + 8.0)
	_box(Vector3(width * CELL * 0.5, -0.5, depth * CELL * 0.5), span)
	_box(Vector3(width * CELL * 0.5, HEIGHT + 0.5, depth * CELL * 0.5), span)

	for ch: Vector2i in _tools:
		var mesh := ArrayMesh.new()
		for id in _tools[ch]:
			var st: SurfaceTool = _tools[ch][id]
			st.generate_tangents()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, Mats.pbr(id))
		var mi := MeshInstance3D.new()
		mi.name = "LevelMesh_%d_%d" % [ch.x, ch.y]
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		parent.add_child(mi)


func make_astar() -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, width, depth)
	a.cell_size = Vector2(1, 1)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.update()
	for z in depth:
		for x in width:
			if not is_walk(x, z) or LOCKED_CHARS.contains(at(x, z)):
				a.set_point_solid(Vector2i(x, z), true)
	return a


func _near_walk(x: int, z: int) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if is_walk(x + dx, z + dz):
				return true
	return false


func _door_cell(x: int, z: int) -> void:
	var along_x := is_walk(x - 1, z) and is_walk(x + 1, z)
	var center := cell_center(x, z)
	var d := Vector3.RIGHT if along_x else Vector3.BACK
	var s := Vector3.BACK if along_x else Vector3.RIGHT
	var zn: Dictionary = ZONES[zone_char(x, z)]
	var h := CELL * 0.5
	var ow := DOOR_W * 0.5
	var up := Vector3.UP * DOOR_H

	_quad(zn.floor, [center + (-d - s) * h, center + (d - s) * h, center + (d + s) * h, center + (-d + s) * h], Vector3.UP, false)
	_quad(zn.wall, [center - d * h - s * ow + up, center + d * h - s * ow + up, center + d * h + s * ow + up, center - d * h + s * ow + up], Vector3.DOWN, false)
	for sgn in [-1.0, 1.0]:
		var off: Vector3 = s * ow * sgn
		_wall(zn.wall, center - d * h + off, center + d * h + off, 0.0, DOOR_H, -s * sgn)
	for sgn in [-1.0, 1.0]:
		var face: Vector3 = center + d * h * sgn
		var nc := Vector2i(x + int(d.x * sgn), z + int(d.z * sgn))
		var nz: Dictionary = ZONES[zone_char(nc.x, nc.y)]
		var nrm: Vector3 = d * sgn
		_wall(nz.wall, face - s * h, face - s * ow, 0.0, HEIGHT, nrm)
		_wall(nz.wall, face + s * ow, face + s * h, 0.0, HEIGHT, nrm)
		_wall(nz.wall, face - s * ow, face + s * ow, DOOR_H, HEIGHT, nrm)

	for sgn in [-1.0, 1.0]:
		var c: Vector3 = center + s * sgn * (h + ow) * 0.5 + Vector3.UP * HEIGHT * 0.5
		_box(c, d.abs() * CELL + s.abs() * (h - ow) + Vector3.UP * HEIGHT)
	_box(center + Vector3.UP * (DOOR_H + HEIGHT) * 0.5, d.abs() * CELL + s.abs() * DOOR_W + Vector3.UP * (HEIGHT - DOOR_H))

	doors.append({"cell": Vector2i(x, z), "char": at(x, z), "along_x": along_x, "center": center})


func _st(id: String) -> SurfaceTool:
	if not _tools.has(_chunk):
		_tools[_chunk] = {}
	var tools: Dictionary = _tools[_chunk]
	if not tools.has(id):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[id] = st
	return tools[id]


## pts: dört köşe. wall_uv=false ise UV = (x, z), aksi halde (yatay, yükseklik).
func _quad(id: String, pts: Array, normal: Vector3, wall_uv: bool) -> void:
	var st := _st(id)
	var uvs: Array[Vector2] = []
	for p: Vector3 in pts:
		if wall_uv:
			uvs.append(Vector2(p.x + p.z, HEIGHT - p.y))
		else:
			uvs.append(Vector2(p.x, p.z))
	# Godot'da ön yüz saat yönündedir; geometrik normal istenen normalle aynı yöne
	# bakıyorsa sıra terstir. Yanlış sarım ışığın görünen yüzde ters normal kullanmasına yol açar.
	var order := [0, 1, 2, 0, 2, 3]
	var p0: Vector3 = pts[0]
	if (pts[1] - p0).cross(pts[2] - p0).dot(normal) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


func _wall(id: String, a: Vector3, b: Vector3, y0: float, y1: float, normal: Vector3) -> void:
	var lo := Vector3.UP * y0
	var hi := Vector3.UP * y1
	_quad(id, [a + lo, b + lo, b + hi, a + hi], normal, true)


func _box(center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = center
	_body.add_child(cs)
