extends CharacterBody2D

# =============================================================================
# 玩家控制器
# WASD移动、鼠标瞄准射击、换弹、武器切换
# =============================================================================

signal health_changed(new_health, max_health)
signal ammo_changed(current, max_ammo, reserve)
signal weapon_changed(weapon_index)
signal grenade_changed(count: int)
signal died()

@onready var sprite: Polygon2D = $Sprite2D

@onready var weapon_mount: Node2D = $WeaponMount
@onready var weapon_pivot: Node2D = $WeaponMount/WeaponPivot
@onready var muzzle_flash: ColorRect = $WeaponMount/WeaponPivot/MuzzleFlash
@onready var camera: Camera2D = $Camera2D
@onready var hit_timer: Timer = $HitTimer
# HUD 由游戏场景管理，此处引用设为 null 安全模式
var health_bar: ProgressBar = null
var crosshair: Node2D = null

var fps_label: Label = null

# 音效
var shoot_sfx: AudioStream = null   # 手枪音效
var rifle_sfx: AudioStream = null   # 步枪音效
var sniper_sfx: AudioStream = null  # 狙击枪音效
var mg_sfx: AudioStream = null      # 机枪音效
var mg_sfx_player: AudioStreamPlayer = null  # 机枪专属播放器（防止音效叠加）
var mg_reload_sfx: AudioStream = null  # 机枪换弹音效
var reload_sfx: AudioStream = null
var knife_draw_sfx: AudioStream = null  # 拔刀音效
var knife_attack_sfx: AudioStream = null  # 刀攻击音效

# 移动（加速度/减速度，手感更顺滑）
@export var move_speed: float = 200.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 1200.0
var _velocity: Vector2 = Vector2.ZERO
var mouse_sensitivity: float = 1.0

# 生命值
@export var max_health: int = 100
var current_health: int = 100
var dead: bool = false

# 武器
var weapons: Array = []
var current_weapon_index: int = 0
var can_shoot: bool = true
var _cooldown_ready: bool = true  # 射击冷却到期标志（非自动武器需要松开鼠标才能重置）
var reloading: bool = false
var infinite_ammo: bool = false
var has_rifle: bool = true
var has_sniper: bool = true
var has_knife: bool = true
var has_machinegun: bool = true
var pistol_visual: Node2D = null
var rifle_visual: Node2D = null
var sniper_visual: Node2D = null
var knife_visual: Node2D = null
var mg_visual: Node2D = null

# 特长（Perks）系统
var perks: Array = [-1, -1, -1]  # 3个特长槽位：Perk类别0/1/2，-1表示未选
# Perk 定义
# 类别0（移动）: 0=轻装上阵(+15%速度), 1=清道夫(击杀掉弹药包)
# 类别1（防御）: 0=防弹衣(+30血), 1=快速治疗(自动回血), 2=爆炸抗性(-40%爆炸伤)
# 类别2（战斗）: 0=精准射击(-25%散布), 1=弹药充沛(+50%备弹), 2=快速换弹(+30%换弹速)
var _regen_timer: float = 0.0    # 快速治疗回血计时
var _regen_active: bool = false   # 是否在回血中
var _last_damage_time: float = 0.0  # 上次受伤时间

# 自定义皮肤（单机模式可替换为外部图片）
var use_custom_skin: bool = false
var _skin_sprite: Sprite2D = null

# 手榴弹
var grenade_count: int = 1
var grenade_aiming: bool = false
var grenade_aim_line: Line2D = null
var grenade_aim_circle: Line2D = null
var boom_sfx: AudioStream = null

const GRENADE_THROW_SPEED: float = 500.0
const GRENADE_FUSE_TIME: float = 0.8
const GRENADE_DAMAGE: int = 100
const GRENADE_BLAST_RADIUS: float = 120.0

# 武器 UI
var weapon_ui_layer: CanvasLayer = null
var weapon_display_container: Control = null
var weapon_display_icon: Control = null
var weapon_display_name: Label = null
var weapon_display_ammo: Label = null
var weapon_display_reserve: Label = null
var grenade_count_label: Label = null
var grenade_key_label: Label = null
var _weapon_slide_tween: Tween = null


# 准星
var crosshair_style: int = 0
var crosshair_color: Color = Color(0, 1, 0, 1)

# FPS显示
var fps_timer: float = 0.0
var show_fps: bool = true

# 控制台作弊
var god_mode: bool = false
var console_open: bool = false

# 屏幕震动
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0

# 刀挥砍动画
var _knife_attack_tween: Tween = null

# 连杀数（由游戏模式维护，Player 只提供接口）

func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	# 初始化武器
	_init_weapons()
	
	# 加载设置
	mouse_sensitivity = GameSettings.get_value("controls", "mouse_sensitivity", 1.0)
	crosshair_style = GameSettings.get_value("game", "crosshair_style", 0)
	crosshair_color = GameSettings.get_value("game", "crosshair_color", Color(0, 1, 0, 1))
	show_fps = GameSettings.get_value("game", "show_fps", true)
	if fps_label:
		fps_label.visible = show_fps
	
	# 瞄准遮罩
	if crosshair:
		_update_crosshair()
	
	# 生成圆形玩家外观
	if sprite is Polygon2D:
		var points: Array = []
		var radius: float = 16.0
		var segments: int = 24
		for i in range(segments):
			var angle: float = i * TAU / segments
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
		sprite.polygon = PackedVector2Array(points)
		sprite.color = Color(0.2, 0.4, 0.9, 1)

	# 加眼睛
	_create_eyes()

	
	muzzle_flash.visible = false
	hit_timer.timeout.connect(_on_hit_timer_timeout)
	
	# 屏幕震动
	_shake_timer = 0.0
	if camera:
		camera.offset = Vector2.ZERO

	# 加入玩家组，供AI查找
	add_to_group("player")

	# 加载音效
	shoot_sfx = load("res://assets/sheji.mp3")      # 手枪射击音效
	rifle_sfx = load("res://assets/buqiangsheji.mp3") # 步枪射击音效
	sniper_sfx = load("res://assets/jujiqiangsheji.mp3") # 狙击枪射击音效
	mg_sfx = load("res://assets/jiqiang.mp3")           # 机枪射击音效
	mg_reload_sfx = load("res://assets/jiqianghuandan.mp3") # 机枪换弹音效
	reload_sfx = load("res://assets/huandan.mp3")
	boom_sfx = load("res://assets/boom.mp3")
	knife_draw_sfx = load("res://assets/csgonadao.mp3")  # 拔刀音效
	knife_attack_sfx = load("res://assets/dao.mp3")       # 刀攻击音效

	# 机枪专属播放器（防止音效叠加炸扬声器）
	mg_sfx_player = AudioStreamPlayer.new()
	mg_sfx_player.bus = "SFX"
	add_child(mg_sfx_player)

	# 创建视觉上的枪
	_create_weapon_visual()

	# 创建手榴弹瞄准线
	_create_grenade_aim()

	# 创建武器 UI
	_create_weapon_ui()

	# 单机模式自定义皮肤
	if use_custom_skin:
		_apply_custom_skin()



