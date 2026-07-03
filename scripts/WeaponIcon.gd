extends Control

# =============================================================================
# 武器/道具图标绘制控件
# 使用自定义 _draw() 绘制简洁的武器轮廓，无需外部图片资源
# =============================================================================

enum IconType { PISTOL, RIFLE, GRENADE, SNIPER, KNIFE, MACHINEGUN }

var icon_type: int = IconType.PISTOL


func set_icon_type(type_val: int) -> void:
	icon_type = type_val
	queue_redraw()


func _draw() -> void:
	match icon_type:
		IconType.PISTOL:
			_draw_pistol()
		IconType.RIFLE:
			_draw_rifle()
		IconType.GRENADE:
			_draw_grenade()
		IconType.SNIPER:
			_draw_sniper()
		IconType.KNIFE:
			_draw_knife()
		IconType.MACHINEGUN:
			_draw_machinegun()


func _draw_pistol() -> void:
	var light: Color = Color(0.72, 0.76, 0.86, 1)
	var dark: Color = Color(0.38, 0.42, 0.52, 1)
	var grip_col: Color = Color(0.32, 0.26, 0.18, 1)
	var highlight: Color = Color(1, 1, 1, 0.25)

	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5

	# 套筒/枪身
	draw_rect(Rect2(cx - 11, cy - 6, 22, 9), light, true)
	# 枪管
	draw_rect(Rect2(cx + 9, cy - 4, 9, 5), dark, true)
	# 准星
	draw_rect(Rect2(cx + 14, cy - 7, 2, 3), dark, true)
	# 握把
	draw_rect(Rect2(cx - 9, cy + 3, 7, 11), grip_col, true)
	# 扳机护圈
	draw_rect(Rect2(cx - 1, cy + 3, 5, 5), dark, true)
	# 高光条
	draw_rect(Rect2(cx - 10, cy - 5, 20, 1.5), highlight, true)


func _draw_rifle() -> void:
	var light: Color = Color(0.65, 0.70, 0.80, 1)
	var dark: Color = Color(0.35, 0.38, 0.48, 1)
	var mid: Color = Color(0.50, 0.55, 0.65, 1)
	var stock_col: Color = Color(0.30, 0.24, 0.16, 1)
	var mag_col: Color = Color(0.22, 0.22, 0.24, 1)
	var highlight: Color = Color(1, 1, 1, 0.22)

	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5

	# 枪托
	draw_rect(Rect2(cx - 22, cy - 3, 8, 8), stock_col, true)
	# 机匣/枪身
	draw_rect(Rect2(cx - 14, cy - 4, 22, 9), light, true)
	# 护木
	draw_rect(Rect2(cx + 2, cy - 3, 10, 7), mid, true)
	# 枪管
	draw_rect(Rect2(cx + 8, cy - 2, 16, 4), dark, true)
	# 准星
	draw_rect(Rect2(cx + 20, cy - 5, 2, 3), dark, true)
	# 弹匣
	draw_rect(Rect2(cx - 4, cy + 5, 6, 10), mag_col, true)
	# 握把
	draw_rect(Rect2(cx - 12, cy + 5, 5, 8), stock_col, true)
	# 高光条
	draw_rect(Rect2(cx - 13, cy - 3, 20, 1.5), highlight, true)


func _draw_grenade() -> void:
	var body_col: Color = Color(0.35, 0.50, 0.20, 1)
	var dark: Color = Color(0.20, 0.25, 0.12, 1)
	var metal: Color = Color(0.55, 0.55, 0.58, 1)
	var highlight: Color = Color(1, 1, 1, 0.30)

	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5

	# 弹体
	draw_circle(Vector2(cx, cy + 2), 8, body_col)
	# 顶部接口
	draw_rect(Rect2(cx - 3, cy - 8, 6, 4), metal, true)
	# 安全栓
	draw_rect(Rect2(cx - 1, cy - 11, 5, 2), dark, true)
	# 拉环
	draw_arc(Vector2(cx + 4, cy - 10), 3, 0, TAU, 16, dark, 1.5, true)
	# 高光
	draw_circle(Vector2(cx - 3, cy - 1), 2, highlight)


