extends Node2D

# VeeStudio 图标：三个 V 形线条组成，青色，代码绘制
# 挂在 intro 场景的 VeeIcon 节点上，替代 SVG

func _ready() -> void:
	# 隐藏原来的 TextureRect（如果有）
	for child in get_children():
		child.queue_free()
	
	# 创建三个 V 形线条
	_add_v_shape(Vector2(-80, 0), 160.0, 60.0, 0.0)
	_add_v_shape(Vector2(0, 0), 160.0, 60.0, 0.0)
	_add_v_shape(Vector2(80, 0), 160.0, 60.0, 0.0)
	
	# 整体颜色：青色（与 VeeStudio 文字同色）
	modulate = Color(0, 0.85, 1, 1)


func _add_v_shape(center: Vector2, width: float, height: float, _angle_deg: float) -> void:
	# 用 Line2D 画 V 形（两条线）
	var left_line: Line2D = Line2D.new()
	left_line.width = 6.0
	left_line.default_color = Color(0, 0.85, 1, 1)
	var top: Vector2 = center + Vector2(0, -height * 0.5)
	var left: Vector2 = center + Vector2(-width * 0.5, height * 0.5)
	left_line.points = PackedVector2Array([top, left])
	left_line.antialiased = true
	add_child(left_line)
	
	var right_line: Line2D = Line2D.new()
	right_line.width = 6.0
	right_line.default_color = Color(0, 0.85, 1, 1)
	var right: Vector2 = center + Vector2(width * 0.5, height * 0.5)
	right_line.points = PackedVector2Array([top, right])
	right_line.antialiased = true
	add_child(right_line)
