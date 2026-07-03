extends CharacterBody2D

# =============================================================================
# 联机玩家控制器
# 基于 Player.gd，加入 multiplayer authority 和位置同步
# 只有 authority 端（本地玩家）处理输入，远程玩家只接收同步数据
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

var health_bar: ProgressBar = null
var crosshair: Node2D = null
var fps_label: Label = null

# 音效
var shoot_sfx: AudioStream = null
var rifle_sfx: AudioStream = null
var sniper_sfx: AudioStream = null
var mg_sfx: AudioStream = null
var mg_sfx_player: AudioStreamPlayer = null
var mg_reload_sfx: AudioStream = null
var reload_sfx: AudioStream = null

# 移动
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
var _cooldown_ready: bool = true
var reloading: bool = false
var infinite_ammo: bool = false
var has_rifle: bool = true
var has_sniper: bool = true
var has_machinegun: bool = true
var pistol_visual: Node2D = null
var rifle_visual: Node2D = null
var sniper_visual: Node2D = null
var mg_visual: Node2D = null

# 特长（Perks）系统
var perks: Array = [-1, -1, -1]  # 3个特长槽位
var _regen_timer: float = 0.0
var _regen_active: bool = false
var _last_damage_time: float = 0.0

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

# FPS
var fps_timer: float = 0.0
var show_fps: bool = true

# 屏幕震动
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0

# ===== 联机相关 =====
var is_local_player: bool = false  # 是否是本地玩家（有输入权限）
var player_color: Color = Color(0.2, 0.4, 0.9, 1)  # 由游戏场景分配
var name_label: Label = null  # 头顶名称标签（仅远程玩家）

# 同步就绪标志：防止场景加载完成前就开始发 RPC
var _sync_enabled: bool = false

# 同步缓冲
var _sync_rotation: float = 0.0
var _sync_weapon_index: int = 0

# 网络同步位置插值
var _target_position: Vector2 = Vector2.ZERO
var _interp_factor: float = 0.1


func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	_init_weapons()

	mouse_sensitivity = GameSettings.get_value("controls", "mouse_sensitivity", 1.0)
	crosshair_style = GameSettings.get_value("game", "crosshair_style", 0)
	crosshair_color = GameSettings.get_value("game", "crosshair_color", Color(0, 1, 0, 1))
	show_fps = GameSettings.get_value("game", "show_fps", true)
	if fps_label:
		fps_label.visible = show_fps

	if crosshair:
		_update_crosshair()

	# 生成圆形外观
	if sprite is Polygon2D:
		var points: Array = []
		var radius: float = 16.0
		var segments: int = 24
		for i in range(segments):
			var angle: float = i * TAU / segments
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
		sprite.polygon = PackedVector2Array(points)
		sprite.color = player_color

	_create_eyes()

	muzzle_flash.visible = false
	hit_timer.timeout.connect(_on_hit_timer_timeout)

	_shake_timer = 0.0
	if camera:
		camera.offset = Vector2.ZERO

	add_to_group("player")

	shoot_sfx = load("res://assets/sheji.mp3")
	rifle_sfx = load("res://assets/buqiangsheji.mp3")
	sniper_sfx = load("res://assets/jujiqiangsheji.mp3")
	mg_sfx = load("res://assets/jiqiang.mp3")
	mg_reload_sfx = load("res://assets/jiqianghuandan.mp3")
	reload_sfx = load("res://assets/huandan.mp3")
	boom_sfx = load("res://assets/boom.mp3")

	_create_weapon_visual()
	_create_grenade_aim()

	# 判断是否是本地玩家
	is_local_player = is_multiplayer_authority()

	# 远程玩家隐藏 Camera2D（避免多个相机冲突）
	if not is_local_player and camera:
		camera.queue_free()
		camera = null

	# 创建武器UI（仅本地玩家）
	_create_weapon_ui()

	# 远程玩家不创建准星、FPS、武器UI
	if not is_local_player:
		if crosshair:
			crosshair.queue_free()
			crosshair = null
		if fps_label:
			fps_label.queue_free()
			fps_label = null
		if weapon_ui_layer:
			weapon_ui_layer.queue_free()
			weapon_ui_layer = null

	# 禁用远程玩家的输入处理
	if not is_local_player:
		set_process_input(false)
		# 创建头顶名称标签
		_create_name_label()


