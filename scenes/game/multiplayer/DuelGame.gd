extends Node2D

# =============================================================================
# 1v1 单挑模式控制器
# 2人，红蓝两队，不能同队，击杀计分
# 先达到 25 击杀的队伍获胜
# =============================================================================


@onready var map_node: Node2D = $Map
@onready var ui_layer: CanvasLayer = $UI
@onready var kills_label: Label = $UI/KillsLabel
@onready var deaths_label: Label = $UI/DeathsLabel
@onready var health_label: Label = $UI/HealthLabel

# 玩家管理
var player_container: Node2D = null
var local_player: CharacterBody2D = null
var remote_players: Dictionary = {}  # peer_id → CharacterBody2D

# 加载握手：记录哪些 peer 已经 ready
var _peers_ready: Dictionary = {}  # peer_id → true

# 计分（个人）
var kills: int = 0
var deaths: int = 0

# 队伍击杀计数（单挑模式）
var red_kills: int = 0
var blue_kills: int = 0
const DUEL_KILL_LIMIT: int = 25

# 状态
var game_over: bool = false
var paused: bool = false
var pause_menu: Control = null

# 设置
var settings_instance: Control = null

# 死亡面板
var death_panel: Control = null

# 结果面板（胜利/失败）
var result_panel: Control = null

# 击杀通知容器
var kill_feed_container: VBoxContainer = null

# 玩家出生点
var spawn_points: Array = [
	Vector2(-400, -400),  # 红队出生点
	Vector2(400, 400),     # 蓝队出生点
]


func _ready() -> void:
	if ui_layer:
		ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	# 通知 NetworkManager 游戏开始
	NetworkManager.set_game_started(NetworkManager.GameMode.DUEL)

	# 创建击杀通知容器
	_create_kill_feed()

	# 创建玩家容器
	player_container = Node2D.new()
	player_container.name = "Players"
	add_child(player_container)

	# 生成所有玩家
	_spawn_players()

	# 连接网络事件
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.host_disconnected.connect(_on_host_disconnected)

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# === 加载握手：场景 ready 后通知房主 ===
	# 等待一帧确保节点树完全初始化后再通知
	await get_tree().process_frame
	var my_id: int = multiplayer.get_unique_id()
	if my_id == 1:
		# 房主：标记自己 ready，检查是否所有人都 ready
		_peers_ready[1] = true
		_check_all_peers_ready()
	else:
		# 客户端：通知房主自己已 ready
		_notify_scene_ready.rpc_id(1)


func _spawn_players() -> void:
	var my_id: int = multiplayer.get_unique_id()

	# 获取本机玩家队伍颜色
	var my_team: String = NetworkManager.duel_teams.get(my_id, "red")
	var my_color: Color = NetworkManager.TEAM_COLORS.get(my_team, Color(0.2, 0.4, 0.9, 1))

	# 创建本机玩家
	local_player = _create_player_node(my_id, my_color)
	local_player.set_multiplayer_authority(my_id)

	# 选择出生点
	var spawn_idx: int = 0 if my_team == "red" else 1
	local_player.global_position = spawn_points[spawn_idx]

	# 连接本地玩家信号
	local_player.health_changed.connect(_on_local_health_changed)
	local_player.died.connect(_on_local_died)
	local_player.weapon_changed.connect(_on_local_weapon_changed)

	player_container.add_child(local_player)

	# 创建已有远程玩家
	var peers: Array = multiplayer.get_peers()
	for pid in peers:
		_add_remote_player(pid)

	# 更新UI引用
	kills_label = $UI/KillsLabel
	deaths_label = $UI/DeathsLabel
	health_label = $UI/HealthLabel

	local_player.health_bar = $UI/HealthBar if has_node("UI/HealthBar") else null
	local_player.crosshair = _create_crosshair()
	local_player.fps_label = null  # FPS在武器UI层内

	# 应用装备配置（联机单挑模式）
	var ld: Dictionary = LoadoutManager.get_current_loadout()
	var pw: int = ld.get("primary_weapon", 1)
	var perks: Array = ld.get("perks", [-1, -1, -1])
	local_player.perks = perks
	local_player.has_rifle = (pw == 1)
	local_player.has_sniper = (pw == 2)
	local_player.has_machinegun = (pw == 4)
	local_player.grenade_count = 1
	local_player._apply_perk_effects()
	# 默认切到主武器
	if pw == 1:
		local_player._switch_weapon(1)
	elif pw == 2:
		local_player._switch_weapon(2)
	elif pw == 4:
		local_player._switch_weapon(3)  # 机枪在联机数组是index 3
	local_player._update_weapon_ui()

	_update_ui()


