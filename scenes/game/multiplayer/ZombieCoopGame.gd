extends Node2D

# =============================================================================
# 僵尸联机模式控制器
# 和单机版完全一样，只是变成能联机的了
# 房主负责：僵尸生成、波次推进、商店逻辑
# 客户端负责：本地玩家输入、同步到房主
# =============================================================================

signal wave_started(wave_number)
signal wave_completed(wave_number)
signal game_over()

@onready var map_node: Node2D = $Map
@onready var enemy_container: Node2D = $Enemies
@onready var ui_layer: CanvasLayer = $UI
@onready var wave_label: Label = $UI/WaveLabel
@onready var enemies_label: Label = $UI/EnemiesLabel
@onready var health_label: Label = $UI/HealthLabel
@onready var money_hud_label: Label = $UI/MoneyHUDLabel
@onready var shop_panel: Panel = $UI/ShopPanel
@onready var shop_vbox: VBoxContainer = $UI/ShopPanel/VBox

# 死亡界面
@onready var death_panel: Panel = $UI/DeathPanel
@onready var death_wave_label: Label = $UI/DeathPanel/VBox/WaveInfoLabel
@onready var death_high_label: Label = $UI/DeathPanel/VBox/HighWaveLabel
@onready var death_restart_btn: Button = $UI/DeathPanel/VBox/RestartBtn
@onready var death_menu_btn: Button = $UI/DeathPanel/VBox/MenuBtn

@onready var exit_panel: Panel = $UI/ExitConfirmPanel
@onready var exit_confirm_btn: Button = $UI/ExitConfirmPanel/VBox/ConfirmBtn
@onready var exit_cancel_btn: Button = $UI/ExitConfirmPanel/VBox/CancelBtn

# 玩家管理
var player_container: Node2D = null
var local_player: CharacterBody2D = null
var remote_players: Dictionary = {}

# 波次系统
var current_wave: int = 0
var enemies_remaining: int = 0
var enemies_killed: int = 0
var wave_in_progress: bool = false
var base_enemy_count: int = 5
var enemy_scene: PackedScene

# 暂停
var pause_menu: Control = null
var paused: bool = false
var settings_instance: Control = null

# 商店
var shop_open: bool = false

# 金钱
var money: int = 0
var money_label: Label = null
var kills: int = 0
var kills_label: Label = null

# 商店价格
var hp_price: int = 150
var damage_price: int = 100
var ammo_price: int = 50
var grenade_price: int = 100
var rifle_price: int = 300
var rifle_purchased: bool = false
var sniper_price: int = 500
var sniper_purchased: bool = false
var mg_price: int = 400
var mg_purchased: bool = false

# 最高波次
var high_wave: int = 0

# 控制台
var console: CanvasLayer = null

# 击杀通知
var kill_feed_container: VBoxContainer = null

# 商店按钮
var hp_btn: Button = null
var dmg_btn: Button = null
var ammo_btn: Button = null
var grenade_btn: Button = null
var rifle_btn: Button = null
var sniper_btn: Button = null
var mg_btn: Button = null
var continue_btn: Button = null

# 多语言
var death_title_label: Label = null
var exit_label: Label = null
var shop_title_label: Label = null

# BOSS血条
var boss_node: CharacterBody2D = null
var boss_health_bar: Control = null
var boss_health_progress: ProgressBar = null
var boss_name_label: Label = null

# --- 观战系统 ---
var spectate_btn: Button = null        # 死亡面板上的"观战"按钮
var exit_game_btn: Button = null       # 死亡面板上的"退出游戏"按钮
var is_spectating: bool = false        # 本地玩家是否正在观战
var spectate_target: CharacterBody2D = null  # 当前观战目标
var spectate_label: Label = null       # 观战信息标签
var spectate_hint_label: Label = null  # 观战切换提示

# 队友信息面板（左下角）
var teammate_panel: PanelContainer = null
var teammate_vbox: VBoxContainer = null
var teammate_entries: Dictionary = {}  # peer_id -> {container, name_label, hp_bar}

# 所有玩家的出生点
var spawn_points: Array = [
	Vector2(-400, -400),
	Vector2(400, -400),
	Vector2(-400, 400),
	Vector2(400, 400),
]

# 宝箱系统
var chest_container: Node2D = null
var chest_count: int = 5
var chest_spawn_timer: float = 0.0
const CHEST_SPAWN_INTERVAL: float = 15.0
var next_chest_id: int = 0

# 加载握手
var _peers_ready: Dictionary = {}


func _get_spawn_bounds() -> Rect2:
	var map_size: Vector2 = Vector2(2400, 2400)
	if is_instance_valid(map_node):
		var ms = map_node.get("map_size")
		if typeof(ms) == TYPE_VECTOR2:
			map_size = ms
	var half: Vector2 = map_size * 0.5
	var margin: float = 100.0
	return Rect2(-half + Vector2(margin, margin), map_size - Vector2(margin * 2, margin * 2))


func _ready() -> void:
	_create_kill_feed()
	_create_minimap()

	# 通知 NetworkManager 游戏开始
	NetworkManager.set_game_started(NetworkManager.GameMode.ZOMBIE)

	high_wave = GameSettings.get_value("game", "high_wave", 0)
	money = 0
	GameSettings.set_value("game", "money", 0)

	if ui_layer:
		ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceLoader.exists("res://scenes/game/zombie_mode/Zombie.tscn"):
		enemy_scene = load("res://scenes/game/zombie_mode/Zombie.tscn")

	# 创建玩家容器
	player_container = Node2D.new()
	player_container.name = "Players"
	add_child(player_container)

	# 生成所有玩家
	_spawn_players()

	# 死亡界面：联机模式不用"再开一局"，改为"观战"+"退出游戏"
	if death_restart_btn:
		death_restart_btn.visible = false  # 联机模式隐藏重启按钮
	if death_menu_btn:
		death_menu_btn.pressed.connect(_on_exit_game_pressed)
		death_menu_btn.visible = false  # 默认隐藏，死亡时根据情况显示
	if death_panel:
		death_panel.visible = false

	# 动态创建"观战"按钮
	spectate_btn = Button.new()
	spectate_btn.name = "SpectateBtn"
	spectate_btn.custom_minimum_size = Vector2(0, 45)
	spectate_btn.text = GameSettings.t("spectate")
	spectate_btn.visible = false
	spectate_btn.pressed.connect(_on_spectate_pressed)
	if death_panel and death_panel.has_node("VBox"):
		death_panel.get_node("VBox").add_child(spectate_btn)

	# 动态创建"退出游戏"按钮
	exit_game_btn = Button.new()
	exit_game_btn.name = "ExitGameBtn"
	exit_game_btn.custom_minimum_size = Vector2(0, 45)
	exit_game_btn.text = GameSettings.t("exit_game")
	exit_game_btn.visible = false
	exit_game_btn.pressed.connect(_on_exit_game_pressed)
	if death_panel and death_panel.has_node("VBox"):
		death_panel.get_node("VBox").add_child(exit_game_btn)

	# 观战信息标签（屏幕上方）
	spectate_label = Label.new()
	spectate_label.name = "SpectateLabel"
	spectate_label.visible = false
	spectate_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	spectate_label.offset_top = 50
	spectate_label.offset_bottom = 80
	spectate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spectate_label.add_theme_font_size_override("font_size", 22)
	spectate_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
	ui_layer.add_child(spectate_label)

	spectate_hint_label = Label.new()
	spectate_hint_label.name = "SpectateHintLabel"
	spectate_hint_label.visible = false
	spectate_hint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	spectate_hint_label.offset_top = 82
	spectate_hint_label.offset_bottom = 106
	spectate_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spectate_hint_label.add_theme_font_size_override("font_size", 16)
	spectate_hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	ui_layer.add_child(spectate_hint_label)

	if exit_confirm_btn:
		exit_confirm_btn.pressed.connect(_on_exit_confirm)
	if exit_cancel_btn:
		exit_cancel_btn.pressed.connect(_on_exit_cancel)
	if exit_panel:
		exit_panel.visible = false

	_init_shop_ui()
	_create_boss_health_bar()
	_create_pause_menu()

	death_title_label = $UI/DeathPanel/VBox/TitleLabel
	exit_label = $UI/ExitConfirmPanel/VBox/Label
	shop_title_label = shop_vbox.get_node_or_null("Title")

	_apply_language()
	if shop_panel:
		shop_panel.visible = false

	_spawn_crosshair()
	_update_money_ui()
	_create_console()
	_create_teammate_panel()
	_create_chest_system()

	# 连接网络事件
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.host_disconnected.connect(_on_host_disconnected)

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# 加载握手：等所有玩家都 ready 后房主才开始第一波
	await get_tree().process_frame
	var my_id: int = multiplayer.get_unique_id()
	if my_id == 1:
		_peers_ready[1] = true
		_check_all_peers_ready()
	else:
		_notify_scene_ready.rpc_id(1)


