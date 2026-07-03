extends CharacterBody2D

# =============================================================================
# BOT AI控制器
# 寻路追击、进入射程后停下射击、自动换弹
# 难度系统：EASY/NORMAL/MEDIUM/HARD
# 武器系统：步枪/手枪/狙击枪
# =============================================================================

signal died(bot, killed_by)

# Bot随机名字池
static var BOT_NAMES: Array = [
	"阿明", "贝卡", "查理", "大卫", "伊森",
	"弗兰克", "乔治", "亨利", "伊恩", "杰克",
	"凯文", "里奥", "迈克", "尼克", "奥斯卡",
	"保罗", "昆西", "瑞恩", "山姆", "汤姆"
]

# 节点引用
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var shoot_timer: Timer = $ShootTimer
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

# AI参数
@export var move_speed: float = 150.0
@export var detection_range: float = 500.0
@export var shoot_range: float = 300.0
@export var health: int = 80
var max_health: int = 80

# 状态
enum State { PATROL, CHASE, SHOOT, COVER, RETREAT }
var current_state: State = State.PATROL
var target_player: CharacterBody2D = null
var bot_name: String = ""

# 击杀归属：最后一次造成伤害的来源
var last_damage_source: Node = null

# 防卡住检测
var _stuck_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO

# 难度等级
enum Difficulty { EASY, NORMAL, MEDIUM, HARD }
var difficulty: int = Difficulty.NORMAL

# 难度控制的参数
var _aim_prediction: float = 0.7
var _enable_strafe: bool = true
var _enable_dodge: bool = true
var _enable_retreat: bool = true
var _enable_weapon_switch: bool = true
var _dodge_range: float = 200.0
var _retreat_threshold: float = 0.3
var _spread_factor: float = 1.0
var _rifle_fire_rate: Array = [0.3, 0.6]
var _pistol_fire_rate: Array = [0.6, 1.0]
var _sniper_fire_rate: Array = [1.5, 2.5]
var _grenade_count: int = 1

# --- 智能行为参数 ---
# 走位（strafe）
var _strafe_dir: int = 1  # 1=右, -1=左
var _strafe_timer: float = 0.0

# 躲子弹
var _dodge_timer: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO

# 障碍物缓存
var _cached_obstacles: Array = []

# 音效
var shoot_sfx: AudioStream = null
var boom_sfx: AudioStream = null
var sniper_sfx: AudioStream = null

# 武器系统
enum Weapon { RIFLE, PISTOL, SNIPER }
var current_weapon: int = Weapon.RIFLE

# 步枪（远距离压制，射速快伤害低）
var rifle_ammo: int = 30
const RIFLE_MAX_AMMO: int = 30
const RIFLE_DAMAGE: int = 10
const RIFLE_BULLET_SPEED: float = 500.0

# 手枪（近距离精准，伤害高射速慢）
var pistol_ammo: int = 12
const PISTOL_MAX_AMMO: int = 12
const PISTOL_DAMAGE: int = 20
const PISTOL_BULLET_SPEED: float = 700.0

# 狙击枪（远距离一枪一个，射速极慢）
var sniper_ammo: int = 5
const SNIPER_MAX_AMMO: int = 5
const SNIPER_DAMAGE: int = 100
const SNIPER_BULLET_SPEED: float = 1000.0

# 当前武器弹药引用（切换武器时同步）
var current_ammo: int = 30
var max_ammo: int = 30

# 武器视觉
var rifle_visual: Node2D = null
var pistol_visual: Node2D = null
var sniper_visual: Node2D = null

var reloading: bool = false
var patrol_points: Array = []
var current_patrol_index: int = 0

# 手榴弹
var grenade_count: int = 1
var grenade_throw_cooldown: float = 5.0
var grenade_timer: float = 0.0

func _ready() -> void:
	# 应用难度设置（必须在其他初始化之前）
	_apply_difficulty()

	_find_player()

	# 记录最大血量（用于残血撤退判断）
	max_health = health

	# 同步手榴弹数量
	grenade_count = _grenade_count

	# 射击计时器
	shoot_timer.wait_time = randf_range(0.5, 1.2)
	shoot_timer.one_shot = false
	shoot_timer.timeout.connect(_on_shoot_timeout)
	shoot_timer.start()

	# 导航设置
	if navigation_agent:
		navigation_agent.path_desired_distance = 20.0
		navigation_agent.target_desired_distance = shoot_range * 0.8

	add_to_group("enemy")

	# 随机分配名字
	bot_name = BOT_NAMES[randi() % BOT_NAMES.size()]

	# 加载音效
	shoot_sfx = load("res://assets/buqiangsheji.mp3")
	boom_sfx = load("res://assets/boom.mp3")
	sniper_sfx = load("res://assets/jujiqiangsheji.mp3")

	# 在 WeaponPivot 上画一把枪（视觉）
	_create_weapon_visual()

	# 加眼睛
	_create_eyes()

	# 随机生成巡逻点（相对于当前位置，防止跑到墙外卡住）
	for i in range(4):
		patrol_points.append(global_position + Vector2(randf_range(-300, 300), randf_range(-300, 300)))

	# 初始化走位计时器
	_strafe_timer = randf_range(1.5, 3.0)
	_strafe_dir = 1 if randf() > 0.5 else -1

