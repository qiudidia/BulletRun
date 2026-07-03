extends Area2D

# =============================================================================
# Bot 模式实体商店
# 玩家进入范围后按 E 打开商店面板
# 商店在地图边缘固定位置
# =============================================================================

signal player_entered_shop()
signal player_exited_shop()

#  shop_id 用于 BotGame 识别不同商店
@export var shop_id: int = 0

var player_inside: bool = false

func _ready() -> void:
	# 确保碰撞检测开启
	monitoring = true
	monitorable = true

	# 连接信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# 创建商店视觉
	_create_visual()


func _create_visual() -> void:
	# 商店主体：一个稍大的方块建筑
	var building: ColorRect = ColorRect.new()
	building.name = "Building"
	building.size = Vector2(120, 80)
	building.position = Vector2(-60, -40)
	building.color = Color(0.4, 0.4, 0.45, 1.0)
	add_child(building)

	# 屋顶：深色三角形用 Polygon2D
	var roof: Polygon2D = Polygon2D.new()
	roof.name = "Roof"
	roof.polygon = PackedVector2Array([
		Vector2(-70, -40),
		Vector2(0, -80),
		Vector2(70, -40)
	])
	roof.color = Color(0.2, 0.2, 0.25, 1.0)
	add_child(roof)

	# 门
	var door: ColorRect = ColorRect.new()
	door.name = "Door"
	door.size = Vector2(30, 45)
	door.position = Vector2(-15, 40)
	door.color = Color(0.15, 0.1, 0.08, 1.0)
	add_child(door)

	# 碰撞形状
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(160, 120)
	collision.shape = shape
	add_child(collision)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		player_entered_shop.emit()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		player_exited_shop.emit()


func is_player_inside() -> bool:
	return player_inside
