extends Control

# =============================================================================
# 联机大厅UI
# 创建房间 / 加入房间 / 等待玩家 / 开始游戏
# =============================================================================

# 界面状态
enum LobbyState {
	SELECT_ACTION,     # 选择：创建房间/加入房间
	CREATE_ROOM,       # 创建房间填写信息
	JOIN_ROOM,         # 加入房间浏览列表
	WAITING_HOST,      # 房主等待玩家加入
	WAITING_CLIENT,    # 客户端等待房主开始
}

var current_state: LobbyState = LobbyState.SELECT_ACTION

# UI节点引用（动态创建）
var select_screen: Control = null
var create_screen: Control = null
var join_screen: Control = null
var waiting_screen: Control = null

# 创建房间字段
var nickname_input: LineEdit = null
var room_name_input: LineEdit = null
var mode_option: OptionButton = null
var mode_desc_label: Label = null
var create_btn: Button = null
var create_back_btn: Button = null

# 加入房间字段
var join_nickname_input: LineEdit = null
var room_list: ItemList = null
var refresh_btn: Button = null
var join_btn: Button = null
var join_back_btn: Button = null
var no_room_label: Label = null

# 等待界面
var waiting_label: Label = null
var waiting_mode_label: Label = null
var player_list_vbox: VBoxContainer = null  # 替代旧 player_list_label，支持头像+文字行
var player_list_title: Label = null  # "玩家: x/y" 标题行
var start_btn: Button = null
var mode_switch_btn: Button = null
var cancel_btn: Button = null
var color_select_container: HBoxContainer = null
var color_buttons: Dictionary = {}  # color_name → Button
var team_info_label: Label = null
var ready_btn: Button = null
var player_kick_buttons: Dictionary = {}  # peer_id → Button
var kick_hbox: HBoxContainer = null

# 游戏进行中相关
var join_game_btn: Button = null            # "中途加入游戏"按钮
var game_status_label: Label = null          # "游戏进行中"提示标签

# 刷新定时器
var refresh_timer: float = 0.0
var refresh_interval: float = 0.5

# 测试人员特殊ID → 显示为 "测试人员 ★"
const TESTER_ID: String = "19992884240891841"
const TESTER_NAME: String = "测试人员 ★"

# 头像脚本（预加载，避免每次 _update_player_list 重复 load）
var avatar_script: GDScript = null


func _resolve_nickname(raw: String) -> String:
	if raw == TESTER_ID:
		return TESTER_NAME
	return raw


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# 预加载头像脚本
	avatar_script = load("res://scripts/AvatarIcon.gd")

	# 连接NetworkManager信号
	NetworkManager.room_created.connect(_on_room_created)
	NetworkManager.room_joined.connect(_on_room_joined)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.player_ready_changed.connect(_on_player_ready_changed)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.room_list_updated.connect(_on_room_list_updated)
	NetworkManager.game_start_requested.connect(_on_game_start_requested)
	NetworkManager.host_disconnected.connect(_on_host_disconnected)
	NetworkManager.kicked_from_room.connect(_on_kicked_from_room)
	NetworkManager.room_mode_changed.connect(_on_room_mode_changed)

	# 构建所有界面
	_build_select_screen()
	_build_create_screen()
	_build_join_screen()
	_build_waiting_screen()

	# 播放主界面 BGM（跨场景连续）
	BGMManager.play_bgm()

	# 给所有按钮添加点击音效
	_connect_click_sounds(self)

	# 如果已连接到房间（游戏结束后返回），直接显示等待界面
	if NetworkManager.connected:
		if NetworkManager.is_host:
			_show_state(LobbyState.WAITING_HOST)
		else:
			_show_state(LobbyState.WAITING_CLIENT)
	else:
		_show_state(LobbyState.SELECT_ACTION)


func _connect_click_sounds(node: Node) -> void:
	for child in node.get_children():
		_connect_click_sounds(child)
		if child is Button:
			child.pressed.connect(UIAudio.play_click)


func _process(delta: float) -> void:
	# 加入房间界面：自动刷新房间列表
	if current_state == LobbyState.JOIN_ROOM:
		refresh_timer += delta
		if refresh_timer >= refresh_interval:
			refresh_timer = 0.0
			_update_room_list()


# =============================================================================
# 选择界面：创建房间 / 加入房间
# =============================================================================
func _build_select_screen() -> void:
	select_screen = Control.new()
	select_screen.name = "SelectScreen"
	select_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 背景
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.06, 1)
	select_screen.add_child(bg)

	# 中心布局
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	select_screen.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# 标题
	var title: Label = Label.new()
	title.text = GameSettings.t("multiplayer_mode")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 创建房间按钮
	var create_room_btn: Button = Button.new()
	create_room_btn.text = GameSettings.t("create_room")
	create_room_btn.custom_minimum_size = Vector2(250, 50)
	create_room_btn.add_theme_font_size_override("font_size", 20)
	create_room_btn.pressed.connect(func(): _show_state(LobbyState.CREATE_ROOM))
	vbox.add_child(create_room_btn)

	# 加入房间按钮
	var join_room_btn: Button = Button.new()
	join_room_btn.text = GameSettings.t("join_room")
	join_room_btn.custom_minimum_size = Vector2(250, 50)
	join_room_btn.add_theme_font_size_override("font_size", 20)
	join_room_btn.pressed.connect(func(): _show_state(LobbyState.JOIN_ROOM))
	vbox.add_child(join_room_btn)

	# 返回按钮
	var back_btn: Button = Button.new()
	back_btn.text = GameSettings.t("back")
	back_btn.custom_minimum_size = Vector2(250, 50)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(_on_back_to_menu)
	vbox.add_child(back_btn)

	add_child(select_screen)