func _init_weapons() -> void:
	# 手枪
	var pistol: Dictionary = {
		"name": "w_pistol",
		"damage": 20,
		"fire_rate": 0.3,
		"max_ammo": 12,
		"current_ammo": 12,
		"reserve_ammo": 60,
		"reload_time": 1.5,
		"auto": false,
		"spread": 0.0,
		"bullet_speed": 800.0
	}
	# 步枪
	var rifle: Dictionary = {
		"name": "w_rifle",
		"damage": 15,
		"fire_rate": 0.1,
		"max_ammo": 30,
		"current_ammo": 30,
		"reserve_ammo": 120,
		"reload_time": 2.0,
		"auto": true,
		"spread": 0.05,
		"bullet_speed": 1000.0
	}
	# 狙击枪（一枪一个，射速极慢，绝对精准）
	var sniper: Dictionary = {
		"name": "w_sniper",
		"damage": 100,
		"fire_rate": 2.0,
		"max_ammo": 5,
		"current_ammo": 5,
		"reserve_ammo": 20,
		"reload_time": 3.0,
		"auto": false,
		"spread": 0.0,
		"bullet_speed": 2000.0
	}
	# 刀（近战，无需弹药）
	var knife: Dictionary = {
		"name": "w_knife",
		"damage": 50,
		"fire_rate": 0.5,
		"melee_range": 55.0,
		"max_ammo": 0,
		"current_ammo": 0,
		"reserve_ammo": 0,
		"reload_time": 0.0,
		"auto": false,
		"spread": 0.0,
		"bullet_speed": 0.0
	}
	# 机枪（高弹匣、低伤害、全自动、慢换弹）
	var machinegun: Dictionary = {
		"name": "w_machinegun",
		"damage": 8,
		"fire_rate": 0.08,
		"max_ammo": 100,
		"current_ammo": 100,
		"reserve_ammo": 300,
		"reload_time": 4.0,
		"auto": true,
		"spread": 0.08,
		"bullet_speed": 900.0
	}
	weapons = [pistol, rifle, sniper, knife, machinegun]
	_apply_perk_effects()
	_update_ammo_display()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_aim()
	_handle_shooting()
	_handle_weapon_switch()
	_handle_reload()
	_handle_grenade()

	# 屏幕震动
	if _shake_timer > 0.0:
		_shake_timer -= delta
		if camera:
			var t: float = _shake_timer / maxf(_shake_duration, 0.001)
			var off: float = _shake_intensity * t
			camera.offset = Vector2(randf_range(-off, off), randf_range(-off, off))
	else:
		if camera and camera.offset.length() > 0.5:
			camera.offset = camera.offset.move_toward(Vector2.ZERO, 200.0 * delta)

	# FPS计数
	if show_fps and fps_label:
		fps_timer += delta
		if fps_timer >= 0.2:
			fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
			fps_timer = 0.0

	# Perk: 快速治疗 — 受伤3秒后自动回血（1HP/秒，上限50%）
	if perks[1] == 1 and not dead and current_health > 0:
		if _regen_active:
			_regen_timer += delta
			if _regen_timer >= 1.0:
				_regen_timer = 0.0
				var regen_cap: int = int(max_health * 0.5)
				if current_health < regen_cap:
					current_health = min(current_health + 1, regen_cap)
					health_changed.emit(current_health, max_health)
					if health_bar:
						health_bar.value = current_health
		else:
			# 检查是否距上次受伤超过3秒
			if _last_damage_time > 0.0 and (Time.get_ticks_msec() / 1000.0 - _last_damage_time) >= 3.0:
				_regen_active = true
				_regen_timer = 0.0

func _handle_movement(delta: float) -> void:
	var input_vec: Vector2 = Vector2.ZERO
	input_vec.x = Input.get_axis("move_left", "move_right")
	input_vec.y = Input.get_axis("move_up", "move_down")
	input_vec = input_vec.normalized() if input_vec.length() > 0.0 else Vector2.ZERO

	var effective_speed: float = move_speed
	# Perk 0: 轻装上阵 +15%速度
	if perks[0] == 0:
		effective_speed *= 1.15

	if input_vec.length() > 0.001:
		# 有输入：朝目标速度加速
		var target_vel: Vector2 = input_vec * effective_speed
		_velocity = _velocity.move_toward(target_vel, acceleration * delta)
	else:
		# 无输入：减速至停止
		_velocity = _velocity.move_toward(Vector2.ZERO, deceleration * delta)

	velocity = _velocity
	move_and_slide()

func _handle_aim() -> void:
	# 玩家朝向鼠标方向（ColorRect 不支持 flip_h，用武器朝向表示方向）
	var mouse_pos: Vector2 = get_global_mouse_position()
	
	# 武器朝向
	if weapon_pivot:
		weapon_pivot.look_at(mouse_pos)
		var angle: float = wrapf(weapon_pivot.rotation, -PI, PI)
		weapon_pivot.rotation = angle

func _handle_shooting() -> void:
	if console_open:
		return
	if reloading:
		return

	var weapon: Dictionary = weapons[current_weapon_index]

	# 刀是近战武器，没有弹药概念
	if current_weapon_index == 3:
		if Input.is_action_just_pressed("shoot") and can_shoot:
			_shoot()
			if _cooldown_ready and not Input.is_action_pressed("shoot"):
				can_shoot = true
				_cooldown_ready = false
		return

	# 机枪和其他射击武器使用相同逻辑（机枪是全自动）

	# 自动换弹：弹药为0时自动换弹（不需要手动按R）
	if weapon.current_ammo <= 0 and not infinite_ammo:
		if weapon.reserve_ammo > 0:
			_start_reload()
		return

	if Input.is_action_pressed("shoot") and can_shoot and weapon.current_ammo > 0:
		_shoot()

	# 半自动武器（手枪/狙击枪）：冷却到期 + 松开鼠标后才能再次射击
	# 自动武器（步枪）：冷却到期即可再次射击
	if weapon.auto:
		# 自动武器：冷却到期就可以再打了（timer 直接设 can_shoot=true）
		pass
	else:
		if _cooldown_ready and not Input.is_action_pressed("shoot"):
			can_shoot = true
			_cooldown_ready = false

func _shoot() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	can_shoot = false

	# 刀是近战攻击
	if current_weapon_index == 3:
		_play_sfx(knife_attack_sfx)
		_knife_attack()
		_cooldown_ready = false
		get_tree().create_timer(weapon.fire_rate).timeout.connect(func(): _cooldown_ready = true)
		return

	if not infinite_ammo:
		weapon.current_ammo -= 1

	# 播放射击音效（手枪/步枪/狙击枪用_play_sfx，机枪用专属播放器防止叠加）
	match current_weapon_index:
		0: _play_sfx(shoot_sfx)
		1: _play_sfx(rifle_sfx)
		2: _play_sfx(sniper_sfx)
		4:
			if mg_sfx_player and mg_sfx:
				mg_sfx_player.stop()
				mg_sfx_player.stream = mg_sfx
				mg_sfx_player.play()
		_: _play_sfx(shoot_sfx)

	# 枪口火焰
	muzzle_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func(): muzzle_flash.visible = false)

	# 生成子弹
	_spawn_bullet()

	# 射击冷却
	if weapon.auto:
		# 自动武器：冷却到期直接恢复可射击状态
		get_tree().create_timer(weapon.fire_rate).timeout.connect(func(): can_shoot = true)
	else:
		# 半自动武器：冷却到期只标记就绪，必须松开鼠标才能再打
		_cooldown_ready = false
		get_tree().create_timer(weapon.fire_rate).timeout.connect(func(): _cooldown_ready = true)

	_update_ammo_display()
	_update_weapon_ui()

	# 自动换弹：子弹打完后自动开始换弹
	if weapon.current_ammo <= 0 and not reloading and not infinite_ammo:
		_start_reload()


