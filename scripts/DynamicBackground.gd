extends Control
## 动态背景效果
## 渐变背景 + 扫描线 + 漂浮粒子 + 光晕效果

@export var base_color: Color = Color(0.03, 0.04, 0.08, 1.0)
@export var accent_color: Color = Color(0.2, 0.5, 1.0, 0.3)
@export var particle_count: int = 50

var particles: Array = []
var time: float = 0.0
var scanline_y: float = 0.0


func _ready() -> void:
	for i in range(particle_count):
		particles.append({
			"x": randf(),
			"y": randf(),
			"size": randf_range(1.5, 4.0),
			"speed": randf_range(0.02, 0.08),
			"opacity": randf_range(0.2, 0.6),
			"drift": randf_range(-0.02, 0.02)
		})


func _process(delta: float) -> void:
	time += delta
	scanline_y = fmod(time * 0.15, 1.0)
	queue_redraw()


func _draw() -> void:
	var rect := get_rect()
	var w: float = rect.size.x
	var h: float = rect.size.y
	
	_draw_gradient_bg(w, h)
	_draw_radial_glow(w, h)
	_draw_scanlines(w, h)
	_draw_scanline_bar(w, h)
	_draw_particles(w, h)
	_draw_corner_brackets(w, h)
	_draw_grid(w, h)


func _draw_gradient_bg(w: float, h: float) -> void:
	draw_rect(Rect2(0, 0, w, h), base_color)
	
	var points := PackedVector2Array([
		Vector2(w * 0.1, h * 0.0),
		Vector2(w * 0.9, h * 0.0),
		Vector2(w * 0.9, h * 0.5),
		Vector2(w * 0.1, h * 0.5),
	])
	var colors := PackedColorArray([
		accent_color * 0.3,
		accent_color * 0.2,
		accent_color * 0.05,
		accent_color * 0.1,
	])
	draw_polygon(points, colors)


func _draw_radial_glow(w: float, h: float) -> void:
	var center: Vector2 = Vector2(w * 0.5, h * 0.35)
	var max_r: float = max(w, h) * 0.6
	
	var steps: int = 24
	for i in range(steps):
		var t: float = float(i) / float(steps)
		var r: float = max_r * t
		var alpha: float = (1.0 - t) * 0.15
		var col: Color = accent_color
		col.a = alpha
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var segments: int = 32
		for j in range(segments + 1):
			var angle: float = float(j) / float(segments) * TAU
			var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (r * 0.8)
			var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (r * 1.0)
			points.append(inner)
			points.append(outer)
			colors.append(Color(accent_color, 0.0))
			colors.append(col)
		draw_polygon(points, colors)


func _draw_scanlines(w: float, h: float) -> void:
	var line_gap: float = 4.0
	for y in range(0, int(h), int(line_gap * 2)):
		var col: Color = Color(0.0, 0.6, 1.0, 0.03)
		draw_line(Vector2(0, y), Vector2(w, y), col, 1.0)


func _draw_scanline_bar(w: float, h: float) -> void:
	var y: float = scanline_y * h
	var bar_height: float = 80.0
	
	for i in range(20):
		var t: float = float(i) / 20.0
		var alpha: float = (1.0 - t) * 0.15
		var col: Color = Color(0.3, 0.7, 1.0, alpha)
		draw_line(Vector2(0, y - t * bar_height), Vector2(w, y - t * bar_height), col, 1.0)
		draw_line(Vector2(0, y + t * bar_height), Vector2(w, y + t * bar_height), col, 1.0)
	
	draw_line(Vector2(0, y), Vector2(w, y), Color(0.4, 0.8, 1.0, 0.4), 2.0)


func _draw_particles(w: float, h: float) -> void:
	for p in particles:
		p["y"] = float(p["y"]) + float(p["speed"]) * 0.01
		p["x"] = float(p["x"]) + sin(time * 0.5 + float(p["y"]) * 10.0) * float(p["drift"]) * 0.01
		
		if float(p["y"]) > 1.1:
			p["y"] = -0.1
			p["x"] = randf()
		
		var px: float = float(p["x"]) * w
		var py: float = float(p["y"]) * h
		var size: float = float(p["size"])
		var op: float = float(p["opacity"])
		
		var glow_col: Color = Color(0.4, 0.7, 1.0, op * 0.3)
		draw_circle(Vector2(px, py), size * 2.0, glow_col)
		
		var core_col: Color = Color(0.7, 0.9, 1.0, op)
		draw_circle(Vector2(px, py), size * 0.6, core_col)


func _draw_corner_brackets(w: float, h: float) -> void:
	var margin: float = 30.0
	var bracket_len: float = 60.0
	var col: Color = Color(0.3, 0.6, 1.0, 0.6)
	var thickness: float = 2.0
	
	draw_line(Vector2(margin, margin), Vector2(margin + bracket_len, margin), col, thickness)
	draw_line(Vector2(margin, margin), Vector2(margin, margin + bracket_len), col, thickness)
	
	draw_line(Vector2(w - margin, margin), Vector2(w - margin - bracket_len, margin), col, thickness)
	draw_line(Vector2(w - margin, margin), Vector2(w - margin, margin + bracket_len), col, thickness)
	
	draw_line(Vector2(margin, h - margin), Vector2(margin + bracket_len, h - margin), col, thickness)
	draw_line(Vector2(margin, h - margin), Vector2(margin, h - margin - bracket_len), col, thickness)
	
	draw_line(Vector2(w - margin, h - margin), Vector2(w - margin - bracket_len, h - margin), col, thickness)
	draw_line(Vector2(w - margin, h - margin), Vector2(w - margin, h - margin - bracket_len), col, thickness)


func _draw_grid(w: float, h: float) -> void:
	var grid_size: float = 80.0
	var col: Color = Color(0.2, 0.4, 0.8, 0.08)
	
	for x in range(0, int(w), int(grid_size)):
		draw_line(Vector2(x, 0), Vector2(x, h), col, 1.0)
	
	for y in range(0, int(h), int(grid_size)):
		draw_line(Vector2(0, y), Vector2(w, y), col, 1.0)