# =============================================================================
# 创建房间界面
# =============================================================================
func _build_create_screen() -> void:
	create_screen = Control.new()
	create_screen.name = "CreateScreen"
	create_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.06, 1)
	create_screen.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_screen.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# 标题
	var title: Label = Label.new()
	title.text = GameSettings.t("create_room")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
	vbox.add_child(title)

	# 你的昵称（只读，已在首次游戏时设置）
	var nick_label: Label = Label.new()
	nick_label.text = GameSettings.t("your_nickname")
	nick_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(nick_label)

	nickname_input = LineEdit.new()
	nickname_input.custom_minimum_size = Vector2(250, 35)
	nickname_input.editable = false
	vbox.add_child(nickname_input)

	# 读取已保存的昵称
	var saved_nick: String = GameSettings.get_value("game", "nickname", "")
	if saved_nick != "":
		nickname_input.text = saved_nick

	# 房间名称
	var name_label: Label = Label.new()
	name_label.text = GameSettings.t("room_name")
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	room_name_input = LineEdit.new()
	room_name_input.placeholder_text = GameSettings.t("enter_room_name")
	room_name_input.custom_minimum_size = Vector2(250, 35)
	room_name_input.max_length = 20
	vbox.add_child(room_name_input)

	# 模式选择
	var mode_label: Label = Label.new()
	mode_label.text = GameSettings.t("select_mode")
	mode_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(mode_label)

	mode_option = OptionButton.new()
	mode_option.add_item(GameSettings.t("duel_mode"), NetworkManager.GameMode.DUEL)
	mode_option.add_item(GameSettings.t("brawl_mode"), NetworkManager.GameMode.BRAWL)
	mode_option.add_item(GameSettings.t("zombie_coop_mode"), NetworkManager.GameMode.ZOMBIE)
	mode_option.custom_minimum_size = Vector2(250, 35)
	vbox.add_child(mode_option)

	# 模式说明
	mode_desc_label = Label.new()
	mode_desc_label.name = "ModeDesc"
	mode_desc_label.text = GameSettings.t("duel_desc")
	mode_desc_label.add_theme_font_size_override("font_size", 14)
	mode_desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	mode_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_desc_label.custom_minimum_size = Vector2(350, 60)
	vbox.add_child(mode_desc_label)

	mode_option.item_selected.connect(func(_idx: int): _update_mode_desc())

	# 创建按钮（初始禁用，填好昵称+房间名后才启用）
	create_btn = Button.new()
	create_btn.text = GameSettings.t("create_room")
	create_btn.custom_minimum_size = Vector2(250, 45)
	create_btn.add_theme_font_size_override("font_size", 18)
	create_btn.disabled = true
	create_btn.pressed.connect(_on_create_room_pressed)
	vbox.add_child(create_btn)

	# 实时验证：昵称和房间名都非空才启用创建按钮
	nickname_input.text_changed.connect(func(_new_text: String): _validate_create_fields())
	room_name_input.text_changed.connect(func(_new_text: String): _validate_create_fields())

	# 返回
	create_back_btn = Button.new()
	create_back_btn.text = GameSettings.t("back")
	create_back_btn.custom_minimum_size = Vector2(250, 40)
	create_back_btn.add_theme_font_size_override("font_size", 16)
	create_back_btn.pressed.connect(func(): _show_state(LobbyState.SELECT_ACTION))
	vbox.add_child(create_back_btn)

	add_child(create_screen)


func _update_mode_desc() -> void:
	var mode: int = mode_option.get_selected_id()
	match mode:
		NetworkManager.GameMode.DUEL:
			mode_desc_label.text = GameSettings.t("duel_desc")
		NetworkManager.GameMode.BRAWL:
			mode_desc_label.text = GameSettings.t("brawl_desc")
		NetworkManager.GameMode.ZOMBIE:
			mode_desc_label.text = GameSettings.t("zombie_coop_desc")