func _draw_sniper() -> void:
	var light: Color = Color(0.72, 0.76, 0.86, 1)
	var dark: Color = Color(0.28, 0.30, 0.36, 1)
	var scope_col: Color = Color(0.40, 0.45, 0.55, 1)
	var stock_col: Color = Color(0.30, 0.24, 0.16, 1)
	var highlight: Color = Color(1, 1, 1, 0.25)

	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5

	# 枪托
	draw_rect(Rect2(cx - 20, cy - 3, 8, 7), stock_col, true)
	# 机匣（较长）
	draw_rect(Rect2(cx - 12, cy - 4, 24, 8), light, true)
	# 长枪管
	draw_rect(Rect2(cx + 12, cy - 2, 14, 4), dark, true)
	# 瞄准镜（上方圆柱）
	draw_rect(Rect2(cx - 6, cy - 9, 16, 4), scope_col, true)
	# 镜片（前后两个小亮条）
	draw_rect(Rect2(cx - 6, cy - 9, 2, 4), highlight, true)
	draw_rect(Rect2(cx + 8, cy - 9, 2, 4), highlight, true)
	# 握把
	draw_rect(Rect2(cx - 10, cy + 4, 5, 8), stock_col, true)
	# 高光条
	draw_rect(Rect2(cx - 11, cy - 3, 22, 1.5), highlight, true)


func _draw_knife() -> void:
	var blade_col: Color = Color(0.75, 0.78, 0.82, 1)
	var edge_col: Color = Color(0.92, 0.94, 0.96, 1)
	var handle_col: Color = Color(0.32, 0.26, 0.18, 1)
	var guard_col: Color = Color(0.45, 0.42, 0.38, 1)

	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5

	# 刀柄
	draw_rect(Rect2(cx - 4, cy + 8, 8, 14), handle_col, true)
	# 护手（略弯）
	draw_rect(Rect2(cx - 8, cy + 5, 16, 4), guard_col, true)
	# 刀身（刀刃）
	draw_rect(Rect2(cx - 3, cy - 12, 6, 17), blade_col, true)
	# 刀尖（三角形效果）
	var tip_pts: PackedVector2Array = PackedVector2Array([
		Vector2(cx - 3, cy - 12),
		Vector2(cx + 3, cy - 12),
		Vector2(cx, cy - 20)
	])
	draw_polygon(tip_pts, PackedColorArray([blade_col, blade_col, blade_col]))
	# 刀刃高光
	draw_rect(Rect2(cx - 2, cy - 11, 1, 14), edge_col, true)
	# 刀背暗面
	draw_rect(Rect2(cx + 2, cy - 11, 1, 14), Color(0.5, 0.52, 0.55, 1), true)


func _draw_machinegun() -> void:
	var light: Color = Color(0.60, 0.64, 0.74, 1)
	var dark: Color = Color(0.25, 0.28, 0.35, 1)
	var mag_col: Color = Color(0.18, 0.18, 0.20, 1)
	var stock_col: Color = Color(0.30, 0.24, 0.16, 1)
	var chain_col: Color = Color(0.50, 0.45, 0.30, 1)
	var highlight: Color = Color(1, 1, 1, 0.20)

	var cx: float = size.x * 0.5
	var cy: float = size.y * 0.5

	# 枪托（宽厚）
	draw_rect(Rect2(cx - 24, cy - 3, 10, 9), stock_col, true)
	# 机匣（长枪身）
	draw_rect(Rect2(cx - 14, cy - 5, 28, 10), light, true)
	# 枪管护罩
	draw_rect(Rect2(cx + 6, cy - 4, 12, 8), dark, true)
	# 枪管（粗长）
	draw_rect(Rect2(cx + 14, cy - 2, 14, 4), dark, true)
	# 大弹匣（弹链盒）
	draw_rect(Rect2(cx - 6, cy + 5, 8, 12), mag_col, true)
	# 弹链
	draw_rect(Rect2(cx + 2, cy + 4, 4, 3), chain_col, true)
	draw_rect(Rect2(cx + 6, cy + 2, 3, 3), chain_col, true)
	# 握把
	draw_rect(Rect2(cx - 14, cy + 5, 5, 9), stock_col, true)
	# 高光条
	draw_rect(Rect2(cx - 13, cy - 4, 26, 1.5), highlight, true)