func _physics_process(delta: float) -> void:
	# 手榴弹冷却
	if grenade_timer > 0:
		grenade_timer -= delta

	# 走位方向切换计时器
	_strafe_timer -= delta
	if _strafe_timer <= 0:
		_strafe_dir *= -1
		_strafe_timer = randf_range(1.5, 3.0)

	# 躲子弹冷却
	if _dodge_timer > 0:
		_dodge_timer -= delta

	# 防卡住：如果移动距离太小就换方向
	_stuck_timer += delta
	if _stuck_timer >= 1.0:
		var moved_dist: float = global_position.distance_to(_last_position)
		if moved_dist < 5.0:  # 1秒内移动不到5像素 = 卡住了
			# 换一个新的巡逻方向
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
			patrol_points[current_patrol_index] = global_position + Vector2(randf_range(-300, 300), randf_range(-300, 300))
			# 如果找不到玩家，重新搜索
			if not is_instance_valid(target_player):
				_find_player()
		_last_position = global_position
		_stuck_timer = 0.0

	_update_state()
	_process_state()

	# 手榴弹逻辑：近距离或血量低时扔手榴弹（EASY难度无手榴弹）
	if grenade_count > 0 and grenade_timer <= 0 and is_instance_valid(target_player):
		var dist: float = global_position.distance_to(target_player.global_position)
		if dist < 150.0 or health < 30:
			_throw_grenade()
			grenade_count -= 1
			grenade_timer = grenade_throw_cooldown

func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func _apply_difficulty() -> void:
	# 从 GameSettings 读取难度并应用所有难度相关参数
	difficulty = GameSettings.get_value("game", "bot_difficulty", 1)

	match difficulty:
		Difficulty.EASY:
			move_speed = 100
			detection_range = 400
			shoot_range = 250
			health = 40
			_aim_prediction = 0.15
			_enable_strafe = false
			_enable_dodge = false
			_enable_retreat = false
			_enable_weapon_switch = false
			_dodge_range = 0
			_retreat_threshold = 0
			_spread_factor = 2.5
			_rifle_fire_rate = [0.8, 1.5]
			_pistol_fire_rate = [1.0, 1.8]
			_sniper_fire_rate = [2.0, 3.5]
			_grenade_count = 0
		Difficulty.NORMAL:
			move_speed = 120
			detection_range = 400
			shoot_range = 250
			health = 60
			_aim_prediction = 0.4
			_enable_strafe = true
			_enable_dodge = true
			_enable_retreat = false
			_enable_weapon_switch = false
			_dodge_range = 150
			_retreat_threshold = 0
			_spread_factor = 2.0
			_rifle_fire_rate = [0.6, 1.0]
			_pistol_fire_rate = [0.8, 1.3]
			_sniper_fire_rate = [2.0, 3.0]
			_grenade_count = 1
		Difficulty.MEDIUM:
			move_speed = 150
			detection_range = 500
			shoot_range = 300
			health = 80
			_aim_prediction = 0.6
			_enable_strafe = true
			_enable_dodge = true
			_enable_retreat = true
			_enable_weapon_switch = true
			_dodge_range = 200
			_retreat_threshold = 0.3
			_spread_factor = 1.5
			_rifle_fire_rate = [0.4, 0.8]
			_pistol_fire_rate = [0.6, 1.0]
			_sniper_fire_rate = [1.5, 2.5]
			_grenade_count = 1
		Difficulty.HARD:
			move_speed = 180
			detection_range = 600
			shoot_range = 350
			health = 100
			_aim_prediction = 0.85
			_enable_strafe = true
			_enable_dodge = true
			_enable_retreat = true
			_enable_weapon_switch = true
			_dodge_range = 250
			_retreat_threshold = 0.4
			_spread_factor = 1.0
			_rifle_fire_rate = [0.3, 0.6]
			_pistol_fire_rate = [0.5, 0.8]
			_sniper_fire_rate = [1.0, 2.0]
			_grenade_count = 2