# =============================================================================
# 加入房间界面
# =============================================================================
func _build_join_screen() -> void:
	join_screen = Control.new()
	join_screen.name = "JoinScreen"
	join_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.06, 1)
	join_screen.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	join_screen.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	# 标题
	var title: Label = Label.new()
	title.text = GameSettings.t("join_room")
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
	vbox.add_child(title)

	# 你的昵称（只读，已在首次游戏时设置）
	var nick_label: Label = Label.new()
	nick_label.text = GameSettings.t("your_nickname")
	nick_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(nick_label)

	join_nickname_input = LineEdit.new()
	join_nickname_input.custom_minimum_size = Vector2(250, 35)
	join_nickname_input.editable = false
	vbox.add_child(join_nickname_input)

	# 读取已保存的昵称
	var saved_nick: String = GameSettings.get_value("game", "nickname", "")
	if saved_nick != "":
		join_nickname_input.text = saved_nick

	# 提示
	var hint: Label = Label.new()
	hint.text = GameSettings.t("double_click_to_join")
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	vbox.add_child(hint)

	# 房间列表
	room_list = ItemList.new()
	room_list.custom_minimum_size = Vector2(400, 250)
	room_list.add_theme_font_size_override("font_size", 16)
	room_list.item_selected.connect(_on_room_selected)
	room_list.item_activated.connect(_on_room_activated)  # 双击
	vbox.add_child(room_list)

	# 无房间提示
	no_room_label = Label.new()
	no_room_label.text = GameSettings.t("no_rooms_found")
	no_room_label.add_theme_font_size_override("font_size", 14)
	no_room_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	no_room_label.visible = true
	vbox.add_child(no_room_label)

	# 刷新
	refresh_btn = Button.new()
	refresh_btn.text = GameSettings.t("refresh")
	refresh_btn.custom_minimum_size = Vector2(250, 40)
	refresh_btn.pressed.connect(func(): _update_room_list())
	vbox.add_child(refresh_btn)

	# 加入按钮（昵称非空+选中房间才能点击）
	join_btn = Button.new()
	join_btn.text = GameSettings.t("join_room")
	join_btn.custom_minimum_size = Vector2(250, 45)
	join_btn.add_theme_font_size_override("font_size", 18)
	join_btn.disabled = true
	join_btn.pressed.connect(_on_join_room_pressed)
	vbox.add_child(join_btn)

	# 实时验证：昵称非空才可能启用加入按钮
	join_nickname_input.text_changed.connect(func(_new_text: String): _validate_join_fields())

	# 返回
	join_back_btn = Button.new()
	join_back_btn.text = GameSettings.t("back")
	join_back_btn.custom_minimum_size = Vector2(250, 40)
	join_back_btn.pressed.connect(func():
		NetworkManager.stop_discovery()
		_show_state(LobbyState.SELECT_ACTION)
	)
	vbox.add_child(join_back_btn)

	add_child(join_screen)


# =============================================================================
# 等待界面（房主和客户端共用）
# =============================================================================
func _build_waiting_screen() -> void:
	waiting_screen = Control.new()
	waiting_screen.name = "WaitingScreen"
	waiting_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.06, 1)
	waiting_screen.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	waiting_screen.add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	# 房间标题
	waiting_label = Label.new()
	waiting_label.add_theme_font_size_override("font_size", 28)
	waiting_label.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
	vbox.add_child(waiting_label)

	# 模式标签
	waiting_mode_label = Label.new()
	waiting_mode_label.name = "ModeLabel"
	waiting_mode_label.add_theme_font_size_override("font_size", 18)
	waiting_mode_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	vbox.add_child(waiting_mode_label)

	# 玩家列表标题行
	player_list_title = Label.new()
	player_list_title.name = "PlayerListTitle"
	player_list_title.add_theme_font_size_override("font_size", 16)
	player_list_title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	vbox.add_child(player_list_title)

	# 玩家列表 VBox（每行一个 HBox：头像+文字）
	player_list_vbox = VBoxContainer.new()
	player_list_vbox.name = "PlayerListVBox"
	player_list_vbox.add_theme_constant_override("separation", 6)
	player_list_vbox.custom_minimum_size = Vector2(400, 120)
	vbox.add_child(player_list_vbox)

	# 颜色选择（所有模式都可以选颜色）
	color_select_container = HBoxContainer.new()
	color_select_container.name = "ColorSelect"
	color_select_container.alignment = BoxContainer.ALIGNMENT_CENTER
	color_select_container.add_theme_constant_override("separation", 12)
	color_select_container.visible = false
	vbox.add_child(color_select_container)

	# 动态创建颜色按钮（在 _update_color_buttons 中根据模式动态更新）
	color_buttons.clear()

	team_info_label = Label.new()
	team_info_label.name = "TeamInfoLabel"
	team_info_label.add_theme_font_size_override("font_size", 14)
	team_info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	vbox.add_child(team_info_label)

	# 模式切换按钮（只有房主可见）
	mode_switch_btn = Button.new()
	mode_switch_btn.name = "ModeSwitchBtn"
	mode_switch_btn.text = GameSettings.t("switch_mode")
	mode_switch_btn.custom_minimum_size = Vector2(250, 40)
	mode_switch_btn.add_theme_font_size_override("font_size", 16)
	mode_switch_btn.pressed.connect(_on_mode_switch_pressed)
	mode_switch_btn.visible = false
	vbox.add_child(mode_switch_btn)

	# 开始按钮（只有房主可见）
	start_btn = Button.new()
	start_btn.name = "StartBtn"
	start_btn.text = GameSettings.t("start_game")
	start_btn.custom_minimum_size = Vector2(250, 50)
	start_btn.add_theme_font_size_override("font_size", 20)
	start_btn.visible = false
	start_btn.pressed.connect(_on_start_game_pressed)
	vbox.add_child(start_btn)

	# 游戏进行中提示标签（游戏已开始时显示）
	game_status_label = Label.new()
	game_status_label.name = "GameStatusLabel"
	game_status_label.text = GameSettings.t("game_in_progress")
	game_status_label.add_theme_font_size_override("font_size", 22)
	game_status_label.add_theme_color_override("font_color", Color(1, 0.5, 0.2, 1))
	game_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_status_label.visible = false
	vbox.add_child(game_status_label)

	# 游戏进行中说明标签
	var game_hint_label: Label = Label.new()
	game_hint_label.name = "GameHintLabel"
	game_hint_label.text = GameSettings.t("game_in_progress_hint")
	game_hint_label.add_theme_font_size_override("font_size", 14)
	game_hint_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	game_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_hint_label.custom_minimum_size = Vector2(400, 30)
	game_hint_label.visible = false
	vbox.add_child(game_hint_label)

	# 中途加入游戏按钮（游戏进行中时显示）
	join_game_btn = Button.new()
	join_game_btn.name = "JoinGameBtn"
	join_game_btn.text = GameSettings.t("join_mid_game")
	join_game_btn.custom_minimum_size = Vector2(250, 50)
	join_game_btn.add_theme_font_size_override("font_size", 20)
	join_game_btn.visible = false
	join_game_btn.pressed.connect(_on_join_mid_game)
	vbox.add_child(join_game_btn)

	# 准备按钮（所有玩家都有）
	ready_btn = Button.new()
	ready_btn.custom_minimum_size = Vector2(250, 45)
	ready_btn.add_theme_font_size_override("font_size", 18)
	ready_btn.pressed.connect(_on_ready_pressed)
	vbox.add_child(ready_btn)

	# 取消按钮
	cancel_btn = Button.new()
	cancel_btn.text = GameSettings.t("cancel")
	cancel_btn.custom_minimum_size = Vector2(250, 40)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.pressed.connect(_on_cancel_waiting)
	vbox.add_child(cancel_btn)

	add_child(waiting_screen)


