extends StaticBody2D
class_name Barrel

# =============================================================================
# 爆炸桶脚本 (StaticBody2D版)
# - 玩家/敌人撞上去会物理碰撞（走不穿）
# - 子弹击中时 body_entered 触发，调用 take_damage
# =============================================================================

signal exploded(pos: Vector2)

@export var health: int = 1
@export var explosion_radius: float = 150.0
@export var explosion_damage: int = 80

var _is_exploding: bool = false
var _visual: ColorRect = null
var _warn_timer: Timer = null
var _trigger_source: Node = null  # 触发爆炸的来源（用于击杀归属）

func _ready() -> void:
	_visual = $Visual
	
	_warn_timer = Timer.new()
	_warn_timer.one_shot = true
	_warn_timer.wait_time = 0.5
	_warn_timer.timeout.connect(_on_explode)
	add_child(_warn_timer)


func take_damage(_dmg: int = 1, source: Node = null) -> void:
	if _is_exploding:
		return
	_is_exploding = true
	if source:
		_trigger_source = source
	if _visual:
		_visual.color = Color(1.0, 0.3, 0.1, 1.0)
		var tw: Tween = create_tween()
		tw.tween_property(_visual, "modulate:a", 0.3, 0.1)
		tw.tween_property(_visual, "modulate:a", 1.0, 0.1)
		tw.tween_property(_visual, "modulate:a", 0.3, 0.1)
		tw.tween_property(_visual, "modulate:a", 1.0, 0.1)
	_warn_timer.start()


func _on_explode() -> void:
	# 播放爆炸音效
	var sfx_path: String = "res://assets/boom2.mp3"
	if ResourceLoader.exists(sfx_path):
		var sfx: AudioStream = load(sfx_path)
		if sfx:
			var asp: AudioStreamPlayer = AudioStreamPlayer.new()
			asp.stream = sfx
			asp.bus = "SFX"
			asp.volume_db = 2.0
			get_tree().current_scene.add_child(asp)
			asp.play()
			asp.finished.connect(func(): asp.queue_free())

	_apply_aoe()
	_spawn_vfx()
	exploded.emit(global_position)
	queue_free()


func _apply_aoe() -> void:
	var tree: SceneTree = get_tree()
	# 用 "enemy" 组（单数），同时兼容其他组名
	for group in ["enemy", "enemies", "zombies", "bots"]:
		for enemy in tree.get_nodes_in_group(group):
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var dist: float = enemy.global_position.distance_to(global_position)
				if dist < explosion_radius:
					var falloff: float = 1.0 - (dist / explosion_radius)
					var dmg: int = int(explosion_damage * falloff)
					if dmg > 0:
						enemy.take_damage(dmg, _trigger_source)

	var player: Node2D = tree.current_scene.get_node_or_null("Player")
	if player and is_instance_valid(player) and player.has_method("take_damage"):
		var dist: float = player.global_position.distance_to(global_position)
		if dist < explosion_radius:
			var falloff: float = 1.0 - (dist / explosion_radius)
			var dmg: int = int(explosion_damage * falloff * 0.4)
			if dmg > 0:
				player.take_damage(dmg, true)


func _spawn_vfx() -> void:
	var vfx: Node2D = Node2D.new()
	vfx.global_position = global_position
	get_tree().current_scene.add_child(vfx)

	var poly: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in range(24):
		var a: float = i * TAU / 24.0
		pts.append(Vector2(cos(a), sin(a)) * 20.0)
	poly.polygon = pts
	poly.color = Color(1.0, 0.6, 0.1, 0.85)
	poly.position = Vector2.ZERO
	vfx.add_child(poly)

	var tween: Tween = vfx.create_tween()
	tween.tween_property(poly, "scale", Vector2(7.0, 7.0), 0.25)
	tween.parallel().tween_property(poly, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): vfx.queue_free())
