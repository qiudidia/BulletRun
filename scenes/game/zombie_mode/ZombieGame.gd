extends Node2D

# =============================================================================
# 僵尸波次模式控制器（无限波次，直到玩家死亡）
# 管理波次递增、敌人生成、商店系统（含金钱）、HUD显示
# 按 ESC 可退出到主菜单
# =============================================================================

signal wave_started(wave_number)
signal wave_completed(wave_number)
signal game_over()


@onready var player: CharacterBody2D = $Player
@onready var enemy_container: Node2D = $Enemies
@onready var map_node: Node2D = $Map
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

# ESC 退出确认面板
@onready var exit_panel: Panel = $UI/ExitConfirmPanel
@onready var exit_confirm_btn: Button = $UI/ExitConfirmPanel/VBox/ConfirmBtn
@onready var exit_cancel_btn: Button = $UI/ExitConfirmPanel/VBox/CancelBtn

# 波次系统（无限波次）
var current_wave: int = 0
var enemies_remaining: int = 0
var enemies_killed: int = 0
var wave_in_progress: bool = false

# 敌人生成
var base_enemy_count: int = 5
var enemy_scene: PackedScene

# 暂停菜单
var pause_menu: Control = null
var paused: bool = false

# 设置界面实例（叠加显示，不切换场景）
var settings_instance: Control = null

# 商店
var shop_open: bool = false



# 金钱系统
var money: int = 0
var money_label: Label = null
var kills: int = 0
var kills_label: Label = null

# 商店价格（随波次递增）
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

# 最高波次记录
var high_wave: int = 0

# 游戏内控制台
var console: CanvasLayer = null

# 宝箱系统
var chest_container: Node2D = null
var chest_count: int = 5  # 地图上同时存在的宝箱数量
var chest_spawn_timer: float = 0.0
const CHEST_SPAWN_INTERVAL: float = 15.0  # 每15秒检查一次是否需要生成新宝箱

# 击杀通知容器
var kill_feed_container: VBoxContainer = null

# 按钮引用
var hp_btn: Button = null
var dmg_btn: Button = null
var ammo_btn: Button = null
var grenade_btn: Button = null
var rifle_btn: Button = null
var sniper_btn: Button = null
var mg_btn: Button = null
var continue_btn: Button = null

# 多语言节点引用
var death_title_label: Label = null
var exit_label: Label = null
var shop_title_label: Label = null

# BOSS 血条
var boss_node: CharacterBody2D = null
var boss_health_bar: Control = null
var boss_health_progress: ProgressBar = null
var boss_name_label: Label = null


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
	# 创建击杀通知容器
	_create_kill_feed()
	# 创建小地图
	_create_minimap()

	high_wave = GameSettings.get_value("game", "high_wave", 0)
	money = 0
	GameSettings.set_value("game", "money", 0)

	if ui_layer:
		ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceLoader.exists("res://scenes/game/zombie_mode/Zombie.tscn"):
		enemy_scene = load("res://scenes/game/zombie_mode/Zombie.tscn")

	if player and player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)

	# 单机模式使用自定义玩家皮肤（已注释，恢复默认角色）
	# if is_instance_valid(player) and player.has_method("_apply_custom_skin"):
	# 	player._apply_custom_skin()

	# 死亡界面按钮
	if death_restart_btn:
		death_restart_btn.pressed.connect(_on_restart_pressed)
	if death_menu_btn:
		death_menu_btn.pressed.connect(_on_menu_pressed)
	if death_panel:
		death_panel.visible = false

	# ESC 退出确认面板按钮（连接固定，不来回改）
	if exit_confirm_btn:
		exit_confirm_btn.pressed.connect(_on_exit_confirm)
	if exit_cancel_btn:
		exit_cancel_btn.pressed.connect(_on_exit_cancel)
	if exit_panel:
		exit_panel.visible = false

	_init_shop_ui()

	# 创建 BOSS 血条（在暂停菜单之前，确保暂停菜单覆盖在上层）
	_create_boss_health_bar()

	# 创建暂停菜单
	_create_pause_menu()

	# 多语言节点引用
	death_title_label = $UI/DeathPanel/VBox/TitleLabel
	exit_label = $UI/ExitConfirmPanel/VBox/Label
	shop_title_label = shop_vbox.get_node_or_null("Title")

	_apply_language()

	if shop_panel:
		shop_panel.visible = false

	# 僵尸模式：开局只有手枪，没有步枪、狙击枪、机枪和手榴弹（主武器需商店购买）
	if is_instance_valid(player):
		player.has_rifle = false
		player.has_sniper = false
		player.has_machinegun = false
		player.grenade_count = 1  # 僵尸模式给1颗手榴弹
		# 应用特长
		var ld: Dictionary = LoadoutManager.get_current_loadout()
		player.perks = ld.get("perks", [-1, -1, -1])
		player._apply_perk_effects()
		player._update_weapon_ui()

	_spawn_crosshair()
	_update_money_ui()

	# 创建游戏内控制台
	_create_console()
	
	# 创建宝箱容器
	chest_container = Node2D.new()
	chest_container.name = "Chests"
	add_child(chest_container)
	
	# 初始生成宝箱
	_spawn_initial_chests()

	start_next_wave()