# =============================================================================
# 界面切换
# =============================================================================
func _show_state(state: LobbyState) -> void:
	current_state = state

	# 隐藏所有界面
	if select_screen: select_screen.visible = false
	if create_screen: create_screen.visible = false
	if join_screen: join_screen.visible = false
	if waiting_screen: waiting_screen.visible = false

	match state:
		LobbyState.SELECT_ACTION:
			select_screen.visible = true
		LobbyState.CREATE_ROOM:
			create_screen.visible = true
		LobbyState.JOIN_ROOM:
			join_screen.visible = true
			NetworkManager.start_discovery()
			refresh_timer = 0.0
		LobbyState.WAITING_HOST:
			waiting_screen.visible = true
			_update_waiting_screen()
		LobbyState.WAITING_CLIENT:
			waiting_screen.visible = true
			_update_waiting_screen()


func _update_waiting_screen() -> void:
	# 房间名称和模式
	if NetworkManager.game_in_progress:
		waiting_label.text = GameSettings.t("game_in_progress")
	else:
		waiting_label.text = GameSettings.t("room_title") % NetworkManager.room_name

	waiting_mode_label.text = NetworkManager.get_mode_display_name(NetworkManager.room_mode)

	# 玩家列表
	_update_player_list()

	# 游戏进行中时的特殊显示
	if NetworkManager.game_in_progress:
		# 游戏进行中：隐藏准备/开始/颜色选择，显示"加入游戏"按钮
		color_select_container.visible = false
		team_info_label.text = GameSettings.t("game_in_progress_hint")
		mode_switch_btn.visible = false
		start_btn.visible = false
		ready_btn.visible = false
		game_status_label.visible = true
		# "中途加入游戏"按钮：只在客户端显示（房主已经在游戏里）
		join_game_btn.visible = not NetworkManager.is_host
		# 显示游戏状态提示行
		var hint_node: Label = waiting_screen.find_child("GameHintLabel", true, false)
		if hint_node:
			hint_node.visible = true
	else:
		# 正常等待：显示准备/开始/颜色选择
		color_select_container.visible = (NetworkManager.room_mode != NetworkManager.GameMode.ZOMBIE)
		_update_color_buttons()
		if NetworkManager.room_mode != NetworkManager.GameMode.ZOMBIE:
			_update_color_highlight()
		# 开始按钮（仅房主），模式切换按钮（仅房主），准备按钮所有人都有
		if mode_switch_btn:
			mode_switch_btn.visible = NetworkManager.is_host
		start_btn.visible = NetworkManager.is_host
		ready_btn.visible = true
		_update_start_button()
		_update_ready_button()
		game_status_label.visible = false
		join_game_btn.visible = false
		var hint_node: Label = waiting_screen.find_child("GameHintLabel", true, false)
		if hint_node:
			hint_node.visible = false

	# 取消按钮文字：房主"解散房间"，客户端"离开房间"
	if NetworkManager.is_host:
		cancel_btn.text = GameSettings.t("disband_room")
	else:
		cancel_btn.text = GameSettings.t("leave_room")


