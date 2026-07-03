extends Node2D

# =============================================================================
# 联机3人乱斗模式地图（比单挑地图稍大）
# 2000x2000
# =============================================================================

@export var map_size: Vector2 = Vector2(2000, 2000)
@export var obstacle_count: int = 28
@export var map_type: int = 1
@export var barrel_count: int = 8
@export var shop_zone_center: Vector2 = Vector2(800, 800)
@export var shop_zone_radius: float = 220.0


func _ready() -> void:
	_create_floor()
	_create_walls()
	_create_obstacles()
	call_deferred("_bake_navigation")
	_spawn_barrels()


func _spawn_barrels() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var half: Vector2 = map_size * 0.5
	var margin: float = 150.0
	var obstacle_rects: Array = []
	for obs in get_children():
		if obs.name == "Obstacle":
			var obs_size: Vector2 = Vector2.ZERO
			for child in obs.get_children():
				if child is CollisionShape2D and child.shape:
					if child.shape is RectangleShape2D:
						obs_size = child.shape.size
					elif child.shape is CircleShape2D:
						obs_size = Vector2(child.shape.radius * 2, child.shape.radius * 2)
			if obs_size != Vector2.ZERO:
				obstacle_rects.append({"pos": obs.position, "size": obs_size})

	for i in range(barrel_count):
		var pos: Vector2 = Vector2.ZERO
		var valid: bool = false
		for _attempt in range(30):
			pos = Vector2(rng.randf_range(-half.x + margin, half.x - margin), rng.randf_range(-half.y + margin, half.y - margin))
			if pos.distance_to(shop_zone_center) < shop_zone_radius:
				continue
			var overlaps: bool = false
			for rect in obstacle_rects:
				var half_s: Vector2 = (rect.size + Vector2(60, 60)) * 0.5
				if abs(pos.x - rect.pos.x) < half_s.x and abs(pos.y - rect.pos.y) < half_s.y:
					overlaps = true
					break
			if not overlaps:
				valid = true
				break
		if not valid:
			continue
		var barrel = load("res://scenes/game/Barrel.tscn").instantiate()
		barrel.global_position = pos
		add_child(barrel)


func _create_floor() -> void:
	var floor_rect: ColorRect = ColorRect.new()
	floor_rect.name = "Floor"
	floor_rect.color = Color(0.30, 0.72, 0.35, 1.0)
	var half: Vector2 = map_size * 0.5
	floor_rect.position = -half
	floor_rect.size = map_size
	floor_rect.z_index = -10
	add_child(floor_rect)
	_add_floor_detail()


func _add_floor_detail() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var base: Color = _get_floor_node().color
	for i in range(500):
		var s: float = rng.randf_range(2, 7)
		var half_map: Vector2 = map_size * 0.5
		var pos: Vector2 = Vector2(rng.randf_range(-half_map.x, half_map.x), rng.randf_range(-half_map.y, half_map.y))
		var vary: float = rng.randf_range(-0.06, 0.06)
		var c: Color = Color(clamp(base.r + vary, 0.0, 1.0), clamp(base.g + vary * 0.85, 0.0, 1.0), clamp(base.b + vary * 0.6, 0.0, 1.0), 1.0)
		_draw_pixel(pos, s, c)
	for i in range(120):
		var half_map: Vector2 = map_size * 0.5
		var pos: Vector2 = Vector2(rng.randf_range(-half_map.x, half_map.x), rng.randf_range(-half_map.y, half_map.y))
		var angle: float = rng.randf_range(0, PI)
		var length: float = rng.randf_range(20, 70)
		var width: float = rng.randf_range(2, 6)
		var vary: float = rng.randf_range(-0.08, 0.04)
		var c: Color = Color(clamp(base.r + vary, 0.0, 1.0), clamp(base.g + vary * 0.8, 0.0, 1.0), clamp(base.b + vary * 0.5, 0.0, 1.0), 1.0)
		_draw_line(pos, angle, length, width, c)
	for i in range(60):
		var half_map: Vector2 = map_size * 0.5
		var pos: Vector2 = Vector2(rng.randf_range(-half_map.x, half_map.x), rng.randf_range(-half_map.y, half_map.y))
		var s: float = rng.randf_range(6, 13)
		var dark: float = rng.randf_range(-0.1, -0.04)
		var c: Color = Color(clamp(base.r + dark, 0.0, 1.0), clamp(base.g + dark * 0.9, 0.0, 1.0), clamp(base.b + dark * 0.7, 0.0, 1.0), 1.0)
		_draw_pixel(pos, s, c)