func _create_console() -> void:
	var console_script: GDScript = load("res://scripts/Console.gd")
	if console_script:
		console = CanvasLayer.new()
		console.set_script(console_script)
		add_child(console)


func _create_boss_health_bar() -> void:
	"""创建 BOSS 血条 UI（屏幕上方居中，默认隐藏）"""
	boss_health_bar = Control.new()
	boss_health_bar.name = "BossHealthBar"
	boss_health_bar.visible = false
	boss_health_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# BOSS 名称
	boss_name_label = Label.new()
	boss_name_label.text = GameSettings.t("boss_name")
	boss_name_label.position = Vector2(0, 50)
	boss_name_label.size = Vector2(1280, 30)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 22)
	boss_name_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	boss_health_bar.add_child(boss_name_label)

	# 血条
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


func _spawn_crosshair() -> void:
	if ResourceLoader.exists("res://UI/Crosshair.tscn"):
		var ch: Node2D = load("res://UI/Crosshair.tscn").instantiate()
		get_tree().current_scene.add_child(ch)
		# 将准星引用分配给玩家，使设置中的准星样式/颜色生效
		if is_instance_valid(player):
			player.crosshair = ch
			player._update_crosshair()


func _on_pause_input() -> void:
	# ESC 键：暂停菜单（商店打开时先关闭商店）
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


