extends Area2D

# =============================================================================
# 联机版宝箱脚本 - 玩家经过时自动拾取
# 拾取本地判定，然后通过RPC同步到房主
# =============================================================================

signal chest_collected(chest_id: int)

# 宝箱属性
var money_amount: int = 50
var respawn_time: float = 30.0
var chest_id: int = -1
var is_active: bool = true

func _ready() -> void:
	# 设置碰撞
	collision_layer = 0
	collision_mask = 2  # 玩家在layer 2
	
	# 创建碰撞形状
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	add_child(col)
	
	# 连接信号
	body_entered.connect(_on_body_entered)
	
	# 创建视觉
	_create_visuals()
	_start_glow()


func _create_visuals() -> void:
	# 宝箱主体
	var sprite: ColorRect = ColorRect.new()
	sprite.name = "Sprite"
	sprite.size = Vector2(40, 40)
	sprite.position = Vector2(-20, -20)
	sprite.color = Color(1.0, 0.85, 0.1, 1.0)
	sprite.z_index = 5
	add_child(sprite)
	
	# 边框
	var border: ColorRect = ColorRect.new()
	border.size = Vector2(44, 44)
	border.position = Vector2(-22, -22)
	border.color = Color(0.6, 0.5, 0.1, 1.0)
	border.z_index = 4
	add_child(border)
	
	# 金钱标签
	var label: Label = Label.new()
	label.name = "Label"
	label.text = "$%d" % money_amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-20, -50)
	label.size = Vector2(40, 30)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.z_index = 6
	add_child(label)


func _start_glow() -> void:
	var sprite: ColorRect = get_node_or_null("Sprite")
	if not sprite:
		return
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(sprite, "modulate:a", 0.6, 0.8)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.8)


func _on_body_entered(body: Node) -> void:
	if not is_active:
		return
	if not body.is_in_group("player"):
		return
	
	# 本地判定拾取
	_collect()


func _collect() -> void:
	# 本地拾取
	if not is_active:
		return
	
	is_active = false
	visible = false
	
	# 通知游戏控制器（ZombieCoopGame._on_chest_collected 负责RPC同步移除）
	chest_collected.emit(chest_id)


@rpc("any_peer", "call_remote", "reliable")
func _notify_collected(cid: int) -> void:
	# 客户端通知房主宝箱被拾取
	if not get_tree().is_server():
		return
	if cid != chest_id:
		return
	
	# 房主同步移除到所有客户端
	_sync_remove.rpc(cid)


@rpc("authority", "call_remote", "reliable")
func _sync_remove(cid: int) -> void:
	# 所有客户端移除宝箱
	if cid != chest_id:
		return
	is_active = false
	visible = false


func respawn() -> void:
	# 刷新宝箱（房主调用）
	is_active = true
	visible = true
	var sprite: ColorRect = get_node_or_null("Sprite")
	if sprite:
		sprite.modulate.a = 1.0
	_start_glow()


func set_money(amount: int) -> void:
	money_amount = amount
	var label: Label = get_node_or_null("Label")
	if label:
		label.text = "$%d" % amount


func set_respawn(time: float) -> void:
	respawn_time = time


func set_id(cid: int) -> void:
	chest_id = cid
