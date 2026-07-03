extends CharacterBody2D

# =============================================================================
# 僵尸AI控制器
# 寻路接近玩家 + 近战攻击
# 僵尸类型：0=普通，1=速度型(Runner)，2=坦克型(Tank)，3=爆炸型(Bomber)
# =============================================================================

signal died(zombie, killed_by)
signal health_changed(current_health: int, max_health: int)

# 节点引用
@onready var attack_timer: Timer = $AttackTimer
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

# AI参数（基础值，会根据类型调整）
@export var move_speed: float = 100.0
@export var attack_range: float = 40.0
@export var attack_damage: int = 15
@export var attack_cooldown: float = 1.0
@export var health: int = 50

# 最大血量（用于血条计算）
var max_health: int = 50

# 僵尸类型标记（由 ZombieGame 生成时设置）
# type: 0=普通, 1=速度型, 2=坦克型, 3=爆炸型
var zombie_type: int = 0
var is_elite: bool = false
var is_boss: bool = false

# 基础颜色，受击闪红后恢复此颜色
var base_color: Color = Color(0.2, 0.7, 0.2, 1.0)

# 状态
var target_player: CharacterBody2D = null

# 击杀归属：最后一次造成伤害的来源（用于判定谁杀死了此僵尸）
var last_damage_source: Node = null

# 音效
var boom_sfx: AudioStream = null

# BOSS 披风
var _cape_node: Polygon2D = null
var _cape_base_points: PackedVector2Array = PackedVector2Array()
var _wave_time: float = 0.0

# 双手（向前伸直，朝向玩家）
var _hands_pivot: Node2D = null

# --- 智能行为参数 ---
# 分离避让
var _separation_force: Vector2 = Vector2.ZERO

# 侧翼包抄：每个僵尸有不同的偏移角度
var _flank_angle: float = 0.0

# 受击发狂
var _frenzy_timer: float = 0.0
var _frenzy_speed_mult: float = 1.6

# 精英突进
var _lunge_timer: float = 0.0
var _lunge_active: bool = false
var _lunge_dir: Vector2 = Vector2.ZERO
var _lunge_duration: float = 0.0

# BOSS 冲锋
var _charge_timer: float = 4.0  # 首次冲锋前的冷却
var _charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_duration: float = 0.0

# 目标重评估计时器：定期重新选择最近的玩家
var _retarget_timer: float = 0.0
const RETARGET_INTERVAL: float = 3.0

# BOSS 扔手榴弹
var _boss_grenade_timer: float = 6.0  # 首次扔手榴弹前的冷却
const BOSS_GRENADE_COOLDOWN: float = 6.0  # 每次扔手榴弹的冷却时间
const BOSS_GRENADE_DAMAGE: int = 60
const BOSS_GRENADE_BLAST_RADIUS: float = 100.0
const BOSS_GRENADE_FUSE_TIME: float = 1.5
const BOSS_GRENADE_SPEED: float = 350.0
const BOSS_GRENADE_COUNT: int = 8  # 一次扔出的手榴弹数量（360度均匀分布）

# 爆炸型僵尸(Bomber)参数
var _bomber_exploded: bool = false  # 防止重复爆炸
const BOMBER_EXPLOSION_DAMAGE: int = 40
const BOMBER_EXPLOSION_RADIUS: float = 80.0