func _spawn_players() -> void:
	var my_id: int = multiplayer.get_unique_id()
	var my_color: Color = NetworkManager.get_player_color(my_id)

	local_player = _create_player_node(my_id, my_color)
	local_player.set_multiplayer_authority(my_id)

	var spawn_idx: int = _get_spawn_index(my_id)
	local_player.global_position = spawn_points[spawn_idx]

	local_player.health_changed.connect(_on_local_health_changed)
	local_player.died.connect(_on_local_died)

	player_container.add_child(local_player)

	# 远程玩家
	for pid in multiplayer.get_peers():
		_add_remote_player(pid)

	local_player.health_bar = $UI/HealthBar if has_node("UI/HealthBar") else null
	local_player.crosshair = _create_crosshair()

	# 僵尸模式开局只有手枪
	local_player.has_rifle = false
	local_player.has_sniper = false
	local_player.has_machinegun = false
	local_player.grenade_count = 1
	# 应用特长
	var ld: Dictionary = LoadoutManager.get_current_loadout()
	local_player.perks = ld.get("perks", [-1, -1, -1])
	local_player._apply_perk_effects()
	local_player._update_weapon_ui()


func _get_spawn_index(peer_id: int) -> int:
	var all_ids: Array = [multiplayer.get_unique_id()]
	for pid in multiplayer.get_peers():
		all_ids.append(pid)
	all_ids.sort()
	return all_ids.find(peer_id) % spawn_points.size()


func _create_player_node(peer_id: int, color: Color) -> CharacterBody2D:
	var player: CharacterBody2D = CharacterBody2D.new()
	player.name = "Player_%d" % peer_id
	player.set_script(load("res://scripts/MultiplayerPlayer.gd"))

	var sprite: Polygon2D = Polygon2D.new()
	sprite.name = "Sprite2D"
	player.add_child(sprite)

	var weapon_mount: Node2D = Node2D.new()
	weapon_mount.name = "WeaponMount"
	player.add_child(weapon_mount)

	var weapon_pivot: Node2D = Node2D.new()
	weapon_pivot.name = "WeaponPivot"
	weapon_mount.add_child(weapon_pivot)

	var muzzle_flash: ColorRect = ColorRect.new()
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.size = Vector2(10, 4)
	muzzle_flash.position = Vector2(30, -2)
	muzzle_flash.color = Color(1, 0.8, 0.2, 1)
	weapon_pivot.add_child(muzzle_flash)

	var camera: Camera2D = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.5, 1.5)
	player.add_child(camera)

	var hit_timer: Timer = Timer.new()
	hit_timer.name = "HitTimer"
	hit_timer.one_shot = true
	player.add_child(hit_timer)

	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	player.add_child(col)

	player.player_color = color
	player.set_multiplayer_authority(peer_id)

	return player


func _create_crosshair() -> Node2D:
	var crosshair: Node2D = Node2D.new()
	crosshair.name = "Crosshair"
	crosshair.set_script(load("res://UI/Crosshair.gd") if ResourceLoader.exists("res://UI/Crosshair.gd") else null)
	crosshair.top_level = true
	add_child(crosshair)
	return crosshair


func _add_remote_player(peer_id: int) -> void:
	if remote_players.has(peer_id):
		return
	var color: Color = NetworkManager.get_player_color(peer_id)
	var remote: CharacterBody2D = _create_player_node(peer_id, color)
	remote.set_multiplayer_authority(peer_id)
	var spawn_idx: int = _get_spawn_index(peer_id)
	remote.global_position = spawn_points[spawn_idx]
	player_container.add_child(remote)
	remote_players[peer_id] = remote
	# 远程玩家死亡：检查是否全员阵亡，而非直接结束游戏
	remote.died.connect(_on_remote_player_died)


func _on_player_joined(peer_id: int) -> void:
	_add_remote_player(peer_id)


# === 加载握手 ===
@rpc("any_peer", "call_remote", "reliable")
func _notify_scene_ready() -> void:
	if multiplayer.get_unique_id() != 1:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_peers_ready[sender] = true
	_check_all_peers_ready()


func _check_all_peers_ready() -> void:
	var all_peers: Array = multiplayer.get_peers()
	for pid in all_peers:
		if not _peers_ready.get(pid, false):
			return
	# 全部就绪：开启同步 + 房主开始第一波
	_broadcast_sync_start.rpc()
	_on_sync_start()


@rpc("authority", "call_remote", "reliable")
func _broadcast_sync_start() -> void:
	_on_sync_start()


func _on_sync_start() -> void:
	if local_player and is_instance_valid(local_player):
		local_player._sync_enabled = true
	# 房主负责开始第一波
	if NetworkManager.is_host:
		start_next_wave()




func _on_player_left(peer_id: int) -> void:
	var left_name: String = NetworkManager.get_player_display_name(peer_id)
	if remote_players.has(peer_id):
		# 如果正在观战离开的玩家，切换目标
		if is_spectating and spectate_target == remote_players[peer_id]:
			spectate_target = null
			_cycle_spectate_target()
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
	_show_exit_notify(left_name)
	# 检查是否全员阵亡（离开的玩家也算"没了"）
	if local_player and local_player.dead:
		_check_all_dead()


func _on_host_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_local_health_changed(new_hp: int, _max_hp: int) -> void:
	if health_label:
		health_label.text = GameSettings.t("health", [new_hp])
	# 血量更新由 health_bar 自动处理，不在这里触发 game_over
	# game_over 由 _on_local_died() 和远程玩家 died 信号统一触发


func _on_local_died() -> void:
	# 本机玩家死亡：不立即结束游戏，显示观战/退出面板
	_show_death_panel()
	# 检查是否全员阵亡（如果是，触发 game_over 停止波次等）
	_check_all_dead()


func _on_remote_player_died() -> void:
	# 远程玩家死亡：如果正在观战该玩家，切换目标
	if is_spectating and spectate_target and is_instance_valid(spectate_target):
		if spectate_target.get("dead") == true:
			_cycle_spectate_target()
	# 检查是否全员阵亡
	_check_all_dead()


func _get_living_remote_players() -> Array:
	var living: Array = []
	for pid in remote_players:
		var rp: CharacterBody2D = remote_players[pid]
		if is_instance_valid(rp) and not rp.dead:
			living.append(rp)
	return living


func _check_all_dead() -> bool:
	# 检查是否所有玩家都阵亡了
	if local_player and not local_player.dead:
		return false
	for pid in remote_players:
		var rp: CharacterBody2D = remote_players[pid]
		if is_instance_valid(rp) and not rp.dead:
			return false
	# 全员阵亡 → 游戏结束
	_game_over()
	return true