func _update_state() -> void:
	if not is_instance_valid(target_player):
		_find_player()
		if not is_instance_valid(target_player):
			current_state = State.PATROL
			return

	var dist: float = global_position.distance_to(target_player.global_position)

	# 残血撤退优先级最高（除非正在换弹），需要启用撤退行为
	if _enable_retreat and health < max_health * _retreat_threshold and not reloading and current_state != State.COVER:
		current_state = State.RETREAT
		return

	match current_state:
		State.PATROL:
			if dist < detection_range:
				current_state = State.CHASE
		State.CHASE:
			if dist < shoot_range:
				current_state = State.SHOOT
			elif dist > detection_range * 1.5:
				current_state = State.PATROL
		State.SHOOT:
			if dist > shoot_range * 1.3:
				current_state = State.CHASE
		State.COVER:
			if not reloading:
				current_state = State.SHOOT
		State.RETREAT:
			# 血量恢复到50%以上或拉开足够距离后重新交战
			if health >= max_health * 0.5 or dist > detection_range * 1.2:
				current_state = State.CHASE

func _process_state() -> void:
	match current_state:
		State.PATROL:
			_patrol()
		State.CHASE:
			_chase_player()
		State.SHOOT:
			_shoot_state()
		State.COVER:
			_cover_state()
		State.RETREAT:
			_retreat_state()

	move_and_slide()

func _patrol() -> void:
	if patrol_points.size() == 0:
		velocity = Vector2.ZERO
		return
	var target: Vector2 = patrol_points[current_patrol_index]
	if global_position.distance_to(target) < 48.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		target = patrol_points[current_patrol_index]
	_nav_to(target)

func _chase_player() -> void:
	if not is_instance_valid(target_player):
		return
	_nav_to(target_player.global_position)

func _shoot_state() -> void:
	if not is_instance_valid(target_player):
		velocity = Vector2.ZERO
		return

	# 旋转武器朝向玩家
	if weapon_pivot:
		weapon_pivot.look_at(target_player.global_position)

	var dist: float = global_position.distance_to(target_player.global_position)

	# 智能武器选择（EASY模式不切换武器）
	if _enable_weapon_switch:
		_decide_weapon(dist)

	# 躲子弹：检测附近飞来的玩家子弹
	if _enable_dodge and _dodge_timer <= 0:
		var dodge: Vector2 = _detect_incoming_bullets()
		if dodge != Vector2.ZERO:
			_dodge_dir = dodge
			_dodge_timer = 0.4  # 躲避持续0.4秒
			velocity = dodge * move_speed
			return

	# 正在躲避中
	if _enable_dodge and _dodge_timer > 0:
		velocity = _dodge_dir * move_speed
		return

	# 侧移走位（strafe）：垂直于玩家方向移动，保持射程
	if not _enable_strafe:
		velocity = Vector2.ZERO
		return

	if dist < shoot_range * 0.4:
		# 太近了，后退拉开距离
		var away_dir: Vector2 = (global_position - target_player.global_position).normalized()
		var strafe_perp: Vector2 = Vector2(-away_dir.y, away_dir.x) * _strafe_dir
		velocity = (away_dir * 0.6 + strafe_perp * 0.4) * move_speed
	elif dist > shoot_range * 0.85:
		# 太远了，靠近一点
		var to_dir: Vector2 = (target_player.global_position - global_position).normalized()
		velocity = to_dir * move_speed * 0.7
	else:
		# 理想射程内：横向走位
		var to_player: Vector2 = (target_player.global_position - global_position).normalized()
		var strafe_perp: Vector2 = Vector2(-to_player.y, to_player.x) * _strafe_dir
		velocity = strafe_perp * move_speed * 0.8


func _detect_incoming_bullets() -> Vector2:
	# 检测附近飞向自己的玩家子弹，返回躲避方向
	var best_dodge: Vector2 = Vector2.ZERO
	var min_dist: float = 999.0

	# 扫描场景中所有 Area2D，找到玩家发射的子弹
	for child in get_tree().current_scene.get_children():
		if not child is Area2D:
			continue
		# 跳过非子弹节点（手榴弹等）
		if not child.has_method("get") or not "direction" in child:
			continue
		if not "shooter_is_player" in child or not child.shooter_is_player:
			continue

		var b_pos: Vector2 = child.global_position
		var b_dir: Vector2 = child.direction
		var to_me: Vector2 = global_position - b_pos
		var dist: float = to_me.length()
		if dist > _dodge_range:
			continue

		# 子弹是否朝向自己？（点积判断）
		if b_dir.length() > 0.01:
			var dot: float = b_dir.dot(to_me.normalized())
			if dot < 0.5:
				continue  # 子弹不是朝这边飞的

			# 计算子弹到自己的最近接近距离
			var perp_dist: float = abs(to_me.cross(b_dir.normalized()))
			if perp_dist < 50.0 and dist < min_dist:
				min_dist = dist
				# 躲避方向 = 垂直于子弹方向
				best_dodge = Vector2(-b_dir.y, b_dir.x)
				# 选远离子弹的一侧
				if best_dodge.dot(to_me) < 0:
					best_dodge = -best_dodge

	return best_dodge


