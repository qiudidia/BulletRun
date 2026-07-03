extends Node2D

# =============================================================================
# 准星：跟随鼠标，根据设置绘制十字/圆点/圆环三种样式
# =============================================================================

# 准星样式: 0=十字, 1=圆点, 2=圆环
var crosshair_style: int = 0
var crosshair_color: Color = Color(0, 1, 0, 1)

# 绘制参数
const LINE_LEN: float = 14.0
const LINE_GAP: float = 6.0
const LINE_WIDTH: float = 2.0
const DOT_RADIUS: float = 4.0
const RING_RADIUS: float = 12.0


func _ready() -> void:
	# 始终处理，确保准星正常跟随鼠标
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 隐藏旧的子节点（HLine/VLine/Dot），改用 _draw() 统一绘制
	_hide_child_nodes()
	# 从设置加载初始值
	crosshair_style = GameSettings.get_value("game", "crosshair_style", 0)
	crosshair_color = GameSettings.get_value("game", "crosshair_color", Color(0, 1, 0, 1))
	queue_redraw()


func _hide_child_nodes() -> void:
	for child in get_children():
		if child is CanvasItem:
			child.visible = false


func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()


func _draw() -> void:
	match crosshair_style:
		0:
			_draw_cross()
		1:
			_draw_dot()
		2:
			_draw_ring()


func _draw_cross() -> void:
	# 水平线（中间留 gap）
	draw_line(Vector2(-LINE_LEN, 0), Vector2(-LINE_GAP, 0), crosshair_color, LINE_WIDTH)
	draw_line(Vector2(LINE_GAP, 0), Vector2(LINE_LEN, 0), crosshair_color, LINE_WIDTH)
	# 垂直线
	draw_line(Vector2(0, -LINE_LEN), Vector2(0, -LINE_GAP), crosshair_color, LINE_WIDTH)
	draw_line(Vector2(0, LINE_GAP), Vector2(0, LINE_LEN), crosshair_color, LINE_WIDTH)


func _draw_dot() -> void:
	draw_circle(Vector2.ZERO, DOT_RADIUS, crosshair_color)


func _draw_ring() -> void:
	draw_arc(Vector2.ZERO, RING_RADIUS, 0, TAU, 48, crosshair_color, LINE_WIDTH, true)


## 外部调用：更新准星样式和颜色，触发重绘
func update_crosshair(style: int, color: Color) -> void:
	crosshair_style = style
	crosshair_color = color
	queue_redraw()