func _show_death_panel() -> void:
	# 隐藏 BOSS 血条
	if boss_health_bar:
		boss_health_bar.visible = false

	if current_wave > high_wave:
		high_wave = current_wave
		GameSettings.set_value("game", "high_wave", high_wave)

	var living_remotes: Array = _get_living_remote_players()

	if death_panel:
		death_panel.visible = true
	if death_title_label:
		death_title_label.text = GameSettings.t("you_died")
	if death_wave_label:
		death_wave_label.text = GameSettings.t("survived_to_wave", [current_wave])

	# 隐藏旧按钮
	if death_restart_btn:
		death_restart_btn.visible = false
	if death_menu_btn:
		death_menu_btn.visible = false

	if living_remotes.size() > 0:
		# 还有队友存活：显示"观战"+"退出游戏"
		if death_high_label:
			death_high_label.text = GameSettings.t("teammates_fighting", [living_remotes.size()])
		if spectate_btn:
			spectate_btn.visible = true
			spectate_btn.text = GameSettings.t("spectate")
		if exit_game_btn:
			exit_game_btn.visible = true
			exit_game_btn.text = GameSettings.t("exit_game")
	else:
		# 全员阵亡：显示"返回主菜单"
		if death_high_label:
			death_high_label.text = GameSettings.t("highest_wave", [high_wave])
		if spectate_btn:
			spectate_btn.visible = false
		if exit_game_btn:
			exit_game_btn.visible = true
			exit_game_btn.text = GameSettings.t("return_menu")
		if death_title_label:
			death_title_label.text = GameSettings.t("all_dead")


func _on_spectate_pressed() -> void:
	_start_spectate()