func _update_player_list() -> void:
	# 清除旧的踢人按钮行
	if kick_hbox and is_instance_valid(kick_hbox):
		kick_hbox.queue_free()
		kick_hbox = null
	player_kick_buttons.clear()

	# 清除旧的玩家行
	for child in player_list_vbox.get_children():
		child.queue_free()

	# 标题行
	player_list_title.text = GameSettings.t("player_count") % [NetworkManager.player_count, NetworkManager.max_players]

	# 构建完整玩家 ID 列表
	var all_ids: Array = []
	for pid in NetworkManager.player_names.keys():
		all_ids.append(pid)
	all_ids.sort()

	var my_id: int = NetworkManager.get_local_player_id()

	for pid in all_ids:
		var p_name: String = NetworkManager.get_player_display_name(pid)
		var p_ready: bool = NetworkManager.player_ready.get(pid, false)
		var p_ready_str: String = GameSettings.t("ready") if p_ready else GameSettings.t("not_ready")
		var p_avatar_id: int = NetworkManager.player_avatars.get(pid, 0)

		# 每个玩家一行 HBox：头像 + 文字信息
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		player_list_vbox.add_child(row)

		# 头像
		var avatar: Control = Control.new()
		avatar.name = "Avatar_%d" % pid
		avatar.set_script(avatar_script)
		avatar.avatar_id = p_avatar_id
		avatar.avatar_size = Vector2(36, 36)
		row.add_child(avatar)

		# 文字信息
		var info_label: Label = Label.new()
		info_label.add_theme_font_size_override("font_size", 16)
		info_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
		var text: String = ""
		if NetworkManager.game_in_progress:
			# 游戏进行中：显示"在游戏中"而不是准备状态
			text = p_name + " [" + GameSettings.t("in_game") + "]"
		else:
			text = p_name + " [%s]" % p_ready_str
		if NetworkManager.room_mode != NetworkManager.GameMode.ZOMBIE:
			text += " — %s" % _get_color_display_name(pid)
		if pid == my_id:
			text += " (%s)" % GameSettings.t("you")
		if pid == 1:
			text += " ★"
		info_label.text = text
		row.add_child(info_label)

	# 房主能看到踢人按钮行（遍历所有玩家，排除自己）
	var non_host_ids: Array = all_ids.filter(func(p): return p != 1)
	if NetworkManager.is_host and non_host_ids.size() > 0:
		kick_hbox = HBoxContainer.new()
		kick_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		kick_hbox.add_theme_constant_override("separation", 8)
		for pid in non_host_ids:
			if pid == my_id:
				continue
			var kick_btn: Button = Button.new()
			kick_btn.text = GameSettings.t("kick") + " " + NetworkManager.get_player_display_name(pid)
			kick_btn.custom_minimum_size = Vector2(120, 30)
			kick_btn.add_theme_font_size_override("font_size", 14)
			var captured_pid: int = pid  # 防止lambda捕获循环变量
			kick_btn.pressed.connect(func(): NetworkManager.kick_player(captured_pid))
			kick_btn.pressed.connect(UIAudio.play_click)
			kick_hbox.add_child(kick_btn)
			player_kick_buttons[pid] = kick_btn
		# 添加踢人按钮行到 player_list_vbox 后面
		player_list_vbox.add_sibling(kick_hbox)


func _get_color_display_name(pid: int) -> String:
	if NetworkManager.room_mode == NetworkManager.GameMode.DUEL:
		return GameSettings.t(NetworkManager.duel_teams.get(pid, "red") + "_team")
	elif NetworkManager.room_mode == NetworkManager.GameMode.BRAWL:
		return GameSettings.t(NetworkManager.brawl_colors.get(pid, "blue") + "_team")
	elif NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
		return GameSettings.t(NetworkManager.zombie_colors.get(pid, "blue") + "_team")
	return ""


func _update_color_buttons() -> void:
	# 根据当前模式动态创建颜色按钮
	# 先清除旧按钮
	for child in color_select_container.get_children():
		child.queue_free()
	color_buttons.clear()

	var options: Array = NetworkManager.get_color_options()
	var color_names_map: Dictionary = {
		"red": GameSettings.t("red_team"),
		"blue": GameSettings.t("blue_team"),
		"yellow": GameSettings.t("yellow_team"),
		"green": GameSettings.t("green_team"),
	}

	for color_name in options:
		var btn: Button = Button.new()
		btn.text = color_names_map.get(color_name, color_name)
		btn.custom_minimum_size = Vector2(100, 40)
		# 按钮背景色对应队伍色
		var c: Color = NetworkManager.TEAM_COLORS[color_name]
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, 1)
		style.border_color = c
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.pressed.connect(func(): _on_color_selected(color_name))
		btn.pressed.connect(UIAudio.play_click)
		color_select_container.add_child(btn)
		color_buttons[color_name] = btn


func _update_color_highlight() -> void:
	# 高亮当前选中的颜色按钮，灰显已被他人选中的颜色
	var my_id: int = NetworkManager.get_local_player_id()
	var my_color: String = _get_my_current_color()

	# 获取已被其他人选的颜色
	var taken_colors: Array = []
	if NetworkManager.room_mode == NetworkManager.GameMode.DUEL:
		for pid in NetworkManager.duel_teams:
			if pid != my_id:
				taken_colors.append(NetworkManager.duel_teams[pid])
	elif NetworkManager.room_mode == NetworkManager.GameMode.BRAWL:
		for pid in NetworkManager.brawl_colors:
			if pid != my_id:
				taken_colors.append(NetworkManager.brawl_colors[pid])
	elif NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
		for pid in NetworkManager.zombie_colors:
			if pid != my_id:
				taken_colors.append(NetworkManager.zombie_colors[pid])

	for color_name in color_buttons:
		var btn: Button = color_buttons[color_name]
		if color_name == my_color:
			btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			btn.disabled = false
		elif color_name in taken_colors:
			btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
			btn.disabled = true
		else:
			btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
			btn.disabled = false

	# 更新信息标签
	_update_color_info()