func _play_sfx(stream: AudioStream) -> void:
	# 用临时 AudioStreamPlayer 播短时间音效，不阻塞
	if stream:
		var sfx: AudioStreamPlayer = AudioStreamPlayer.new()
		sfx.stream = stream
		sfx.volume_db = -3.0
		sfx.bus = "SFX"
		add_child(sfx)
		sfx.play()
		# 播完自动销毁
		sfx.finished.connect(func(): sfx.queue_free())

func _knife_attack() -> void:
	# 近战攻击：检测前方弧形范围内所有敌人
	var weapon: Dictionary = weapons[3]
	var melee_range: float = weapon.melee_range
	var attack_origin: Vector2 = weapon_pivot.global_position if weapon_pivot else global_position
	var attack_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	var hit_count: int = 0

	# 触发挥刀动画 + 刀光
	_play_knife_swing()
	_spawn_knife_trail(melee_range)

	# 攻击敌人
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage"):
			continue
		var dist: float = attack_origin.distance_to(enemy.global_position)
		if dist > melee_range:
			continue
		# 检查是否在前方120度弧形内
		var to_enemy: Vector2 = (enemy.global_position - attack_origin).normalized()
		var dot: float = attack_dir.dot(to_enemy)
		if dot < 0.5:  # cos(60°) ≈ 0.5，120度弧形
			continue
		enemy.take_damage(weapon.damage, self)
		hit_count += 1

	# 攻击其他玩家（PvP 模式用）
	for p in get_tree().get_nodes_in_group("player"):
		if p == self or not is_instance_valid(p):
			continue
		if not p.has_method("take_damage"):
			continue
		if p.get("dead") == true:
			continue
		var dist: float = attack_origin.distance_to(p.global_position)
		if dist > melee_range:
			continue
		var to_enemy: Vector2 = (p.global_position - attack_origin).normalized()
		var dot: float = attack_dir.dot(to_enemy)
		if dot < 0.5:
			continue
		p.take_damage(weapon.damage)
		hit_count += 1

	# 击中反馈：短暂屏幕震动
	if hit_count > 0:
		screen_shake(2.0, 0.08)


func _play_knife_swing() -> void:
	if not knife_visual:
		return
	if _knife_attack_tween and _knife_attack_tween.is_valid():
		_knife_attack_tween.kill()
	# 重置到初始角度
	knife_visual.rotation = 0.0
	_knife_attack_tween = create_tween()
	# 蓄力向后拉 → 快速向前挥 → 回正
	_knife_attack_tween.tween_property(knife_visual, "rotation", -deg_to_rad(50), 0.04)
	_knife_attack_tween.tween_property(knife_visual, "rotation", deg_to_rad(60), 0.07)
	_knife_attack_tween.tween_property(knife_visual, "rotation", 0.0, 0.06)


func _spawn_knife_trail(range_val: float) -> void:
	if not weapon_pivot:
		return
	var trail: Polygon2D = Polygon2D.new()
	trail.name = "KnifeTrail"
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(Vector2.ZERO)
	var segments: int = 12
	var half_angle: float = PI / 3.0  # 60°，120°总弧
	for i in range(segments + 1):
		var angle: float = -half_angle + (2.0 * half_angle) * i / segments
		pts.append(Vector2(cos(angle) * range_val, sin(angle) * range_val))
	trail.polygon = pts
	trail.color = Color(0.85, 0.92, 1.0, 0.45)
	trail.z_index = -1
	weapon_pivot.add_child(trail)
	var tween: Tween = create_tween()
	# 颜色变淡同时透明度降低
	tween.parallel().tween_property(trail, "modulate", Color(0.85, 0.92, 1.0, 0.0), 0.18)
	tween.tween_callback(trail.queue_free)

func _spawn_bullet() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	var bullet: Area2D = null
	
	# 如果子弹场景存在就实例化，否则用代码创建
	if ResourceLoader.exists("res://scenes/game/Bullet.tscn"):
		bullet = load("res://scenes/game/Bullet.tscn").instantiate()
	else:
		bullet = _create_bullet()
	
	if bullet:
		bullet.global_position = weapon_pivot.global_position
		var aim_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
		# 散布
		var spread: float = weapon.spread
		if spread > 0:
			aim_dir = aim_dir.rotated(randf_range(-spread, spread))
		bullet.direction = aim_dir
		bullet.speed = weapon.bullet_speed
		bullet.damage = weapon.damage
		bullet.shooter = self  # 击杀归属：子弹发射者
		bullet.shooter_is_player = true
		get_tree().current_scene.add_child(bullet)

func _create_bullet() -> Area2D:
	# 代码创建子弹（当场景文件不存在时）
	var bullet: Area2D = Area2D.new()
	bullet.name = "Bullet"
	
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(8, 3)
	col.shape = shape
	bullet.add_child(col)
	
	var vis: ColorRect = ColorRect.new()
	vis.color = Color.YELLOW
	vis.size = Vector2(8, 3)
	bullet.add_child(vis)
	
	# 子弹脚本（内嵌）
	bullet.set_script(load("res://scripts/Bullet.gd") if ResourceLoader.exists("res://scripts/Bullet.gd") else null)
	
	return bullet

func _handle_weapon_switch() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		_switch_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"):
		if has_rifle:
			_switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_3"):
		if has_sniper:
			_switch_weapon(2)
	elif Input.is_action_just_pressed("weapon_4"):
		if has_knife:
			_switch_weapon(3)
	elif Input.is_action_just_pressed("weapon_5"):
		if has_machinegun:
			_switch_weapon(4)

func _switch_weapon(index: int) -> void:
	if index == current_weapon_index:
		return
	current_weapon_index = index
	reloading = false
	can_shoot = true
	weapon_changed.emit(current_weapon_index)
	_update_ammo_display()
	_update_weapon_ui()
	_update_weapon_visual()
	# 切换到刀时播放拔刀音效
	if index == 3:
		_play_sfx(knife_draw_sfx)
	# CSGO风格：切换武器时从右侧滑入动画
	_play_weapon_switch_animation()


func _play_weapon_switch_animation() -> void:
	if not weapon_display_container:
		return
	# 停止之前的动画
	if _weapon_slide_tween and _weapon_slide_tween.is_valid():
		_weapon_slide_tween.kill()
	# 从右侧滑入（先移到屏幕外，再滑回原位）
	var target_x: float = weapon_display_container.offset_left
	weapon_display_container.offset_left = target_x + 80
	_weapon_slide_tween = weapon_display_container.create_tween()
	_weapon_slide_tween.set_ease(Tween.EASE_OUT)
	_weapon_slide_tween.set_trans(Tween.TRANS_QUAD)
	_weapon_slide_tween.tween_property(weapon_display_container, "offset_left", target_x, 0.2)