func _ready() -> void:
	# 根据僵尸类型调整属性与基础颜色
	match zombie_type:
		1:  # 速度型(Runner)
			scale = Vector2(0.85, 0.85)
			health = 30
			max_health = 30
			attack_damage = 10
			move_speed = 150.0
			attack_cooldown = 0.7
			base_color = Color(0.4, 0.9, 0.4, 1.0)  # 浅绿色
		2:  # 坦克型(Tank)
			scale = Vector2(1.8, 1.8)
			health = 200
			max_health = 200
			attack_damage = 30
			move_speed = 60.0
			attack_cooldown = 1.8
			base_color = Color(0.1, 0.3, 0.1, 1.0)  # 深绿色
		3:  # 爆炸型(Bomber)
			scale = Vector2(1.2, 1.2)
			health = 80
			max_health = 80
			attack_damage = 20
			move_speed = 90.0
			attack_cooldown = 1.2
			base_color = Color(0.9, 0.7, 0.2, 1.0)  # 黄色
		_:
			if is_boss:
				scale = Vector2(2.5, 2.5)
				health = 10000
				max_health = 10000
				attack_damage = 50
				move_speed = 80.0
				attack_cooldown = 1.5
				base_color = Color(0.5, 0.0, 0.0, 1.0)
			elif is_elite:
				scale = Vector2(1.5, 1.5)
				health = 500
				max_health = 500
				attack_damage = 25
				move_speed = 120.0
				attack_cooldown = 0.8
				base_color = Color(0.8, 0.0, 0.8, 1.0)
			else:
				base_color = Color(0.2, 0.7, 0.2, 1.0)
				max_health = health

	# 找到玩家
	_find_player()

	# 侧翼包抄角度：基于实例ID分配，让僵尸分散从不同方向接近
	var id_hash: int = get_instance_id() % 360
	_flank_angle = deg_to_rad(float(id_hash)) * 0.5  # ±90度范围
	if (get_instance_id() % 2) == 0:
		_flank_angle = -_flank_angle

	# 攻击计时器
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timeout)

	# 导航代理设置
	if navigation_agent:
		navigation_agent.path_desired_distance = 20.0
		navigation_agent.target_desired_distance = attack_range * 0.8

	# 设置精灵颜色
	var sprite: Node = get_node_or_null("Sprite2D")
	if sprite is ColorRect:
		sprite.color = base_color

	add_to_group("enemy")

	# 加载音效
	boom_sfx = load("res://assets/boom.mp3")

	# 加眼睛
	_create_eyes()

	# 加双手（向前伸直）
	_create_hands()

	# BOSS 加披风
	if is_boss:
		_create_cape()