func _retreat_state() -> void:
	# 残血撤退：远离玩家并寻找障碍物
	if not is_instance_valid(target_player):
		velocity = Vector2.ZERO
		return

	# 旋转武器朝向玩家（边退边射击）
	if weapon_pivot:
		weapon_pivot.look_at(target_player.global_position)

	# 导航到最近障碍物后方
	var cover_pos: Vector2 = _find_nearest_cover()
	if cover_pos != Vector2.ZERO:
		_nav_to(cover_pos)
	else:
		# 没找到掩体，直线远离玩家
		var away_dir: Vector2 = (global_position - target_player.global_position).normalized()
		# 垂直偏移让撤退路线不是直线
		var perp: Vector2 = Vector2(-away_dir.y, away_dir.x) * _strafe_dir * 0.3
		velocity = (away_dir + perp) * move_speed

func _cover_state() -> void:
	# 换弹时寻找最近障碍物后方
	var cover_pos: Vector2 = _find_nearest_cover()
	if cover_pos != Vector2.ZERO:
		_nav_to(cover_pos)
	else:
		# 没找到掩体，直线后退
		if is_instance_valid(target_player):
			var away: Vector2 = (global_position - target_player.global_position).normalized()
			_nav_to(global_position + away * 150)


func _find_nearest_cover() -> Vector2:
	# 寻找最近的障碍物，返回其远离玩家一侧的位置作为掩体
	if not is_instance_valid(target_player):
		return Vector2.ZERO

	# 缓存障碍物列表（障碍物在游戏过程中不会变化）
	if _cached_obstacles.is_empty():
		for child in get_tree().current_scene.get_children():
			_find_static_bodies(child, _cached_obstacles)

	var best_pos: Vector2 = Vector2.ZERO
	var best_dist: float = 400.0  # 只考虑400像素内的障碍物

	for obs in _cached_obstacles:
		if not is_instance_valid(obs) or not obs is StaticBody2D:
			continue
		var obs_pos: Vector2 = obs.global_position
		var dist_to_obs: float = global_position.distance_to(obs_pos)
		if dist_to_obs > best_dist:
			continue

		# 障碍物远离玩家的一侧 = 障碍物位置 + (障碍物→远离玩家方向) * 偏移
		var away_from_player: Vector2 = (obs_pos - target_player.global_position).normalized()
		var cover_pos: Vector2 = obs_pos + away_from_player * 50.0

		# 确认掩体位置离自己不太远
		if global_position.distance_to(cover_pos) < best_dist:
			best_dist = global_position.distance_to(cover_pos)
			best_pos = cover_pos

	return best_pos


func _find_static_bodies(node: Node, result: Array) -> void:
	# 递归查找所有 StaticBody2D
	if node is StaticBody2D and node.name == "Obstacle":
		result.append(node)
	for child in node.get_children():
		_find_static_bodies(child, result)

func _nav_to(target: Vector2) -> void:
	if not navigation_agent:
		var fallback_dir: Vector2 = (target - global_position).normalized()
		velocity = fallback_dir * move_speed
		return

	navigation_agent.target_position = target

	# 导航不可达时改用直线追踪
	if not navigation_agent.is_target_reachable():
		var fallback_dir: Vector2 = (target - global_position).normalized()
		velocity = fallback_dir * move_speed
		return

	# 如果导航立即认为"已完成"（说明没有有效路径），改用直线追踪
	if navigation_agent.is_navigation_finished():
		# 检查是否真的到达了目标附近
		if global_position.distance_to(target) > 50.0:
			var fallback_dir: Vector2 = (target - global_position).normalized()
			velocity = fallback_dir * move_speed
			return
		velocity = Vector2.ZERO
		return

	var next_pos: Vector2 = navigation_agent.get_next_path_position()
	# 保底：如果下一个路径点和当前位置几乎一样，说明路径无效
	if next_pos.is_equal_approx(global_position):
		var fallback_dir: Vector2 = (target - global_position).normalized()
		velocity = fallback_dir * move_speed
		return

	var move_dir: Vector2 = (next_pos - global_position).normalized()
	velocity = move_dir * move_speed


