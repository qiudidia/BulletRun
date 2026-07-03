extends Node2D

# =============================================================================
# BOT对战模式控制器
# 管理BOT生成、计分系统、商店、暂停菜单、核爆结束
# =============================================================================

signal score_updated(kills, deaths)


@onready var player: CharacterBody2D = $Player
@onready var bot_container: Node2D = $Bots
@onready var map_node: Node2D = $Map
@onready var ui_layer: CanvasLayer = $UI
@onready var kills_label: Label = $UI/KillsLabel
@onready var deaths_label: Label = $UI/DeathsLabel
@onready var health_label: Label = $UI/HealthLabel
@onready var shop_hint: Label = $UI/ShopHint

# 商店
var shop_node: Area2D = null
var shop_ui: Control = null
var near_shop: bool = false

# 暂停菜单（动态创建）
var pause_menu: Control = null
var game_over_panel: Control = null
var death_panel: Control = null

# 计分系统
var kills: int = 0
var deaths: int = 0

# BOT管理
var max_bots: int = 8
var bot_scene: PackedScene
var bot_spawn_timer: float = 0.0
var bot_spawn_interval: float = 3.0

# 状态
var game_over: bool = false
var shop_open: bool = false
var paused: bool = false

# 击杀通知容器（屏幕中央偏上）
var kill_feed_container: VBoxContainer = null

# 设置界面实例（叠加显示，不切换场景）
var settings_instance: Control = null

# 购买状态
var damage_bonus: int = 0
var infinite_ammo: bool = false
# 保存玩家原始碰撞值，部署时恢复
var player_orig_collision_layer: int = 0
var player_orig_collision_mask: int = 0

# 难度选择面板
var difficulty_panel: Control = null
var difficulty_selected: bool = false

# 游戏内控制台
var console: CanvasLayer = null


func _ready() -> void:
	if ui_layer:
		ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceLoader.exists("res://scenes/game/bot_mode/Bot.tscn"):
		bot_scene = load("res://scenes/game/bot_mode/Bot.tscn")

	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)

	# 单机模式使用自定义玩家皮肤（已注释，恢复默认角色）
	# if is_instance_valid(player) and player.has_method("_apply_custom_skin"):
	# 	player._apply_custom_skin()

	# 创建商店实体
	_spawn_shop()

	# 创建商店 UI
	if ResourceLoader.exists("res://scenes/game/ShopUI.tscn"):
		shop_ui = load("res://scenes/game/ShopUI.tscn").instantiate()
		shop_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		shop_ui.item_purchased.connect(_on_shop_item_purchased)
		shop_ui.shop_closed.connect(_on_shop_closed)
		ui_layer.add_child(shop_ui)

	# 创建暂停菜单
	_create_pause_menu()

	# 创建击杀通知容器（屏幕正上方偏下）
	_create_kill_feed()
	# 创建小地图（右上角）
	_create_minimap()

	# 先显示难度选择面板，选完后再生成 Bot
	_create_difficulty_panel()
	_show_difficulty_panel()

	_update_score_ui()
	_spawn_crosshair()
	_apply_language()

	# 创建游戏内控制台
	_create_console()

	# 应用装备配置（背包系统）
	_apply_loadout()

	# 游戏暂停，等待难度选择
	get_tree().paused = true


func _create_minimap() -> void:
	"""创建小地图"""
	var minimap: Control = Control.new()
	minimap.set_script(load("res://scripts/Minimap.gd"))
	minimap.name = "Minimap"
	ui_layer.add_child(minimap)


func _create_console() -> void:
	var console_script: GDScript = load("res://scripts/Console.gd")
	if console_script:
		console = CanvasLayer.new()
		console.set_script(console_script)
		add_child(console)