func _get_my_current_color() -> String:
	var my_id: int = NetworkManager.get_local_player_id()
	if NetworkManager.room_mode == NetworkManager.GameMode.DUEL:
		return NetworkManager.duel_teams.get(my_id, "red")
	elif NetworkManager.room_mode == NetworkManager.GameMode.BRAWL:
		return NetworkManager.brawl_colors.get(my_id, "red")
	elif NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
		return NetworkManager.zombie_colors.get(my_id, "blue")
	return "red"


func _update_color_info() -> void:
	if NetworkManager.room_mode == NetworkManager.GameMode.DUEL:
		if NetworkManager.player_count < NetworkManager.max_players:
			team_info_label.text = GameSettings.t("waiting_for_player")
		else:
			# 检查是否同队
			var teams: Array = []
			for pid in NetworkManager.duel_teams:
				teams.append(NetworkManager.duel_teams[pid])
			if teams.size() >= 2 and teams[0] == teams[1]:
				team_info_label.text = GameSettings.t("same_team_warning")
			else:
				team_info_label.text = GameSettings.t("ready_to_start")
	elif NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
		# 僵尸合作模式不需要选色提示
		if NetworkManager.player_count < NetworkManager.max_players:
			team_info_label.text = GameSettings.t("waiting_for_player")
		elif not NetworkManager.is_host:
			team_info_label.text = GameSettings.t("waiting_for_host")
		else:
			team_info_label.text = GameSettings.t("ready_to_start")
	elif not NetworkManager.is_host:
		team_info_label.text = GameSettings.t("waiting_for_host")
	else:
		team_info_label.text = GameSettings.t("select_your_color")


func _update_start_button() -> void:
	if not NetworkManager.is_host:
		return

	# 单挑模式：队伍冲突优先提示（即使未全部准备也要显示）
	if NetworkManager.room_mode == NetworkManager.GameMode.DUEL:
		if not NetworkManager.can_start_duel():
			start_btn.disabled = true
			if NetworkManager.player_count < NetworkManager.max_players:
				start_btn.text = GameSettings.t("waiting_for_player")
			else:
				start_btn.text = GameSettings.t("same_team_warning")
			return
	# 乱斗/僵尸模式：颜色冲突优先提示
	if NetworkManager.room_mode == NetworkManager.GameMode.BRAWL or NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
		if _has_color_conflict():
			start_btn.disabled = true
			start_btn.text = GameSettings.t("color_conflict_warning")
			return

	# 所有模式都要求所有成员准备才能开始
	if not NetworkManager.all_ready():
		start_btn.disabled = true
		start_btn.text = GameSettings.t("waiting_for_ready")
		return

	# 条件全部满足
	if NetworkManager.room_mode == NetworkManager.GameMode.BRAWL:
		if NetworkManager.player_count < 2:
			start_btn.disabled = true
			start_btn.text = GameSettings.t("waiting_for_player")
		else:
			start_btn.disabled = false
			start_btn.text = GameSettings.t("start_game")
	elif NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
		if NetworkManager.player_count < 2:
			start_btn.disabled = true
			start_btn.text = GameSettings.t("waiting_for_player")
		else:
			start_btn.disabled = false
			start_btn.text = GameSettings.t("start_game")
	else:
		# 单挑：can_start_duel 已在上面检查通过
		start_btn.disabled = false
		start_btn.text = GameSettings.t("start_game")


func _has_color_conflict() -> bool:
	# 检查是否有两人选了相同颜色
	var used_colors: Array = []
	var color_dict: Dictionary = {}
	if NetworkManager.room_mode == NetworkManager.GameMode.BRAWL:
		color_dict = NetworkManager.brawl_colors
	elif NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
		color_dict = NetworkManager.zombie_colors
	else:
		return false

	for pid in color_dict:
		var c: String = color_dict[pid]
		if c in used_colors:
			return true
		used_colors.append(c)
	return false


# =============================================================================
# 事件回调
# =============================================================================
func _on_create_room_pressed() -> void:
	# 设置昵称（已由 _validate_create_fields 确保非空）
	var nick: String = _resolve_nickname(nickname_input.text.strip_edges())
	NetworkManager.player_name = nick

	# 保存昵称到本地（保存原始输入，下次仍自动填充）
	GameSettings.set_value("game", "nickname", nickname_input.text.strip_edges())

	var room_name_str: String = room_name_input.text.strip_edges()
	var mode: int = mode_option.get_selected_id()
	NetworkManager.create_room(room_name_str, mode as NetworkManager.GameMode)


func _validate_create_fields() -> void:
	var raw: String = nickname_input.text.strip_edges()
	# 禁止手动输入测试人员名称（必须通过特殊ID）
	if raw == TESTER_NAME and raw != TESTER_ID:
		create_btn.disabled = true
		return
	var nick_ok: bool = raw != ""
	var name_ok: bool = room_name_input.text.strip_edges() != ""
	create_btn.disabled = not (nick_ok and name_ok)


func _on_room_created(_room_name: String, _mode: int) -> void:
	_show_state(LobbyState.WAITING_HOST)