func _on_shoot_timeout() -> void:
	# SHOOT 和 RETREAT 状态都可以射击
	if (current_state == State.SHOOT or current_state == State.RETREAT) and is_instance_valid(target_player) and not reloading:
		_shoot()
		# 根据难度和武器选择射速
		match current_weapon:
			Weapon.RIFLE:
				shoot_timer.wait_time = randf_range(_rifle_fire_rate[0], _rifle_fire_rate[1])
			Weapon.PISTOL:
				shoot_timer.wait_time = randf_range(_pistol_fire_rate[0], _pistol_fire_rate[1])
			Weapon.SNIPER:
				shoot_timer.wait_time = randf_range(_sniper_fire_rate[0], _sniper_fire_rate[1])
		shoot_timer.start()

func _shoot() -> void:
	if current_ammo <= 0:
		_reload()
		return

	current_ammo -= 1
	# 同步弹药到对应武器
	match current_weapon:
		Weapon.RIFLE:
			rifle_ammo = current_ammo
		Weapon.PISTOL:
			pistol_ammo = current_ammo
		Weapon.SNIPER:
			sniper_ammo = current_ammo

	# 播放音效（狙击枪使用专用音效）
	if current_weapon == Weapon.SNIPER:
		_play_sfx(sniper_sfx)
	else:
		_play_sfx(shoot_sfx)

	var bullet_scene: PackedScene = load("res://scenes/game/Bullet.tscn")
	if not bullet_scene:
		return
	var bullet: Area2D = bullet_scene.instantiate()

	# 敌人子弹检测玩家(layer 2) + 障碍物(layer 1) = mask 3
	bullet.collision_mask = 3

	if weapon_pivot:
		bullet.global_position = weapon_pivot.global_position
	else:
		bullet.global_position = global_position

	if is_instance_valid(target_player):
		# 根据武器设置子弹参数
		var bullet_speed: float
		var damage: int
		match current_weapon:
			Weapon.RIFLE:
				bullet_speed = RIFLE_BULLET_SPEED
				damage = RIFLE_DAMAGE
			Weapon.PISTOL:
				bullet_speed = PISTOL_BULLET_SPEED
				damage = PISTOL_DAMAGE
			Weapon.SNIPER:
				bullet_speed = SNIPER_BULLET_SPEED
				damage = SNIPER_DAMAGE

		# 预判瞄准：根据玩家速度计算提前量
		var to_player: Vector2 = target_player.global_position - global_position
		var dist: float = to_player.length()
		var time_to_hit: float = dist / bullet_speed

		# 预测玩家在子弹到达时的位置
		var player_vel: Vector2 = target_player.velocity if "velocity" in target_player else Vector2.ZERO
		var predicted_pos: Vector2 = target_player.global_position + player_vel * time_to_hit * _aim_prediction

		var shoot_dir: Vector2 = (predicted_pos - global_position).normalized()
		# 散布计算：基础散布 * 难度系数
		var base_spread: float
		match current_weapon:
			Weapon.RIFLE:
				base_spread = 0.05 + (dist / 500.0) * 0.10
			Weapon.PISTOL:
				base_spread = 0.03
			Weapon.SNIPER:
				base_spread = 0.01
		var spread: float = base_spread * _spread_factor
		shoot_dir = shoot_dir.rotated(randf_range(-spread, spread))
		bullet.direction = shoot_dir
		bullet.speed = bullet_speed
		bullet.damage = damage
		bullet.shooter_is_player = false
		bullet.shooter = self  # Bot子弹的击杀归属

	get_tree().current_scene.add_child(bullet)