func _init_weapons() -> void:
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
	weapons = [pistol, rifle, sniper, machinegun]
	_apply_perk_effects()
	_update_ammo_display()


func _physics_process(delta: float) -> void:
	if is_local_player and not dead:
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

		# FPS
		if show_fps and fps_label:
			fps_timer += delta
			if fps_timer >= 0.2:
				fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
				fps_timer = 0.0

		# Perk: 快速治疗 — 受伤3秒后自动回血（1HP/秒，上限50%）
		if perks[1] == 1 and current_health > 0:
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
						_sync_health.rpc(current_health)
			else:
				if _last_damage_time > 0.0 and (Time.get_ticks_msec() / 1000.0 - _last_damage_time) >= 3.0:
					_regen_active = true
					_regen_timer = 0.0

		# 同步位置和武器到其他玩家
		_sync_state()

	elif not is_local_player and not dead:
		# 远程玩家：插值移动到同步位置
		position = position.lerp(_target_position, _interp_factor)
		weapon_pivot.rotation = _sync_rotation
		# 更新武器视觉
		if current_weapon_index != _sync_weapon_index:
			current_weapon_index = _sync_weapon_index
			_update_weapon_visual()


# =============================================================================
# 网络同步
# =============================================================================
@rpc("authority", "call_remote", "unreliable")
func _sync_position_and_rotation(pos: Vector2, rot: float, w_idx: int) -> void:
	_target_position = pos
	_sync_rotation = rot
	_sync_weapon_index = w_idx


@rpc("authority", "call_remote", "reliable")
func _sync_shoot(pos: Vector2, dir: Vector2, speed: float, damage: int, _w_idx: int) -> void:
	# 远程玩家射击同步：在本地生成子弹
	_spawn_bullet_at(pos, dir, speed, damage)


@rpc("authority", "call_remote", "reliable")
func _sync_health(hp: int) -> void:
	# 远程玩家血量同步
	current_health = hp
	health_changed.emit(hp, max_health)
	if health_bar:
		health_bar.value = hp


@rpc("authority", "call_remote", "reliable")
func _sync_ammo(w_idx: int, current: int, max_a: int, reserve: int) -> void:
	# 远程玩家弹药同步（含武器索引，避免竞态条件）
	if w_idx < 0 or w_idx >= weapons.size():
		return
	var weapon: Dictionary = weapons[w_idx]
	weapon.current_ammo = current
	weapon.max_ammo = max_a
	weapon.reserve_ammo = reserve
	if w_idx == current_weapon_index:
		_update_ammo_display()


@rpc("authority", "call_remote", "reliable")
func _sync_died() -> void:
	# 远程玩家死亡同步
	_die()


func _sync_state() -> void:
	if not is_local_player:
		return
	if not _sync_enabled:
		return
	# 位置和旋转同步（ unreliable 频率高）
	_sync_position_and_rotation.rpc(global_position, weapon_pivot.rotation, current_weapon_index)


# =============================================================================
# 本地玩家逻辑（与原 Player.gd 基本相同）
# =============================================================================
func _handle_movement(delta: float) -> void:
	var input_vec: Vector2 = Vector2.ZERO
	input_vec.x = Input.get_axis("move_left", "move_right")
	input_vec.y = Input.get_axis("move_up", "move_down")
	input_vec = input_vec.normalized() if input_vec.length() > 0.0 else Vector2.ZERO

	if input_vec.length() > 0.001:
		var effective_speed: float = move_speed
		# Perk 0: 轻装上阵 +15%速度
		if perks[0] == 0:
			effective_speed *= 1.15
		var target_vel: Vector2 = input_vec * effective_speed
		_velocity = _velocity.move_toward(target_vel, acceleration * delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, deceleration * delta)

	velocity = _velocity
	move_and_slide()


func _handle_aim() -> void:
	if not weapon_pivot:
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	weapon_pivot.look_at(mouse_pos)
	var angle: float = wrapf(weapon_pivot.rotation, -PI, PI)
	weapon_pivot.rotation = angle


func _handle_shooting() -> void:
	if reloading:
		return
	var weapon: Dictionary = weapons[current_weapon_index]

	if weapon.current_ammo <= 0 and not infinite_ammo:
		if weapon.reserve_ammo > 0:
			_start_reload()
		return

	if Input.is_action_pressed("shoot") and can_shoot and weapon.current_ammo > 0:
		_shoot()

	if not weapon.auto:
		if _cooldown_ready and not Input.is_action_pressed("shoot"):
			can_shoot = true
			_cooldown_ready = false


