extends Area2D

# =============================================================================
# 手榴弹：投掷后飞行一段时间，引信到期后爆炸
# 爆炸对范围内所有 "enemy" 组成员造成伤害
# =============================================================================

var direction: Vector2 = Vector2.ZERO
var speed: float = 500.0
var damage: int = 100
var blast_radius: float = 120.0
var fuse_time: float = 0.8
var boom_sfx: AudioStream = null
var owner_peer_id: int = 0  # 联机模式：手榴弹所属玩家
var is_enemy_grenade: bool = false  # 敌人（BOSS）投掷的手榴弹：伤害玩家而非僵尸

var _fuse_timer: Timer = null
var _exploded: bool = false
var thrown_by: Node = null  # 投掷者引用（用于击杀归属）


func _ready() -> void:
	# 视觉：深灰色小球（敌人手榴弹为暗红色）
	var vis: ColorRect = ColorRect.new()
	if is_enemy_grenade:
		vis.color = Color(0.6, 0.1, 0.1, 1.0)
	else:
		vis.color = Color(0.25, 0.25, 0.25, 1.0)
	vis.size = Vector2(10, 10)
	vis.position = Vector2(-5, -5)
	add_child(vis)

	# 引信计时器
	_fuse_timer = Timer.new()
	_fuse_timer.wait_time = fuse_time
	_fuse_timer.one_shot = true
	_fuse_timer.timeout.connect(_explode)
	add_child(_fuse_timer)
	_fuse_timer.start()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	# 减速模拟空气阻力
	speed = move_toward(speed, 150.0, 200.0 * delta)


func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	# 播放爆炸音效
	if boom_sfx:
		var sfx: AudioStreamPlayer = AudioStreamPlayer.new()
		sfx.stream = boom_sfx
		sfx.volume_db = -3.0
		sfx.bus = "SFX"
		var scene_root: Node = get_tree().current_scene
		if scene_root:
			scene_root.add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())

	if is_enemy_grenade:
		# 敌人（BOSS）手榴弹：伤害玩家（爆炸伤害）
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.has_method("take_damage"):
				if global_position.distance_to(p.global_position) <= blast_radius:
					p.take_damage(damage, true)
		# 联机僵尸模式：同步爆炸位置到客户端，让客户端玩家也受伤害
		if NetworkManager.connected and NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
			var scene: Node = get_tree().current_scene
			if scene and scene.has_method("_sync_enemy_grenade"):
				scene._sync_enemy_grenade.rpc(global_position, damage, blast_radius)
	else:
		# 玩家手榴弹：对范围内敌人造成爆炸伤害
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				if global_position.distance_to(enemy.global_position) <= blast_radius:
					enemy.take_damage(damage, thrown_by)

		# 联机PvP模式：手榴弹也能伤害其他玩家（但不是发射者自己）
		if NetworkManager.connected:
			if NetworkManager.room_mode == NetworkManager.GameMode.DUEL or NetworkManager.room_mode == NetworkManager.GameMode.BRAWL:
				for p in get_tree().get_nodes_in_group("player"):
					if is_instance_valid(p) and p.has_method("take_damage") and p.has_method("get_multiplayer_authority"):
						# 不伤害发射者自己
						if p.get_multiplayer_authority() == owner_peer_id:
							continue
						# 单挑模式：不伤害队友
						if NetworkManager.room_mode == NetworkManager.GameMode.DUEL:
							var my_team: String = NetworkManager.duel_teams.get(owner_peer_id, "red")
							var target_team: String = NetworkManager.duel_teams.get(p.get_multiplayer_authority(), "blue")
							if my_team == target_team:
								continue
						if global_position.distance_to(p.global_position) <= blast_radius:
							p.take_damage(damage, true)

	# 爆炸视觉效果
	_create_explosion_visual()

	queue_free()


func _create_explosion_visual() -> void:
	var explosion: Node2D = Node2D.new()
	explosion.global_position = global_position
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(explosion)

	var circle: Polygon2D = Polygon2D.new()
	var points: Array = []
	var segs: int = 32
	for i in range(segs):
		var angle: float = i * TAU / segs
		points.append(Vector2(cos(angle) * blast_radius, sin(angle) * blast_radius))
	circle.polygon = PackedVector2Array(points)
	circle.color = Color(1.0, 0.5, 0.1, 0.6)
	explosion.add_child(circle)

	var tween: Tween = explosion.create_tween()
	tween.tween_property(circle, "scale", Vector2(1.3, 1.3), 0.2)
	tween.parallel().tween_property(circle, "color:a", 0.0, 0.3)
	tween.tween_callback(func(): explosion.queue_free())
