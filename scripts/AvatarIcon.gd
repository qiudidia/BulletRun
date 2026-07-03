extends Control

# =============================================================================
# 头像绘制控件
# 根据 avatar_id 代码绘制不同风格的头像
# =====================================================================

signal avatar_clicked

@export var avatar_id: int = 0
@export var avatar_size: Vector2 = Vector2(48, 48)

var _hovered: bool = false

func _ready() -> void:
	custom_minimum_size = avatar_size
	size = avatar_size
	_draw_avatar()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		avatar_clicked.emit()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovered = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovered = false
		queue_redraw()

func set_avatar(id: int) -> void:
	avatar_id = id
	_draw_avatar()

func _draw_avatar() -> void:
	queue_redraw()

func _draw() -> void:
	var r: float = minf(avatar_size.x, avatar_size.y) * 0.45
	var cx: float = avatar_size.x * 0.5
	var cy: float = avatar_size.y * 0.5

	# 外圈（深色边框）
	draw_circle(Vector2(cx, cy), r + 2, Color(0.15, 0.15, 0.18, 1))

	# 根据头像 ID 绘制不同图案
	match avatar_id:
		0:  # 默认：蓝色圆形 + 十字星
			draw_circle(Vector2(cx, cy), r, Color(0.2, 0.4, 0.9, 1))
			# 十字星装饰
			var star_r: float = r * 0.4
			for i in range(4):
				var angle: float = i * PI / 2.0
				draw_line(Vector2(cx, cy), Vector2(cx + cos(angle) * star_r, cy + sin(angle) * star_r), Color(1, 1, 1, 0.7), 2.0)
			draw_circle(Vector2(cx, cy), r * 0.15, Color(1, 1, 1, 0.9))
		1:  # 红色 + 三角形（战士）
			draw_circle(Vector2(cx, cy), r, Color(0.85, 0.15, 0.15, 1))
			var tri_r: float = r * 0.55
			var pts: PackedVector2Array = []
			for i in range(3):
				var a: float = -PI / 2.0 + i * TAU / 3.0
				pts.append(Vector2(cx + cos(a) * tri_r, cy + sin(a) * tri_r))
			draw_colored_polygon(pts, Color(1, 0.85, 0.2, 0.9))
		2:  # 绿色 + 六边形（自然）
			draw_circle(Vector2(cx, cy), r, Color(0.15, 0.7, 0.25, 1))
			var hex_r: float = r * 0.5
			var hex_pts: PackedVector2Array = []
			for i in range(6):
				var a: float = i * TAU / 6.0
				hex_pts.append(Vector2(cx + cos(a) * hex_r, cy + sin(a) * hex_r))
			draw_colored_polygon(hex_pts, Color(0.9, 0.95, 0.3, 0.9))
		3:  # 金色 + 五角星（精英）
			draw_circle(Vector2(cx, cy), r, Color(0.9, 0.75, 0.1, 1))
			var star_pts: PackedVector2Array = []
			for i in range(10):
				var a: float = -PI / 2.0 + i * TAU / 10.0
				var sr: float = r * 0.55 if i % 2 == 0 else r * 0.25
				star_pts.append(Vector2(cx + cos(a) * sr, cy + sin(a) * sr))
			draw_colored_polygon(star_pts, Color(0.2, 0.1, 0.0, 0.85))
		4:  # 紫色 + 菱形（神秘）
			draw_circle(Vector2(cx, cy), r, Color(0.5, 0.2, 0.8, 1))
			var dia_r: float = r * 0.55
			var dia_pts: PackedVector2Array = [
				Vector2(cx, cy - dia_r),
				Vector2(cx + dia_r * 0.6, cy),
				Vector2(cx, cy + dia_r),
				Vector2(cx - dia_r * 0.6, cy)
			]
			draw_colored_polygon(dia_pts, Color(0.9, 0.6, 1.0, 0.85))
		5:  # 白色 + 圆环（狙击手）
			draw_circle(Vector2(cx, cy), r, Color(0.85, 0.85, 0.9, 1))
			draw_circle(Vector2(cx, cy), r * 0.7, Color(0.15, 0.15, 0.18, 1))
			draw_circle(Vector2(cx, cy), r * 0.35, Color(0.9, 0.9, 0.95, 0.9))
			draw_line(Vector2(cx - r * 0.7, cy), Vector2(cx + r * 0.7, cy), Color(0.9, 0.3, 0.3, 0.7), 1.5)
			draw_line(Vector2(cx, cy - r * 0.7), Vector2(cx, cy + r * 0.7), Color(0.9, 0.3, 0.3, 0.7), 1.5)
		6:  # 橙色 + 火焰（爆破手）
			draw_circle(Vector2(cx, cy), r, Color(0.9, 0.5, 0.1, 1))
			# 简单火焰形状
			var flame_pts: PackedVector2Array = [
				Vector2(cx, cy - r * 0.6),
				Vector2(cx + r * 0.3, cy - r * 0.1),
				Vector2(cx + r * 0.15, cy + r * 0.4),
				Vector2(cx, cy + r * 0.2),
				Vector2(cx - r * 0.15, cy + r * 0.4),
				Vector2(cx - r * 0.3, cy - r * 0.1)
			]
			draw_colored_polygon(flame_pts, Color(1, 0.95, 0.3, 0.85))
		7:  # 银色 + 齿轮（工程师）
			draw_circle(Vector2(cx, cy), r, Color(0.65, 0.65, 0.7, 1))
			var gear_r_outer: float = r * 0.55
			var gear_r_inner: float = r * 0.35
			var teeth: int = 8
			var gear_pts: PackedVector2Array = []
			for i in range(teeth * 2):
				var a: float = i * TAU / (teeth * 2.0)
				var gr: float = gear_r_outer if i % 2 == 0 else gear_r_inner
				gear_pts.append(Vector2(cx + cos(a) * gr, cy + sin(a) * gr))
			draw_colored_polygon(gear_pts, Color(0.2, 0.2, 0.25, 0.85))
			draw_circle(Vector2(cx, cy), r * 0.18, Color(0.65, 0.65, 0.7, 0.9))
		8:  # 青色 + 螺旋（风暴使者）
			draw_circle(Vector2(cx, cy), r, Color(0.0, 0.75, 0.85, 1))
			for i in range(3):
				var sa: float = i * TAU / 3.0
				var arm_pts: PackedVector2Array = []
				for j in range(8):
					var t: float = j / 7.0
					var aa: float = sa + t * PI * 0.8
					var rr: float = r * 0.15 + r * 0.45 * t
					arm_pts.append(Vector2(cx + cos(aa) * rr, cy + sin(aa) * rr))
				draw_polyline(arm_pts, Color(1, 1, 1, 0.7), 2.0)
			draw_circle(Vector2(cx, cy), r * 0.12, Color(1, 1, 1, 0.9))
		9:  # 暗红 + 十字剑（剑圣）
			draw_circle(Vector2(cx, cy), r, Color(0.6, 0.08, 0.08, 1))
			# 剑柄横线
			draw_line(Vector2(cx - r * 0.35, cy), Vector2(cx + r * 0.35, cy), Color(0.9, 0.85, 0.6, 0.9), 3.0)
			# 剑刃竖线
			draw_line(Vector2(cx, cy + r * 0.35), Vector2(cx, cy - r * 0.55), Color(0.9, 0.85, 0.6, 0.9), 2.5)
			# 剑尖
			draw_circle(Vector2(cx, cy - r * 0.55), 2.0, Color(1, 0.95, 0.7, 1))
		10:  # 深蓝 + V形鹰翼（侦察兵）
			draw_circle(Vector2(cx, cy), r, Color(0.1, 0.2, 0.65, 1))
			var wing_pts: PackedVector2Array = [
				Vector2(cx, cy + r * 0.2),
				Vector2(cx - r * 0.55, cy - r * 0.3),
				Vector2(cx - r * 0.2, cy - r * 0.15),
				Vector2(cx, cy - r * 0.45),
				Vector2(cx + r * 0.2, cy - r * 0.15),
				Vector2(cx + r * 0.55, cy - r * 0.3),
			]
			draw_colored_polygon(wing_pts, Color(0.8, 0.85, 1.0, 0.85))
			draw_circle(Vector2(cx, cy + r * 0.2), r * 0.08, Color(0.9, 0.5, 0.2, 1))
		11:  # 暗绿 + 蛇形（毒蛇）
			draw_circle(Vector2(cx, cy), r, Color(0.1, 0.45, 0.15, 1))
			var snake_pts: PackedVector2Array = []
			for i in range(12):
				var t: float = i / 11.0
				var sx: float = cx + sin(t * PI * 2.5) * r * 0.35
				var sy: float = cy - r * 0.5 + t * r * 1.0
				snake_pts.append(Vector2(sx, sy))
			draw_polyline(snake_pts, Color(0.6, 0.9, 0.3, 0.8), 3.0)
			# 蛇头
			draw_circle(snake_pts[0], 4.0, Color(0.9, 0.2, 0.1, 1))
			# 蛇眼
			draw_circle(Vector2(snake_pts[0].x - 1.5, snake_pts[0].y - 1), 1.5, Color(1, 1, 0.2, 1))
			draw_circle(Vector2(snake_pts[0].x + 1.5, snake_pts[0].y - 1), 1.5, Color(1, 1, 0.2, 1))
		12:  # 粉色 + 心形（医护兵）
			draw_circle(Vector2(cx, cy), r, Color(0.85, 0.35, 0.55, 1))
			var hr: float = r * 0.35
			var heart_pts: PackedVector2Array = [
				Vector2(cx, cy + r * 0.45),
				Vector2(cx - hr * 1.2, cy - hr * 0.1),
				Vector2(cx - hr * 0.5, cy - r * 0.4),
				Vector2(cx, cy - r * 0.2),
				Vector2(cx + hr * 0.5, cy - r * 0.4),
				Vector2(cx + hr * 1.2, cy - hr * 0.1),
			]
			draw_colored_polygon(heart_pts, Color(1, 0.8, 0.85, 0.9))
			# 心形顶部两个圆弧
			draw_circle(Vector2(cx - hr * 0.5, cy - r * 0.35), hr * 0.5, Color(1, 0.8, 0.85, 0.9))
			draw_circle(Vector2(cx + hr * 0.5, cy - r * 0.35), hr * 0.5, Color(1, 0.8, 0.85, 0.9))
		13:  # 深紫 + 月牙（暗影刺客）
			draw_circle(Vector2(cx, cy), r, Color(0.3, 0.1, 0.5, 1))
			# 月牙：大圆减去偏移圆
			draw_circle(Vector2(cx - r * 0.15, cy), r * 0.55, Color(0.75, 0.4, 0.95, 1))
			draw_circle(Vector2(cx + r * 0.25, cy), r * 0.45, Color(0.3, 0.1, 0.5, 1))
			# 星点
			draw_circle(Vector2(cx + r * 0.35, cy - r * 0.35), 2.0, Color(1, 1, 0.9, 0.9))
			draw_circle(Vector2(cx + r * 0.45, cy - r * 0.1), 1.5, Color(1, 1, 0.9, 0.7))
		14:  # 金铜色 + 交叉箭（弓手）
			draw_circle(Vector2(cx, cy), r, Color(0.7, 0.55, 0.2, 1))
			# 箭1
			draw_line(Vector2(cx - r * 0.45, cy + r * 0.45), Vector2(cx + r * 0.45, cy - r * 0.45), Color(1, 0.95, 0.7, 0.85), 2.5)
			# 箭2
			draw_line(Vector2(cx + r * 0.45, cy + r * 0.45), Vector2(cx - r * 0.45, cy - r * 0.45), Color(1, 0.95, 0.7, 0.85), 2.5)
			# 箭尖（上下）
			var arr_sz: float = r * 0.15
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, cy - r * 0.55),
				Vector2(cx - arr_sz, cy - r * 0.45),
				Vector2(cx + arr_sz, cy - r * 0.45),
			]), Color(1, 0.95, 0.7, 1))
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, cy + r * 0.55),
				Vector2(cx - arr_sz, cy + r * 0.45),
				Vector2(cx + arr_sz, cy + r * 0.45),
			]), Color(1, 0.95, 0.7, 1))
		15:  # 黑色 + 棋盘格眼（战术大师）
			draw_circle(Vector2(cx, cy), r, Color(0.12, 0.12, 0.15, 1))
			var grid_sz: float = r * 0.65
			var cell: float = grid_sz / 4.0
			var gx: float = cx - grid_sz * 0.5
			var gy: float = cy - grid_sz * 0.5
			for row in range(4):
				for col in range(4):
					if (row + col) % 2 == 0:
						draw_rect(Rect2(gx + col * cell, gy + row * cell, cell, cell), Color(0.85, 0.85, 0.9, 0.8))
			# 红色中心点
			draw_circle(Vector2(cx, cy), r * 0.08, Color(0.9, 0.15, 0.15, 1))
		_:  # fallback
			draw_circle(Vector2(cx, cy), r, Color(0.5, 0.5, 0.5, 1))

	# hover 高亮环
	if _hovered:
		draw_arc(Vector2(cx, cy), r + 4, 0, TAU, 64, Color(0.6, 0.8, 1.0, 0.7), 2.5)