func _on_exit_game_pressed() -> void:
	NetworkManager.disconnect_network()
	GameSettings.set_value("game", "money", 0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _start_spectate() -> void:
	is_spectating = true
	if death_panel:
		death_panel.visible = false
	# 找到第一个存活的远程玩家作为观战目标
	_cycle_spectate_target()
	# 摄像机脱离本地玩家，设为 top_level 跟随观战目标
	if local_player and local_player.has_method("get") and local_player.get("camera"):
		var cam: Camera2D = local_player.get("camera")
		cam.top_level = true
	# 显示观战信息
	if spectate_label:
		spectate_label.visible = true
	if spectate_hint_label:
		spectate_hint_label.text = GameSettings.t("spectate_switch_hint")
		spectate_hint_label.visible = true
	_update_spectate_label()


func _cycle_spectate_target() -> void:
	var living: Array = _get_living_remote_players()
	if living.size() == 0:
		# 没有存活队友了 → 显示全员阵亡面板
		_stop_spectate()
		_show_death_panel()
		return
	# 找下一个目标（循环切换）
	var current_idx: int = -1
	if spectate_target and is_instance_valid(spectate_target):
		current_idx = living.find(spectate_target)
	var next_idx: int = (current_idx + 1) % living.size()
	spectate_target = living[next_idx]
	_update_spectate_label()


func _stop_spectate() -> void:
	is_spectating = false
	spectate_target = null
	if spectate_label:
		spectate_label.visible = false
	if spectate_hint_label:
		spectate_hint_label.visible = false


func _update_spectate_label() -> void:
	if not spectate_label:
		return
	if spectate_target and is_instance_valid(spectate_target):
		var pid: int = spectate_target.get_multiplayer_authority()
		var display_name: String = NetworkManager.get_player_display_name(pid)
		spectate_label.text = GameSettings.t("spectating_label", [display_name])
	else:
		spectate_label.text = GameSettings.t("spectating_label", ["..."])


# =============================================================================
# 波次系统（仅房主执行）
# =============================================================================
func _process(_delta: float) -> void:
	if NetworkManager.is_host and wave_in_progress:
		_check_wave_complete()
	# 更新队友信息面板
	_update_teammate_panel()
	# 观战模式：摄像机跟随观战目标
	if is_spectating and spectate_target and is_instance_valid(spectate_target):
		if local_player and local_player.has_method("get") and local_player.get("camera"):
			var cam: Camera2D = local_player.get("camera")
			cam.global_position = spectate_target.global_position
	elif is_spectating and (not spectate_target or not is_instance_valid(spectate_target)):
		# 观战目标失效，尝试切换
		_cycle_spectate_target()


func _input(event: InputEvent) -> void:
	# 观战模式：按空格切换观战目标
	if is_spectating and event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_cycle_spectate_target()


func start_next_wave() -> void:
	if not NetworkManager.is_host:
		return

	current_wave += 1
	wave_in_progress = true
	enemies_killed = 0

	var normal_count: int = base_enemy_count + (current_wave - 1) * 3
	var elite_count: int = 0
	var boss_count: int = 0

	if current_wave >= 5:
		@warning_ignore("integer_division")
		elite_count = maxi(1, current_wave / 5)
	if current_wave >= 10 and current_wave % 10 == 0:
		boss_count = 1

	enemies_remaining = normal_count + elite_count + boss_count
	_update_wave_ui()
	wave_started.emit(current_wave)
	_spawn_wave_enemies(normal_count, elite_count, boss_count)
	_show_wave_announcement()

	# 同步波次信息到客户端
	_sync_wave_info.rpc(current_wave, enemies_remaining)


@rpc("authority", "call_remote", "reliable")
func _sync_wave_info(wave: int, remaining: int) -> void:
	current_wave = wave
	enemies_remaining = remaining
	_update_wave_ui()


func _spawn_wave_enemies(normal_count: int, elite_count: int, boss_count: int) -> void:
	"""房主调用：生成僵尸并同步位置到客户端"""
	# 所有客户端都执行此函数，但只在自己的树上生成僵尸
	# PackedFloat64Array 格式：[x1, y1, type1, x2, y2, type2, ...] 
	# type: 0-3=普通品种, 10=精英, 20=BOSS

	var total: int = normal_count + elite_count + boss_count
	
	if not enemy_scene:
		for i in range(total):
			_spawn_temp_zombie()
		if NetworkManager.is_host and total > 0:
			_rpc_spawn_wave.rpc(PackedFloat64Array())  # 空数据通知客户端生成临时僵尸
		return
	
	var bounds: Rect2 = _get_spawn_bounds()
	var min_pos: Vector2 = bounds.position
	var max_pos: Vector2 = bounds.end
	
	# 根据波次决定可以生成哪些品种（0=普通，1=速度型，2=坦克型，3=爆炸型）
	var available_types: Array = [0]
	if current_wave >= 3:
		available_types.append(1)
	if current_wave >= 5:
		available_types.append(2)
	if current_wave >= 7:
		available_types.append(3)
	
	# 生成所有僵尸的出生位置
	var spawn_data: PackedFloat64Array = []
	
	# 普通僵尸（可能混入新种类）
	for i in range(normal_count):
		var p: Vector2 = _get_valid_spawn_pos(min_pos, max_pos)
		var type_to_use: int = 0
		if randf() < 0.3 and available_types.size() > 1:
			type_to_use = available_types[randi() % available_types.size()]
		spawn_data.append_array([p.x, p.y, float(type_to_use)])
	
	# 精英僵尸（type=10）
	for i in range(elite_count):
		var p: Vector2 = _get_valid_spawn_pos(min_pos, max_pos)
		spawn_data.append_array([p.x, p.y, 10.0])
	
	# BOSS（type=20）
	for i in range(boss_count):
		var p: Vector2 = _get_valid_spawn_pos(min_pos, max_pos)
		spawn_data.append_array([p.x, p.y, 20.0])
	
	# 房主和客户端都使用相同的位置数据生成
	_spawn_wave_from_data(spawn_data)
	
	# 房主：RPC 通知客户端用相同位置生成僵尸
	if NetworkManager.is_host:
		_rpc_spawn_wave.rpc(spawn_data)


func _get_valid_spawn_pos(min_pos: Vector2, max_pos: Vector2) -> Vector2:
	"""生成一个远离本地玩家的有效出生位置"""
	for attempt in range(20):
		var pos: Vector2 = Vector2(randf_range(min_pos.x, max_pos.x), randf_range(min_pos.y, max_pos.y))
		if local_player and pos.distance_to(local_player.global_position) > 250.0:
			return pos
	return Vector2(randf_range(min_pos.x, max_pos.x), randf_range(min_pos.y, max_pos.y))


func _spawn_wave_from_data(spawn_data: PackedFloat64Array) -> void:
	"""根据位置数据生成僵尸（房主和客户端共用）"""
	for i in range(0, spawn_data.size(), 3):
		var pos: Vector2 = Vector2(spawn_data[i], spawn_data[i + 1])
		var enemy_type: int = int(spawn_data[i + 2])
		
		var enemy: CharacterBody2D = enemy_scene.instantiate()
		
		# 解析类型：<10=普通品种，10=精英，>=20=BOSS
		var is_elite: bool = (enemy_type == 10)
		var is_boss: bool = (enemy_type >= 20)
		var zombie_variant: int = enemy_type if not is_elite and not is_boss else 0
		
		_configure_enemy_at(enemy, pos, is_elite, is_boss, zombie_variant)


func _configure_enemy_at(enemy: CharacterBody2D, pos: Vector2, elite: bool, boss: bool, variant: int = 0) -> void:
	"""在指定位置配置僵尸（使用固定位置，不再随机）"""
	enemy.global_position = pos

	if enemy.has_method("set"):
		enemy.set("is_elite", elite)
		enemy.set("is_boss", boss)
		enemy.set("zombie_type", variant)

	enemy_container.add_child(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	if boss:
		boss_node = enemy
		if enemy.has_signal("health_changed"):
			enemy.health_changed.connect(_on_boss_health_changed)
		if boss_health_bar:
			boss_health_progress.max_value = enemy.max_health
			boss_health_progress.value = enemy.max_health
			boss_health_bar.visible = true


func _spawn_temp_zombie() -> void:
	var zombie: CharacterBody2D = CharacterBody2D.new()
	zombie.name = "Zombie"
	zombie.add_to_group("enemy")
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	zombie.add_child(col)
	var vis: ColorRect = ColorRect.new()
	vis.color = Color.GREEN
	vis.size = Vector2(32, 32)
	vis.position = Vector2(-16, -16)
	zombie.add_child(vis)
	var ai_script: GDScript = load("res://scripts/ZombieAI.gd")
	if ai_script:
		zombie.set_script(ai_script)
	var bounds: Rect2 = _get_spawn_bounds()
	var min_pos: Vector2 = bounds.position
	var max_pos: Vector2 = bounds.end
	var spawn_pos: Vector2
	for attempt in range(20):
		spawn_pos = Vector2(randf_range(min_pos.x, max_pos.x), randf_range(min_pos.y, max_pos.y))
		if local_player and spawn_pos.distance_to(local_player.global_position) > 200.0:
			break
	zombie.global_position = spawn_pos
	enemy_container.add_child(zombie)
	if zombie.has_signal("died"):
		zombie.died.connect(_on_enemy_died)


func _check_wave_complete() -> void:
	if enemies_remaining <= 0:
		if enemy_container.get_child_count() == 0:
			_finish_wave()
		else:
			await get_tree().process_frame
			if enemy_container.get_child_count() == 0:
				_finish_wave()


func _finish_wave() -> void:
	wave_in_progress = false
	wave_completed.emit(current_wave)
	if current_wave > high_wave:
		high_wave = current_wave
		GameSettings.set_value("game", "high_wave", high_wave)
	_open_shop()


func _on_enemy_died(_enemy: Node2D, killed_by: Node = null) -> void:
	enemies_remaining -= 1
	# 只有玩家造成的击杀才计分和奖励
	var is_player_kill: bool = false
	if killed_by and is_instance_valid(killed_by):
		if killed_by.is_in_group("player"):
			is_player_kill = true
	var kill_reward: int = 0
	if is_player_kill:
		enemies_killed += 1
		kill_reward = 50 + current_wave * 10
		money += kill_reward
		GameSettings.set_value("game", "money", money)
		_update_money_ui()
		# XP 增加：普通击杀 +5 XP，精英 +35 XP，BOSS +75 XP
		var xp_gain: int = 5
		if _enemy.get("is_elite") == true:
			xp_gain = 35
		elif _enemy.get("is_boss") == true:
			xp_gain = 75
		GameSettings.add_xp(xp_gain)
		# 击杀通知（BOSS 有单独的大通知，这里只处理普通/精英）
		if _enemy.get("is_boss") != true:
			var zombie_name: String = _get_zombie_name(_enemy)
			_show_kill_notification(zombie_name, xp_gain)
		# 清道夫 Perk：击杀掉落弹药补给包
		if local_player.perks[0] == 1:
			local_player._spawn_ammo_pack(_enemy.global_position)
	_update_enemies_ui()

	# 屏幕震动 + 血液特效（任何敌人死亡都有视觉反馈）
	if is_instance_valid(local_player):
		local_player.screen_shake(3.0, 0.15)
	_spawn_blood_vfx(_enemy.global_position)

	# BOSS 死亡：隐藏血条 + 击杀通知
	if _enemy == boss_node:
		boss_node = null
		if boss_health_bar:
			boss_health_bar.visible = false
		if is_player_kill:
			_show_boss_kill_notification()

	# 同步敌人剩余数和击杀奖励到客户端（合作模式：全员共享击杀奖励）
	if NetworkManager.is_host:
		_sync_enemies_remaining.rpc(enemies_remaining)
		_sync_kill_reward.rpc(kill_reward)


@rpc("authority", "call_remote", "reliable")
func _sync_kill_reward(reward: int) -> void:
	# 客户端收到击杀奖励（合作模式所有玩家共享）
	money += reward
	GameSettings.set_value("game", "money", money)
	_update_money_ui()


@rpc("authority", "call_remote", "reliable")
func _sync_enemies_remaining(remaining: int) -> void:
	enemies_remaining = remaining
	_update_enemies_ui()


# =============================================================================
# 商店系统（每个玩家本地独立购买，房主只控制开关时机）
# =============================================================================
func _open_shop() -> void:
	shop_open = true
	var wave_reward: int = 100 + current_wave * 20
	money += wave_reward
	GameSettings.set_value("game", "money", money)
	_update_money_ui()
	if shop_panel:
		shop_panel.visible = true
		get_tree().paused = true
	# 通知客户端商店打开（只发波次奖励金额，不发房主总金钱）
	if NetworkManager.is_host:
		_sync_shop_open.rpc(wave_reward)


@rpc("authority", "call_remote", "reliable")
func _sync_shop_open(reward: int) -> void:
	# 客户端收到商店打开通知：把波次奖励加到自己的金钱上
	money += reward
	GameSettings.set_value("game", "money", money)
	_update_money_ui()
	shop_open = true
	if shop_panel:
		shop_panel.visible = true
	get_tree().paused = true


func _close_shop() -> void:
	# 只有房主能关闭商店并开始下一波，客户端等待房主同步
	if not NetworkManager.is_host:
		return
	shop_open = false
	if shop_panel:
		shop_panel.visible = false
	get_tree().paused = false
	start_next_wave()
	_sync_shop_close.rpc()


@rpc("authority", "call_remote", "reliable")
func _sync_shop_close() -> void:
	# 客户端收到商店关闭通知
	shop_open = false
	if shop_panel:
		shop_panel.visible = false
	get_tree().paused = false


# =============================================================================
# BOSS血条
# =============================================================================
func _create_boss_health_bar() -> void:
	boss_health_bar = Control.new()
	boss_health_bar.name = "BossHealthBar"
	boss_health_bar.visible = false
	boss_health_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	boss_name_label = Label.new()
	boss_name_label.text = GameSettings.t("boss_name")
	boss_name_label.position = Vector2(0, 50)
	boss_name_label.size = Vector2(1280, 30)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 22)
	boss_name_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	boss_health_bar.add_child(boss_name_label)

	boss_health_progress = ProgressBar.new()
	boss_health_progress.position = Vector2(390, 82)
	boss_health_progress.size = Vector2(500, 24)
	boss_health_progress.min_value = 0
	boss_health_progress.max_value = 10000
	boss_health_progress.value = 10000
	boss_health_progress.show_percentage = false

	var pb_bg: StyleBoxFlat = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.15, 0.0, 0.0, 0.9)
	pb_bg.border_width_left = 2
	pb_bg.border_width_top = 2
	pb_bg.border_width_right = 2
	pb_bg.border_width_bottom = 2
	pb_bg.border_color = Color(0.5, 0.0, 0.0, 1)
	boss_health_progress.add_theme_stylebox_override("background", pb_bg)

	var pb_fill: StyleBoxFlat = StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.8, 0.1, 0.1, 1)
	boss_health_progress.add_theme_stylebox_override("fill", pb_fill)
	boss_health_bar.add_child(boss_health_progress)

	ui_layer.add_child(boss_health_bar)