func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_player):
		_find_player()
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# 目标已死亡：重新寻找存活玩家
	if target_player.get("dead") == true:
		_find_player()
		if not is_instance_valid(target_player) or target_player.get("dead") == true:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	# 定期重新评估最近的玩家（避免一直追远处目标而忽略近处玩家）
	_retarget_timer -= delta
	if _retarget_timer <= 0:
		_retarget_timer = RETARGET_INTERVAL
		_find_player()

	# --- 计时器更新 ---
	if _frenzy_timer > 0:
		_frenzy_timer -= delta
	if _lunge_timer > 0:
		_lunge_timer -= delta
	if _charge_timer > 0:
		_charge_timer -= delta

	# --- 分离避让：计算附近僵尸的推开力 ---
	_separation_force = Vector2.ZERO
	var nearby_zombies: Array = get_tree().get_nodes_in_group("enemy")
	var pack_count: int = 0
	for z in nearby_zombies:
		if z == self or not is_instance_valid(z):
			continue
		var dist_to_z: float = global_position.distance_to(z.global_position)
		if dist_to_z < 150.0:
			pack_count += 1
		if dist_to_z < 50.0 and dist_to_z > 0.1:
			# 距离越近，推力越大
			var push_dir: Vector2 = (global_position - z.global_position).normalized()
			_separation_force += push_dir * (50.0 / dist_to_z)

	# --- 计算实际速度 ---
	var actual_speed: float = move_speed
	# 群体加速
	if pack_count >= 2:
		actual_speed *= 1.3
	# 受击发狂加速
	if _frenzy_timer > 0:
		actual_speed *= _frenzy_speed_mult

	var dist: float = global_position.distance_to(target_player.global_position)

	# --- BOSS 冲锋 ---
	if is_boss:
		if _charging:
			_charge_duration -= delta
			if _charge_duration <= 0:
				_charging = false
				_charge_timer = 5.0  # 冷却5秒
			else:
				# 冲锋中：高速直线冲撞
				velocity = _charge_dir * move_speed * 4.0
				# 冲锋中也叠加分离力防止重叠
				velocity += _separation_force * 20.0
				_move_and_slide_check(delta)
				return
		elif _charge_timer <= 0 and dist < 600.0 and dist > 80.0:
			# 开始冲锋
			_charging = true
			_charge_duration = 0.6
			_charge_dir = (target_player.global_position - global_position).normalized()

		# --- BOSS 扔手榴弹 ---
		if _boss_grenade_timer > 0:
			_boss_grenade_timer -= delta
		elif not _charging and dist > 100.0 and dist < 700.0:
			# 距离适中时扔手榴弹（不在冲锋中）
			_throw_boss_grenade()
			_boss_grenade_timer = BOSS_GRENADE_COOLDOWN

	# --- 精英突进 ---
	if is_elite and not _lunge_active:
		if _lunge_timer <= 0 and dist < 250.0 and dist > 80.0:
			_lunge_active = true
			_lunge_duration = 0.35
			_lunge_dir = (target_player.global_position - global_position).normalized()
			_lunge_timer = 3.0  # 冷却3秒
	elif _lunge_active:
		_lunge_duration -= delta
		if _lunge_duration <= 0:
			_lunge_active = false
		else:
			velocity = _lunge_dir * move_speed * 3.5
			velocity += _separation_force * 20.0
			_move_and_slide_check(delta)
			return

	# --- 设置导航目标（带侧翼偏移） ---
	if navigation_agent:
		var target_pos: Vector2 = target_player.global_position
		# 侧翼包抄：将目标点绕玩家旋转一个角度，让僵尸从侧面接近
		if dist > attack_range * 2:
			var to_target: Vector2 = target_pos - global_position
			var rotated_target: Vector2 = global_position + to_target.rotated(_flank_angle * 0.4)
			# 不要偏离太远，混合一下
			target_pos = target_pos.lerp(rotated_target, 0.35)
		navigation_agent.target_position = target_pos

	# 用导航路径移动
	_move_with_nav(actual_speed)

	# 叠加分离力（防止僵尸堆叠）
	if _separation_force.length() > 0.01:
		velocity += _separation_force * 30.0

	# 攻击逻辑
	if dist <= attack_range:
		if attack_timer and attack_timer.is_stopped():
			_perform_attack()
			attack_timer.start()

	_move_and_slide_check(delta)

	# BOSS 披风摇摆动画
	if is_boss and _cape_node:
		_wave_time += delta
		var pts: PackedVector2Array = []
		for i in range(_cape_base_points.size()):
			var p: Vector2 = _cape_base_points[i]
			if p.y > 20:
				p.x += sin(_wave_time * 3.0 + p.y * 0.15) * 3.0
			pts.append(p)
		_cape_node.polygon = pts

	# 双手始终朝向玩家
	if _hands_pivot and is_instance_valid(target_player):
		_hands_pivot.look_at(target_player.global_position)


func _move_and_slide_check(_delta: float) -> void:
	move_and_slide()

func _move_with_nav(custom_speed: float = -1.0) -> void:
	var speed_to_use: float = custom_speed if custom_speed > 0 else move_speed

	if not navigation_agent:
		_fallback_move(speed_to_use)
		return

	# 如果导航代理无法到达目标，改用直线追踪
	if not navigation_agent.is_target_reachable():
		_fallback_move(speed_to_use)
		return

	# 如果导航立即认为"已完成"（说明没有有效路径），改用直线追踪
	if navigation_agent.is_navigation_finished():
		# 但检查一下是否真的到达了玩家附近
		if target_player and global_position.distance_to(target_player.global_position) > attack_range:
			_fallback_move(speed_to_use)
			return
		velocity = Vector2.ZERO
		return

	var next_pos: Vector2 = navigation_agent.get_next_path_position()
	# 保底：如果下一个路径点和当前位置几乎一样，说明路径无效
	if next_pos.is_equal_approx(global_position):
		_fallback_move(speed_to_use)
		return

	var move_dir: Vector2 = (next_pos - global_position).normalized()
	velocity = move_dir * speed_to_use


func _fallback_move(custom_speed: float = -1.0) -> void:
	"""导航不可用时的直线追踪（保底逻辑）"""
	if not is_instance_valid(target_player):
		velocity = Vector2.ZERO
		return
	var speed_to_use: float = custom_speed if custom_speed > 0 else move_speed
	var dir: Vector2 = (target_player.global_position - global_position).normalized()
	velocity = dir * speed_to_use


