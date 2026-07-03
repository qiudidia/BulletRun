extends Control

# =============================================================================
# 小地图脚本
# 右上角显示：自己(绿点)、敌人(红点)、商店(黄标)、掩体(灰块)
# 按 M 键切换显示
# =============================================================================

var map_size: Vector2 = Vector2(2400, 2400)
var minimap_size: float = 200.0
var player_node: CharacterBody2D = null
var enemy_container: Node2D = null
var shop_node: Area2D = null
var map_node: Node2D = null

var dot_radius: float = 3.0
var enemy_dot_radius: float = 2.5

func _ready() -> void:
	# 全屏锚点，自己定位在右上角
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = true

	# 找到场景里的关键节点
	call_deferred("find_nodes")

func find_nodes() -> void:
	var scene: Node = get_tree().current_scene
	player_node = scene.get_node_or_null("Player")
	map_node = scene.get_node_or_null("Map")
	# 动态读取地图尺寸（GameMap.map_size 是 @export 变量）
	if map_node:
		var ms = map_node.get("map_size")
		if ms and ms is Vector2:
			map_size = ms
	# 找敌人容器（Bot模式：$Bots；僵尸模式：$Enemies）
	enemy_container = null
	if scene.has_node("Bots"):
		enemy_container = scene.get_node("Bots")
	elif scene.has_node("Enemies"):
		enemy_container = scene.get_node("Enemies")
	# 找商店
	var shop: Node = scene.get_node_or_null("Shop")
	if not shop:
		shop = scene.get_node_or_null("shop_node")
	shop_node = shop

func _draw() -> void:
	if not visible:
		return
	if not player_node:
		return

	# 小地图位置：右上角，留10px边距
	var mm_pos: Vector2 = Vector2(get_viewport_rect().size.x - minimap_size - 10, 10)
	var mm_rect: Rect2 = Rect2(mm_pos, Vector2(minimap_size, minimap_size))

	# 背景
	draw_rect(mm_rect, Color(0.0, 0.0, 0.0, 0.65), true)
	# 边框
	draw_rect(mm_rect, Color(0.5, 0.5, 0.5, 0.8), false, 1.5)

	# 掩体现在地图上（检测所有StaticBody2D和命名含掩体关键字的节点）
	if map_node:
		for child in map_node.get_children():
			if child is StaticBody2D or "Cover" in child.name or "Obstacle" in child.name or "Wall" in child.name:
				var ob_pos: Vector2 = child.global_position
				var dot_pos: Vector2 = _world_to_minimap(ob_pos, mm_pos)
				draw_rect(Rect2(dot_pos - Vector2(2, 2), Vector2(4, 4)), Color(0.5, 0.5, 0.5, 0.7))

	# 商店位置（黄色菱形）
	if shop_node:
		var shop_mm: Vector2 = _world_to_minimap(shop_node.global_position, mm_pos)
		var shop_size: float = 5.0
		var pts: PackedVector2Array = [
			Vector2(shop_mm.x, shop_mm.y - shop_size),
			Vector2(shop_mm.x + shop_size, shop_mm.y),
			Vector2(shop_mm.x, shop_mm.y + shop_size),
			Vector2(shop_mm.x - shop_size, shop_mm.y),
		]
		var colors: PackedColorArray = PackedColorArray()
		colors.append(Color(1.0, 0.9, 0.0, 1.0))
		draw_polygon(pts, colors)

	# 敌人位置（红色圆点）
	if enemy_container:
		for enemy in enemy_container.get_children():
			if is_instance_valid(enemy):
				var e_pos: Vector2 = _world_to_minimap(enemy.global_position, mm_pos)
				draw_circle(e_pos, enemy_dot_radius, Color(1.0, 0.2, 0.2, 0.9))

	# 自己位置（绿色箭头/圆点）
	var p_pos: Vector2 = _world_to_minimap(player_node.global_position, mm_pos)
	draw_circle(p_pos, dot_radius + 1.0, Color(0.0, 1.0, 0.0, 1.0))
	# 用一个小三角形表示朝向
	var angle: float = player_node.rotation if "rotation" in player_node else 0.0
	var arrow_len: float = 8.0
	var tip: Vector2 = p_pos + Vector2(cos(angle), sin(angle)) * arrow_len
	draw_line(p_pos, tip, Color(0.0, 1.0, 0.0, 1.0), 2.0)


func _world_to_minimap(world_pos: Vector2, mm_top_left: Vector2) -> Vector2:
	var half: Vector2 = map_size * 0.5
	var nx: float = (world_pos.x + half.x) / map_size.x
	var ny: float = (world_pos.y + half.y) / map_size.y
	nx = clamp(nx, 0.0, 1.0)
	ny = clamp(ny, 0.0, 1.0)
	return Vector2(mm_top_left.x + nx * minimap_size, mm_top_left.y + ny * minimap_size)


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_minimap"):
		visible = not visible