func _create_player_node(peer_id: int, color: Color) -> CharacterBody2D:
	var player: CharacterBody2D = CharacterBody2D.new()
	player.name = "Player_%d" % peer_id
	player.set_script(load("res://scripts/MultiplayerPlayer.gd"))

	# 子节点结构（与原Player.tscn一致）
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
	player.add_child(camera)

	var hit_timer: Timer = Timer.new()
	hit_timer.name = "HitTimer"
	hit_timer.one_shot = true
	player.add_child(hit_timer)

	# 碰撞形状
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	player.add_child(col)

	# 设置玩家颜色
	player.player_color = color
	player.set_multiplayer_authority(peer_id)

	return player


func _create_crosshair() -> Node2D:
	if ResourceLoader.exists("res://UI/Crosshair.tscn"):
		var ch: Node2D = load("res://UI/Crosshair.tscn").instantiate()
		ch.top_level = true
		add_child(ch)
		return ch
	var crosshair: Node2D = Node2D.new()
	crosshair.name = "Crosshair"
	crosshair.set_script(load("res://UI/Crosshair.gd") if ResourceLoader.exists("res://UI/Crosshair.gd") else null)
	crosshair.top_level = true
	add_child(crosshair)
	return crosshair


func _add_remote_player(peer_id: int) -> void:
	if remote_players.has(peer_id):
		return

	var team: String = NetworkManager.duel_teams.get(peer_id, "blue")
	var color: Color = NetworkManager.TEAM_COLORS.get(team, Color(0.2, 0.4, 0.9, 1))

	var remote: CharacterBody2D = _create_player_node(peer_id, color)
	remote.set_multiplayer_authority(peer_id)

	# 远程玩家出生点
	var spawn_idx: int = 0 if team == "red" else 1
	remote.global_position = spawn_points[spawn_idx]

	player_container.add_child(remote)
	remote_players[peer_id] = remote

	remote.died.connect(func(): _on_remote_died(peer_id))


func _on_player_joined(peer_id: int) -> void:
	_add_remote_player(peer_id)


# === 加载握手 ===
@rpc("any_peer", "call_remote", "reliable")
func _notify_scene_ready() -> void:
	# 仅房主处理
	if multiplayer.get_unique_id() != 1:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_peers_ready[sender] = true
	_check_all_peers_ready()


func _check_all_peers_ready() -> void:
	# 检查所有已连接玩家（含房主自己）是否都已 ready
	var all_peers: Array = multiplayer.get_peers()
	for pid in all_peers:
		if not _peers_ready.get(pid, false):
			return  # 还有人没就绪
	# 全部就绪：广播"开始同步"
	_broadcast_sync_start.rpc()
	# 房主本地也开启
	_on_sync_start()


@rpc("authority", "call_remote", "reliable")
func _broadcast_sync_start() -> void:
	_on_sync_start()


func _on_sync_start() -> void:
	# 允许本地玩家开始发送 RPC
	if local_player and is_instance_valid(local_player):
		local_player._sync_enabled = true


func _on_player_left(peer_id: int) -> void:
	var left_name: String = NetworkManager.get_player_display_name(peer_id)
	if remote_players.has(peer_id):
		var rp: CharacterBody2D = remote_players[peer_id]
		rp.queue_free()
		remote_players.erase(peer_id)
	_show_exit_notify(left_name)


func _on_host_disconnected() -> void:
	# 房主断开，回到主菜单
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


# =============================================================================
# 本地玩家事件
# =============================================================================
func _on_local_health_changed(new_hp: int, max_hp: int) -> void:
	if health_label:
		health_label.text = "HP: %d/%d" % [new_hp, max_hp]
	if has_node("UI/HealthBar"):
		var hb: ProgressBar = $UI/HealthBar
		hb.value = new_hp
		hb.max_value = max_hp


func _on_local_weapon_changed(_weapon_index: int) -> void:
	pass


func _on_local_died() -> void:
	if game_over:
		return

	deaths += 1
	# 对方队伍得分
	var my_id: int = multiplayer.get_unique_id()
	var my_team: String = NetworkManager.duel_teams.get(my_id, "red")
	var opponent_team: String = "blue" if my_team == "red" else "red"
	if opponent_team == "red":
		red_kills += 1
	else:
		blue_kills += 1
	_update_ui()
	_check_win_condition()

	# 显示死亡面板
	_show_death_panel()

	# 3秒后重生（如果游戏未结束）
	get_tree().create_timer(3.0).timeout.connect(func():
		if not game_over:
			_respawn_local_player()
	)