func _shoot() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	can_shoot = false

	if not infinite_ammo:
		weapon.current_ammo -= 1

	var sfx_to_play: AudioStream
	match current_weapon_index:
		0: sfx_to_play = shoot_sfx
		1: sfx_to_play = rifle_sfx
		2: sfx_to_play = sniper_sfx
		3: sfx_to_play = mg_sfx
		_: sfx_to_play = shoot_sfx
	_play_sfx(sfx_to_play)

	muzzle_flash.visible = true
	get_tree().create_timer(0.05).timeout.connect(func(): muzzle_flash.visible = false)

	_spawn_bullet()

	if weapon.auto:
		get_tree().create_timer(weapon.fire_rate).timeout.connect(func(): can_shoot = true)
	else:
		_cooldown_ready = false
		get_tree().create_timer(weapon.fire_rate).timeout.connect(func(): _cooldown_ready = true)

	_update_ammo_display()
	_update_weapon_ui()

	if weapon.current_ammo <= 0 and not reloading and not infinite_ammo:
		_start_reload()

	# 同步弹药
	if is_local_player:
		var w: Dictionary = weapons[current_weapon_index]
		_sync_ammo.rpc(current_weapon_index, w.current_ammo, w.max_ammo, w.reserve_ammo)


func _play_sfx(stream: AudioStream) -> void:
	if stream:
		var sfx: AudioStreamPlayer = AudioStreamPlayer.new()
		sfx.stream = stream
		sfx.volume_db = -3.0
		sfx.bus = "SFX"
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(func(): sfx.queue_free())


func _spawn_bullet() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	var bullet: Area2D = null
	var aim_dir: Vector2 = Vector2.ZERO

	if ResourceLoader.exists("res://scenes/game/Bullet.tscn"):
		bullet = load("res://scenes/game/Bullet.tscn").instantiate()
	else:
		bullet = _create_bullet()

	if bullet:
		bullet.global_position = weapon_pivot.global_position
		aim_dir = (get_global_mouse_position() - global_position).normalized()
		var spread: float = weapon.spread
		if spread > 0:
			aim_dir = aim_dir.rotated(randf_range(-spread, spread))
		bullet.direction = aim_dir
		bullet.speed = weapon.bullet_speed
		bullet.damage = weapon.damage
		bullet.shooter = self  # 击杀归属：子弹发射者

		# 标记子弹所属玩家（用于区分友方/敌方）
		bullet.owner_peer_id = multiplayer.get_unique_id()
		var scene_root: Node = get_tree().current_scene
		if scene_root:
			scene_root.add_child(bullet)

	# 同步射击到远程玩家
	if is_local_player and aim_dir != Vector2.ZERO:
		_sync_shoot.rpc(weapon_pivot.global_position, aim_dir, weapon.bullet_speed, weapon.damage, current_weapon_index)


func _spawn_bullet_at(pos: Vector2, dir: Vector2, speed: float, damage: int) -> void:
	# 远程玩家的子弹在本地生成
	var bullet: Area2D = null
	if ResourceLoader.exists("res://scenes/game/Bullet.tscn"):
		bullet = load("res://scenes/game/Bullet.tscn").instantiate()
	else:
		bullet = _create_bullet()

	if bullet:
		bullet.global_position = pos
		bullet.direction = dir
		bullet.speed = speed
		bullet.damage = damage
		bullet.shooter = self  # 击杀归属：远程玩家发射的子弹
		# 远程玩家的子弹属于对方
		bullet.owner_peer_id = get_multiplayer_authority()
		var scene_root: Node = get_tree().current_scene
		if scene_root:
			scene_root.add_child(bullet)


func _create_bullet() -> Area2D:
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
	elif Input.is_action_just_pressed("weapon_5"):
		if has_machinegun:
			_switch_weapon(3)


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
	_play_weapon_switch_animation()


func _play_weapon_switch_animation() -> void:
	if not weapon_display_container:
		return
	if _weapon_slide_tween and _weapon_slide_tween.is_valid():
		_weapon_slide_tween.kill()
	var target_x: float = weapon_display_container.offset_left
	weapon_display_container.offset_left = target_x + 80
	_weapon_slide_tween = weapon_display_container.create_tween()
	_weapon_slide_tween.set_ease(Tween.EASE_OUT)
	_weapon_slide_tween.set_trans(Tween.TRANS_QUAD)
	_weapon_slide_tween.tween_property(weapon_display_container, "offset_left", target_x, 0.2)


