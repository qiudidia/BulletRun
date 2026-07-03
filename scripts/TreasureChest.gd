extends Area2D

# =============================================================================
# 宝箱脚本 - 玩家经过时自动拾取，获得金钱
# 只用于单机僵尸模式
# =============================================================================

signal chest_collected(money_amount: int)

# 宝箱属性
var money_amount: int = 50
var respawn_time: float = 30.0  # 拾取后多少秒重新刷新
var is_active: bool = true
var glow_tween: Tween = null

func _ready() -> void:
	# 设置碰撞（检测玩家）
	collision_layer = 0
	collision_mask = 2  # 玩家在layer 2
	
	# 创建碰撞形状
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	add_child(col)
	
	# 连接碰撞信号
	body_entered.connect(_on_body_entered)
	
	# 创建视觉表现
	_create_visuals()
	
	# 开始光效动画
	_start_glow_animation()


func _create_visuals() -> void:
	# 宝箱主体（金色）
	var sprite: ColorRect = ColorRect.new()
	sprite.name = "ChestSprite"
	sprite.size = Vector2(40, 40)
	sprite.position = Vector2(-20, -20)
	sprite.color = Color(1.0, 0.85, 0.1, 1.0)  # 金色
	sprite.z_index = 5
	add_child(sprite)
	
	# 宝箱边框（深色）
	var border: ColorRect = ColorRect.new()
	border.size = Vector2(44, 44)
	border.position = Vector2(-22, -22)
	border.color = Color(0.6, 0.5, 0.1, 1.0)
	border.z_index = 4
	add_child(border)
	
	# 金钱标签
	var label: Label = Label.new()
	label.name = "MoneyLabel"
	label.text = "$%d" % money_amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-20, -50)
	label.size = Vector2(40, 30)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	label.z_index = 6
	add_child(label)


func _start_glow_animation() -> void:
	# 金色光效脉动
	var sprite: ColorRect = get_node_or_null("ChestSprite")
	if not sprite:
		return
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(sprite, "modulate:a", 0.6, 0.8)
	glow_tween.tween_property(sprite, "modulate:a", 1.0, 0.8)


func _on_body_entered(body: Node) -> void:
	# 玩家经过时拾取
	if not is_active:
		return
	
	# 检查是否是玩家
	if body.is_in_group("player") or body.has_method("take_damage"):
		_collect_chest(body)


func _collect_chest(_player: Node) -> void:
	# 拾取宝箱
	is_active = false
	
	# 发送信号
	chest_collected.emit(money_amount)
	
	# 视觉反馈：放大+淡出
	var sprite: ColorRect = get_node_or_null("ChestSprite")
	if sprite:
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.3)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): _on_collect_animation_done())


func _on_collect_animation_done() -> void:
	# 拾取动画完成后移除宝箱
	queue_free()


func _reset_chest() -> void:
	# 重置宝箱状态（重新刷新）
	is_active = true
	visible = true
	var sprite: ColorRect = get_node_or_null("ChestSprite")
	if sprite:
		sprite.modulate.a = 1.0
		sprite.scale = Vector2(1, 1)
	
	# 重新启动光效
	_start_glow_animation()


func set_money_amount(amount: int) -> void:
	# 设置宝箱金钱数量
	money_amount = amount
	var label: Label = get_node_or_null("MoneyLabel")
	if label:
		label.text = "$%d" % money_amount


func set_respawn_time(time: float) -> void:
	# 设置刷新时间
	respawn_time = time