func _handle_reload() -> void:
	if Input.is_action_just_pressed("reload") and not reloading:
		# 刀没有换弹
		if current_weapon_index == 3:
			return
		_start_reload()

func _start_reload() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	if weapon.current_ammo >= weapon.max_ammo or weapon.reserve_ammo <= 0:
		return

	reloading = true
	can_shoot = false

	# 机枪用专属换弹音效，其他武器用通用换弹音效
	if current_weapon_index == 4 and mg_reload_sfx:
		_play_sfx(mg_reload_sfx)
	else:
		_play_sfx(reload_sfx)

	get_tree().create_timer(weapon.reload_time).timeout.connect(func():
		_reload_done()
	)

func _reload_done() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	var needed: int = weapon.max_ammo - weapon.current_ammo
	var available: int = min(needed, weapon.reserve_ammo)
	weapon.current_ammo += available
	weapon.reserve_ammo -= available
	reloading = false
	can_shoot = true
	_update_ammo_display()
	_update_weapon_ui()

func take_damage(amount: int, is_explosion: bool = false) -> void:
	if dead:
		return
	if god_mode:
		return
	# Perk 1 爆炸抗性：爆炸伤害 -40%
	if is_explosion and perks[1] == 2:
		amount = int(amount * 0.6)
	current_health -= amount
	current_health = max(0, current_health)
	health_changed.emit(current_health, max_health)
	if health_bar:
		health_bar.value = current_health
	
	# 受击闪红
	modulate = Color.RED
	hit_timer.start(0.1)
	
	# 记录受伤时间（用于快速治疗Perk）
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	_regen_active = false
	_regen_timer = 0.0
	
	if current_health <= 0:
		_die()

func screen_shake(intensity: float = 3.0, duration: float = 0.15) -> void:
	"""触发屏幕震动（由游戏模式在击杀时调用）"""
	if not camera:
		return
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration


func _on_hit_timer_timeout() -> void:
	modulate = Color.WHITE

func _die() -> void:
	if dead:
		return
	dead = true
	set_physics_process(false)
	set_process_input(false)
	died.emit()


func _update_ammo_display() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	ammo_changed.emit(weapon.current_ammo, weapon.max_ammo, weapon.reserve_ammo)

func _create_eyes() -> void:
	# 玩家眼睛：两个小白色方块
	var eye_left: ColorRect = ColorRect.new()
	eye_left.name = "EyeLeft"
	eye_left.size = Vector2(4, 4)
	eye_left.position = Vector2(-6, -8)
	eye_left.color = Color(1, 1, 1, 1)
	add_child(eye_left)

	var eye_right: ColorRect = ColorRect.new()
	eye_right.name = "EyeRight"
	eye_right.size = Vector2(4, 4)
	eye_right.position = Vector2(2, -8)
	eye_right.color = Color(1, 1, 1, 1)
	add_child(eye_right)

	# 瞳孔
	var pupil_left: ColorRect = ColorRect.new()
	pupil_left.name = "PupilLeft"
	pupil_left.size = Vector2(2, 2)
	pupil_left.position = Vector2(-5, -7)
	pupil_left.color = Color(0, 0, 0, 1)
	add_child(pupil_left)

	var pupil_right: ColorRect = ColorRect.new()
	pupil_right.name = "PupilRight"
	pupil_right.size = Vector2(2, 2)
	pupil_right.position = Vector2(3, -7)
	pupil_right.color = Color(0, 0, 0, 1)
	add_child(pupil_right)


func _apply_custom_skin() -> void:
	# 单机模式：用外部图片替换默认圆形+眼睛外观
	if not sprite:
		return
	# 隐藏默认多边形身体
	sprite.visible = false
	# 删除眼睛节点
	var eye_names: Array = ["EyeLeft", "EyeRight", "PupilLeft", "PupilRight"]
	for eye_name in eye_names:
		var n = get_node_or_null(eye_name)
		if n:
			n.queue_free()
	# 创建图片精灵
	_skin_sprite = Sprite2D.new()
	_skin_sprite.name = "SkinSprite"
	var tex: Texture2D = load("res://assets/wanjia.png")
	if tex:
		_skin_sprite.texture = tex
		# 计算缩放：原角色直径约 32px，按图片高度等比缩放
		var img_size: Vector2 = tex.get_size()
		if img_size.y > 0:
			var target_height: float = 36.0
			var s: float = target_height / img_size.y
			_skin_sprite.scale = Vector2(s, s)
		# 应用剔除黑色背景的 shader
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = load("res://assets/wanjia_black_transparent.gdshader")
		_skin_sprite.material = mat
	add_child(_skin_sprite)


func _update_crosshair() -> void:
	if not crosshair:
		return
	# 从设置读取最新值（设置界面可能已更改）
	crosshair_style = GameSettings.get_value("game", "crosshair_style", 0)
	crosshair_color = GameSettings.get_value("game", "crosshair_color", Color(0, 1, 0, 1))
	# 调用 Crosshair.gd 的统一绘制接口（支持十字/圆点/圆环）
	if crosshair.has_method("update_crosshair"):
		crosshair.update_crosshair(crosshair_style, crosshair_color)


