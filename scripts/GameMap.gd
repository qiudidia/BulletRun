extends Node2D

# =============================================================================
# 游戏地图脚本
# map_type: 0 = 僵尸模式(暗色战场风), 1 = BOT模式(明亮干净风)
# =============================================================================

@export var map_size: Vector2 = Vector2(2400, 2400)
@export var obstacle_count: int = 36
@export var map_type: int = 0

# 爆炸桶数量
@export var barrel_count: int = 10

# 商店安全区：Bot 模式会在此放置实体商店，生成掩体时自动避开
@export var shop_zone_center: Vector2 = Vector2(900, 900)
@export var shop_zone_radius: float = 250.0


func _ready() -> void:
	_create_floor()
	_create_walls()
	_create_obstacles()
	call_deferred("_bake_navigation")
	_spawn_barrels()


func _spawn_barrels() -> void:
	# 在地图随机位置生成爆炸桶，避开掩体和商店
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var half: Vector2 = map_size * 0.5
	var margin: float = 150.0
	# 收集所有掩体位置和大小，用于避开重叠
	var obstacle_rects: Array = []
	for obs in get_children():
		if obs.name == "Obstacle":
			var obs_size: Vector2 = Vector2.ZERO
			# 获取掩体碰撞形状大小
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
		# 多次尝试找一个不重叠的位置
		for _attempt in range(30):
			pos = Vector2(
				rng.randf_range(-half.x + margin, half.x - margin),
				rng.randf_range(-half.y + margin, half.y - margin)
			)
			# 避开商店安全区
			if pos.distance_to(shop_zone_center) < shop_zone_radius:
				continue
			# 避开所有掩体（加60px缓冲区，防止桶贴在掩体边缘）
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
			continue  # 找不到合适位置就跳过这个桶
		var barrel = load("res://scenes/game/Barrel.tscn").instantiate()
		barrel.global_position = pos
		add_child(barrel)



# =============================================================================
# 地板
# =============================================================================
func _create_floor() -> void:
	# 直接用 ColorRect 铺色，无贴图、无平铺缝隙
	var floor_rect: ColorRect = ColorRect.new()
	floor_rect.name = "Floor"

	if map_type == 1:
		# BOT模式：亮青绿色草地
		floor_rect.color = Color(0.30, 0.72, 0.35, 1.0)
	else:
		# 僵尸模式：深灰绿，阴沉战场
		floor_rect.color = Color(0.18, 0.23, 0.18, 1.0)

	var half: Vector2 = map_size * 0.5
	floor_rect.position = -half
	floor_rect.size = map_size
	floor_rect.z_index = -10
	add_child(floor_rect)

	# 加地面细节纹理（微小色块，不用贴图平铺）
	_add_floor_detail()



func _add_floor_detail() -> void:
	# 在地上随机撒深浅色块/短线条，模拟草地/战场纹理细节
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var base: Color = _get_floor_node().color

	# 1. 小色点：600 个，营造颗粒感
	for i in range(600):
		var s: float = rng.randf_range(2, 7)
		var half_map: Vector2 = map_size * 0.5
		var pos: Vector2 = Vector2(
			rng.randf_range(-half_map.x, half_map.x),
			rng.randf_range(-half_map.y, half_map.y)
		)
		var vary: float = rng.randf_range(-0.06, 0.06)
		var c: Color = Color(
			clamp(base.r + vary, 0.0, 1.0),
			clamp(base.g + vary * 0.85, 0.0, 1.0),
			clamp(base.b + vary * 0.6, 0.0, 1.0),
			1.0
		)
		_draw_pixel(pos, s, c)

	# 2. 长条草痕/泥土痕：150 条，方向随机
	for i in range(150):
		var half_map: Vector2 = map_size * 0.5
		var pos: Vector2 = Vector2(
			rng.randf_range(-half_map.x, half_map.x),
			rng.randf_range(-half_map.y, half_map.y)
		)
		var angle: float = rng.randf_range(0, PI)
		var length: float = rng.randf_range(20, 80)
		var width: float = rng.randf_range(2, 6)
		var vary: float = rng.randf_range(-0.08, 0.04)
		var c: Color = Color(
			clamp(base.r + vary, 0.0, 1.0),
			clamp(base.g + vary * 0.8, 0.0, 1.0),
			clamp(base.b + vary * 0.5, 0.0, 1.0),
			1.0
		)
		_draw_line(pos, angle, length, width, c)

	# 3. 偶尔的小石块/土块：80 个稍大深色斑点
	for i in range(80):
		var half_map: Vector2 = map_size * 0.5
		var pos: Vector2 = Vector2(
			rng.randf_range(-half_map.x, half_map.x),
			rng.randf_range(-half_map.y, half_map.y)
		)
		var s: float = rng.randf_range(6, 14)
		var dark: float = rng.randf_range(-0.1, -0.04)
		var c: Color = Color(
			clamp(base.r + dark, 0.0, 1.0),
			clamp(base.g + dark * 0.9, 0.0, 1.0),
			clamp(base.b + dark * 0.7, 0.0, 1.0),
			1.0
		)
		_draw_pixel(pos, s, c)