func _handle_reload() -> void:
	if Input.is_action_just_pressed("reload") and not reloading:
		_start_reload()


func _start_reload() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	if weapon.current_ammo >= weapon.max_ammo or weapon.reserve_ammo <= 0:
		return
	reloading = true
	can_shoot = false
	# 机枪用专属换弹音效，其他武器用通用换弹音效
	if current_weapon_index == 3 and mg_reload_sfx:
		_play_sfx(mg_reload_sfx)
	else:
		_play_sfx(reload_sfx)
	get_tree().create_timer(weapon.reload_time).timeout.connect(func(): _reload_done())


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
	if is_local_player:
		_sync_ammo.rpc(current_weapon_index, weapon.current_ammo, weapon.max_ammo, weapon.reserve_ammo)


func take_damage(amount: int, is_explosion: bool = false) -> void:
	if dead:
		return
	# Perk 1 爆炸抗性：爆炸伤害 -40%
	if is_explosion and perks[1] == 2:
		amount = int(amount * 0.6)
	current_health -= amount
	current_health = max(0, current_health)
	health_changed.emit(current_health, max_health)
	if health_bar:
		health_bar.value = current_health

	modulate = Color.RED
	hit_timer.start(0.1)

	# 记录受伤时间（用于快速治疗Perk）
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	_regen_active = false
	_regen_timer = 0.0

	if is_local_player:
		_sync_health.rpc(current_health)

	if current_health <= 0:
		_die()


func screen_shake(intensity: float = 3.0, duration: float = 0.15) -> void:
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

	if is_local_player:
		_sync_died.rpc()


func _update_ammo_display() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	ammo_changed.emit(weapon.current_ammo, weapon.max_ammo, weapon.reserve_ammo)


func _create_eyes() -> void:
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


func _create_name_label() -> void:
	var peer_id: int = get_multiplayer_authority()
	var display_name: String = ""
	if NetworkManager.connected:
		display_name = NetworkManager.get_player_display_name(peer_id)
	if display_name.is_empty():
		display_name = "Player %d" % peer_id

	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = display_name
	name_label.size = Vector2(100, 16)
	name_label.position = Vector2(-50, -32)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_label.add_theme_constant_override("outline_size", 3)
	add_child(name_label)


func _update_crosshair() -> void:
	if not crosshair:
		return
	crosshair_style = GameSettings.get_value("game", "crosshair_style", 0)
	crosshair_color = GameSettings.get_value("game", "crosshair_color", Color(0, 1, 0, 1))
	if crosshair.has_method("update_crosshair"):
		crosshair.update_crosshair(crosshair_style, crosshair_color)