func _apply_loadout() -> void:
	# 根据装备配置设置玩家武器和特长
	if not is_instance_valid(player):
		return
	var ld: Dictionary = LoadoutManager.get_current_loadout()
	var pw: int = ld.get("primary_weapon", 1)
	var perks: Array = ld.get("perks", [-1, -1, -1])

	# 设置特长
	player.perks = perks

	# 根据主武器选择决定玩家拥有哪些武器
	# Bot模式：手枪固定拥有，主武器按配置拥有，刀固定拥有，其他主武器不拥有
	player.has_rifle = (pw == 1)
	player.has_sniper = (pw == 2)
	player.has_machinegun = (pw == 4)
	player.has_knife = true
	player.grenade_count = 1

	# 默认切到主武器
	if pw == 1:
		player._switch_weapon(1)
	elif pw == 2:
		player._switch_weapon(2)
	elif pw == 4:
		player._switch_weapon(4)
	else:
		player._switch_weapon(0)

	# 应用特长效果
	player._apply_perk_effects()


func _create_difficulty_panel() -> void:
	"""创建难度选择面板（游戏开始前弹出，4个按钮：简单/普通/中等/困难）"""
	difficulty_panel = Control.new()
	difficulty_panel.name = "DifficultyPanel"
	difficulty_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	difficulty_panel.visible = false
	difficulty_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = Color(0, 0, 0, 0.85)
	panel.add_theme_stylebox_override("panel", pstyle)
	difficulty_panel.add_child(panel)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 350)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# 标题
	var title: Label = Label.new()
	title.name = "DifficultyTitle"
	title.text = GameSettings.t("select_difficulty")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	# 4个难度按钮
	var difficulties: Array = [
		{"name": "difficulty_easy", "value": 0, "color": Color(0.2, 0.8, 0.2, 1)},
		{"name": "difficulty_normal", "value": 1, "color": Color(0.2, 0.6, 1.0, 1)},
		{"name": "difficulty_medium", "value": 2, "color": Color(1.0, 0.8, 0.2, 1)},
		{"name": "difficulty_hard", "value": 3, "color": Color(1.0, 0.2, 0.2, 1)},
	]

	for diff in difficulties:
		var btn: Button = Button.new()
		btn.name = "DiffBtn_%d" % diff.value
		btn.text = GameSettings.t(diff.name)
		btn.add_theme_font_size_override("font_size", 24)
		btn.custom_minimum_size = Vector2(300, 60)
		btn.pressed.connect(func(): _on_difficulty_selected(diff.value))
		vbox.add_child(btn)

	ui_layer.add_child(difficulty_panel)


func _show_difficulty_panel() -> void:
	if difficulty_panel:
		difficulty_panel.visible = true


func _on_difficulty_selected(diff_value: int) -> void:
	"""选择难度后，保存到 GameSettings，隐藏面板，开始游戏"""
	difficulty_selected = true
	GameSettings.set_value("game", "bot_difficulty", diff_value)

	if difficulty_panel:
		difficulty_panel.visible = false

	# 取消暂停，开始游戏
	get_tree().paused = false

	# 初始生成BOT
	for i in range(max_bots):
		_spawn_bot()

	# 随机给1-3个Bot手榴弹
	_assign_grenades_to_random_bots()


func _spawn_crosshair() -> void:
	if ResourceLoader.exists("res://UI/Crosshair.tscn"):
		var ch: Node2D = load("res://UI/Crosshair.tscn").instantiate()
		get_tree().current_scene.add_child(ch)
		# 将准星引用分配给玩家，使设置中的准星样式/颜色生效
		if is_instance_valid(player):
			player.crosshair = ch
			player._update_crosshair()