func _on_switch_mode() -> void:
	GameSettings.set_value("game", "money", 0)
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
	GameSettings.set_value("game", "money", 0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _show_exit_confirm() -> void:
	_toggle_pause()



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

	# 手榴弹购买按钮（动态创建，放在弹药按钮和继续按钮之间）
	grenade_btn = Button.new()
	grenade_btn.name = "GrenadeBuyBtn"
	grenade_btn.pressed.connect(_on_grenade_buy)
	# 插到 continue_btn 前面
	var btn_index: int = shop_vbox.get_child_count()
	if continue_btn and continue_btn.get_parent() == shop_vbox:
		btn_index = continue_btn.get_index()
	shop_vbox.add_child(grenade_btn)
	shop_vbox.move_child(grenade_btn, btn_index)

	# 步枪购买按钮（动态创建，放在手榴弹按钮和继续按钮之间）
	rifle_btn = Button.new()
	rifle_btn.name = "RifleBuyBtn"
	rifle_btn.pressed.connect(_on_rifle_buy)
	var rifle_idx: int = shop_vbox.get_child_count()
	if continue_btn and continue_btn.get_parent() == shop_vbox:
		rifle_idx = continue_btn.get_index()
	shop_vbox.add_child(rifle_btn)
	shop_vbox.move_child(rifle_btn, rifle_idx)

	# 狙击枪购买按钮（动态创建，放在步枪按钮和继续按钮之间）
	sniper_btn = Button.new()
	sniper_btn.name = "SniperBuyBtn"
	sniper_btn.pressed.connect(_on_sniper_buy)
	var sniper_idx: int = shop_vbox.get_child_count()
	if continue_btn and continue_btn.get_parent() == shop_vbox:
		sniper_idx = continue_btn.get_index()
	shop_vbox.add_child(sniper_btn)
	shop_vbox.move_child(sniper_btn, sniper_idx)

	# 机枪购买按钮
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


func _update_money_ui() -> void:
	if money_label:
		money_label.text = GameSettings.t("balance", [money])
	if money_hud_label:
		money_hud_label.text = GameSettings.t("money_display", [money])
	_update_shop_buttons()


func _on_hp_upgrade() -> void:
	if money < hp_price:
		return
	money -= hp_price
	hp_price += 50
	player.max_health += 20
	player.current_health = player.max_health
	player.health_changed.emit(player.current_health, player.max_health)
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_damage_upgrade() -> void:
	if money < damage_price:
		return
	money -= damage_price
	damage_price += 50
	for weapon in player.weapons:
		weapon.damage += 5
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_ammo_buy() -> void:
	if money < ammo_price:
		return
	money -= ammo_price
	ammo_price += 25
	for weapon in player.weapons:
		weapon.reserve_ammo += 60
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_grenade_buy() -> void:
	if money < grenade_price:
		return
	money -= grenade_price
	grenade_price += 50
	if is_instance_valid(player):
		player.grenade_count += 1
		player.grenade_changed.emit(player.grenade_count)
		player._update_weapon_ui()
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_rifle_buy() -> void:
	if rifle_purchased:
		return
	if money < rifle_price:
		return
	money -= rifle_price
	rifle_purchased = true
	if is_instance_valid(player):
		player.unlock_rifle()
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_sniper_buy() -> void:
	if sniper_purchased:
		return
	if money < sniper_price:
		return
	money -= sniper_price
	sniper_purchased = true
	if is_instance_valid(player):
		player.unlock_sniper()
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _on_mg_buy() -> void:
	if mg_purchased:
		return
	if money < mg_price:
		return
	money -= mg_price
	mg_purchased = true
	if is_instance_valid(player):
		player.unlock_machinegun()
	_update_money_ui()
	GameSettings.set_value("game", "money", money)


func _process(_delta: float) -> void:
	if wave_in_progress:
		_check_wave_complete()
	
	# 宝箱生成检查
	_chest_spawn_timer += _delta
	if _chest_spawn_timer >= CHEST_SPAWN_INTERVAL:
		_chest_spawn_timer = 0.0
		# 如果当前宝箱数量少于目标，生成新的
		if chest_container and chest_container.get_child_count() < chest_count:
			_spawn_treasure_chest()


func start_next_wave() -> void:
	current_wave += 1
	wave_in_progress = true
	enemies_killed = 0

	# 每波怪物数量递增
	var normal_count: int = base_enemy_count + (current_wave - 1) * 3
	var elite_count: int = 0
	var boss_count: int = 0

	# 每 5 波出精英怪
	if current_wave >= 5:
		@warning_ignore("integer_division")
		elite_count = maxi(1, current_wave / 5)
	# 每 10 波出 BOSS
	if current_wave >= 10 and current_wave % 10 == 0:
		boss_count = 1

	enemies_remaining = normal_count + elite_count + boss_count
	_update_wave_ui()
	wave_started.emit(current_wave)
	_spawn_wave_enemies(normal_count, elite_count, boss_count)
	_show_wave_announcement()



func _spawn_wave_enemies(normal_count: int, elite_count: int, boss_count: int) -> void:
	var total: int = normal_count + elite_count + boss_count
	
	if not enemy_scene:
		for i in range(total):
			_spawn_temp_zombie()
		return
	
	var bounds: Rect2 = _get_spawn_bounds()
	var min_pos: Vector2 = bounds.position
	var max_pos: Vector2 = bounds.end
	
	# 根据波次决定可以生成哪些类型（0=普通，1=速度型，2=坦克型，3=爆炸型）
	var available_types: Array = [0]  # 至少有普通僵尸
	if current_wave >= 3:
		available_types.append(1)  # 波次3+ 可能有速度型
	if current_wave >= 5:
		available_types.append(2)  # 波次5+ 可能有坦克型
	if current_wave >= 7:
		available_types.append(3)  # 波次7+ 可能有爆炸型
	
	# 普通怪（可能混入新类型）
	for i in range(normal_count):
		var enemy: CharacterBody2D = enemy_scene.instantiate()
		# 30% 概率生成特殊类型（如果已解锁）
		var type_to_use: int = 0
		if randf() < 0.3 and available_types.size() > 1:
			type_to_use = available_types[randi() % available_types.size()]
		_configure_enemy(enemy, min_pos, max_pos, false, false, type_to_use)
	
	# 精英怪
	for i in range(elite_count):
		var enemy: CharacterBody2D = enemy_scene.instantiate()
		_configure_enemy(enemy, min_pos, max_pos, true, false, 0)
	
	# BOSS
	for i in range(boss_count):
		var enemy: CharacterBody2D = enemy_scene.instantiate()
		_configure_enemy(enemy, min_pos, max_pos, false, true, 0)


func _configure_enemy(enemy: CharacterBody2D, min_pos: Vector2, max_pos: Vector2, elite: bool, boss: bool, type: int = 0) -> void:
	var spawn_pos: Vector2
	for attempt in range(20):
		spawn_pos = Vector2(randf_range(min_pos.x, max_pos.x), randf_range(min_pos.y, max_pos.y))
		if spawn_pos.distance_to(player.global_position) > 250.0:
			break
	
	enemy.global_position = spawn_pos
	
	# 设置精英 / BOSS 标记
	if enemy.has_method("set"):
		enemy.set("is_elite", elite)
		enemy.set("is_boss", boss)
		enemy.set("zombie_type", type)
	
	enemy_container.add_child(enemy)
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	
	# BOSS 出现时显示血条
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
		if spawn_pos.distance_to(player.global_position) > 200.0:
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


func _open_shop() -> void:
	shop_open = true
	var wave_reward: int = 100 + current_wave * 20
	money += wave_reward
	GameSettings.set_value("game", "money", money)
	_update_money_ui()

	if shop_panel:
		shop_panel.visible = true
		get_tree().paused = true


func _close_shop() -> void:
	shop_open = false
	if shop_panel:
		shop_panel.visible = false
	get_tree().paused = false
	start_next_wave()


func _on_player_health_changed(new_health: int, _max_health: int) -> void:
	if health_label:
		health_label.text = GameSettings.t("health", [new_health])
	if new_health <= 0:
		_game_over()


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

	# 隐藏 BOSS 血条
	if boss_health_bar:
		boss_health_bar.visible = false

	if current_wave > high_wave:
		high_wave = current_wave
		GameSettings.set_value("game", "high_wave", high_wave)

	if player:
		player.set_physics_process(false)
		player.set_process_input(false)

	get_tree().paused = false

	if death_panel:
		death_panel.visible = true
	if death_wave_label:
		death_wave_label.text = GameSettings.t("died_at_wave", [current_wave])
	if death_high_label:
		death_high_label.text = GameSettings.t("highest_wave", [high_wave])


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	GameSettings.set_value("game", "money", 0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _apply_language() -> void:
	if death_title_label:
		death_title_label.text = GameSettings.t("you_died")
	if death_restart_btn:
		death_restart_btn.text = GameSettings.t("restart")
	if death_menu_btn:
		death_menu_btn.text = GameSettings.t("return_menu")
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
	# 刷新金钱 HUD
	if money_hud_label:
		money_hud_label.text = GameSettings.t("money_display", [money])
	# 刷新暂停菜单按钮文本
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
			quit_btn.text = GameSettings.t("quit_game")
	# 刷新准星样式（设置可能已更改）
	if is_instance_valid(player) and player.crosshair:
		player._update_crosshair()


func _on_exit_confirm() -> void:
	GameSettings.set_value("game", "money", 0)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")



func _on_exit_cancel() -> void:
	if exit_panel:
		exit_panel.visible = false
	_on_resume()


# =============================================================================
# 连杀系统（与 BotGame 对称）
# =============================================================================
func _create_kill_feed() -> void:
	"""创建击杀通知容器"""
	kill_feed_container = VBoxContainer.new()
	kill_feed_container.name = "KillFeed"
	kill_feed_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	kill_feed_container.position = Vector2(0, 120)
	kill_feed_container.alignment = BoxContainer.ALIGNMENT_CENTER
	kill_feed_container.add_theme_constant_override("separation", 8)
	kill_feed_container.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_layer.add_child(kill_feed_container)


func _create_minimap() -> void:
	"""创建小地图"""
	var minimap: Control = Control.new()
	minimap.set_script(load("res://scripts/Minimap.gd"))
	minimap.name = "Minimap"
	ui_layer.add_child(minimap)


func _on_enemy_died(_enemy: Node2D, killed_by: Node = null) -> void:
	enemies_remaining -= 1
	# 只有玩家造成的击杀才计分和奖励
	var is_player_kill: bool = false
	if killed_by and is_instance_valid(killed_by):
		if killed_by.is_in_group("player"):
			is_player_kill = true
	if is_player_kill:
		enemies_killed += 1
		var kill_reward: int = 50 + current_wave * 10
		money += kill_reward
		GameSettings.set_value("game", "money", money)
		_update_money_ui()
		# XP 增加：普通击杀 +5 XP，精英 +35 XP，BOSS +75 XP
		var xp_gain: int = 5
		if _enemy.get("is_boss") == true:
			xp_gain = 75
		elif _enemy.get("is_elite") == true:
			xp_gain = 35
		GameSettings.add_xp(xp_gain)
		# 击杀通知（BOSS 有单独的大通知，这里只处理普通/精英/新品种）
		if _enemy.get("is_boss") != true:
			var zombie_name: String = _get_zombie_name(_enemy)
			_show_kill_notification(zombie_name, xp_gain)
		# 清道夫 Perk：击杀掉落弹药补给包
		if player.perks[0] == 1:
			player._spawn_ammo_pack(_enemy.global_position)
	_update_enemies_ui()

	# 屏幕震动 + 血液特效（任何敌人死亡都有视觉反馈）
	if is_instance_valid(player):
		player.screen_shake(3.0, 0.15)
	_spawn_blood_vfx(_enemy.global_position)

	# BOSS 死亡：隐藏血条 + 显示击杀通知
	if _enemy == boss_node:
		boss_node = null
		if boss_health_bar:
			boss_health_bar.visible = false
		# BOSS 击杀通知（仅玩家击杀才显示）
		if is_player_kill:
			_show_boss_kill_notification()


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
	# 上滑动画 + 淡出
	var tween: Tween = notif.create_tween()
	tween.tween_property(notif, "position:y", notif.position.y - 80, 3.0)
	tween.parallel().tween_property(notif, "modulate:a", 0.0, 3.0)
	tween.tween_callback(func(): notif.queue_free())


func _get_zombie_name(enemy: Node2D) -> String:
	"""根据僵尸类型返回显示名称"""
	if enemy.get("is_boss") == true:
		return GameSettings.t("boss_name")
	if enemy.get("is_elite") == true:
		return GameSettings.t("zombie_elite")
	var type: int = enemy.get("zombie_type") if enemy.has_method("get") else 0
	match type:
		1: return GameSettings.t("zombie_runner")
		2: return GameSettings.t("zombie_tank")
		3: return GameSettings.t("zombie_bomber")
		_: return GameSettings.t("zombie_normal")


func _spawn_blood_vfx(pos: Vector2) -> void:
	"""在指定位置生成血液喷溅效果，血迹留在地上约8秒"""
	var scene: Node = get_tree().current_scene
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
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
		
		# 血色变化
		var brightness: float = rng.randf_range(0.6, 1.0)
		drop.color = Color(0.8 * brightness, 0.05 * brightness, 0.0, 1.0)
		scene.add_child(drop)
		
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


# =============================================================================
# 宝箱系统
# =============================================================================
func _spawn_initial_chests() -> void:
	"""初始生成宝箱"""
	for i in range(chest_count):
		_spawn_treasure_chest()


func _spawn_treasure_chest() -> void:
	"""在地图上随机位置生成宝箱"""
	if not chest_container:
		return
	
	var chest_scene: PackedScene = PackedScene.new()
	var chest_script: GDScript = load("res://scripts/TreasureChest.gd")
	
	var chest: Area2D = Area2D.new()
	chest.name = "TreasureChest"
	chest.set_script(chest_script)
	chest.money_amount = 50 + randi() % 100  # 50-150 随机金钱
	chest.respawn_time = 20.0 + randf() * 20.0  # 20-40秒刷新
	
	# 随机位置（避开玩家初始位置）
	var bounds: Rect2 = _get_spawn_bounds()
	var pos: Vector2 = Vector2(
		randf_range(bounds.position.x, bounds.end.x),
		randf_range(bounds.position.y, bounds.end.y)
	)
	# 确保不在玩家附近
	if player and pos.distance_to(player.global_position) < 300.0:
		pos = player.global_position + Vector2(400, 0).rotated(randf_range(0, TAU))
	chest.global_position = pos
	
	chest_container.add_child(chest)
	chest.chest_collected.connect(_on_chest_collected.bind(chest))


func _on_chest_collected(money_amount: int, chest: Area2D) -> void:
	"""处理宝箱拾取"""
	money += money_amount
	GameSettings.set_value("game", "money", money)
	_update_money_ui()
	
	# 显示拾取通知
	_show_chest_notification(money_amount)
	
	# 3秒后重新生成宝箱（由 TreaureChest 自己处理刷新）
	# 这里不需要额外处理，TreasureChest 脚本会自动刷新


func _show_chest_notification(amount: int) -> void:
	"""显示宝箱拾取通知"""
	if not is_instance_valid(kill_feed_container):
		return
	
	var notif: Label = Label.new()
	notif.text = "  +$%d" % amount
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.add_theme_font_size_override("font_size", 20)
	notif.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))  # 金色
	notif.modulate = Color(1, 1, 1, 1)
	notif.process_mode = Node.PROCESS_MODE_ALWAYS
	kill_feed_container.add_child(notif)
	
	var tween: Tween = notif.create_tween()
	tween.tween_property(notif, "position:y", notif.position.y - 50, 2.0)
	tween.parallel().tween_property(notif, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func(): notif.queue_free())