func _on_room_joined(_room_name: String, _mode: int) -> void:
	_show_state(LobbyState.WAITING_CLIENT)


func _on_player_joined(_peer_id: int) -> void:
	_update_waiting_screen()


func _on_player_left(_peer_id: int) -> void:
	_update_waiting_screen()


func _on_player_ready_changed(_peer_id: int, _is_ready: bool) -> void:
	_update_waiting_screen()


func _on_connection_failed(reason: String) -> void:
	# 显示错误信息
	var err_label: Label = Label.new()
	err_label.text = reason
	err_label.add_theme_font_size_override("font_size", 16)
	err_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	err_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_label.position = Vector2(200, 200)
	add_child(err_label)
	get_tree().create_timer(3.0).timeout.connect(func(): err_label.queue_free())
	_show_state(LobbyState.SELECT_ACTION)


func _on_host_disconnected() -> void:
	# 房主断开，回到选择界面
	NetworkManager.disconnect_network()
	_show_state(LobbyState.SELECT_ACTION)


func _on_kicked_from_room() -> void:
	# 被房主踢出，显示提示弹窗
	NetworkManager.disconnect_network()
	_show_kicked_dialog()


func _on_room_list_updated(_rooms: Dictionary) -> void:
	_update_room_list()


func _update_room_list() -> void:
	if not room_list:
		return
	room_list.clear()

	if NetworkManager.discovered_rooms.is_empty():
		if no_room_label:
			no_room_label.visible = true
		join_btn.disabled = true
		return

	if no_room_label:
		no_room_label.visible = false

	for ip in NetworkManager.discovered_rooms:
		var room: Dictionary = NetworkManager.discovered_rooms[ip]
		var mode_display: String = ""
		match room.mode:
			"duel": mode_display = GameSettings.t("duel_mode")
			"brawl": mode_display = GameSettings.t("brawl_mode")
			"zombie": mode_display = GameSettings.t("zombie_coop_mode")
		var in_game_tag: String = ""
		if room.get("in_game", false):
			in_game_tag = " [" + GameSettings.t("in_game") + "]"
		var display_text: String = "%s | %s%s | %d/%d" % [room.name, mode_display, in_game_tag, room.players, room.max_players]
		var idx: int = room_list.add_item(display_text)
		# 存储IP到item metadata
		room_list.set_item_metadata(idx, ip)

		if room.players >= room.max_players:
			room_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5, 1))


func _on_room_selected(idx: int) -> void:
	if idx < 0:
		join_btn.disabled = true
		return
	var ip: String = room_list.get_item_metadata(idx)
	var room: Dictionary = NetworkManager.discovered_rooms.get(ip, {})
	if room.is_empty() or room.players >= room.max_players:
		join_btn.disabled = true
	else:
		_validate_join_fields()


func _on_room_activated(idx: int) -> void:
	# 双击加入房间
	_on_room_selected(idx)
	if not join_btn.disabled:
		_on_join_room_pressed()


func _on_join_room_pressed() -> void:
	# 设置昵称（已由 _validate_join_fields 确保非空）
	var nick: String = _resolve_nickname(join_nickname_input.text.strip_edges())
	NetworkManager.player_name = nick

	# 保存昵称到本地（保存原始输入，下次仍自动填充）
	GameSettings.set_value("game", "nickname", join_nickname_input.text.strip_edges())

	var selected: Array = room_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	var ip: String = room_list.get_item_metadata(idx)
	NetworkManager.join_room(ip)


func _validate_join_fields() -> void:
	var raw: String = join_nickname_input.text.strip_edges()
	# 禁止手动输入测试人员名称（必须通过特殊ID）
	if raw == TESTER_NAME and raw != TESTER_ID:
		join_btn.disabled = true
		return
	var nick_ok: bool = raw != ""
	join_btn.disabled = not nick_ok or room_list.get_selected_items().is_empty()


func _on_color_selected(color_name: String) -> void:
	var my_id: int = NetworkManager.get_local_player_id()
	if NetworkManager.room_mode == NetworkManager.GameMode.DUEL:
		NetworkManager.set_duel_team(my_id, color_name)
	elif NetworkManager.room_mode == NetworkManager.GameMode.BRAWL:
		NetworkManager.set_brawl_color(my_id, color_name)
	elif NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
		NetworkManager.set_zombie_color(my_id, color_name)

	# 房主同步颜色信息到其他玩家
	if NetworkManager.is_host:
		_sync_colors.rpc(NetworkManager.duel_teams, NetworkManager.brawl_colors, NetworkManager.zombie_colors)
	else:
		_request_color_change.rpc(my_id, color_name)
	_update_waiting_screen()


@rpc("any_peer", "call_remote", "reliable")
func _request_color_change(peer_id: int, color_name: String) -> void:
	# 客户端请求切换颜色，房主处理
	if not NetworkManager.is_host:
		return
	if NetworkManager.room_mode == NetworkManager.GameMode.DUEL:
		NetworkManager.set_duel_team(peer_id, color_name)
	elif NetworkManager.room_mode == NetworkManager.GameMode.BRAWL:
		NetworkManager.set_brawl_color(peer_id, color_name)
	elif NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
		NetworkManager.set_zombie_color(peer_id, color_name)
	_sync_colors.rpc(NetworkManager.duel_teams, NetworkManager.brawl_colors, NetworkManager.zombie_colors)