func _spawn_shop() -> void:
	if ResourceLoader.exists("res://scenes/game/Shop.tscn"):
		shop_node = load("res://scenes/game/Shop.tscn").instantiate()
		# 放在地图定义的商店安全区中心，GameMap 生成掩体时会避开这里
		var shop_pos: Vector2 = Vector2(900, 900)
		if is_instance_valid(map_node):
			var sp = map_node.get("shop_zone_center")
			if typeof(sp) == TYPE_VECTOR2:
				shop_pos = sp
		shop_node.global_position = shop_pos
		shop_node.player_entered_shop.connect(_on_shop_entered)
		shop_node.player_exited_shop.connect(_on_shop_exited)
		add_child(shop_node)


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

	var switch_btn: Button = Button.new()
	switch_btn.name = "SwitchModeBtn"
	switch_btn.text = GameSettings.t("switch_mode")
	switch_btn.pressed.connect(_on_switch_mode)
	vbox.add_child(switch_btn)

	var settings_btn: Button = Button.new()
	settings_btn.name = "SettingsBtn"
	settings_btn.text = GameSettings.t("settings")
	settings_btn.pressed.connect(_on_pause_settings)
	vbox.add_child(settings_btn)

	var quit_btn: Button = Button.new()
	quit_btn.name = "QuitBtn"
	quit_btn.text = GameSettings.t("return_to_menu")
	quit_btn.pressed.connect(_on_quit_to_menu)
	vbox.add_child(quit_btn)

	ui_layer.add_child(pause_menu)


func _create_kill_feed() -> void:
	"""创建击杀通知容器（屏幕正上方偏下位置）"""
	kill_feed_container = VBoxContainer.new()
	kill_feed_container.name = "KillFeed"
	kill_feed_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	kill_feed_container.position = Vector2(0, 120)  # 顶部偏下
	kill_feed_container.alignment = BoxContainer.ALIGNMENT_CENTER
	kill_feed_container.add_theme_constant_override("separation", 8)
	kill_feed_container.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(kill_feed_container)


func _create_game_over_panel() -> void:
	game_over_panel = Control.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_panel.visible = false
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = Color(0, 0, 0, 0.85)
	panel.add_theme_stylebox_override("panel", pstyle)
	game_over_panel.add_child(panel)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(500, 300)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)


	var title: Label = Label.new()
	title.name = "GameOverTitle"
	title.text = GameSettings.t("player_nuked")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	vbox.add_child(title)


	var sub: Label = Label.new()
	sub.name = "GameOverSub"
	sub.text = GameSettings.t("game_over")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	vbox.add_child(sub)


	var restart_btn: Button = Button.new()
	restart_btn.name = "RestartBtn"
	restart_btn.text = GameSettings.t("play_again")
	restart_btn.pressed.connect(_on_restart_game)
	vbox.add_child(restart_btn)

	var menu_btn: Button = Button.new()
	menu_btn.name = "MenuBtn"
	menu_btn.text = GameSettings.t("return_to_menu")
	menu_btn.pressed.connect(_on_quit_to_menu)
	vbox.add_child(menu_btn)

	ui_layer.add_child(game_over_panel)


func _create_death_panel() -> void:
	death_panel = Control.new()
	death_panel.name = "DeathPanel"
	death_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	death_panel.visible = false
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pstyle: StyleBoxFlat = StyleBoxFlat.new()
	pstyle.bg_color = Color(0, 0, 0, 0.85)
	panel.add_theme_stylebox_override("panel", pstyle)
	death_panel.add_child(panel)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(400, 300)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)


	var title: Label = Label.new()
	title.name = "DeathTitle"
	title.text = GameSettings.t("you_died")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	vbox.add_child(title)


	var stats: Label = Label.new()
	stats.name = "DeathStats"
	stats.text = GameSettings.t("kills", [0]) + "  " + GameSettings.t("deaths", [0])
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 22)
	vbox.add_child(stats)


	var deploy_btn: Button = Button.new()
	deploy_btn.name = "DeployBtn"
	deploy_btn.text = GameSettings.t("deploy")
	deploy_btn.pressed.connect(_on_deploy)
	vbox.add_child(deploy_btn)

	var quit_btn: Button = Button.new()
	quit_btn.name = "QuitBtn"
	quit_btn.text = GameSettings.t("quit")
	quit_btn.pressed.connect(_on_quit_to_menu)
	vbox.add_child(quit_btn)

	ui_layer.add_child(death_panel)