func _create_weapon_visual() -> void:
	if not weapon_pivot:
		return

	# 手枪
	var pistol_holder: Node2D = Node2D.new()
	pistol_holder.name = "PistolVisual"
	weapon_pivot.add_child(pistol_holder)
	var p_slide: ColorRect = ColorRect.new()
	p_slide.name = "Slide"
	p_slide.size = Vector2(18, 7)
	p_slide.position = Vector2(2, -3.5)
	p_slide.color = Color(0.25, 0.25, 0.28, 1.0)
	pistol_holder.add_child(p_slide)
	var p_barrel: ColorRect = ColorRect.new()
	p_barrel.name = "Barrel"
	p_barrel.size = Vector2(6, 4)
	p_barrel.position = Vector2(20, -2.0)
	p_barrel.color = Color(0.12, 0.12, 0.12, 1.0)
	pistol_holder.add_child(p_barrel)
	var p_grip: ColorRect = ColorRect.new()
	p_grip.name = "Grip"
	p_grip.size = Vector2(7, 12)
	p_grip.position = Vector2(5, 3.5)
	p_grip.color = Color(0.3, 0.25, 0.2, 1.0)
	pistol_holder.add_child(p_grip)
	var p_trigger: ColorRect = ColorRect.new()
	p_trigger.name = "TriggerGuard"
	p_trigger.size = Vector2(6, 5)
	p_trigger.position = Vector2(11, 3.5)
	p_trigger.color = Color(0.18, 0.18, 0.18, 1.0)
	pistol_holder.add_child(p_trigger)
	var p_right_hand: ColorRect = ColorRect.new()
	p_right_hand.name = "RightHand"
	p_right_hand.size = Vector2(8, 7)
	p_right_hand.position = Vector2(4, 9)
	p_right_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	pistol_holder.add_child(p_right_hand)
	var p_left_hand: ColorRect = ColorRect.new()
	p_left_hand.name = "LeftHand"
	p_left_hand.size = Vector2(7, 6)
	p_left_hand.position = Vector2(17, 2)
	p_left_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	pistol_holder.add_child(p_left_hand)
	pistol_visual = pistol_holder

	# 步枪
	var rifle_holder: Node2D = Node2D.new()
	rifle_holder.name = "RifleVisual"
	weapon_pivot.add_child(rifle_holder)
	var r_body: ColorRect = ColorRect.new()
	r_body.name = "Receiver"
	r_body.size = Vector2(30, 9)
	r_body.position = Vector2(0, -4.5)
	r_body.color = Color(0.2, 0.2, 0.22, 1.0)
	rifle_holder.add_child(r_body)
	var r_barrel: ColorRect = ColorRect.new()
	r_barrel.name = "Barrel"
	r_barrel.size = Vector2(16, 4)
	r_barrel.position = Vector2(30, -2.0)
	r_barrel.color = Color(0.1, 0.1, 0.1, 1.0)
	rifle_holder.add_child(r_barrel)
	var r_stock: ColorRect = ColorRect.new()
	r_stock.name = "Stock"
	r_stock.size = Vector2(10, 7)
	r_stock.position = Vector2(-10, -3.5)
	r_stock.color = Color(0.35, 0.28, 0.18, 1.0)
	rifle_holder.add_child(r_stock)
	var r_mag: ColorRect = ColorRect.new()
	r_mag.name = "Magazine"
	r_mag.size = Vector2(7, 13)
	r_mag.position = Vector2(10, 4.5)
	r_mag.color = Color(0.15, 0.15, 0.15, 1.0)
	rifle_holder.add_child(r_mag)
	var r_grip: ColorRect = ColorRect.new()
	r_grip.name = "Grip"
	r_grip.size = Vector2(6, 10)
	r_grip.position = Vector2(3, 4.5)
	r_grip.color = Color(0.25, 0.22, 0.2, 1.0)
	rifle_holder.add_child(r_grip)
	var r_handguard: ColorRect = ColorRect.new()
	r_handguard.name = "Handguard"
	r_handguard.size = Vector2(14, 6)
	r_handguard.position = Vector2(18, -3.0)
	r_handguard.color = Color(0.18, 0.18, 0.18, 1.0)
	rifle_holder.add_child(r_handguard)
	var r_right_hand: ColorRect = ColorRect.new()
	r_right_hand.name = "RightHand"
	r_right_hand.size = Vector2(8, 7)
	r_right_hand.position = Vector2(2, 9)
	r_right_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	rifle_holder.add_child(r_right_hand)
	var r_left_hand: ColorRect = ColorRect.new()
	r_left_hand.name = "LeftHand"
	r_left_hand.size = Vector2(8, 6)
	r_left_hand.position = Vector2(20, 2)
	r_left_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	rifle_holder.add_child(r_left_hand)
	rifle_visual = rifle_holder

	# 狙击枪
	var sniper_holder: Node2D = Node2D.new()
	sniper_holder.name = "SniperVisual"
	weapon_pivot.add_child(sniper_holder)
	var s_body: ColorRect = ColorRect.new()
	s_body.name = "Receiver"
	s_body.size = Vector2(34, 8)
	s_body.position = Vector2(-2, -4)
	s_body.color = Color(0.18, 0.18, 0.20, 1.0)
	sniper_holder.add_child(s_body)
	var s_barrel: ColorRect = ColorRect.new()
	s_barrel.name = "Barrel"
	s_barrel.size = Vector2(18, 4)
	s_barrel.position = Vector2(32, -2)
	s_barrel.color = Color(0.08, 0.08, 0.08, 1.0)
	sniper_holder.add_child(s_barrel)
	var s_scope: ColorRect = ColorRect.new()
	s_scope.name = "Scope"
	s_scope.size = Vector2(14, 5)
	s_scope.position = Vector2(8, -9)
	s_scope.color = Color(0.35, 0.38, 0.42, 1.0)
	sniper_holder.add_child(s_scope)
	var s_stock: ColorRect = ColorRect.new()
	s_stock.name = "Stock"
	s_stock.size = Vector2(10, 7)
	s_stock.position = Vector2(-12, -3.5)
	s_stock.color = Color(0.3, 0.24, 0.16, 1.0)
	sniper_holder.add_child(s_stock)
	var s_mag: ColorRect = ColorRect.new()
	s_mag.name = "Magazine"
	s_mag.size = Vector2(5, 8)
	s_mag.position = Vector2(10, 4)
	s_mag.color = Color(0.12, 0.12, 0.12, 1.0)
	sniper_holder.add_child(s_mag)
	var s_grip: ColorRect = ColorRect.new()
	s_grip.name = "Grip"
	s_grip.size = Vector2(6, 9)
	s_grip.position = Vector2(3, 4)
	s_grip.color = Color(0.25, 0.22, 0.2, 1.0)
	sniper_holder.add_child(s_grip)
	var s_right_hand: ColorRect = ColorRect.new()
	s_right_hand.name = "RightHand"
	s_right_hand.size = Vector2(8, 7)
	s_right_hand.position = Vector2(2, 9)
	s_right_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	sniper_holder.add_child(s_right_hand)
	var s_left_hand: ColorRect = ColorRect.new()
	s_left_hand.name = "LeftHand"
	s_left_hand.size = Vector2(8, 6)
	s_left_hand.position = Vector2(26, 2)
	s_left_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	sniper_holder.add_child(s_left_hand)
	sniper_visual = sniper_holder

	# --- 机枪模型（武器3） ---
	var mg_holder: Node2D = Node2D.new()
	mg_holder.name = "MGVisual"
	weapon_pivot.add_child(mg_holder)

	var m_body: ColorRect = ColorRect.new()
	m_body.name = "Receiver"
	m_body.size = Vector2(36, 10)
	m_body.position = Vector2(-2, -5)
	m_body.color = Color(0.18, 0.18, 0.20, 1.0)
	mg_holder.add_child(m_body)

	var m_barrel: ColorRect = ColorRect.new()
	m_barrel.name = "Barrel"
	m_barrel.size = Vector2(20, 5)
	m_barrel.position = Vector2(34, -2.5)
	m_barrel.color = Color(0.08, 0.08, 0.08, 1.0)
	mg_holder.add_child(m_barrel)

	var m_shroud: ColorRect = ColorRect.new()
	m_shroud.name = "Shroud"
	m_shroud.size = Vector2(16, 7)
	m_shroud.position = Vector2(20, -3.5)
	m_shroud.color = Color(0.15, 0.15, 0.16, 1.0)
	mg_holder.add_child(m_shroud)

	var m_mag: ColorRect = ColorRect.new()
	m_mag.name = "MagazineBox"
	m_mag.size = Vector2(10, 16)
	m_mag.position = Vector2(8, 5)
	m_mag.color = Color(0.12, 0.12, 0.12, 1.0)
	mg_holder.add_child(m_mag)

	var m_stock: ColorRect = ColorRect.new()
	m_stock.name = "Stock"
	m_stock.size = Vector2(12, 8)
	m_stock.position = Vector2(-14, -4)
	m_stock.color = Color(0.3, 0.24, 0.16, 1.0)
	mg_holder.add_child(m_stock)

	var m_grip: ColorRect = ColorRect.new()
	m_grip.name = "Grip"
	m_grip.size = Vector2(7, 12)
	m_grip.position = Vector2(2, 5)
	m_grip.color = Color(0.25, 0.22, 0.20, 1.0)
	mg_holder.add_child(m_grip)

	var m_right_hand: ColorRect = ColorRect.new()
	m_right_hand.name = "RightHand"
	m_right_hand.size = Vector2(8, 7)
	m_right_hand.position = Vector2(1, 10)
	m_right_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	mg_holder.add_child(m_right_hand)

	var m_left_hand: ColorRect = ColorRect.new()
	m_left_hand.name = "LeftHand"
	m_left_hand.size = Vector2(9, 6)
	m_left_hand.position = Vector2(24, 2)
	m_left_hand.color = Color(0.75, 0.6, 0.45, 1.0)
	mg_holder.add_child(m_left_hand)

	mg_visual = mg_holder

	_update_weapon_visual()