func _draw_line(pos: Vector2, angle: float, length: float, width: float, color: Color) -> void:
	# 用 Polygon2D 画一条旋转的短线（草痕/泥土痕）
	var poly: Polygon2D = Polygon2D.new()
	var half_l: float = length * 0.5
	var half_w: float = width * 0.5
	var dir: Vector2 = Vector2(cos(angle), sin(angle))
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	var p1: Vector2 = pos + dir * half_l + perp * half_w
	var p2: Vector2 = pos + dir * half_l - perp * half_w
	var p3: Vector2 = pos - dir * half_l - perp * half_w
	var p4: Vector2 = pos - dir * half_l + perp * half_w

	poly.polygon = PackedVector2Array([p1, p2, p3, p4])
	poly.color = color
	poly.z_index = -9
	add_child(poly)



func _draw_pixel(pos: Vector2, size: float, color: Color) -> void:
	# 用 Polygon2D 画一个小方块，比 ColorRect 节点少开销
	var poly: Polygon2D = Polygon2D.new()
	var half_s: float = size * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-half_s, -half_s),
		Vector2( half_s, -half_s),
		Vector2( half_s,  half_s),
		Vector2(-half_s,  half_s),
	])
	poly.color = color
	poly.position = pos
	poly.z_index = -9
	add_child(poly)


func _get_floor_node() -> ColorRect:
	return get_node("Floor") as ColorRect



# =============================================================================
# 墙壁
# =============================================================================
func _create_walls() -> void:
	var thickness: float = 64.0
	var half: Vector2 = map_size * 0.5
	var wall_defs: Array = [
		[Vector2(0, -half.y - thickness * 0.5), Vector2(map_size.x + thickness * 2, thickness)],
		[Vector2(0,  half.y + thickness * 0.5), Vector2(map_size.x + thickness * 2, thickness)],
		[Vector2(-half.x - thickness * 0.5, 0), Vector2(thickness, map_size.y + thickness * 2)],
		[Vector2( half.x + thickness * 0.5, 0), Vector2(thickness, map_size.y + thickness * 2)],
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


# =============================================================================
# 障碍物 - 5x5网格分布，覆盖全图包括边缘
# =============================================================================
func _create_obstacles() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var half: Vector2 = map_size * 0.5
	var margin: float = 130.0  # 离边墙的距离
	var playable_w: float = map_size.x - margin * 2
	var playable_h: float = map_size.y - margin * 2

	# 6x6 网格，确保全图覆盖
	var grid_n: int = 6
	var cell_w: float = playable_w / grid_n
	var cell_h: float = playable_h / grid_n

	var placed: int = 0
	var candidates: Array = []

	# 收集所有网格中心
	for row in range(grid_n):
		for col in range(grid_n):
			var cx: float = -half.x + margin + (col + 0.5) * cell_w
			var cy: float = -half.y + margin + (row + 0.5) * cell_h
			candidates.append(Vector2(cx, cy))

	candidates.shuffle()

	# 第一遍：随机抽取网格点，跳过商店安全区
	for pos in candidates:
		if placed >= obstacle_count:
			break
		if pos.distance_to(shop_zone_center) < shop_zone_radius:
			continue
		_create_obstacle_at(rng, pos)
		placed += 1

	# 第二遍：如果还不够，在 playable 区域随机补充，仍然避开商店区
	while placed < obstacle_count:
		var pos: Vector2 = Vector2(
			rng.randf_range(-half.x + margin, half.x - margin),
			rng.randf_range(-half.y + margin, half.y - margin)
		)
		if pos.distance_to(shop_zone_center) < shop_zone_radius:
			continue
		_create_obstacle_at(rng, pos)
		placed += 1


func _create_obstacle_at(rng: RandomNumberGenerator, pos: Vector2) -> void:
	# 掩体尺寸：偏向方形，更自然
	var base_s: float = rng.randf_range(55, 110)
	var ratio: float = rng.randf_range(0.6, 1.4)
	var size: Vector2 = Vector2(base_s, base_s * ratio)
	# 限制最大最小
	size.x = clamp(size.x, 50, 140)
	size.y = clamp(size.y, 50, 140)

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

	# 视觉：带深灰边框的掩体，看起来更清晰
	var vis: Panel = Panel.new()
	vis.size = size
	vis.position = -size * 0.5

	# 主体颜色
	var base_c: float = 0.28 if map_type == 0 else 0.42
	var vary: float = rng.randf_range(-0.06, 0.06)
	vis.self_modulate = Color(base_c + vary, base_c + vary * 0.9, base_c + vary * 0.75, 1.0)

	body.add_child(vis)
	add_child(body)


# =============================================================================
# 导航烘焙
# =============================================================================
func _bake_navigation() -> void:
	var nav_region: NavigationRegion2D = NavigationRegion2D.new()
	nav_region.name = "NavRegion"

	var nav_poly: NavigationPolygon = NavigationPolygon.new()
	var half: Vector2 = map_size * 0.5
	var margin: float = 80.0

	var verts: PackedVector2Array = PackedVector2Array([
		Vector2(-half.x + margin, -half.y + margin),
		Vector2( half.x - margin, -half.y + margin),
		Vector2( half.x - margin,  half.y - margin),
		Vector2(-half.x + margin,  half.y - margin),
	])
	nav_poly.vertices = verts
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))

	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)