func _respawn_local_player() -> void:
	if not local_player or game_over:
		return
	local_player.dead = false
	local_player.current_health = local_player.max_health
	local_player.set_physics_process(true)
	# 只有本地玩家才恢复输入，远程玩家不应处理输入
	if local_player.is_local_player:
		local_player.set_process_input(true)
	local_player.modulate = Color.WHITE

	var my_team: String = NetworkManager.duel_teams.get(multiplayer.get_unique_id(), "red")
	var spawn_idx: int = 0 if my_team == "red" else 1
	local_player.global_position = spawn_points[spawn_idx]

	local_player.health_changed.emit(local_player.max_health, local_player.max_health)

	# 重生后补满弹药和道具
	for weapon in local_player.weapons:
		weapon.reserve_ammo = 9999 if local_player.infinite_ammo else (weapon.max_ammo * 3)
		weapon.current_ammo = weapon.max_ammo
	local_player.grenade_count = 1
	local_player._update_weapon_ui()

	_update_ui()

	# 清除死亡面板
	if death_panel:
		death_panel.queue_free()
		death_panel = null

	# 同步重生
	_respawn_player.rpc()


@rpc("authority", "call_remote", "reliable")
func _respawn_player() -> void:
	# 远端收到：找到发送者对应的远程玩家节点，恢复其视觉状态和出生点
	var sender_id: int = multiplayer.get_remote_sender_id()
	var rp: CharacterBody2D = remote_players.get(sender_id)
	if rp and is_instance_valid(rp):
		rp.dead = false
		rp.current_health = rp.max_health
		rp.set_physics_process(true)
		rp.modulate = Color.WHITE
		var team: String = NetworkManager.duel_teams.get(sender_id, "blue")
		var spawn_idx: int = 0 if team == "red" else 1
		rp.global_position = spawn_points[spawn_idx]


func _show_death_panel() -> void:
	if game_over:
		return
	if death_panel:
		death_panel.queue_free()
	death_panel = Control.new()
	death_panel.name = "DeathPanel"
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	death_panel.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_panel.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var death_lbl: Label = Label.new()
	death_lbl.text = GameSettings.t("you_died")
	death_lbl.add_theme_font_size_override("font_size", 36)
	death_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	vbox.add_child(death_lbl)

	var respawn_lbl: Label = Label.new()
	respawn_lbl.name = "RespawnTimer"
	respawn_lbl.text = GameSettings.t("respawning")
	respawn_lbl.add_theme_font_size_override("font_size", 20)
	respawn_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(respawn_lbl)

	ui_layer.add_child(death_panel)


func _update_ui() -> void:
	if kills_label:
		kills_label.text = GameSettings.t("kills", [kills])
	if deaths_label:
		deaths_label.text = GameSettings.t("deaths", [deaths])


# =============================================================================
# 远程玩家死亡处理
# =============================================================================
func _on_remote_died(peer_id: int) -> void:
	if game_over:
		return

	kills += 1
	# 本地玩家击杀了远程玩家 → 本地加 XP
	GameSettings.add_xp(10)
	# 击杀通知
	var victim_name: String = NetworkManager.get_player_display_name(peer_id)
	_show_kill_notification(victim_name, 10)
	# 本地玩家队伍得分
	var my_id: int = multiplayer.get_unique_id()
	var my_team: String = NetworkManager.duel_teams.get(my_id, "red")
	if my_team == "red":
		red_kills += 1
	else:
		blue_kills += 1
	_update_ui()
	_check_win_condition()

	var rp: CharacterBody2D = remote_players.get(peer_id)
	if rp:
		# 3秒后重生远程玩家（如果游戏未结束）
		get_tree().create_timer(3.0).timeout.connect(func():
			if game_over:
				return
			if rp and is_instance_valid(rp):
				rp.dead = false
				rp.current_health = rp.max_health
				rp.set_physics_process(true)
				# 远程玩家不需要恢复输入（本来就不处理输入）
				rp.modulate = Color.WHITE
				var team: String = NetworkManager.duel_teams.get(peer_id, "blue")
				var spawn_idx: int = 0 if team == "red" else 1
				rp.global_position = spawn_points[spawn_idx]
		)