func _on_boss_health_changed(current: int, _max_val: int) -> void:
	if boss_health_progress:
		boss_health_progress.value = current
	# 同步BOSS血量到客户端
	if NetworkManager.is_host:
		_sync_boss_health.rpc(current)


@rpc("authority", "call_remote", "reliable")
func _sync_boss_health(hp: int) -> void:
	if boss_health_progress:
		boss_health_progress.value = hp


@rpc("authority", "call_remote", "reliable")
func _sync_enemy_grenade(pos: Vector2, dmg: int, radius: float) -> void:
	# 客户端收到 BOSS 手榴弹爆炸通知，检查本地玩家是否在范围内
	if local_player and not local_player.dead:
		if local_player.global_position.distance_to(pos) <= radius:
			local_player.take_damage(dmg)


# =============================================================================
# 其他辅助（与单机版一致）
# =============================================================================
func _create_console() -> void:
	var console_script: GDScript = load("res://scripts/Console.gd")
	if console_script:
		console = CanvasLayer.new()
		console.set_script(console_script)
		add_child(console)


func _create_kill_feed() -> void:
	kill_feed_container = VBoxContainer.new()
	kill_feed_container.name = "KillFeed"
	kill_feed_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	kill_feed_container.position = Vector2(0, 120)
	kill_feed_container.alignment = BoxContainer.ALIGNMENT_CENTER
	kill_feed_container.add_theme_constant_override("separation", 8)
	kill_feed_container.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(kill_feed_container)


func _show_kill_notification(victim_name: String, xp_amount: int) -> void:
	if not is_instance_valid(kill_feed_container):
		return
	var notif: Label = Label.new()
	notif.text = GameSettings.t("kill_notify", [victim_name, xp_amount])
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.add_theme_font_size_override("font_size", 22)
	notif.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))
	notif.modulate = Color(1, 1, 1, 1)
	notif.process_mode = Node.PROCESS_MODE_ALWAYS
	kill_feed_container.add_child(notif)
	var tween: Tween = notif.create_tween()
	tween.tween_property(notif, "position:y", notif.position.y - 60, 2.0)
	tween.parallel().tween_property(notif, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func(): notif.queue_free())


func _show_boss_kill_notification() -> void:
	"""BOSS击杀通知（大字体，红色闪烁，战地5风格上滑淡出）"""
	if not is_instance_valid(kill_feed_container):
		return
	var notif: Label = Label.new()
	notif.text = GameSettings.t("boss_kill_notify")
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.add_theme_font_size_override("font_size", 28)
	notif.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))  # 红色
	notif.modulate = Color(1, 1, 1, 1)
	notif.process_mode = Node.PROCESS_MODE_ALWAYS
	kill_feed_container.add_child(notif)
	var tween: Tween = notif.create_tween()
	tween.tween_property(notif, "position:y", notif.position.y - 80, 3.0)
	tween.parallel().tween_property(notif, "modulate:a", 0.0, 3.0)
	tween.tween_callback(func(): notif.queue_free())


func _create_minimap() -> void:
	var minimap: Control = Control.new()
	minimap.set_script(load("res://scripts/Minimap.gd"))
	minimap.name = "Minimap"
	ui_layer.add_child(minimap)


func _spawn_crosshair() -> void:
	if ResourceLoader.exists("res://UI/Crosshair.tscn"):
		var ch: Node2D = load("res://UI/Crosshair.tscn").instantiate()
		get_tree().current_scene.add_child(ch)
		if is_instance_valid(local_player):
			local_player.crosshair = ch
			local_player._update_crosshair()


func _on_pause_input() -> void:
	if shop_open:
		_close_shop()
	else:
		_toggle_pause()