func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	# 优先选择存活的玩家（联机模式下可能有已死亡的玩家仍在场景中）
	var living_players: Array = []
	for p in players:
		if is_instance_valid(p) and p.get("dead") != true:
			living_players.append(p)
	if living_players.size() > 0:
		# 选择距离最近的存活玩家
		var nearest: Node = living_players[0]
		var nearest_dist: float = global_position.distance_squared_to(nearest.global_position)
		for i in range(1, living_players.size()):
			var p: Node = living_players[i]
			var d: float = global_position.distance_squared_to(p.global_position)
			if d < nearest_dist:
				nearest = p
				nearest_dist = d
		target_player = nearest
	elif players.size() > 0:
		target_player = players[0]

func _perform_attack() -> void:
	if not is_instance_valid(target_player):
		return
	if target_player.has_method("take_damage"):
		target_player.take_damage(attack_damage)

func _create_eyes() -> void:
	# 僵尸眼睛颜色根据类型变化
	var eye_color: Color = Color(1, 0.9, 0.2, 1)  # 默认黄色（普通僵尸）
	match zombie_type:
		1:  # 速度型 - 白色眼睛
			eye_color = Color(0.9, 0.9, 1.0, 1)
		2:  # 坦克型 - 红色眼睛
			eye_color = Color(1.0, 0.2, 0.2, 1)
		3:  # 爆炸型 - 橙色眼睛
			eye_color = Color(1.0, 0.6, 0.1, 1)
	
	var eye_left: ColorRect = ColorRect.new()
	eye_left.name = "EyeLeft"
	eye_left.size = Vector2(4, 4)
	eye_left.position = Vector2(-8, -8)
	eye_left.color = eye_color
	add_child(eye_left)
	
	var eye_right: ColorRect = ColorRect.new()
	eye_right.name = "EyeRight"
	eye_right.size = Vector2(4, 4)
	eye_right.position = Vector2(4, -8)
	eye_right.color = eye_color
	add_child(eye_right)
	
	var pupil_left: ColorRect = ColorRect.new()
	pupil_left.name = "PupilLeft"
	pupil_left.size = Vector2(2, 2)
	pupil_left.position = Vector2(-7, -7)
	pupil_left.color = Color(0.2, 0.1, 0.0, 1)
	add_child(pupil_left)
	
	var pupil_right: ColorRect = ColorRect.new()
	pupil_right.name = "PupilRight"
	pupil_right.size = Vector2(2, 2)
	pupil_right.position = Vector2(5, -7)
	pupil_right.color = Color(0.2, 0.1, 0.0, 1)
	add_child(pupil_right)


func _create_cape() -> void:
	"""BOSS 幽灵披风：暗色多边形，底边波浪形"""
	_cape_node = Polygon2D.new()
	_cape_node.name = "Cape"
	# 披风形状：上窄下宽，底边呈波浪状（幽灵尾巴感）
	_cape_base_points = PackedVector2Array([
		Vector2(-14, 14),
		Vector2(14, 14),
		Vector2(18, 30),
		Vector2(15, 44),
		Vector2(10, 52),
		Vector2(2, 50),
		Vector2(-5, 54),
		Vector2(-12, 48),
		Vector2(-18, 42),
		Vector2(-16, 28)
	])
	_cape_node.polygon = _cape_base_points
	_cape_node.color = Color(0.12, 0.0, 0.04, 0.9)
	_cape_node.z_index = -1
	add_child(_cape_node)