func _on_pause_input() -> void:
	if game_over:
		return
	if shop_open:
		_close_shop()
	else:
		_toggle_pause()


func _open_shop() -> void:
	if shop_ui:
		shop_ui.open(kills)
		shop_open = true
		get_tree().paused = true


func _close_shop() -> void:
	if shop_ui:
		shop_ui.close()
	shop_open = false
	get_tree().paused = false


func _on_shop_closed() -> void:
	shop_open = false
	get_tree().paused = false


func _on_shop_entered() -> void:
	near_shop = true
	if shop_hint:
		shop_hint.visible = true
		shop_hint.text = GameSettings.t("shop_hint")


func _on_shop_exited() -> void:
	near_shop = false
	if shop_hint:
		shop_hint.visible = false
	if shop_open:
		_close_shop()


func _on_shop_item_purchased(item_id: int) -> void:
	# 消耗人头
	match item_id:
		0: # 补满弹药
			if kills >= 2:
				kills -= 2
				_refill_ammo()
		1: # 医疗包
			if kills >= 1:
				kills -= 1
				_heal_player(50)
		2: # 升级伤害
			if kills >= 10:
				kills -= 10
				damage_bonus += 10
				_apply_damage_bonus()
		3: # 无限子弹
			if kills >= 30:
				kills -= 30
				infinite_ammo = true
				if is_instance_valid(player):
					player.infinite_ammo = true

		4: # 核爆
			if kills >= 40:
				kills -= 40
				_trigger_nuke()
		5: # 手榴弹
			if kills >= 8:
				kills -= 8
				if is_instance_valid(player):
					player.grenade_count += 1
					player.grenade_changed.emit(player.grenade_count)
					player._update_weapon_ui()
		6: # 机枪
			if kills >= 12:
				kills -= 12
				if is_instance_valid(player):
					player.unlock_machinegun()
	score_updated.emit(kills, deaths)
	_update_score_ui()
	if shop_ui:
		shop_ui.set_kills(kills)


func _refill_ammo() -> void:
	if not is_instance_valid(player):
		return
	var weapon: Dictionary = player.weapons[player.current_weapon_index]
	weapon.current_ammo = weapon.max_ammo
	weapon.reserve_ammo = 120 if player.current_weapon_index == 1 else 60
	player.ammo_changed.emit(weapon.current_ammo, weapon.max_ammo, weapon.reserve_ammo)
	player._update_weapon_ui()


func _heal_player(amount: int) -> void:
	if not is_instance_valid(player):
		return
	player.current_health = min(player.current_health + amount, player.max_health)
	player.health_changed.emit(player.current_health, player.max_health)
	if player.health_bar:
		player.health_bar.value = player.current_health


func _apply_damage_bonus() -> void:
	if not is_instance_valid(player):
		return
	for weapon in player.weapons:
		weapon.damage += 10


func _trigger_nuke() -> void:
	game_over = true
	get_tree().paused = true

	# 杀掉所有 Bot
	for bot in bot_container.get_children():
		if bot.has_method("take_damage"):
			bot.take_damage(9999, player)  # 核爆击杀归属玩家

	# 显示核爆结束面板
	if not game_over_panel:
		_create_game_over_panel()
	game_over_panel.visible = true


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


func _on_switch_mode() -> void:
	get_tree().paused = false
	Engine.set_meta("show_mode_select", true)
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_pause_settings() -> void:
	# 叠加显示设置界面，不切换场景（保持游戏暂停状态）
	if settings_instance:
		return  # 设置已打开
	var settings_scene: PackedScene = load("res://UI/settings.tscn")
	if not settings_scene:
		return
	settings_instance = settings_scene.instantiate()
	settings_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	# 使用回调替代信号，更可靠
	settings_instance.on_close_callback = func(): _on_settings_closed()
	ui_layer.add_child(settings_instance)
	# 隐藏暂停菜单，设置关闭时再显示
	if pause_menu:
		pause_menu.visible = false