func _create_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visible = false
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = Color(0, 0, 0, 0.7)
	panel.add_theme_stylebox_override("panel", pstyle)
	pause_menu.add_child(panel)

	var input_handler: Node = Node.new()
	input_handler.name = "PauseInputHandler"
	input_handler.process_mode = Node.PROCESS_MODE_ALWAYS
	input_handler.set_script(load("res://scripts/PauseInputHandler.gd"))
	input_handler.toggle_callable = _on_pause_input
	pause_menu.add_child(input_handler)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 300)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title: Label = Label.new()
	title.name = "PauseTitle"
	title.text = GameSettings.t("pause_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var resume_btn: Button = Button.new()
	resume_btn.name = "ResumeBtn"
	resume_btn.text = GameSettings.t("resume")
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	var settings_btn: Button = Button.new()
	settings_btn.name = "SettingsBtn"
	settings_btn.text = GameSettings.t("settings")
	settings_btn.pressed.connect(_on_pause_settings)
	vbox.add_child(settings_btn)

	var quit_btn: Button = Button.new()
	quit_btn.name = "QuitBtn"
	quit_btn.text = GameSettings.t("quit_game")
	quit_btn.pressed.connect(_on_quit_to_menu)
	vbox.add_child(quit_btn)

	ui_layer.add_child(pause_menu)


func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	if pause_menu:
		pause_menu.visible = paused


func _on_resume() -> void:
	paused = false
	get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false


func _on_pause_settings() -> void:
	if settings_instance:
		return
	var settings_scene: PackedScene = load("res://UI/settings.tscn")
	if not settings_scene:
		return
	settings_instance = settings_scene.instantiate()
	settings_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_instance.on_close_callback = func(): _on_settings_closed()
	ui_layer.add_child(settings_instance)
	if pause_menu:
		pause_menu.visible = false


func _on_settings_closed() -> void:
	if settings_instance:
		settings_instance.queue_free()
		settings_instance = null
	if pause_menu:
		pause_menu.visible = true
	_apply_language()


func _on_quit_to_menu() -> void:
	NetworkManager.disconnect_network()
	GameSettings.set_value("game", "money", 0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _init_shop_ui() -> void:
	if not shop_vbox:
		return
	money_label = shop_vbox.get_node_or_null("MoneyLabel")
	hp_btn = shop_vbox.get_node_or_null("HPUpgradeBtn")
	dmg_btn = shop_vbox.get_node_or_null("DamageUpgradeBtn")
	ammo_btn = shop_vbox.get_node_or_null("AmmoBuyBtn")
	continue_btn = shop_vbox.get_node_or_null("ContinueBtn")

	if hp_btn:
		hp_btn.pressed.connect(_on_hp_upgrade)
	if dmg_btn:
		dmg_btn.pressed.connect(_on_damage_upgrade)
	if ammo_btn:
		ammo_btn.pressed.connect(_on_ammo_buy)
	if continue_btn:
		continue_btn.pressed.connect(_close_shop)
		# 客户端的 Continue 按钮禁用——只有房主能开始下一波
		if not NetworkManager.is_host:
			continue_btn.disabled = true

	grenade_btn = Button.new()
	grenade_btn.name = "GrenadeBuyBtn"
	grenade_btn.pressed.connect(_on_grenade_buy)
	var btn_index: int = shop_vbox.get_child_count()
	if continue_btn and continue_btn.get_parent() == shop_vbox:
		btn_index = continue_btn.get_index()
	shop_vbox.add_child(grenade_btn)
	shop_vbox.move_child(grenade_btn, btn_index)

	rifle_btn = Button.new()
	rifle_btn.name = "RifleBuyBtn"
	rifle_btn.pressed.connect(_on_rifle_buy)
	var rifle_idx: int = shop_vbox.get_child_count()
	if continue_btn and continue_btn.get_parent() == shop_vbox:
		rifle_idx = continue_btn.get_index()
	shop_vbox.add_child(rifle_btn)
	shop_vbox.move_child(rifle_btn, rifle_idx)

	sniper_btn = Button.new()
	sniper_btn.name = "SniperBuyBtn"
	sniper_btn.pressed.connect(_on_sniper_buy)
	var sniper_idx: int = shop_vbox.get_child_count()
	if continue_btn and continue_btn.get_parent() == shop_vbox:
		sniper_idx = continue_btn.get_index()
	shop_vbox.add_child(sniper_btn)
	shop_vbox.move_child(sniper_btn, sniper_idx)

	mg_btn = Button.new()
	mg_btn.name = "MGBuyBtn"
	mg_btn.pressed.connect(_on_mg_buy)
	var mg_idx: int = shop_vbox.get_child_count()
	if continue_btn and continue_btn.get_parent() == shop_vbox:
		mg_idx = continue_btn.get_index()
	shop_vbox.add_child(mg_btn)
	shop_vbox.move_child(mg_btn, mg_idx)

	_update_shop_buttons()


func _update_shop_buttons() -> void:
	if hp_btn:
		hp_btn.text = GameSettings.t("upgrade_hp", [hp_price])
		hp_btn.disabled = money < hp_price
	if dmg_btn:
		dmg_btn.text = GameSettings.t("upgrade_damage", [damage_price])
		dmg_btn.disabled = money < damage_price
	if ammo_btn:
		ammo_btn.text = GameSettings.t("buy_ammo", [ammo_price])
		ammo_btn.disabled = money < ammo_price
	if grenade_btn:
		grenade_btn.text = GameSettings.t("buy_grenade", [grenade_price])
		grenade_btn.disabled = money < grenade_price
	if rifle_btn:
		if rifle_purchased:
			rifle_btn.text = GameSettings.t("rifle_owned")
			rifle_btn.disabled = true
		else:
			rifle_btn.text = GameSettings.t("buy_rifle", [rifle_price])
			rifle_btn.disabled = money < rifle_price
	if sniper_btn:
		if sniper_purchased:
			sniper_btn.text = GameSettings.t("sniper_owned")
			sniper_btn.disabled = true
		else:
			sniper_btn.text = GameSettings.t("buy_sniper", [sniper_price])
			sniper_btn.disabled = money < sniper_price
	if mg_btn:
		if mg_purchased:
			mg_btn.text = GameSettings.t("machinegun_owned")
			mg_btn.disabled = true
		else:
			mg_btn.text = GameSettings.t("buy_machinegun", [mg_price])
			mg_btn.disabled = money < mg_price
	# Continue 按钮：房主显示"下一波"，客户端显示"等待房主"并禁用
	if continue_btn:
		if NetworkManager.is_host:
			continue_btn.text = GameSettings.t("next_wave")
			continue_btn.disabled = false
		else:
			continue_btn.text = GameSettings.t("waiting_for_host")
			continue_btn.disabled = true


func _update_money_ui() -> void:
	if money_label:
		money_label.text = GameSettings.t("balance", [money])
	if money_hud_label:
		money_hud_label.text = GameSettings.t("money_display", [money])
	_update_shop_buttons()


func _on_hp_upgrade() -> void:
	# 每个玩家自己花钱自己买，不经过房主
	if money < hp_price:
		return
	money -= hp_price
	hp_price += 50
	if local_player:
		local_player.max_health += 20
		local_player.current_health = local_player.max_health
		local_player.health_changed.emit(local_player.current_health, local_player.max_health)
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_damage_upgrade() -> void:
	if money < damage_price:
		return
	money -= damage_price
	damage_price += 50
	if local_player:
		for weapon in local_player.weapons:
			weapon.damage += 5
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_ammo_buy() -> void:
	if money < ammo_price:
		return
	money -= ammo_price
	ammo_price += 25
	if local_player:
		for weapon in local_player.weapons:
			weapon.reserve_ammo += 60
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_grenade_buy() -> void:
	if money < grenade_price:
		return
	money -= grenade_price
	grenade_price += 50
	if local_player:
		local_player.grenade_count += 1
		local_player.grenade_changed.emit(local_player.grenade_count)
		local_player._update_weapon_ui()
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_rifle_buy() -> void:
	if rifle_purchased:
		return
	if money < rifle_price:
		return
	money -= rifle_price
	rifle_purchased = true
	if local_player:
		local_player.unlock_rifle()
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_sniper_buy() -> void:
	if sniper_purchased:
		return
	if money < sniper_price:
		return
	money -= sniper_price
	sniper_purchased = true
	if local_player:
		local_player.unlock_sniper()
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_mg_buy() -> void:
	if mg_purchased:
		return
	if money < mg_price:
		return
	money -= mg_price
	mg_purchased = true
	if local_player:
		local_player.unlock_machinegun()
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _update_wave_ui() -> void:
	if wave_label:
		wave_label.text = GameSettings.t("wave", [current_wave])


func _update_enemies_ui() -> void:
	if enemies_label:
		enemies_label.text = GameSettings.t("enemies_left", [enemies_remaining])


func _show_wave_announcement() -> void:
	if wave_label:
		wave_label.modulate.a = 1.0
		var tween: Tween = create_tween()
		tween.tween_property(wave_label, "modulate:a", 0.0, 2.0).set_delay(1.0)


func _game_over() -> void:
	game_over.emit()
	wave_in_progress = false
	_stop_spectate()
	if boss_health_bar:
		boss_health_bar.visible = false
	if current_wave > high_wave:
		high_wave = current_wave
		GameSettings.set_value("game", "high_wave", high_wave)
	if local_player:
		local_player.set_physics_process(false)
		local_player.set_process_input(false)
	get_tree().paused = false
	# 显示全员阵亡面板
	if death_panel:
		death_panel.visible = true
	if death_title_label:
		death_title_label.text = GameSettings.t("all_dead")
	if death_wave_label:
		death_wave_label.text = GameSettings.t("survived_to_wave", [current_wave])
	if death_high_label:
		death_high_label.text = GameSettings.t("highest_wave", [high_wave])
	# 隐藏不需要的按钮
	if death_restart_btn:
		death_restart_btn.visible = false
	if death_menu_btn:
		death_menu_btn.visible = false
	if spectate_btn:
		spectate_btn.visible = false
	if exit_game_btn:
		exit_game_btn.visible = true
		exit_game_btn.text = GameSettings.t("return_menu")


func _apply_language() -> void:
	if death_title_label:
		death_title_label.text = GameSettings.t("you_died")
	if death_restart_btn:
		death_restart_btn.text = GameSettings.t("restart")
	if death_menu_btn:
		death_menu_btn.text = GameSettings.t("return_menu")
	if spectate_btn:
		spectate_btn.text = GameSettings.t("spectate")
	if exit_game_btn:
		exit_game_btn.text = GameSettings.t("exit_game")
	if spectate_hint_label:
		spectate_hint_label.text = GameSettings.t("spectate_switch_hint")
	if exit_label:
		exit_label.text = GameSettings.t("exit_confirm")
	if exit_confirm_btn:
		exit_confirm_btn.text = GameSettings.t("confirm_exit")
	if exit_cancel_btn:
		exit_cancel_btn.text = GameSettings.t("cancel")
	if shop_title_label:
		shop_title_label.text = GameSettings.t("shop_title")
	if continue_btn:
		continue_btn.text = GameSettings.t("next_wave")
	if boss_name_label:
		boss_name_label.text = GameSettings.t("boss_name")
	if pause_menu:
		var pause_title: Label = pause_menu.find_child("PauseTitle", true, false)
		if pause_title:
			pause_title.text = GameSettings.t("pause_title")
		var resume_btn: Button = pause_menu.find_child("ResumeBtn", true, false)
		if resume_btn:
			resume_btn.text = GameSettings.t("resume")
		var settings_btn: Button = pause_menu.find_child("SettingsBtn", true, false)
		if settings_btn:
			settings_btn.text = GameSettings.t("settings")
		var quit_btn: Button = pause_menu.find_child("QuitBtn", true, false)
		if quit_btn:
			quit_btn.text = GameSettings.t("quit_game")
	if is_instance_valid(local_player) and local_player.crosshair:
		local_player._update_crosshair()


func _on_exit_confirm() -> void:
	NetworkManager.disconnect_network()
	GameSettings.set_value("game", "money", 0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_exit_cancel() -> void:
	if exit_panel:
		exit_panel.visible = false
	_on_resume()


func _get_zombie_name(enemy: Node2D) -> String:
	"""根据僵尸类型返回显示名称"""
	if enemy.get('is_boss') == true:
		return GameSettings.t('boss_name')
	if enemy.get('is_elite') == true:
		return GameSettings.t('zombie_elite')
	var type: int = enemy.get('zombie_type') if enemy.has_method('get') else 0
	match type:
		1: return GameSettings.t('zombie_runner')
		2: return GameSettings.t('zombie_tank')
		3: return GameSettings.t('zombie_bomber')
		_: return GameSettings.t('zombie_normal')


func _spawn_blood_vfx(pos: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(12, 20)
	for i in range(count):
		var drop: Polygon2D = Polygon2D.new()
		var angle: float = rng.randf_range(0, TAU)
		var dist: float = rng.randf_range(5, 35)
		drop.position = pos + Vector2(cos(angle), sin(angle)) * dist
		var pts: PackedVector2Array = []
		var sz: float = rng.randf_range(5, 14)
		var vertices: int = rng.randi_range(3, 6)
		for j in range(vertices):
			var a: float = j * TAU / vertices + rng.randf_range(-0.3, 0.3)
			var r: float = sz * rng.randf_range(0.6, 1.0)
			pts.append(Vector2(cos(a) * r, sin(a) * r))
		drop.polygon = pts
		var brightness: float = rng.randf_range(0.6, 1.0)
		drop.color = Color(0.8 * brightness, 0.05 * brightness, 0.0, 1.0)
		scene.add_child(drop)
		var tw: Tween = drop.create_tween()
		tw.tween_interval(5.0)
		tw.tween_property(drop, "color:a", 0.0, 2.5)
		tw.tween_callback(func(): drop.queue_free())

	var pool: Polygon2D = Polygon2D.new()
	var pool_pts: PackedVector2Array = []
	var pool_r: float = rng.randf_range(18, 28)
	var pool_verts: int = 8
	for j in range(pool_verts):
		var a: float = j * TAU / pool_verts + rng.randf_range(-0.2, 0.2)
		var r: float = pool_r * rng.randf_range(0.7, 1.0)
		pool_pts.append(Vector2(cos(a) * r, sin(a) * r))
	pool.polygon = pool_pts
	pool.color = Color(0.6, 0.0, 0.0, 0.9)
	pool.position = pos
	scene.add_child(pool)
	var tw3: Tween = pool.create_tween()
	tw3.tween_interval(6.0)
	tw3.tween_property(pool, "color:a", 0.0, 2.0)
	tw3.tween_callback(func(): pool.queue_free())

	var splash: Polygon2D = Polygon2D.new()
	var splash_pts: PackedVector2Array = []
	var splash_r: float = 8.0
	for j in range(16):
		var a: float = j * TAU / 16
		splash_pts.append(Vector2(cos(a) * splash_r, sin(a) * splash_r))
	splash.polygon = splash_pts
	splash.color = Color(1.0, 0.1, 0.1, 0.7)
	splash.position = pos
	scene.add_child(splash)
	var tw2: Tween = splash.create_tween()
	tw2.tween_property(splash, "scale", Vector2(6, 6), 0.2)
	tw2.parallel().tween_property(splash, "color:a", 0.0, 0.3)
	tw2.tween_callback(func(): splash.queue_free())


# =============================================================================
# 队友信息面板（左下角）
# =============================================================================
func _create_teammate_panel() -> void:
	if not ui_layer:
		return
	teammate_panel = PanelContainer.new()
	teammate_panel.name = "TeammatePanel"
	teammate_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	teammate_panel.offset_left = 10
	teammate_panel.offset_top = -200
	teammate_panel.offset_right = 220
	teammate_panel.offset_bottom = -10
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.5, 0.6, 0.8, 0.7)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 10
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 10
	panel_style.content_margin_bottom = 8
	teammate_panel.add_theme_stylebox_override("panel", panel_style)
	ui_layer.add_child(teammate_panel)

	teammate_vbox = VBoxContainer.new()
	teammate_vbox.name = "TeammateVBox"
	teammate_vbox.add_theme_constant_override("separation", 6)
	teammate_panel.add_child(teammate_vbox)

	# 标题
	var title_lbl: Label = Label.new()
	title_lbl.name = "Title"
	title_lbl.text = GameSettings.t("teammates")
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
	teammate_vbox.add_child(title_lbl)

	var sep: HSeparator = HSeparator.new()
	teammate_vbox.add_child(sep)


func _update_teammate_panel() -> void:
	if not teammate_panel or not teammate_vbox:
		return

	# 添加新队友条目
	for pid in remote_players:
		if not teammate_entries.has(pid):
			_add_teammate_entry(pid)

	# 移除已离开的玩家条目
	for pid in teammate_entries.keys():
		if not remote_players.has(pid):
			_remove_teammate_entry(pid)

	# 更新每个条目的血量
	for pid in teammate_entries:
		var rp: CharacterBody2D = remote_players.get(pid)
		if not is_instance_valid(rp):
			continue
		var entry: Dictionary = teammate_entries[pid]
		var hp_bar: ProgressBar = entry.hp_bar
		var hp: int = rp.get("current_health") if rp.has_method("get") else 0
		var max_hp: int = rp.get("max_health") if rp.has_method("get") else 100
		hp_bar.value = hp
		hp_bar.max_value = max_hp

		# 根据血量比例设置颜色
		var ratio: float = float(hp) / max_hp if max_hp > 0 else 0.0
		if ratio > 0.5:
			hp_bar.add_theme_color_override("fill", Color(0.2, 0.8, 0.2, 1))
		elif ratio > 0.25:
			hp_bar.add_theme_color_override("fill", Color(0.9, 0.7, 0.1, 1))
		else:
			hp_bar.add_theme_color_override("fill", Color(0.9, 0.2, 0.2, 1))

		# 显示死亡状态
		var dead_val = rp.get("dead") if rp.has_method("get") else false
		if dead_val == true:
			entry.name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
			entry.name_label.text = entry.base_name + " [DEAD]"
		else:
			entry.name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
			entry.name_label.text = entry.base_name


func _add_teammate_entry(peer_id: int) -> void:
	if not teammate_vbox:
		return
	var display_name: String = NetworkManager.get_player_display_name(peer_id)
	if display_name.is_empty():
		display_name = "Player %d" % peer_id

	var container: VBoxContainer = VBoxContainer.new()
	container.name = "Entry_%d" % peer_id
	container.add_theme_constant_override("separation", 2)
	teammate_vbox.add_child(container)

	var name_lbl: Label = Label.new()
	name_lbl.name = "Name"
	name_lbl.text = display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	container.add_child(name_lbl)

	var hp_bar: ProgressBar = ProgressBar.new()
	hp_bar.name = "HP"
	hp_bar.custom_minimum_size = Vector2(0, 10)
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.add_theme_color_override("fill", Color(0.2, 0.8, 0.2, 1))
	container.add_child(hp_bar)

	teammate_entries[peer_id] = {
		"container": container,
		"name_label": name_lbl,
		"hp_bar": hp_bar,
		"base_name": display_name,
	}


func _remove_teammate_entry(peer_id: int) -> void:
	if not teammate_entries.has(peer_id):
		return
	var entry: Dictionary = teammate_entries[peer_id]
	if entry.container and is_instance_valid(entry.container):
		entry.container.queue_free()
	teammate_entries.erase(peer_id)


# =============================================================================
# 僵尸同步 RPC（房主发送精确位置到客户端）
# =============================================================================
@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_wave(spawn_data: PackedFloat64Array) -> void:
	"""客户端收到：用房主的精确位置生成僵尸"""
	if NetworkManager.is_host:
		return  # 房主自己已经生成了
	# 先清除旧僵尸
	for child in enemy_container.get_children():
		child.queue_free()
	# 用房主发送的精确位置生成
	_spawn_wave_from_data(spawn_data)


# =============================================================================
# 退出广播通知
# =============================================================================
func _show_exit_notify(player_name: String) -> void:
	if not ui_layer:
		return
	var notify: Label = Label.new()
	notify.name = "ExitNotify"
	notify.text = GameSettings.t("player_left_notify", [player_name])
	notify.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notify.add_theme_font_size_override("font_size", 24)
	notify.add_theme_color_override("font_color", Color(1, 0.5, 0.2, 1))
	notify.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notify.offset_top = 120
	notify.offset_bottom = 150
	notify.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(notify)
	var tween: Tween = notify.create_tween()
	tween.tween_property(notify, "position:y", notify.position.y - 60, 3.0)
	tween.parallel().tween_property(notify, "modulate:a", 0.0, 3.0)
	tween.tween_callback(func(): notify.queue_free())


# =============================================================================
# 宝箱系统（联机同步）
# =============================================================================
func _create_chest_system() -> void:
	"""创建宝箱容器并初始生成宝箱"""
	chest_container = Node2D.new()
	chest_container.name = "Chests"
	add_child(chest_container)
	
	# 房主负责生成初始宝箱
	if NetworkManager.is_host:
		call_deferred("_spawn_initial_chests")


func _spawn_initial_chests() -> void:
	"""初始生成宝箱（房主调用）"""
	for i in range(chest_count):
		_spawn_chest()


func _spawn_chest() -> void:
	"""生成单个宝箱（房主调用）"""
	if not chest_container:
		return
	
	var cid: int = next_chest_id
	next_chest_id += 1
	
	var money: int = 50 + randi() % 100  # 50-150
	var respawn: float = 20.0 + randf() * 20.0  # 20-40秒
	
	# 随机位置
	var bounds: Rect2 = _get_spawn_bounds()
	var pos: Vector2 = Vector2(
		randf_range(bounds.position.x, bounds.end.x),
		randf_range(bounds.position.y, bounds.end.y)
	)
	
	# 房主本地生成
	_do_spawn_chest(pos, money, respawn, cid)
	
	# 同步到客户端
	_sync_chest_spawn.rpc(pos.x, pos.y, money, respawn, cid)


@rpc("authority", "call_remote", "reliable")
func _sync_chest_spawn(px: float, py: float, money: int, respawn: float, cid: int) -> void:
	"""客户端收到：生成宝箱"""
	if NetworkManager.is_host:
		return  # 房主已经生成了
	
	var pos: Vector2 = Vector2(px, py)
	_do_spawn_chest(pos, money, respawn, cid)


func _do_spawn_chest(pos: Vector2, money: int, respawn: float, cid: int) -> void:
	"""执行生成宝箱"""
	var chest: Area2D = Area2D.new()
	chest.name = "Chest_%d" % cid
	
	var chest_script: GDScript = load("res://scripts/MultiplayerTreasureChest.gd")
	if chest_script:
		chest.set_script(chest_script)
	
	chest.money_amount = money
	chest.respawn_time = respawn
	chest.chest_id = cid
	chest.global_position = pos
	
	chest_container.add_child(chest)
	chest.chest_collected.connect(_on_chest_collected.bind(cid))


func _on_chest_collected(cid: int) -> void:
	"""处理宝箱拾取（本地判定）"""
	# 本地玩家获得金钱
	var chest: Node = chest_container.get_node_or_null("Chest_%d" % cid)
	if not chest:
		return
	
	var amount: int = chest.get("money_amount") if chest.has_method("get") else 50
	money += amount
	GameSettings.set_value("game", "money", money)
	_update_money_ui()
	
	# 显示拾取通知
	_show_chest_notification(amount)
	
	# 通知房主同步移除宝箱
	if not NetworkManager.is_host:
		_request_chest_remove.rpc_id(1, cid)
	else:
		# 房主直接同步移除
		_sync_chest_remove.rpc(cid)
		
		# 启动刷新计时器
		_start_chest_respawn_timer(cid)


@rpc("any_peer", "call_remote", "reliable")
func _request_chest_remove(cid: int) -> void:
	"""客户端请求移除宝箱，房主执行"""
	if not multiplayer.is_server():
		return
	
	# 房主同步移除到所有客户端
	_sync_chest_remove.rpc(cid)
	
	# 启动刷新计时器
	_start_chest_respawn_timer(cid)


@rpc("authority", "call_remote", "reliable")
func _sync_chest_remove(cid: int) -> void:
	"""所有客户端移除宝箱"""
	var chest: Node = chest_container.get_node_or_null("Chest_%d" % cid)
	if chest:
		chest.queue_free()


func _start_chest_respawn_timer(cid: int) -> void:
	"""房主启动宝箱刷新计时器（使用Timer节点）"""
	# 获取刷新时间
	var respawn_time: float = 30.0
	
	# 创建计时器
	var timer: Timer = Timer.new()
	timer.name = "ChestTimer_%d" % cid
	timer.wait_time = respawn_time
	timer.one_shot = true
	timer.timeout.connect(func(): _on_chest_timer_timeout(cid))
	add_child(timer)
	timer.start()


func _on_chest_timer_timeout(cid: int) -> void:
	"""宝箱刷新计时器到期"""
	_respawn_chest(cid)
	
	# 删除计时器
	var timer: Timer = get_node_or_null("ChestTimer_%d" % cid)
	if timer:
		timer.queue_free()


func _respawn_chest(cid: int) -> void:
	"""刷新宝箱（房主调用）"""
	var money: int = 50 + randi() % 100
	var respawn: float = 20.0 + randf() * 20.0
	
	# 随机位置
	var bounds: Rect2 = _get_spawn_bounds()
	var pos: Vector2 = Vector2(
		randf_range(bounds.position.x, bounds.end.x),
		randf_range(bounds.position.y, bounds.end.y)
	)
	
	# 房主本地生成
	_do_spawn_chest(pos, money, respawn, cid)
	
	# 同步到客户端
	_sync_chest_respawn.rpc(pos.x, pos.y, money, respawn, cid)


@rpc("authority", "call_remote", "reliable")
func _sync_chest_respawn(px: float, py: float, money: int, respawn: float, cid: int) -> void:
	"""客户端收到：刷新宝箱"""
	if NetworkManager.is_host:
		return
	
	var pos: Vector2 = Vector2(px, py)
	_do_spawn_chest(pos, money, respawn, cid)


func _show_chest_notification(amount: int) -> void:
	"""显示宝箱拾取通知"""
	if not is_instance_valid(kill_feed_container):
		return
	
	var notif: Label = Label.new()
	notif.text = "  +$%d" % amount
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.add_theme_font_size_override("font_size", 20)
	notif.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
	notif.modulate = Color(1, 1, 1, 1)
	notif.process_mode = Node.PROCESS_MODE_ALWAYS
	kill_feed_container.add_child(notif)
	
	var tween: Tween = notif.create_tween()
	tween.tween_property(notif, "position:y", notif.position.y - 50, 2.0)
	tween.parallel().tween_property(notif, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func(): notif.queue_free())