func _create_weapon_visual() -> void:
	# 在 WeaponPivot 下分别创建手枪和步枪的视觉模型
	if not weapon_pivot:
		return

	# --- 手枪模型（武器0） ---
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
	p_barrel.position = Vector2(20, -2.0)
	p_barrel.color = Color(0.12, 0.12, 0.12, 1.0)
	pistol_holder.add_child(p_barrel)

	# 握把
	var p_grip: ColorRect = ColorRect.new()
	p_grip.name = "Grip"
	p_grip.size = Vector2(7, 12)
	p_grip.position = Vector2(5, 3.5)
	p_grip.color = Color(0.3, 0.25, 0.2, 1.0)
	pistol_holder.add_child(p_grip)

	# 扳机护圈
	var p_trigger: ColorRect = ColorRect.new()
	p_trigger.name = "TriggerGuard"
	p_trigger.size = Vector2(6, 5)
	p_trigger.position = Vector2(11, 3.5)
	p_trigger.color = Color(0.18, 0.18, 0.18, 1.0)
	pistol_holder.add_child(p_trigger)

	# 右手（握把上）
	var p_right_hand: ColorRect = ColorRect.new()
	p_right_hand.name = "RightHand"
	p_right_hand.size = Vector2(8, 7)
	p_right_hand.position = Vector2(4, 9)
	p_right_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	pistol_holder.add_child(p_right_hand)

	# 左手（枪管下方）
	var p_left_hand: ColorRect = ColorRect.new()
	p_left_hand.name = "LeftHand"
	p_left_hand.size = Vector2(7, 6)
	p_left_hand.position = Vector2(17, 2)
	p_left_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	pistol_holder.add_child(p_left_hand)

	pistol_visual = pistol_holder

	# --- 步枪模型（武器1） ---
	var rifle_holder: Node2D = Node2D.new()
	rifle_holder.name = "RifleVisual"
	weapon_pivot.add_child(rifle_holder)

	# 机匣（枪身主体）
	var r_body: ColorRect = ColorRect.new()
	r_body.name = "Receiver"
	r_body.size = Vector2(30, 9)
	r_body.position = Vector2(0, -4.5)
	r_body.color = Color(0.2, 0.2, 0.22, 1.0)
	rifle_holder.add_child(r_body)

	# 枪管（更长更细）
	var r_barrel: ColorRect = ColorRect.new()
	r_barrel.name = "Barrel"
	r_barrel.size = Vector2(16, 4)
	r_barrel.position = Vector2(30, -2.0)
	r_barrel.color = Color(0.1, 0.1, 0.1, 1.0)
	rifle_holder.add_child(r_barrel)

	# 枪托
	var r_stock: ColorRect = ColorRect.new()
	r_stock.name = "Stock"
	r_stock.size = Vector2(10, 7)
	r_stock.position = Vector2(-10, -3.5)
	r_stock.color = Color(0.35, 0.28, 0.18, 1.0)
	rifle_holder.add_child(r_stock)

	# 弹匣（弯曲形状用两段模拟）
	var r_mag: ColorRect = ColorRect.new()
	r_mag.name = "Magazine"
	r_mag.size = Vector2(7, 13)
	r_mag.position = Vector2(10, 4.5)
	r_mag.color = Color(0.15, 0.15, 0.15, 1.0)
	rifle_holder.add_child(r_mag)

	# 握把
	var r_grip: ColorRect = ColorRect.new()
	r_grip.name = "Grip"
	r_grip.size = Vector2(6, 10)
	r_grip.position = Vector2(3, 4.5)
	r_grip.color = Color(0.25, 0.22, 0.2, 1.0)
	rifle_holder.add_child(r_grip)

	# 护木
	var r_handguard: ColorRect = ColorRect.new()
	r_handguard.name = "Handguard"
	r_handguard.size = Vector2(14, 6)
	r_handguard.position = Vector2(18, -3.0)
	r_handguard.color = Color(0.18, 0.18, 0.18, 1.0)
	rifle_holder.add_child(r_handguard)

	# 右手（握把上）
	var r_right_hand: ColorRect = ColorRect.new()
	r_right_hand.name = "RightHand"
	r_right_hand.size = Vector2(8, 7)
	r_right_hand.position = Vector2(2, 9)
	r_right_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	rifle_holder.add_child(r_right_hand)

	# 左手（护木下方）
	var r_left_hand: ColorRect = ColorRect.new()
	r_left_hand.name = "LeftHand"
	r_left_hand.size = Vector2(8, 6)
	r_left_hand.position = Vector2(20, 2)
	r_left_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	rifle_holder.add_child(r_left_hand)

	rifle_visual = rifle_holder

	# --- 狙击枪模型（武器2） ---
	var sniper_holder: Node2D = Node2D.new()
	sniper_holder.name = "SniperVisual"
	weapon_pivot.add_child(sniper_holder)

	# 机匣（较长枪身）
	var s_body: ColorRect = ColorRect.new()
	s_body.name = "Receiver"
	s_body.size = Vector2(34, 8)
	s_body.position = Vector2(-2, -4)
	s_body.color = Color(0.18, 0.18, 0.20, 1.0)
	sniper_holder.add_child(s_body)

	# 长枪管
	var s_barrel: ColorRect = ColorRect.new()
	s_barrel.name = "Barrel"
	s_barrel.size = Vector2(18, 4)
	s_barrel.position = Vector2(32, -2)
	s_barrel.color = Color(0.08, 0.08, 0.08, 1.0)
	sniper_holder.add_child(s_barrel)

	# 瞄准镜
	var s_scope: ColorRect = ColorRect.new()
	s_scope.name = "Scope"
	s_scope.size = Vector2(14, 5)
	s_scope.position = Vector2(8, -9)
	s_scope.color = Color(0.35, 0.38, 0.42, 1.0)
	sniper_holder.add_child(s_scope)

	# 枪托
	var s_stock: ColorRect = ColorRect.new()
	s_stock.name = "Stock"
	s_stock.size = Vector2(10, 7)
	s_stock.position = Vector2(-12, -3.5)
	s_stock.color = Color(0.3, 0.24, 0.16, 1.0)
	sniper_holder.add_child(s_stock)

	# 弹匣
	var s_mag: ColorRect = ColorRect.new()
	s_mag.name = "Magazine"
	s_mag.size = Vector2(5, 8)
	s_mag.position = Vector2(10, 4)
	s_mag.color = Color(0.12, 0.12, 0.12, 1.0)
	sniper_holder.add_child(s_mag)

	# 握把
	var s_grip: ColorRect = ColorRect.new()
	s_grip.name = "Grip"
	s_grip.size = Vector2(6, 9)
	s_grip.position = Vector2(3, 4)
	s_grip.color = Color(0.25, 0.22, 0.2, 1.0)
	sniper_holder.add_child(s_grip)

	# 右手（握把上）
	var s_right_hand: ColorRect = ColorRect.new()
	s_right_hand.name = "RightHand"
	s_right_hand.size = Vector2(8, 7)
	s_right_hand.position = Vector2(2, 9)
	s_right_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	sniper_holder.add_child(s_right_hand)

	# 左手（枪管下方）
	var s_left_hand: ColorRect = ColorRect.new()
	s_left_hand.name = "LeftHand"
	s_left_hand.size = Vector2(8, 6)
	s_left_hand.position = Vector2(26, 2)
	s_left_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	sniper_holder.add_child(s_left_hand)

	sniper_visual = sniper_holder

	# --- 刀模型（武器3） ---
	var knife_holder: Node2D = Node2D.new()
	knife_holder.name = "KnifeVisual"
	weapon_pivot.add_child(knife_holder)

	# 刀柄
	var k_handle: ColorRect = ColorRect.new()
	k_handle.name = "Handle"
	k_handle.size = Vector2(5, 14)
	k_handle.position = Vector2(2, 4)
	k_handle.color = Color(0.35, 0.28, 0.18, 1.0)
	knife_holder.add_child(k_handle)

	# 护手
	var k_guard: ColorRect = ColorRect.new()
	k_guard.name = "Guard"
	k_guard.size = Vector2(14, 3)
	k_guard.position = Vector2(-2, 2)
	k_guard.color = Color(0.5, 0.45, 0.35, 1.0)
	knife_holder.add_child(k_guard)

	# 刀身
	var k_blade: ColorRect = ColorRect.new()
	k_blade.name = "Blade"
	k_blade.size = Vector2(5, 18)
	k_blade.position = Vector2(2, -16)
	k_blade.color = Color(0.7, 0.72, 0.78, 1.0)
	knife_holder.add_child(k_blade)

	# 刀尖（三角形）
	var k_tip: Polygon2D = Polygon2D.new()
	k_tip.name = "Tip"
	var tip_pts: PackedVector2Array = PackedVector2Array([
		Vector2(2, -16),
		Vector2(7, -16),
		Vector2(4.5, -24)
	])
	k_tip.polygon = tip_pts
	k_tip.color = Color(0.7, 0.72, 0.78, 1.0)
	knife_holder.add_child(k_tip)

	# 刀刃高光线
	var k_edge: ColorRect = ColorRect.new()
	k_edge.name = "Edge"
	k_edge.size = Vector2(1, 16)
	k_edge.position = Vector2(2.5, -15)
	k_edge.color = Color(0.9, 0.92, 0.95, 1.0)
	knife_holder.add_child(k_edge)

	# 右手（握柄上）
	var k_hand: ColorRect = ColorRect.new()
	k_hand.name = "RightHand"
	k_hand.size = Vector2(9, 8)
	k_hand.position = Vector2(0, 10)
	k_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	knife_holder.add_child(k_hand)

	knife_visual = knife_holder

	# --- 机枪模型（武器4） ---
	var mg_holder: Node2D = Node2D.new()
	mg_holder.name = "MGVisual"
	weapon_pivot.add_child(mg_holder)

	# 机匣（长枪身主体）
	var m_body: ColorRect = ColorRect.new()
	m_body.name = "Receiver"
	m_body.size = Vector2(36, 10)
	m_body.position = Vector2(-2, -5)
	m_body.color = Color(0.18, 0.18, 0.20, 1.0)
	mg_holder.add_child(m_body)

	# 长枪管（粗重）
	var m_barrel: ColorRect = ColorRect.new()
	m_barrel.name = "Barrel"
	m_barrel.size = Vector2(20, 5)
	m_barrel.position = Vector2(34, -2.5)
	m_barrel.color = Color(0.08, 0.08, 0.08, 1.0)
	mg_holder.add_child(m_barrel)

	# 枪管护罩/散热孔
	var m_shroud: ColorRect = ColorRect.new()
	m_shroud.name = "Shroud"
	m_shroud.size = Vector2(16, 7)
	m_shroud.position = Vector2(20, -3.5)
	m_shroud.color = Color(0.15, 0.15, 0.16, 1.0)
	mg_holder.add_child(m_shroud)

	# 大弹匣（弹链盒风格）
	var m_mag: ColorRect = ColorRect.new()
	m_mag.name = "MagazineBox"
	m_mag.size = Vector2(10, 16)
	m_mag.position = Vector2(8, 5)
	m_mag.color = Color(0.12, 0.12, 0.12, 1.0)
	mg_holder.add_child(m_mag)

	# 弹链（从弹匣伸出的小方块）
	var m_chain1: ColorRect = ColorRect.new()
	m_chain1.name = "Chain1"
	m_chain1.size = Vector2(4, 3)
	m_chain1.position = Vector2(12, 5)
	m_chain1.color = Color(0.5, 0.45, 0.3, 1.0)
	mg_holder.add_child(m_chain1)

	var m_chain2: ColorRect = ColorRect.new()
	m_chain2.name = "Chain2"
	m_chain2.size = Vector2(3, 3)
	m_chain2.position = Vector2(16, 3)
	m_chain2.color = Color(0.5, 0.45, 0.3, 1.0)
	mg_holder.add_child(m_chain2)

	# 枪托（宽厚）
	var m_stock: ColorRect = ColorRect.new()
	m_stock.name = "Stock"
	m_stock.size = Vector2(12, 8)
	m_stock.position = Vector2(-14, -4)
	m_stock.color = Color(0.3, 0.24, 0.16, 1.0)
	mg_holder.add_child(m_stock)

	# 握把
	var m_grip: ColorRect = ColorRect.new()
	m_grip.name = "Grip"
	m_grip.size = Vector2(7, 12)
	m_grip.position = Vector2(2, 5)
	m_grip.color = Color(0.25, 0.22, 0.20, 1.0)
	mg_holder.add_child(m_grip)

	# 右手（握把上）
	var m_right_hand: ColorRect = ColorRect.new()
	m_right_hand.name = "RightHand"
	m_right_hand.size = Vector2(8, 7)
	m_right_hand.position = Vector2(1, 10)
	m_right_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	mg_holder.add_child(m_right_hand)

	# 左手（护罩下方支撑）
	var m_left_hand: ColorRect = ColorRect.new()
	m_left_hand.name = "LeftHand"
	m_left_hand.size = Vector2(9, 6)
	m_left_hand.position = Vector2(24, 2)
	m_left_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	mg_holder.add_child(m_left_hand)

	mg_visual = mg_holder

	# 默认显示手枪
	_update_weapon_visual()