func _on_settings_closed() -> void:
	# 设置关闭，恢复暂停菜单的显示
	if settings_instance:
		settings_instance.queue_free()
		settings_instance = null
	if pause_menu:
		pause_menu.visible = true
	# 刷新多语言文本（语言可能已被更改）
	_apply_language()


func _on_quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if game_over or paused:
		return

	bot_spawn_timer += delta
	if bot_spawn_timer >= bot_spawn_interval:
		bot_spawn_timer = 0.0
		if bot_container.get_child_count() < max_bots:
			_spawn_bot()


func _spawn_bot() -> void:
	var bot: CharacterBody2D

	if bot_scene:
		bot = bot_scene.instantiate()
	else:
		bot = CharacterBody2D.new()
		bot.name = "Bot"
		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 16.0
		col.shape = shape
		bot.add_child(col)

		var vis: ColorRect = ColorRect.new()
		vis.color = Color(0.9, 0.2, 0.2, 1)
		vis.size = Vector2(32, 32)
		vis.position = Vector2(-16, -16)
		bot.add_child(vis)

		var ai_script: GDScript = load("res://scripts/BotAI.gd")
		if ai_script:
			bot.set_script(ai_script)

	bot.global_position = _get_random_spawn_position()

	if bot.has_signal("died"):
		bot.died.connect(_on_bot_died)

	bot_container.add_child(bot)

	# 新Bot生成后，重新随机分配手榴弹（保持1-3个有手榴弹）
	_assign_grenades_to_random_bots()


func _get_random_spawn_position() -> Vector2:
	var map_size: Vector2 = Vector2(2400, 2400)
	if is_instance_valid(map_node):
		var ms = map_node.get("map_size")
		if typeof(ms) == TYPE_VECTOR2:
			map_size = ms
	var half: Vector2 = map_size * 0.5
	var margin: float = 100.0
	var pos: Vector2 = Vector2(randf_range(-half.x + margin, half.x - margin),
							   randf_range(-half.y + margin, half.y - margin))
	if is_instance_valid(player):
		for _i in range(20):
			if pos.distance_to(player.global_position) >= 300.0:
				break
			pos = Vector2(randf_range(-half.x + margin, half.x - margin),
						  randf_range(-half.y + margin, half.y - margin))
	return pos


func _assign_grenades_to_random_bots() -> void:
	"""随机给1个活着的Bot手榴弹，其他的清空"""
	var living_bots: Array = []
	for bot in bot_container.get_children():
		if is_instance_valid(bot) and bot.has_method("take_damage"):
			bot.grenade_count = 0  # 先全部清空
			living_bots.append(bot)

	if living_bots.size() > 0:
		living_bots.shuffle()
		living_bots[0].grenade_count = 1


func _show_kill_notification(bot: Node2D) -> void:
	"""显示击杀通知（战地5风格：正上方向下，上滑淡出）"""
	if not is_instance_valid(kill_feed_container):
		return

	# 获取Bot名字
	var name_str: String = GameSettings.t("enemy")
	if bot.has_method("get") and "bot_name" in bot:
		name_str = bot.bot_name
	elif "bot_name" in bot:
		name_str = bot.bot_name

	# 创建通知Label
	var notif: Label = Label.new()
	notif.text = GameSettings.t("kill_notify", [name_str, 10])
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.add_theme_font_size_override("font_size", 22)
	notif.add_theme_color_override("font_color", Color(1, 0.9, 0.2, 1))  # 金黄色
	notif.modulate = Color(1, 1, 1, 1)
	notif.process_mode = Node.PROCESS_MODE_ALWAYS
	kill_feed_container.add_child(notif)

	# 上滑动画 + 淡出
	var tween: Tween = notif.create_tween()
	tween.tween_property(notif, "position:y", notif.position.y - 60, 2.0)
	tween.parallel().tween_property(notif, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func(): notif.queue_free())