@rpc("authority", "call_remote", "reliable")
func _sync_colors(teams: Dictionary, b_colors: Dictionary, z_colors: Dictionary) -> void:
	# 房主同步颜色信息到所有客户端
	NetworkManager.duel_teams = teams
	NetworkManager.brawl_colors = b_colors
	NetworkManager.zombie_colors = z_colors
	_update_waiting_screen()


func _update_ready_button() -> void:
	if not ready_btn:
		return
	var is_ready: bool = NetworkManager.is_local_ready()
	if is_ready:
		ready_btn.text = GameSettings.t("cancel_ready")
		# 准备后按钮变绿色
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.6, 0.3, 1)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		ready_btn.add_theme_stylebox_override("normal", style)
	else:
		ready_btn.text = GameSettings.t("ready_up")
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.3, 0.3, 1)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		ready_btn.add_theme_stylebox_override("normal", style)


func _on_ready_pressed() -> void:
	NetworkManager.toggle_ready()
	_update_ready_button()
	_update_player_list()


func _on_start_game_pressed() -> void:
	if not NetworkManager.is_host:
		return

	# 验证条件
	if NetworkManager.room_mode == NetworkManager.GameMode.DUEL and not NetworkManager.can_start_duel():
		return

	# 通知所有客户端开始游戏
	# _notify_game_start 是 @rpc("call_remote") 无 call_local
	# .rpc() 仅发送到远程客户端，不在主机本地执行
	NetworkManager._notify_game_start.rpc(NetworkManager.room_mode)
	# 等一帧让 RPC 发出，避免 Lobby 节点提前释放导致 pending RPC 找不到目标
	await get_tree().process_frame
	# 主机加载游戏场景
	_start_game_scene(NetworkManager.room_mode)


func _on_game_start_requested(mode: int) -> void:
	# 客户端收到开始游戏信号
	_start_game_scene(mode as NetworkManager.GameMode)


func _start_game_scene(mode: NetworkManager.GameMode) -> void:
	# 进入游戏场景前停止主界面BGM
	BGMManager.stop_bgm()
	match mode:
		NetworkManager.GameMode.DUEL:
			get_tree().change_scene_to_file("res://scenes/game/multiplayer/duel_game.tscn")
		NetworkManager.GameMode.BRAWL:
			get_tree().change_scene_to_file("res://scenes/game/multiplayer/brawl_game.tscn")
		NetworkManager.GameMode.ZOMBIE:
			get_tree().change_scene_to_file("res://scenes/game/multiplayer/zombie_coop_game.tscn")


func _on_join_mid_game() -> void:
	# 中途加入正在进行的游戏
	if not NetworkManager.game_in_progress:
		return
	var mode: int = NetworkManager.game_in_progress_mode
	_start_game_scene(mode as NetworkManager.GameMode)


func _on_mode_switch_pressed() -> void:
	# 只有房主可以切换模式
	if not NetworkManager.is_host:
		return
	# 循环切换模式：DUEL → BRAWL → ZOMBIE → DUEL
	var current_mode: NetworkManager.GameMode = NetworkManager.room_mode
	var new_mode: NetworkManager.GameMode
	match current_mode:
		NetworkManager.GameMode.DUEL:
			new_mode = NetworkManager.GameMode.BRAWL
		NetworkManager.GameMode.BRAWL:
			new_mode = NetworkManager.GameMode.ZOMBIE
		NetworkManager.GameMode.ZOMBIE:
			new_mode = NetworkManager.GameMode.DUEL
		_:
			new_mode = NetworkManager.GameMode.DUEL
	NetworkManager.change_room_mode(new_mode)
	# 重置所有玩家准备状态（模式切换后需要重新确认）
	NetworkManager.reset_ready()
	# 更新界面
	_update_waiting_screen()


func _on_room_mode_changed(_mode: NetworkManager.GameMode) -> void:
	# 房主切换了模式，更新等待界面
	if current_state == LobbyState.WAITING_HOST or current_state == LobbyState.WAITING_CLIENT:
		_update_waiting_screen()


func _on_cancel_waiting() -> void:
	NetworkManager.disconnect_network()
	_show_state(LobbyState.SELECT_ACTION)


func _on_back_to_menu() -> void:
	NetworkManager.disconnect_network()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _show_kicked_dialog() -> void:
	# 被踢出房间的提示弹窗
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "KickedDialog"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.08, 1)
	style.border_color = Color(0.8, 0.2, 0.2, 1)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	style.content_margin_left = 30
	style.content_margin_right = 30
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	var msg_label: Label = Label.new()
	msg_label.text = GameSettings.t("kicked_msg")
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg_label)

	var ok_btn: Button = Button.new()
	ok_btn.text = GameSettings.t("confirm_btn")
	ok_btn.custom_minimum_size = Vector2(150, 45)
	ok_btn.add_theme_font_size_override("font_size", 18)
	ok_btn.pressed.connect(UIAudio.play_click)
	ok_btn.pressed.connect(func():
		overlay.queue_free()
		_show_state(LobbyState.SELECT_ACTION)
	)
	vbox.add_child(ok_btn)

	add_child(overlay)