func _create_hands() -> void:
	"""僵尸双手：两支手臂平行向前伸直，末端有手"""
	_hands_pivot = Node2D.new()
	_hands_pivot.name = "HandsPivot"
	add_child(_hands_pivot)

	# 手臂颜色比身体稍暗，手比手臂稍亮
	var arm_color: Color = base_color.darkened(0.3)
	var hand_color: Color = base_color.darkened(0.12)

	# 左臂（上）
	var left_arm: ColorRect = ColorRect.new()
	left_arm.name = "LeftArm"
	left_arm.size = Vector2(20, 5)
	left_arm.position = Vector2(8, -9)
	left_arm.color = arm_color
	_hands_pivot.add_child(left_arm)

	# 左手
	var left_hand: ColorRect = ColorRect.new()
	left_hand.name = "LeftHand"
	left_hand.size = Vector2(8, 7)
	left_hand.position = Vector2(26, -10)
	left_hand.color = hand_color
	_hands_pivot.add_child(left_hand)

	# 右臂（下）
	var right_arm: ColorRect = ColorRect.new()
	right_arm.name = "RightArm"
	right_arm.size = Vector2(20, 5)
	right_arm.position = Vector2(8, 4)
	right_arm.color = arm_color
	_hands_pivot.add_child(right_arm)

	# 右手
	var right_hand: ColorRect = ColorRect.new()
	right_hand.name = "RightHand"
	right_hand.size = Vector2(8, 7)
	right_hand.position = Vector2(26, 3)
	right_hand.color = hand_color
	_hands_pivot.add_child(right_hand)


func take_damage(amount: int, source: Node = null) -> void:
	health -= amount
	health_changed.emit(health, max_health)
	# 记录伤害来源，用于击杀归属判定
	if source:
		last_damage_source = source
	# 受击发狂：短暂加速
	_frenzy_timer = 1.2
	if is_instance_valid($Sprite2D):
		$Sprite2D.color = Color.RED
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid($Sprite2D):
				$Sprite2D.color = base_color
		)
	if health <= 0:
		_die()

func _throw_boss_grenade() -> void:
	if not is_instance_valid(target_player):
		return
	# 连环手榴弹：360度均匀分布，一次扔出多个
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return

	# 朝玩家方向偏移一个角度，让弹幕以玩家为中心但不完全对准
	var base_angle: float = 0.0
	if is_instance_valid(target_player):
		base_angle = (target_player.global_position - global_position).angle()

	for i in range(BOSS_GRENADE_COUNT):
		var angle: float = base_angle + (TAU * i / BOSS_GRENADE_COUNT)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))

		var grenade: Area2D = Area2D.new()
		grenade.name = "BossGrenade"
		grenade.set_script(load("res://scripts/Grenade.gd"))
		grenade.global_position = global_position
		grenade.direction = dir
		grenade.speed = BOSS_GRENADE_SPEED
		grenade.damage = BOSS_GRENADE_DAMAGE
		grenade.blast_radius = BOSS_GRENADE_BLAST_RADIUS
		grenade.fuse_time = BOSS_GRENADE_FUSE_TIME
		grenade.boom_sfx = boom_sfx
		grenade.is_enemy_grenade = true

		scene_root.add_child(grenade)


func _die() -> void:
	# 爆炸型僵尸：死亡时爆炸
	if zombie_type == 3 and not _bomber_exploded:
		_bomber_exploded = true
		_trigger_bomber_explosion()
	
	died.emit(self, last_damage_source)
	call_deferred("queue_free")

func _trigger_bomber_explosion() -> void:
	"""爆炸型僵尸死亡时触发范围爆炸"""
	# 创建爆炸视觉效果
	var explosion: ColorRect = ColorRect.new()
	explosion.size = Vector2(BOMBER_EXPLOSION_RADIUS * 2, BOMBER_EXPLOSION_RADIUS * 2)
	explosion.position = -Vector2(BOMBER_EXPLOSION_RADIUS, BOMBER_EXPLOSION_RADIUS)
	explosion.color = Color(1.0, 0.6, 0.1, 0.7)  # 橙黄色爆炸
	explosion.z_index = 100
	get_tree().current_scene.add_child(explosion)
	
	# 渐隐动画
	var tween: Tween = explosion.create_tween()
	tween.tween_property(explosion, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): explosion.queue_free())
	
	# 对所有附近的玩家造成伤害
	var players: Array = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.get("dead") != true:
			var dist: float = global_position.distance_to(p.global_position)
			if dist <= BOMBER_EXPLOSION_RADIUS:
				if p.has_method("take_damage"):
					p.take_damage(BOMBER_EXPLOSION_DAMAGE, null)


func _on_attack_timeout() -> void:
	pass