func _on_bot_died(bot: Node2D, killed_by: Node = null) -> void:
	# 只有玩家造成的击杀才计分
	var is_player_kill: bool = false
	if killed_by and is_instance_valid(killed_by):
		if killed_by.is_in_group("player"):
			is_player_kill = true
	if is_player_kill:
		kills += 1
		score_updated.emit(kills, deaths)
		_update_score_ui()
		# 清道夫 Perk：击杀掉落弹药补给包
		if player.perks[0] == 1:
			player._spawn_ammo_pack(bot.global_position)
		# 显示击杀通知
		_show_kill_notification(bot)
		# XP 增加：Bot击杀 +10 XP
		GameSettings.add_xp(10)

	# 屏幕震动 + 血液特效（任何bot死亡都有视觉反馈）
	if is_instance_valid(player):
		player.screen_shake(3.0, 0.15)
	_spawn_blood_vfx(bot.global_position)

	# Bot死后，重新分配手榴弹
	_assign_grenades_to_random_bots()


func _on_player_health_changed(new_health: int, _max_health: int) -> void:
	if health_label:
		health_label.text = GameSettings.t("health", [new_health])
	if new_health <= 0:
		_on_player_died()


func _on_player_died() -> void:
	deaths += 1
	score_updated.emit(kills, deaths)
	_update_score_ui()
	game_over = true

	# 取消商店无限子弹
	if is_instance_valid(player):
		player.infinite_ammo = false

	if not death_panel:
		_create_death_panel()
	var stats_label: Label = death_panel.find_child("DeathStats", true, false)
	if stats_label:
		stats_label.text = GameSettings.t("kills", [kills]) + "  " + GameSettings.t("deaths", [deaths])

	# 玩家进入阵亡状态：隐藏并取消碰撞，但游戏世界继续运行，敌人不会停在原地
	if is_instance_valid(player):
		# 保存原始碰撞值，部署时恢复
		player_orig_collision_layer = player.collision_layer
		player_orig_collision_mask = player.collision_mask
		player.visible = false
		player.collision_layer = 0
		player.collision_mask = 0

	death_panel.visible = true


func _on_deploy() -> void:
	game_over = false
	death_panel.visible = false

	if not is_instance_valid(player):
		return

	# 部署时击杀数归零
	kills = 0
	score_updated.emit(kills, deaths)
	_update_score_ui()

	# 随机出生地复活，而不是回到固定中心
	player.global_position = _get_random_spawn_position()
	player.current_health = player.max_health
	player.dead = false
	player.visible = true
	player.collision_layer = player_orig_collision_layer
	player.collision_mask = player_orig_collision_mask
	player.set_physics_process(true)
	player.set_process_input(true)
	player.health_changed.emit(player.current_health, player.max_health)



func _update_score_ui() -> void:
	if kills_label:
		kills_label.text = GameSettings.t("kills", [kills])
	if deaths_label:
		deaths_label.text = GameSettings.t("deaths", [deaths])


func set_kills(value: int) -> void:
	kills = value
	_update_score_ui()