func _reload() -> void:
	# 当前武器空了，先尝试切到其他武器继续战斗
	if current_weapon == Weapon.RIFLE:
		if pistol_ammo > 0:
			_switch_weapon(Weapon.PISTOL)
			return
		elif sniper_ammo > 0:
			_switch_weapon(Weapon.SNIPER)
			return
	elif current_weapon == Weapon.PISTOL:
		if rifle_ammo > 0:
			_switch_weapon(Weapon.RIFLE)
			return
		elif sniper_ammo > 0:
			_switch_weapon(Weapon.SNIPER)
			return
	elif current_weapon == Weapon.SNIPER:
		if rifle_ammo > 0:
			_switch_weapon(Weapon.RIFLE)
			return
		elif pistol_ammo > 0:
			_switch_weapon(Weapon.PISTOL)
			return

	# 三把都空了，去掩体换弹
	if reloading:
		return
	reloading = true
	current_state = State.COVER
	await get_tree().create_timer(2.0).timeout
	# 换弹完成：三把武器都填满
	rifle_ammo = RIFLE_MAX_AMMO
	pistol_ammo = PISTOL_MAX_AMMO
	sniper_ammo = SNIPER_MAX_AMMO
	match current_weapon:
		Weapon.RIFLE:
			current_ammo = rifle_ammo
		Weapon.PISTOL:
			current_ammo = pistol_ammo
		Weapon.SNIPER:
			current_ammo = sniper_ammo
	reloading = false

func _create_eyes() -> void:
	# Bot 眼睛：红色凶眼
	var eye_left: ColorRect = ColorRect.new()
	eye_left.name = "EyeLeft"
	eye_left.size = Vector2(4, 4)
	eye_left.position = Vector2(-8, -8)
	eye_left.color = Color(1, 0.2, 0.2, 1)
	add_child(eye_left)

	var eye_right: ColorRect = ColorRect.new()
	eye_right.name = "EyeRight"
	eye_right.size = Vector2(4, 4)
	eye_right.position = Vector2(4, -8)
	eye_right.color = Color(1, 0.2, 0.2, 1)
	add_child(eye_right)

	var pupil_left: ColorRect = ColorRect.new()
	pupil_left.name = "PupilLeft"
	pupil_left.size = Vector2(2, 2)
	pupil_left.position = Vector2(-7, -7)
	pupil_left.color = Color(0, 0, 0, 1)
	add_child(pupil_left)

	var pupil_right: ColorRect = ColorRect.new()
	pupil_right.name = "PupilRight"
	pupil_right.size = Vector2(2, 2)
	pupil_right.position = Vector2(5, -7)
	pupil_right.color = Color(0, 0, 0, 1)
	add_child(pupil_right)

func take_damage(amount: int, source: Node = null) -> void:
	health -= amount
	if source:
		last_damage_source = source
	if health <= 0:
		_die()


func _play_sfx(stream: AudioStream) -> void:
	# 播放射击音效
	if stream:
		var sfx: AudioStreamPlayer = AudioStreamPlayer.new()
		sfx.stream = stream
		sfx.volume_db = -3.0
		sfx.bus = "SFX"
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())