func _draw_line(pos: Vector2, angle: float, length: float, width: float, color: Color) -> void:
	var poly: Polygon2D = Polygon2D.new()
	var half_l: float = length * 0.5
	var half_w: float = width * 0.5
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	poly.polygon = PackedVector2Array([
		pos + dir * half_l + perp * half_w,
		pos + dir * half_l - perp * half_w,
		pos - dir * half_l - perp * half_w,
		pos - dir * half_l + perp * half_w,
	])
	poly.color = color
	poly.z_index = -9
	add_child(poly)


func _draw_pixel(pos: Vector2, size: float, color: Color) -> void:
	var poly: Polygon2D = Polygon2D.new()
	var half_s: float = size * 0.5
	poly.polygon = PackedVector2Array([Vector2(-half_s, -half_s), Vector2(half_s, -half_s), Vector2(half_s, half_s), Vector2(-half_s, half_s)])
	poly.color = color
	poly.position = pos
	poly.z_index = -9
	add_child(poly)


func _get_floor_node() -> ColorRect:
	return get_node("Floor") as ColorRect


func _create_walls() -> void:
	var thickness: float = 64.0
	var half: Vector2 = map_size * 0.5
	var wall_defs: Array = [
		[Vector2(0, -half.y - thickness * 0.5), Vector2(map_size.x + thickness * 2, thickness)],
		[Vector2(0, half.y + thickness * 0.5), Vector2(map_size.x + thickness * 2, thickness)],
		[Vector2(-half.x - thickness * 0.5, 0), Vector2(thickness, map_size.y + thickness * 2)],
		[Vector2(half.x + thickness * 0.5, 0), Vector2(thickness, map_size.y + thickness * 2)],
	]
	for wd in wall_defs:
		var wall: StaticBody2D = StaticBody2D.new()
		wall.position = wd[0]
		wall.collision_layer = 1
		wall.collision_mask = 0
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = wd[1]
		col.shape = shape
		wall.add_child(col)
		var vis: ColorRect = ColorRect.new()
		vis.size = wd[1]
		vis.position = -wd[1] * 0.5
		vis.color = Color(0.15, 0.15, 0.18, 1.0)
		wall.add_child(vis)
		add_child(wall)


func _create_obstacles() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var half: Vector2 = map_size * 0.5
	var margin: float = 120.0
	var playable_w: float = map_size.x - margin * 2
	var playable_h: float = map_size.y - margin * 2
	var grid_n: int = 5
	var cell_w: float = playable_w / grid_n
	var cell_h: float = playable_h / grid_n
	var placed: int = 0
	var candidates: Array = []
	for row in range(grid_n):
		for col in range(grid_n):
			var cx: float = -half.x + margin + (col + 0.5) * cell_w
			var cy: float = -half.y + margin + (row + 0.5) * cell_h
			candidates.append(Vector2(cx, cy))
	candidates.shuffle()
	for pos in candidates:
		if placed >= obstacle_count:
			break
		if pos.distance_to(shop_zone_center) < shop_zone_radius:
			continue
		_create_obstacle_at(rng, pos)
		placed += 1
	while placed < obstacle_count:
		var pos: Vector2 = Vector2(rng.randf_range(-half.x + margin, half.x - margin), rng.randf_range(-half.y + margin, half.y - margin))
		if pos.distance_to(shop_zone_center) < shop_zone_radius:
			continue
		_create_obstacle_at(rng, pos)
		placed += 1


func _create_obstacle_at(rng: RandomNumberGenerator, pos: Vector2) -> void:
	var base_s: float = rng.randf_range(55, 110)
	var ratio: float = rng.randf_range(0.6, 1.4)
	var size: Vector2 = Vector2(base_s, base_s * ratio)
	size.x = clamp(size.x, 50, 130)
	size.y = clamp(size.y, 50, 130)
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Obstacle"
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var vis: Panel = Panel.new()
	vis.size = size
	vis.position = -size * 0.5
	var base_c: float = 0.42
	var vary: float = rng.randf_range(-0.06, 0.06)
	vis.self_modulate = Color(base_c + vary, base_c + vary * 0.9, base_c + vary * 0.75, 1.0)
	body.add_child(vis)
	add_child(body)


func _bake_navigation() -> void:
	var nav_region: NavigationRegion2D = NavigationRegion2D.new()
	nav_region.name = "NavRegion"
	var nav_poly: NavigationPolygon = NavigationPolygon.new()
	var half: Vector2 = map_size * 0.5
	var margin: float = 80.0
	var verts: PackedVector2Array = PackedVector2Array([
		Vector2(-half.x + margin, -half.y + margin),
		Vector2(half.x - margin, -half.y + margin),
		Vector2(half.x - margin, half.y - margin),
		Vector2(-half.x + margin, half.y - margin),
	])
	nav_poly.vertices = verts
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)