func _update_weapon_visual() -> void:
	if pistol_visual:
		pistol_visual.visible = (current_weapon_index == 0)
	if rifle_visual:
		rifle_visual.visible = (current_weapon_index == 1 and has_rifle)
	if sniper_visual:
		sniper_visual.visible = (current_weapon_index == 2 and has_sniper)
	if knife_visual:
		knife_visual.visible = (current_weapon_index == 3 and has_knife)
	if mg_visual:
		mg_visual.visible = (current_weapon_index == 4 and has_machinegun)


func unlock_rifle() -> void:
	has_rifle = true
	_update_weapon_ui()
	_update_weapon_visual()


func unlock_sniper() -> void:
	has_sniper = true
	_update_weapon_ui()
	_update_weapon_visual()


func unlock_machinegun() -> void:
	has_machinegun = true
	_update_weapon_ui()
	_update_weapon_visual()


# =============================================================================
# 手榴弹系统
# =============================================================================

func _create_grenade_aim() -> void:
	# 瞄准线（虚线效果）
	grenade_aim_line = Line2D.new()
	grenade_aim_line.name = "GrenadeAimLine"
	grenade_aim_line.top_level = true
	grenade_aim_line.width = 2.0
	grenade_aim_line.default_color = Color(1, 0.5, 0, 0.7)
	grenade_aim_line.visible = false
	add_child(grenade_aim_line)

	# 爆炸范围预览圆
	grenade_aim_circle = Line2D.new()
	grenade_aim_circle.name = "GrenadeAimCircle"
	grenade_aim_circle.top_level = true
	grenade_aim_circle.width = 2.0
	grenade_aim_circle.default_color = Color(1, 0.3, 0, 0.5)
	grenade_aim_circle.visible = false
	add_child(grenade_aim_circle)


func _handle_grenade() -> void:
	if console_open:
		if grenade_aiming and grenade_aim_line:
			grenade_aiming = false
			grenade_aim_line.visible = false
		if grenade_aim_circle:
			grenade_aim_circle.visible = false
		return
	if dead:
		grenade_aiming = false
		if grenade_aim_line:
			grenade_aim_line.visible = false
		if grenade_aim_circle:
			grenade_aim_circle.visible = false
		return

	if Input.is_action_just_pressed("grenade") and grenade_count > 0:
		grenade_aiming = true
		if grenade_aim_line:
			grenade_aim_line.visible = true
		if grenade_aim_circle:
			grenade_aim_circle.visible = true

	if grenade_aiming:
		_update_grenade_aim()

	if Input.is_action_just_released("grenade") and grenade_aiming:
		grenade_aiming = false
		if grenade_aim_line:
			grenade_aim_line.visible = false
		if grenade_aim_circle:
			grenade_aim_circle.visible = false
		_throw_grenade()