func _create_weapon_visual() -> void:
	# 在 WeaponPivot 上分别创建步枪和手枪两套视觉模型
	if not weapon_pivot:
		return

	# --- 步枪模型（较长，带枪托） ---
	var rifle_holder: Node2D = Node2D.new()
	rifle_holder.name = "RifleVisual"
	weapon_pivot.add_child(rifle_holder)

	# 机匣（枪身主体）
	var r_body: ColorRect = ColorRect.new()
	r_body.name = "Receiver"
	r_body.size = Vector2(28, 8)
	r_body.position = Vector2(0, -4)
	r_body.color = Color(0.2, 0.2, 0.22, 1.0)
	rifle_holder.add_child(r_body)

	# 枪管
	var r_barrel: ColorRect = ColorRect.new()
	r_barrel.name = "Barrel"
	r_barrel.size = Vector2(14, 4)
	r_barrel.position = Vector2(28, -2)
	r_barrel.color = Color(0.1, 0.1, 0.1, 1.0)
	rifle_holder.add_child(r_barrel)

	# 枪托
	var r_stock: ColorRect = ColorRect.new()
	r_stock.name = "Stock"
	r_stock.size = Vector2(8, 6)
	r_stock.position = Vector2(-8, -3)
	r_stock.color = Color(0.35, 0.25, 0.15, 1.0)
	rifle_holder.add_child(r_stock)

	# 弹匣
	var r_mag: ColorRect = ColorRect.new()
	r_mag.name = "Magazine"
	r_mag.size = Vector2(6, 10)
	r_mag.position = Vector2(8, 4)
	r_mag.color = Color(0.15, 0.15, 0.15, 1.0)
	rifle_holder.add_child(r_mag)

	# 右手（握把处）
	var r_right_hand: ColorRect = ColorRect.new()
	r_right_hand.name = "RightHand"
	r_right_hand.size = Vector2(8, 7)
	r_right_hand.position = Vector2(2, 4)
	r_right_hand.color = Color(0.7, 0.55, 0.4, 1.0)
	rifle_holder.add_child(r_right_hand)

	# 左手（护木处）
	var r_left_hand: ColorRect = ColorRect.new()
	r_left_hand.name = "LeftHand"
	r_left_hand.size = Vector2(8, 6)
	r_left_hand.position = Vector2(20, 2)
	r_left_hand.color = Color(0.7, 0.55, 0.4, 1.0)
	rifle_holder.add_child(r_left_hand)

	rifle_visual = rifle_holder

	# --- 手枪模型（较短，无枪托） ---
	var pistol_holder: Node2D = Node2D.new()
	pistol_holder.name = "PistolVisual"
	weapon_pivot.add_child(pistol_holder)

	# 滑套（枪身主体）
	var p_slide: ColorRect = ColorRect.new()
	p_slide.name = "Slide"
	p_slide.size = Vector2(18, 7)
	p_slide.position = Vector2(2, -3.5)
	p_slide.color = Color(0.25, 0.25, 0.28, 1.0)
	pistol_holder.add_child(p_slide)

	# 枪管
	var p_barrel: ColorRect = ColorRect.new()
	p_barrel.name = "Barrel"
	p_barrel.size = Vector2(6, 4)
	p_barrel.position = Vector2(20, -2)
	p_barrel.color = Color(0.12, 0.12, 0.12, 1.0)
	pistol_holder.add_child(p_barrel)

	# 握把
	var p_grip: ColorRect = ColorRect.new()
	p_grip.name = "Grip"
	p_grip.size = Vector2(7, 10)
	p_grip.position = Vector2(5, 3.5)
	p_grip.color = Color(0.3, 0.25, 0.2, 1.0)
	pistol_holder.add_child(p_grip)

	# 右手（握把上）
	var p_right_hand: ColorRect = ColorRect.new()
	p_right_hand.name = "RightHand"
	p_right_hand.size = Vector2(8, 7)
	p_right_hand.position = Vector2(4, 8)
	p_right_hand.color = Color(0.7, 0.55, 0.4, 1.0)
	pistol_holder.add_child(p_right_hand)

	# 左手（枪管下方）
	var p_left_hand: ColorRect = ColorRect.new()
	p_left_hand.name = "LeftHand"
	p_left_hand.size = Vector2(7, 6)
	p_left_hand.position = Vector2(16, 2)
	p_left_hand.color = Color(0.7, 0.55, 0.4, 1.0)
	pistol_holder.add_child(p_left_hand)

	pistol_visual = pistol_holder

	# --- 狙击枪模型（长枪管，带瞄准镜，木质枪托，小弹匣） ---
	var sniper_holder: Node2D = Node2D.new()
	sniper_holder.name = "SniperVisual"
	weapon_pivot.add_child(sniper_holder)

	# 机匣（枪身主体，深灰色）
	var s_body: ColorRect = ColorRect.new()
	s_body.name = "Receiver"
	s_body.size = Vector2(32, 9)
	s_body.position = Vector2(0, -4.5)
	s_body.color = Color(0.18, 0.18, 0.2, 1.0)
	sniper_holder.add_child(s_body)

	# 枪管（超长）
	var s_barrel: ColorRect = ColorRect.new()
	s_barrel.name = "Barrel"
	s_barrel.size = Vector2(22, 4)
	s_barrel.position = Vector2(32, -2)
	s_barrel.color = Color(0.1, 0.1, 0.1, 1.0)
	sniper_holder.add_child(s_barrel)

	# 瞄准镜（浅色）
	var s_scope: ColorRect = ColorRect.new()
	s_scope.name = "Scope"
	s_scope.size = Vector2(14, 8)
	s_scope.position = Vector2(10, -12.5)
	s_scope.color = Color(0.25, 0.28, 0.32, 1.0)
	sniper_holder.add_child(s_scope)

	# 瞄准镜镜片（蓝色反光）
	var s_scope_lens: ColorRect = ColorRect.new()
	s_scope_lens.name = "ScopeLens"
	s_scope_lens.size = Vector2(5, 6)
	s_scope_lens.position = Vector2(12, -11.5)
	s_scope_lens.color = Color(0.1, 0.3, 0.8, 0.6)
	sniper_holder.add_child(s_scope_lens)

	# 枪托（木质颜色）
	var s_stock: ColorRect = ColorRect.new()
	s_stock.name = "Stock"
	s_stock.size = Vector2(10, 7)
	s_stock.position = Vector2(-10, -3.5)
	s_stock.color = Color(0.35, 0.25, 0.15, 1.0)
	sniper_holder.add_child(s_stock)

	# 弹匣（小弹匣）
	var s_mag: ColorRect = ColorRect.new()
	s_mag.name = "Magazine"
	s_mag.size = Vector2(5, 8)
	s_mag.position = Vector2(6, 4.5)
	s_mag.color = Color(0.12, 0.12, 0.12, 1.0)
	sniper_holder.add_child(s_mag)

	# 右手（握把处）
	var s_right_hand: ColorRect = ColorRect.new()
	s_right_hand.name = "RightHand"
	s_right_hand.size = Vector2(8, 7)
	s_right_hand.position = Vector2(0, 4.5)
	s_right_hand.color = Color(0.7, 0.55, 0.4, 1.0)
	sniper_holder.add_child(s_right_hand)

	# 左手（枪管末端附近）
	var s_left_hand: ColorRect = ColorRect.new()
	s_left_hand.name = "LeftHand"
	s_left_hand.size = Vector2(8, 6)
	s_left_hand.position = Vector2(44, 1)
	s_left_hand.color = Color(0.7, 0.55, 0.4, 1.0)
	sniper_holder.add_child(s_left_hand)

	sniper_visual = sniper_holder

	# 默认显示步枪
	_update_weapon_visual()


