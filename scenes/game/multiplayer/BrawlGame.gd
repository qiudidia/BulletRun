extends Node2D

# =============================================================================
# 3人乱斗模式控制器
# 3人，无队伍，各打各的，颜色随机分配（红/蓝/黄）
# =============================================================================


@onready var map_node: Node2D = $Map
@onready var ui_layer: CanvasLayer = $UI
@onready var kills_label: Label = $UI/KillsLabel
@onready var deaths_label: Label = $UI/DeathsLabel
@onready var health_label: Label = $UI/HealthLabel

# 玩家管理
var player_container: Node2D = null
var local_player: CharacterBody2D = null
var remote_players: Dictionary = {}

# 加载握手
var _peers_ready: Dictionary = {}

# 计分
var kills: int = 0
var deaths: int = 0

# 状态
var game_over: bool = false
var paused: bool = false
var pause_menu: Control = null
var death_panel: Control = null
var settings_instance: Control = null

# 击杀通知容器
var kill_feed_container: VBoxContainer = null

# 3人出生点（均匀分布）
var spawn_points: Array = [
	Vector2(-500, 0),    # 左侧
	Vector2(500, 0),     # 右侧
	Vector2(0, -500),    # 上方
]


func _ready() -> void:
	if ui_layer:
		ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	# 通知 NetworkManager 游戏开始
	NetworkManager.set_game_started(NetworkManager.GameMode.BRAWL)

	# 创建击杀通知容器
	_create_kill_feed()

	player_container = Node2D.new()
	player_container.name = "Players"
	add_child(player_container)

	_spawn_players()

	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.host_disconnected.connect(_on_host_disconnected)

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

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

	# 本机玩家
	local_player = _create_player_node(my_id, my_color)
	local_player.set_multiplayer_authority(my_id)

	# 分配出生点（按颜色顺序）
	var spawn_idx: int = _get_spawn_index(my_id)
	local_player.global_position = spawn_points[spawn_idx]

	local_player.health_changed.connect(_on_local_health_changed)
	local_player.died.connect(_on_local_died)

	player_container.add_child(local_player)

	# 远程玩家
	var peers: Array = multiplayer.get_peers()
	for pid in peers:
		_add_remote_player(pid)

	local_player.health_bar = $UI/HealthBar if has_node("UI/HealthBar") else null
	local_player.crosshair = _create_crosshair()

	# 应用装备配置（联机乱斗模式）
	var ld: Dictionary = LoadoutManager.get_current_loadout()
	var pw: int = ld.get("primary_weapon", 1)
	var perks: Array = ld.get("perks", [-1, -1, -1])
	local_player.perks = perks
	local_player.has_rifle = (pw == 1)
	local_player.has_sniper = (pw == 2)
	local_player.has_machinegun = (pw == 4)
	local_player.grenade_count = 1
	local_player._apply_perk_effects()
	if pw == 1:
		local_player._switch_weapon(1)
	elif pw == 2:
		local_player._switch_weapon(2)
	elif pw == 4:
		local_player._switch_weapon(3)  # 机枪在联机数组是index 3
	local_player._update_weapon_ui()

	_update_ui()


func _get_spawn_index(peer_id: int) -> int:
	# 根据 peer_id 分配出生点
	var all_ids: Array = [multiplayer.get_unique_id()]
	for pid in multiplayer.get_peers():
		all_ids.append(pid)
	all_ids.sort()
	var idx: int = all_ids.find(peer_id)
	return idx % spawn_points.size()


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

	var color: Color = NetworkManager.get_player_color(peer_id)
	var remote: CharacterBody2D = _create_player_node(peer_id, color)
	remote.set_multiplayer_authority(peer_id)

	var spawn_idx: int = _get_spawn_index(peer_id)
	remote.global_position = spawn_points[spawn_idx]

	player_container.add_child(remote)
	remote_players[peer_id] = remote

	remote.died.connect(func(): _on_remote_died(peer_id))


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
	_broadcast_sync_start.rpc()
	_on_sync_start()


@rpc("authority", "call_remote", "reliable")
func _broadcast_sync_start() -> void:
	_on_sync_start()


func _on_sync_start() -> void:
	if local_player and is_instance_valid(local_player):
		local_player._sync_enabled = true


func _on_player_left(peer_id: int) -> void:
	var left_name: String = NetworkManager.get_player_display_name(peer_id)
	if remote_players.has(peer_id):
		remote_players[peer_id].queue_free()
		remote_players.erase(peer_id)
	_show_exit_notify(left_name)


func _on_host_disconnected() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_local_health_changed(new_hp: int, max_hp: int) -> void:
	if health_label:
		health_label.text = "HP: %d/%d" % [new_hp, max_hp]
	if has_node("UI/HealthBar"):
		$UI/HealthBar.value = new_hp
		$UI/HealthBar.max_value = max_hp


func _on_local_died() -> void:
	deaths += 1
	_update_ui()
	_show_death_panel()
	get_tree().create_timer(3.0).timeout.connect(func(): _respawn_local_player())


func _respawn_local_player() -> void:
	if not local_player:
		return
	local_player.dead = false
	local_player.current_health = local_player.max_health
	local_player.set_physics_process(true)
	# 只有本地玩家才恢复输入
	if local_player.is_local_player:
		local_player.set_process_input(true)
	local_player.modulate = Color.WHITE

	var spawn_idx: int = _get_spawn_index(multiplayer.get_unique_id())
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

	# 同步重生到其他玩家
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
		var spawn_idx: int = _get_spawn_index(sender_id)
		rp.global_position = spawn_points[spawn_idx]


func _show_death_panel() -> void:
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
	respawn_lbl.text = GameSettings.t("respawning")
	respawn_lbl.add_theme_font_size_override("font_size", 20)
	respawn_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(respawn_lbl)

	ui_layer.add_child(death_panel)


func _on_remote_died(peer_id: int) -> void:
	kills += 1
	# 本地玩家击杀了远程玩家 → 本地加 XP
	GameSettings.add_xp(10)
	# 击杀通知
	var victim_name: String = NetworkManager.get_player_display_name(peer_id)
	_show_kill_notification(victim_name, 10)
	_update_ui()

	var rp: CharacterBody2D = remote_players.get(peer_id)
	if rp:
		get_tree().create_timer(3.0).timeout.connect(func():
			if rp and is_instance_valid(rp):
				rp.dead = false
				rp.current_health = rp.max_health
				rp.set_physics_process(true)
				# 远程玩家不需要恢复输入
				rp.modulate = Color.WHITE
				var spawn_idx: int = _get_spawn_index(peer_id)
				rp.global_position = spawn_points[spawn_idx]
		)


func _update_ui() -> void:
	if kills_label:
		kills_label.text = GameSettings.t("kills", [kills])
	if deaths_label:
		deaths_label.text = GameSettings.t("deaths", [deaths])


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