func _update_grenade_aim() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var dir: Vector2 = (mouse_pos - global_position).normalized()
	var landing: Vector2 = global_position + dir * GRENADE_THROW_SPEED * GRENADE_FUSE_TIME

	# 瞄准线
	if grenade_aim_line:
		var pts: Array = []
		var steps: int = 12
		for i in range(steps + 1):
			var t: float = float(i) / steps
			pts.append(global_position.lerp(landing, t))
		grenade_aim_line.points = PackedVector2Array(pts)
		grenade_aim_line.global_position = Vector2.ZERO

	# 爆炸范围圆
	if grenade_aim_circle:
		var cpt: Array = []
		var segs: int = 32
		for i in range(segs + 1):
			var angle: float = i * TAU / segs
			cpt.append(landing + Vector2(cos(angle) * GRENADE_BLAST_RADIUS, sin(angle) * GRENADE_BLAST_RADIUS))
		grenade_aim_circle.points = PackedVector2Array(cpt)
		grenade_aim_circle.global_position = Vector2.ZERO


func _throw_grenade() -> void:
	if grenade_count <= 0:
		return

	grenade_count -= 1
	grenade_changed.emit(grenade_count)
	_update_weapon_ui()

	var mouse_pos: Vector2 = get_global_mouse_position()
	var dir: Vector2 = (mouse_pos - global_position).normalized()

	var grenade: Area2D = Area2D.new()
	grenade.name = "Grenade"
	grenade.set_script(load("res://scripts/Grenade.gd"))
	grenade.global_position = weapon_pivot.global_position
	grenade.direction = dir
	grenade.speed = GRENADE_THROW_SPEED
	grenade.damage = GRENADE_DAMAGE
	grenade.blast_radius = GRENADE_BLAST_RADIUS
	grenade.fuse_time = GRENADE_FUSE_TIME
	grenade.boom_sfx = boom_sfx
	grenade.thrown_by = self  # 击杀归属：手榴弹投掷者

	get_tree().current_scene.add_child(grenade)


func _get_grenade_key_name() -> String:
	var evs: Array = InputMap.action_get_events("grenade")
	if evs.size() > 0 and evs[0] is InputEventKey:
		return OS.get_keycode_string(evs[0].keycode)
	return "G"


# =============================================================================
# 武器 UI（右下角）
# =============================================================================

func _get_weapon_key_name(index: int) -> String:
	var action: String = "weapon_%d" % (index + 1)
	var evs: Array = InputMap.action_get_events(action)
	if evs.size() > 0 and evs[0] is InputEventKey:
		return OS.get_keycode_string(evs[0].keycode)
	return str(index + 1)


func _create_weapon_icon(icon_type_val: int) -> Control:
	var icon: Control = Control.new()
	var icon_script: GDScript = load("res://scripts/WeaponIcon.gd")
	if icon_script:
		icon.set_script(icon_script)
		icon.icon_type = icon_type_val
	return icon


func _create_weapon_ui() -> void:
	weapon_ui_layer = CanvasLayer.new()
	weapon_ui_layer.name = "WeaponUI"
	weapon_ui_layer.layer = 0
	add_child(weapon_ui_layer)

	# FPS 标签（左上角）
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.position = Vector2(10, 10)
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_color", Color(1, 1, 0.5, 1))
	fps_label.visible = show_fps
	weapon_ui_layer.add_child(fps_label)

	# --- CSGO风格主武器显示框（右下角） ---
	weapon_display_container = Control.new()
	weapon_display_container.name = "WeaponDisplay"
	weapon_display_container.custom_minimum_size = Vector2(300, 80)
	# 右下角定位
	weapon_display_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_display_container.offset_left = -310
	weapon_display_container.offset_top = -90
	weapon_display_container.offset_right = -10
	weapon_display_container.offset_bottom = -10
	weapon_ui_layer.add_child(weapon_display_container)

	# 背景面板（半透明黑色，发光边框）
	var bg: Panel = Panel.new()
	bg.name = "WeaponBG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.75)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.5, 0.6, 0.8, 0.9)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	bg.add_theme_stylebox_override("panel", bg_style)
	weapon_display_container.add_child(bg)

	# 武器图标（80x50，左侧）
	weapon_display_icon = _create_weapon_icon(0)
	weapon_display_icon.name = "WeaponIcon"
	weapon_display_icon.custom_minimum_size = Vector2(80, 50)
	weapon_display_icon.position = Vector2(10, 15)
	weapon_display_container.add_child(weapon_display_icon)

	# 武器名称（左上区域，小字体）
	weapon_display_name = Label.new()
	weapon_display_name.name = "WeaponName"
	weapon_display_name.position = Vector2(100, 8)
	weapon_display_name.add_theme_font_size_override("font_size", 14)
	weapon_display_name.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
	weapon_display_container.add_child(weapon_display_name)

	# 弹药当前数量（大字体，白色，右侧）
	weapon_display_ammo = Label.new()
	weapon_display_ammo.name = "AmmoCurrent"
	weapon_display_ammo.position = Vector2(175, 12)
	weapon_display_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_display_ammo.add_theme_font_size_override("font_size", 38)
	weapon_display_ammo.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	weapon_display_container.add_child(weapon_display_ammo)

	# 备用弹药（小字体，弹药下方）
	weapon_display_reserve = Label.new()
	weapon_display_reserve.name = "AmmoReserve"
	weapon_display_reserve.position = Vector2(195, 55)
	weapon_display_reserve.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_display_reserve.add_theme_font_size_override("font_size", 16)
	weapon_display_reserve.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
	weapon_display_container.add_child(weapon_display_reserve)

	# --- 手榴弹方框（武器框左边） ---
	var grenade_box: Control = Control.new()
	grenade_box.name = "GrenadeBox"
	# 定位于武器框左边
	grenade_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grenade_box.offset_left = -370
	grenade_box.offset_top = -90
	grenade_box.offset_right = -320
	grenade_box.offset_bottom = -10
	weapon_ui_layer.add_child(grenade_box)

	var gbg: Panel = Panel.new()
	gbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gstyle: StyleBoxFlat = StyleBoxFlat.new()
	gstyle.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	gstyle.border_width_left = 2
	gstyle.border_width_top = 2
	gstyle.border_width_right = 2
	gstyle.border_width_bottom = 2
	gstyle.border_color = Color(0.7, 0.45, 0.1, 1)
	gbg.add_theme_stylebox_override("panel", gstyle)
	grenade_box.add_child(gbg)

	# 按键标签（左上角）
	grenade_key_label = Label.new()
	grenade_key_label.name = "GrenadeKeyLabel"
	grenade_key_label.text = _get_grenade_key_name()
	grenade_key_label.position = Vector2(3, 1)
	grenade_key_label.add_theme_font_size_override("font_size", 12)
	grenade_key_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3, 1))
	grenade_box.add_child(grenade_key_label)

	# 手榴弹图标 + 数量
	var grenade_vbox: VBoxContainer = VBoxContainer.new()
	grenade_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grenade_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	grenade_vbox.add_theme_constant_override("separation", 2)
	grenade_box.add_child(grenade_vbox)

	var grenade_icon: Control = _create_weapon_icon(2)  # GRENADE
	grenade_icon.custom_minimum_size = Vector2(30, 28)
	grenade_vbox.add_child(grenade_icon)

	grenade_count_label = Label.new()
	grenade_count_label.text = "x1"
	grenade_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grenade_count_label.add_theme_font_size_override("font_size", 14)
	grenade_count_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2, 1))
	grenade_vbox.add_child(grenade_count_label)

	_update_weapon_ui()