func _update_weapon_visual() -> void:
	if pistol_visual:
		pistol_visual.visible = (current_weapon_index == 0)
	if rifle_visual:
		rifle_visual.visible = (current_weapon_index == 1 and has_rifle)
	if sniper_visual:
		sniper_visual.visible = (current_weapon_index == 2 and has_sniper)
	if mg_visual:
		mg_visual.visible = (current_weapon_index == 3 and has_machinegun)


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
	grenade_aim_line = Line2D.new()
	grenade_aim_line.name = "GrenadeAimLine"
	grenade_aim_line.top_level = true
	grenade_aim_line.width = 2.0
	grenade_aim_line.default_color = Color(1, 0.5, 0, 0.7)
	grenade_aim_line.visible = false
	add_child(grenade_aim_line)

	grenade_aim_circle = Line2D.new()
	grenade_aim_circle.name = "GrenadeAimCircle"
	grenade_aim_circle.top_level = true
	grenade_aim_circle.width = 2.0
	grenade_aim_circle.default_color = Color(1, 0.3, 0, 0.5)
	grenade_aim_circle.visible = false
	add_child(grenade_aim_circle)


func _handle_grenade() -> void:
	if not is_local_player:
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

	if grenade_aim_line:
		var pts: Array = []
		var steps: int = 12
		for i in range(steps + 1):
			var t: float = float(i) / steps
			pts.append(global_position.lerp(landing, t))
		grenade_aim_line.points = PackedVector2Array(pts)
		grenade_aim_line.global_position = Vector2.ZERO

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
	grenade.owner_peer_id = multiplayer.get_unique_id()
	grenade.thrown_by = self  # 击杀归属：手榴弹投掷者

	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(grenade)

	# 同步手榴弹
	if is_local_player:
		_sync_grenade.rpc(weapon_pivot.global_position, dir)