func _apply_language() -> void:
	# HUD 标签
	_update_score_ui()
	# 商店提示
	if shop_hint and shop_hint.visible:
		shop_hint.text = GameSettings.t("shop_hint")
	# 暂停菜单
	if pause_menu:
		var pause_title: Label = pause_menu.find_child("PauseTitle", true, false)
		if pause_title:
			pause_title.text = GameSettings.t("pause_title")
		var resume_btn: Button = pause_menu.find_child("ResumeBtn", true, false)
		if resume_btn:
			resume_btn.text = GameSettings.t("resume")
		var switch_btn: Button = pause_menu.find_child("SwitchModeBtn", true, false)
		if switch_btn:
			switch_btn.text = GameSettings.t("switch_mode")
		var settings_btn: Button = pause_menu.find_child("SettingsBtn", true, false)
		if settings_btn:
			settings_btn.text = GameSettings.t("settings")
		var quit_btn: Button = pause_menu.find_child("QuitBtn", true, false)
		if quit_btn:
			quit_btn.text = GameSettings.t("return_to_menu")
	# 游戏结束面板
	if game_over_panel:
		var go_title: Label = game_over_panel.find_child("GameOverTitle", true, false)
		if go_title:
			go_title.text = GameSettings.t("player_nuked")
		var go_sub: Label = game_over_panel.find_child("GameOverSub", true, false)
		if go_sub:
			go_sub.text = GameSettings.t("game_over")
		var go_restart: Button = game_over_panel.find_child("RestartBtn", true, false)
		if go_restart:
			go_restart.text = GameSettings.t("play_again")
		var go_menu: Button = game_over_panel.find_child("MenuBtn", true, false)
		if go_menu:
			go_menu.text = GameSettings.t("return_to_menu")
	# 死亡面板
	if death_panel:
		var d_title: Label = death_panel.find_child("DeathTitle", true, false)
		if d_title:
			d_title.text = GameSettings.t("you_died")
		var d_stats: Label = death_panel.find_child("DeathStats", true, false)
		if d_stats:
			d_stats.text = GameSettings.t("kills", [kills]) + "  " + GameSettings.t("deaths", [deaths])
		var d_deploy: Button = death_panel.find_child("DeployBtn", true, false)
		if d_deploy:
			d_deploy.text = GameSettings.t("deploy")
		var d_quit: Button = death_panel.find_child("QuitBtn", true, false)
		if d_quit:
			d_quit.text = GameSettings.t("quit")
	# 刷新准星样式（设置可能已更改）
	if is_instance_valid(player) and player.crosshair:
		player._update_crosshair()
	# 难度选择面板
	if difficulty_panel:
		var diff_title: Label = difficulty_panel.find_child("DifficultyTitle", true, false)
		if diff_title:
			diff_title.text = GameSettings.t("select_difficulty")
		var diff_names: Array = ["difficulty_easy", "difficulty_normal", "difficulty_medium", "difficulty_hard"]
		for i in range(4):
			var btn: Button = difficulty_panel.find_child("DiffBtn_%d" % i, true, false)
			if btn:
				btn.text = GameSettings.t(diff_names[i])


func _unhandled_input(event: InputEvent) -> void:
	if game_over or paused:
		return
	
	# 商店交互
	if event.is_action_pressed("interact"):
		if near_shop and not shop_open:
			_open_shop()
		elif shop_open:
			_close_shop()


func _spawn_blood_vfx(pos: Vector2) -> void:
	"""在指定位置生成血液喷溅效果，血迹留在地上约8秒"""
	var scene: Node = get_tree().current_scene
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
	# 创建不规则血迹（用Polygon2D替代ColorRect，更真实）
	var count: int = rng.randi_range(12, 20)
	for i in range(count):
		var drop: Polygon2D = Polygon2D.new()
		var angle: float = rng.randf_range(0, TAU)
		var dist: float = rng.randf_range(5, 35)
		drop.position = pos + Vector2(cos(angle), sin(angle)) * dist
		
		# 不规则多边形血滴
		var pts: PackedVector2Array = []
		var sz: float = rng.randf_range(5, 14)
		var vertices: int = rng.randi_range(3, 6)
		for j in range(vertices):
			var a: float = j * TAU / vertices + rng.randf_range(-0.3, 0.3)
			var r: float = sz * rng.randf_range(0.6, 1.0)
			pts.append(Vector2(cos(a) * r, sin(a) * r))
		drop.polygon = pts
		
		# 血色变化（新鲜血更亮，干血更暗）
		var brightness: float = rng.randf_range(0.6, 1.0)
		drop.color = Color(0.8 * brightness, 0.05 * brightness, 0.0, 1.0)
		scene.add_child(drop)
		
		# 停留5秒后淡出
		var tw: Tween = drop.create_tween()
		tw.tween_interval(5.0)
		tw.tween_property(drop, "color:a", 0.0, 2.5)
		tw.tween_callback(func(): drop.queue_free())
	
	# 中心血池（大而暗）
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
	
	# 红色冲击波效果（瞬间扩散）
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