func _update_weapon_ui() -> void:
	if not weapon_display_container:
		return

	var weapon: Dictionary = weapons[current_weapon_index]

	# 更新武器名称
	if weapon_display_name:
		var is_locked: bool = false
		if current_weapon_index == 1 and not has_rifle:
			is_locked = true
		elif current_weapon_index == 2 and not has_sniper:
			is_locked = true
		elif current_weapon_index == 4 and not has_machinegun:
			is_locked = true
		if is_locked:
			weapon_display_name.text = "未解锁"
			weapon_display_name.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		else:
			weapon_display_name.text = GameSettings.t(weapon.name)
			weapon_display_name.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))

	# 更新武器图标
	if weapon_display_icon:
		if weapon_display_icon.has_method("set_icon_type"):
			var icon_map: Array = [0, 1, 3, 4, 5]  # PISTOL, RIFLE, SNIPER, KNIFE, MACHINEGUN
			weapon_display_icon.set_icon_type(icon_map[current_weapon_index])
		var is_locked: bool = false
		if current_weapon_index == 1 and not has_rifle:
			is_locked = true
		elif current_weapon_index == 2 and not has_sniper:
			is_locked = true
		elif current_weapon_index == 4 and not has_machinegun:
			is_locked = true
		weapon_display_icon.modulate = Color(0.3, 0.3, 0.3, 1) if is_locked else Color(1, 1, 1, 1)

	# 更新弹药（大字体：当前弹药，小字体：备用弹药）
	# 刀没有弹药
	if current_weapon_index == 3:
		if weapon_display_ammo:
			weapon_display_ammo.text = "--"
			weapon_display_ammo.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
		if weapon_display_reserve:
			weapon_display_reserve.text = ""
	else:
		if weapon_display_ammo:
			if infinite_ammo:
				weapon_display_ammo.text = "∞"
				weapon_display_ammo.add_theme_color_override("font_color", Color(1, 0.7, 0, 1))
			else:
				weapon_display_ammo.text = str(weapon.current_ammo)
				# 弹药不足时变红
				if weapon.current_ammo <= weapon.max_ammo * 0.25:
					weapon_display_ammo.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
				else:
					weapon_display_ammo.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		if weapon_display_reserve:
			if infinite_ammo:
				weapon_display_reserve.text = ""
			else:
				weapon_display_reserve.text = "/ %d" % weapon.reserve_ammo

	# 更新边框颜色（当前武器高亮）
	var bg: Panel = weapon_display_container.find_child("WeaponBG", false, false)
	if bg:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.75)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.5, 0.6, 0.8, 0.9) if not infinite_ammo else Color(1, 0.6, 0.2, 0.9)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		bg.add_theme_stylebox_override("panel", style)

	# 更新手榴弹
	if grenade_count_label:
		grenade_count_label.text = "x%d" % grenade_count
	if grenade_key_label:
		grenade_key_label.text = _get_grenade_key_name()


# =============================================================================
# 特长（Perks）系统
# =============================================================================

var _perks_applied: bool = false

# 存储武器原始属性，防止重复调用时叠加
var _orig_weapon_data: Array = []

func _save_orig_weapon_data() -> void:
	_orig_weapon_data.clear()
	for w in weapons:
		_orig_weapon_data.append({
			"spread": w.get("spread", 0.0),
			"reserve_ammo": w.get("reserve_ammo", 0),
			"reload_time": w.get("reload_time", 0.0),
		})

func _restore_orig_weapon_data() -> void:
	for i in range(weapons.size()):
		if i < _orig_weapon_data.size():
			var orig: Dictionary = _orig_weapon_data[i]
			var w: Dictionary = weapons[i]
			if w.has("spread"):
				w.spread = orig.spread
			if w.has("reserve_ammo"):
				w.reserve_ammo = orig.reserve_ammo
			if w.has("reload_time"):
				w.reload_time = orig.reload_time

func _apply_perk_effects() -> void:
	# 防止重复叠加：先恢复原始属性
	if _perks_applied:
		_restore_orig_weapon_data()
	else:
		_save_orig_weapon_data()
		_perks_applied = true

	# 重置 max_health 到基础值 100
	max_health = 100

	# Perk 1: 防弹衣 — 最大血量 100→130
	if perks[1] == 0:
		max_health = 130
		# 按比例增加当前血量（不免费治愈）
		current_health = mini(current_health + 30, max_health)
		if health_bar:
			health_bar.max_value = max_health
			health_bar.value = current_health
		health_changed.emit(current_health, max_health)

	# Perk 2: 精准射击 — 散布 -25%
	if perks[2] == 0:
		for i in range(weapons.size()):
			var w: Dictionary = weapons[i]
			if w.has("spread") and w.spread > 0:
				w.spread *= 0.75

	# Perk 2: 弹药充沛 — 备用弹药 +50%
	if perks[2] == 1:
		for i in range(weapons.size()):
			var w: Dictionary = weapons[i]
			if w.has("reserve_ammo") and w.reserve_ammo > 0:
				w.reserve_ammo = int(w.reserve_ammo * 1.5)

	# Perk 2: 快速换弹 — 换弹速度 +30%
	if perks[2] == 2:
		for i in range(weapons.size()):
			var w: Dictionary = weapons[i]
			if w.has("reload_time") and w.reload_time > 0:
				w.reload_time *= 0.7

	# 刷新 HUD（弹药显示、武器 UI）
	_update_ammo_display()
	_update_weapon_ui()


func _spawn_ammo_pack(pos: Vector2) -> void:
	# 清道夫 Perk：击杀掉落弹药补给包
	var pack: Area2D = Area2D.new()
	pack.name = "AmmoPack"
	pack.global_position = pos

	# 碰撞形状（拾取范围）
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 20.0
	col.shape = shape
	pack.add_child(col)

	# 视觉：金色弹药箱图标
	var vis: ColorRect = ColorRect.new()
	vis.name = "Vis"
	vis.size = Vector2(16, 12)
	vis.position = Vector2(-8, -6)
	vis.color = Color(1, 0.85, 0.3, 1)
	pack.add_child(vis)

	# 小标签
	var lbl: Label = Label.new()
	lbl.name = "Label"
	lbl.text = "弹药"
	lbl.position = Vector2(-14, 8)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 0.9))
	pack.add_child(lbl)

	# 拾取脚本：玩家走近自动补满弹药
	pack.set_script(load("res://scripts/AmmoPack.gd"))

	if get_tree().current_scene:
		get_tree().current_scene.add_child(pack)


func _refill_current_ammo() -> void:
	# 补满当前武器备用弹药
	var weapon: Dictionary = weapons[current_weapon_index]
	if weapon.has("reserve_ammo"):
		weapon.reserve_ammo = max(weapon.reserve_ammo, weapon.max_ammo * 3)
		_update_ammo_display()
		_update_weapon_ui()