@rpc("authority", "call_remote", "reliable")
func _sync_grenade(pos: Vector2, dir: Vector2) -> void:
	# 远程玩家扔手榴弹同步
	var grenade: Area2D = Area2D.new()
	grenade.name = "Grenade"
	grenade.set_script(load("res://scripts/Grenade.gd"))
	grenade.global_position = pos
	grenade.direction = dir
	grenade.speed = GRENADE_THROW_SPEED
	grenade.damage = GRENADE_DAMAGE
	grenade.blast_radius = GRENADE_BLAST_RADIUS
	grenade.fuse_time = GRENADE_FUSE_TIME
	grenade.boom_sfx = boom_sfx
	grenade.owner_peer_id = get_multiplayer_authority()
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(grenade)


func _get_grenade_key_name() -> String:
	var evs: Array = InputMap.action_get_events("grenade")
	if evs.size() > 0 and evs[0] is InputEventKey:
		return OS.get_keycode_string(evs[0].keycode)
	return "G"


# =============================================================================
# 武器UI（仅本地玩家创建）
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
	if not is_local_player:
		return

	weapon_ui_layer = CanvasLayer.new()
	weapon_ui_layer.name = "WeaponUI"
	weapon_ui_layer.layer = 0
	add_child(weapon_ui_layer)

	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.position = Vector2(10, 10)
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_color", Color(1, 1, 0.5, 1))
	fps_label.visible = show_fps
	weapon_ui_layer.add_child(fps_label)

	weapon_display_container = Control.new()
	weapon_display_container.name = "WeaponDisplay"
	weapon_display_container.custom_minimum_size = Vector2(300, 80)
	weapon_display_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_display_container.offset_left = -310
	weapon_display_container.offset_top = -90
	weapon_display_container.offset_right = -10
	weapon_display_container.offset_bottom = -10
	weapon_ui_layer.add_child(weapon_display_container)

	var bg_panel: Panel = Panel.new()
	bg_panel.name = "WeaponBG"
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	weapon_display_container.add_child(bg_panel)

	weapon_display_icon = _create_weapon_icon(0)
	weapon_display_icon.name = "WeaponIcon"
	weapon_display_icon.custom_minimum_size = Vector2(80, 50)
	weapon_display_icon.position = Vector2(10, 15)
	weapon_display_container.add_child(weapon_display_icon)

	weapon_display_name = Label.new()
	weapon_display_name.name = "WeaponName"
	weapon_display_name.position = Vector2(100, 8)
	weapon_display_name.add_theme_font_size_override("font_size", 14)
	weapon_display_name.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
	weapon_display_container.add_child(weapon_display_name)

	weapon_display_ammo = Label.new()
	weapon_display_ammo.name = "AmmoCurrent"
	weapon_display_ammo.position = Vector2(175, 12)
	weapon_display_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_display_ammo.add_theme_font_size_override("font_size", 38)
	weapon_display_ammo.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	weapon_display_container.add_child(weapon_display_ammo)

	weapon_display_reserve = Label.new()
	weapon_display_reserve.name = "AmmoReserve"
	weapon_display_reserve.position = Vector2(195, 55)
	weapon_display_reserve.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_display_reserve.add_theme_font_size_override("font_size", 16)
	weapon_display_reserve.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
	weapon_display_container.add_child(weapon_display_reserve)

	# 手榴弹方框
	var grenade_box: Control = Control.new()
	grenade_box.name = "GrenadeBox"
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

	grenade_key_label = Label.new()
	grenade_key_label.name = "GrenadeKeyLabel"
	grenade_key_label.text = _get_grenade_key_name()
	grenade_key_label.position = Vector2(3, 1)
	grenade_key_label.add_theme_font_size_override("font_size", 12)
	grenade_key_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3, 1))
	grenade_box.add_child(grenade_key_label)

	var grenade_vbox: VBoxContainer = VBoxContainer.new()
	grenade_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grenade_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	grenade_vbox.add_theme_constant_override("separation", 2)
	grenade_box.add_child(grenade_vbox)

	var grenade_icon: Control = _create_weapon_icon(2)
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
	if not weapon_display_container or not is_local_player:
		return

	var weapon: Dictionary = weapons[current_weapon_index]

	if weapon_display_name:
		var is_locked: bool = false
		if current_weapon_index == 1 and not has_rifle:
			is_locked = true
		elif current_weapon_index == 2 and not has_sniper:
			is_locked = true
		elif current_weapon_index == 3 and not has_machinegun:
			is_locked = true
		if is_locked:
			weapon_display_name.text = "未解锁"
			weapon_display_name.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		else:
			weapon_display_name.text = GameSettings.t(weapon.name)
			weapon_display_name.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))

	if weapon_display_icon:
		if weapon_display_icon.has_method("set_icon_type"):
			var icon_map: Array = [0, 1, 3, 5]  # PISTOL, RIFLE, SNIPER, MACHINEGUN
			weapon_display_icon.set_icon_type(icon_map[current_weapon_index])
		var is_locked: bool = false
		if current_weapon_index == 1 and not has_rifle:
			is_locked = true
		elif current_weapon_index == 2 and not has_sniper:
			is_locked = true
		elif current_weapon_index == 3 and not has_machinegun:
			is_locked = true
		weapon_display_icon.modulate = Color(0.3, 0.3, 0.3, 1) if is_locked else Color(1, 1, 1, 1)

	if weapon_display_ammo:
		if infinite_ammo:
			weapon_display_ammo.text = "∞"
			weapon_display_ammo.add_theme_color_override("font_color", Color(1, 0.7, 0, 1))
		else:
			weapon_display_ammo.text = str(weapon.current_ammo)
			if weapon.current_ammo <= weapon.max_ammo * 0.25:
				weapon_display_ammo.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
			else:
				weapon_display_ammo.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	if weapon_display_reserve:
		if infinite_ammo:
			weapon_display_reserve.text = ""
		else:
			weapon_display_reserve.text = "/ %d" % weapon.reserve_ammo

	if grenade_count_label:
		grenade_count_label.text = "x%d" % grenade_count
	if grenade_key_label:
		grenade_key_label.text = _get_grenade_key_name()


# =============================================================================
# 特长（Perks）系统
# =============================================================================

var _perks_applied: bool = false
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

	# 刷新 HUD
	if is_local_player:
		_update_ammo_display()
		_update_weapon_ui()


func _refill_current_ammo() -> void:
	var weapon: Dictionary = weapons[current_weapon_index]
	if weapon.has("reserve_ammo"):
		weapon.reserve_ammo = max(weapon.reserve_ammo, weapon.max_ammo * 3)
		_update_ammo_display()
		_update_weapon_ui()
		if is_local_player:
			_sync_ammo.rpc(current_weapon_index, weapon.current_ammo, weapon.max_ammo, weapon.reserve_ammo)