func _update_weapon_visual() -> void:
	if rifle_visual:
		rifle_visual.visible = (current_weapon == Weapon.RIFLE)
	if pistol_visual:
		pistol_visual.visible = (current_weapon == Weapon.PISTOL)
	if sniper_visual:
		sniper_visual.visible = (current_weapon == Weapon.SNIPER)


func _switch_weapon(weapon: int) -> void:
	if current_weapon == weapon:
		return
	# 保存当前武器弹药
	match current_weapon:
		Weapon.RIFLE:
			rifle_ammo = current_ammo
		Weapon.PISTOL:
			pistol_ammo = current_ammo
		Weapon.SNIPER:
			sniper_ammo = current_ammo
	# 切换到新武器
	current_weapon = weapon
	match current_weapon:
		Weapon.RIFLE:
			current_ammo = rifle_ammo
			max_ammo = RIFLE_MAX_AMMO
		Weapon.PISTOL:
			current_ammo = pistol_ammo
			max_ammo = PISTOL_MAX_AMMO
		Weapon.SNIPER:
			current_ammo = sniper_ammo
			max_ammo = SNIPER_MAX_AMMO
	reloading = false
	_update_weapon_visual()


func _decide_weapon(dist: float) -> void:
	# 根据距离和弹药量智能选择武器（受难度控制）
	# EASY模式不切换武器
	if not _enable_weapon_switch:
		return

	# 当前武器弹空了 → 尝试切到任何其他有弹药的武器
	if current_ammo <= 0:
		if current_weapon != Weapon.RIFLE and rifle_ammo > 0:
			_switch_weapon(Weapon.RIFLE)
			return
		if current_weapon != Weapon.PISTOL and pistol_ammo > 0:
			_switch_weapon(Weapon.PISTOL)
			return
		if current_weapon != Weapon.SNIPER and sniper_ammo > 0:
			_switch_weapon(Weapon.SNIPER)
			return
		return

	# 远距离 → 狙击枪（一枪一个）
	if dist > shoot_range * 0.7 and sniper_ammo > 0:
		if current_weapon != Weapon.SNIPER:
			_switch_weapon(Weapon.SNIPER)
		return

	# 近距离 → 手枪（伤害高、精准）
	if dist < shoot_range * 0.35 and pistol_ammo > 0:
		if current_weapon != Weapon.PISTOL:
			_switch_weapon(Weapon.PISTOL)
		return

	# 中距离 → 步枪（射速快、压制）
	if current_weapon != Weapon.RIFLE and rifle_ammo > 0:
		_switch_weapon(Weapon.RIFLE)

func _die() -> void:
	died.emit(self, last_damage_source)
	call_deferred("queue_free")


func _throw_grenade() -> void:
	# 投掷手榴弹
	if not is_instance_valid(target_player):
		return

	var dir: Vector2 = (target_player.global_position - global_position).normalized()

	var grenade: Area2D = Area2D.new()
	grenade.name = "Grenade"
	var grenade_script: GDScript = load("res://scripts/Grenade.gd")
	if grenade_script:
		grenade.set_script(grenade_script)
		grenade.global_position = global_position + dir * 20
		grenade.direction = dir
		grenade.speed = 400.0
		grenade.damage = 100
		grenade.blast_radius = 120.0
		grenade.fuse_time = 1.0
		grenade.boom_sfx = boom_sfx
		grenade.thrown_by = self  # Bot手榴弹击杀归属
		get_tree().current_scene.add_child(grenade)