# =============================================================================
# 胜利条件检测
# =============================================================================
func _check_win_condition() -> void:
	if game_over:
		return

	if red_kills >= DUEL_KILL_LIMIT or blue_kills >= DUEL_KILL_LIMIT:
		game_over = true
		var my_id: int = multiplayer.get_unique_id()
		var my_team: String = NetworkManager.duel_teams.get(my_id, "red")
		var my_team_won: bool = (my_team == "red" and red_kills >= DUEL_KILL_LIMIT) or (my_team == "blue" and blue_kills >= DUEL_KILL_LIMIT)
		if my_team_won:
			_show_victory_panel()
		else:
			_show_defeat_panel()


func _show_victory_panel() -> void:
	if result_panel:
		result_panel.queue_free()
	result_panel = Control.new()
	result_panel.name = "ResultPanel"
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	result_panel.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	# 标题：胜利
	var title: Label = Label.new()
	title.text = GameSettings.t("victory")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	vbox.add_child(title)

	# 比分
	var score_lbl: Label = Label.new()
	score_lbl.text = GameSettings.t("duel_score_format", [red_kills, blue_kills])
	score_lbl.add_theme_font_size_override("font_size", 24)
	score_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	vbox.add_child(score_lbl)

	# 提示
	var hint: Label = Label.new()
	hint.text = GameSettings.t("first_to_25")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	vbox.add_child(hint)

	# 返回房间按钮
	var room_btn: Button = Button.new()
	room_btn.text = GameSettings.t("return_room")
	room_btn.custom_minimum_size = Vector2(240, 45)
	room_btn.add_theme_font_size_override("font_size", 20)
	room_btn.pressed.connect(_on_return_to_room)
	vbox.add_child(room_btn)

	ui_layer.add_child(result_panel)


func _show_defeat_panel() -> void:
	if result_panel:
		result_panel.queue_free()
	result_panel = Control.new()
	result_panel.name = "ResultPanel"
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	result_panel.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	# 标题：失败
	var title: Label = Label.new()
	title.text = GameSettings.t("defeat")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	vbox.add_child(title)

	# 比分
	var score_lbl: Label = Label.new()
	score_lbl.text = GameSettings.t("duel_score_format", [red_kills, blue_kills])
	score_lbl.add_theme_font_size_override("font_size", 24)
	score_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	vbox.add_child(score_lbl)

	# 提示
	var hint: Label = Label.new()
	hint.text = GameSettings.t("first_to_25")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	vbox.add_child(hint)

	# 返回房间按钮
	var room_btn: Button = Button.new()
	room_btn.text = GameSettings.t("return_room")
	room_btn.custom_minimum_size = Vector2(240, 45)
	room_btn.add_theme_font_size_override("font_size", 20)
	room_btn.pressed.connect(_on_return_to_room)
	vbox.add_child(room_btn)

	ui_layer.add_child(result_panel)


func _on_return_to_room() -> void:
	# 清除结果面板
	if result_panel:
		result_panel.queue_free()
		result_panel = null
	if death_panel:
		death_panel.queue_free()
		death_panel = null

	# 通知 NetworkManager 游戏结束
	NetworkManager.set_game_ended()

	# 重置准备状态
	NetworkManager.reset_ready()

	# 恢复鼠标
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false

	# 回到联机等待房间（保持网络连接）
	get_tree().change_scene_to_file("res://scenes/multiplayer/Lobby.tscn")


# =============================================================================
# 输入处理
# =============================================================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not game_over:
		_toggle_pause()


func _toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
	if paused:
		_show_pause_menu()
	else:
		if pause_menu:
			pause_menu.queue_free()
			pause_menu = null


func _show_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	pause_menu.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var resume_btn: Button = Button.new()
	resume_btn.text = GameSettings.t("resume")
	resume_btn.custom_minimum_size = Vector2(200, 40)
	resume_btn.pressed.connect(func(): _toggle_pause())
	vbox.add_child(resume_btn)

	var room_btn: Button = Button.new()
	room_btn.text = GameSettings.t("return_room")
	room_btn.custom_minimum_size = Vector2(200, 40)
	room_btn.pressed.connect(func():
		_toggle_pause()
		_on_return_to_room()
	)
	vbox.add_child(room_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = GameSettings.t("return_to_menu")
	menu_btn.custom_minimum_size = Vector2(200, 40)
	menu_btn.pressed.connect(func():
		NetworkManager.disconnect_network()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)
	vbox.add_child(menu_btn)

	ui_layer.add_child(pause_menu)

# =============================================================================
# 击杀通知
# =============================================================================
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
