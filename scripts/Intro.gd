extends Control

# =============================================================================
# 开场动画控制器
# 三阶段：Vee Studio Logo+文字(同时) → Godot Logo → 游戏标题 → 进入主菜单
# 点击左键可跳过
# =============================================================================

@onready var vee_icon: TextureRect = $VBoxContainer/VeeIcon
@onready var vee_text: Label = $VBoxContainer/VeeText
@onready var godot_logo: Control = $VBoxContainer/GodotLogo
@onready var title_card: Control = $VBoxContainer/TitleCard
@onready var title_label: Label = $VBoxContainer/TitleCard/TitleLabel
@onready var subtitle_label: Label = $VBoxContainer/TitleCard/SubtitleLabel
@onready var skip_hint: Label = $SkipHint

# 动画阶段
enum Phase { VEE, GODOT, TITLE, DONE }
var current_phase: Phase = Phase.VEE
var phase_timer: float = 0.0

# 各阶段时长（秒）
const VEE_DURATION: float = 2.2
const GODOT_DURATION: float = 2.0
const TITLE_DURATION: float = 2.5

# 插值用
var transition_triggered: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# 多语言
	if skip_hint:
		skip_hint.text = GameSettings.t("skip_hint")

	# 初始状态：全部隐藏
	vee_icon.modulate.a = 0.0
	vee_icon.visible = true
	vee_icon.scale = Vector2(0.7, 0.7)

	vee_text.modulate.a = 0.0
	vee_text.visible = true
	vee_text.scale = Vector2(0.9, 0.9)

	godot_logo.modulate.a = 0.0
	godot_logo.scale = Vector2(0.9, 0.9)
	godot_logo.visible = false

	title_card.modulate.a = 0.0
	title_card.scale = Vector2(0.8, 0.8)
	title_card.visible = false
	subtitle_label.modulate.a = 0.0

	phase_timer = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if current_phase == Phase.DONE:
		return
	match current_phase:
		Phase.VEE:
			_process_vee(delta)
		Phase.GODOT:
			_process_godot(delta)
		Phase.TITLE:
			_process_title(delta)


func _input(event: InputEvent) -> void:
	if current_phase != Phase.DONE and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_skip_to_menu()


# ── 阶段1：Vee Studio Logo + 文字同时淡入 ──────────────────────

func _process_vee(delta: float) -> void:
	phase_timer += delta
	var t: float = clamp(phase_timer / VEE_DURATION, 0.0, 1.0)

	var a: float = ease_in_out(t)

	# 图标淡入 + 缩放
	vee_icon.modulate.a = a
	var si: float = lerp(0.7, 1.0, t)
	vee_icon.scale = Vector2(si, si)

	# 文字同时淡入 + 缩放
	vee_text.modulate.a = a
	var st: float = lerp(0.9, 1.0, t)
	vee_text.scale = Vector2(st, st)

	# 显示完毕，切换到 Godot 阶段
	if phase_timer >= VEE_DURATION:
		_vee_to_godot()


func _vee_to_godot() -> void:
	current_phase = Phase.GODOT
	phase_timer = 0.0
	vee_icon.visible = false
	vee_text.visible = false
	godot_logo.visible = true


# ── 阶段2：Godot Logo 淡入 ─────────────────────────────────────

func _process_godot(delta: float) -> void:
	phase_timer += delta
	var t: float = clamp(phase_timer / GODOT_DURATION, 0.0, 1.0)

	godot_logo.modulate.a = ease_in_out(t)
	var s: float = lerp(0.9, 1.0, t)
	godot_logo.scale = Vector2(s, s)

	if phase_timer >= GODOT_DURATION:
		_godot_to_title()


func _godot_to_title() -> void:
	current_phase = Phase.TITLE
	phase_timer = 0.0
	godot_logo.visible = false
	title_card.visible = true


# ── 阶段3：游戏标题淡入 ───────────────────────────────────────

func _process_title(delta: float) -> void:
	phase_timer += delta
	var t: float = clamp(phase_timer / TITLE_DURATION, 0.0, 1.0)

	title_card.modulate.a = ease_in_out(t)
	title_card.scale = Vector2(lerp(0.8, 1.0, t), lerp(0.8, 1.0, t))

	if t > 0.3:
		var st: float = clamp((t - 0.3) / 0.7, 0.0, 1.0)
		subtitle_label.modulate.a = ease_in_out(st)

	if phase_timer > TITLE_DURATION and not transition_triggered:
		transition_triggered = true
		get_tree().create_timer(0.8).timeout.connect(_transition_to_menu)


func _transition_to_menu() -> void:
	current_phase = Phase.DONE
	# 检查是否已设置昵称，未设置则弹出设置窗口
	var saved_nick: String = GameSettings.get_value("game", "nickname", "")
	if saved_nick == "":
		_show_nickname_setup()
	else:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _skip_to_menu() -> void:
	current_phase = Phase.DONE
	# 检查是否已设置昵称，未设置则弹出设置窗口
	var saved_nick: String = GameSettings.get_value("game", "nickname", "")
	if saved_nick == "":
		_show_nickname_setup()
	else:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


# ── 首次游戏昵称设置窗口 ───────────────────────────────────────

func _show_nickname_setup() -> void:
	# 停止输入处理（避免触发跳过）
	set_process_input(false)

	# 全屏半透明遮罩
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "NicknameOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	add_child(overlay)

	# 中央居中容器
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	# 中央面板
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "NicknamePanel"
	panel.custom_minimum_size = Vector2(400, 220)
	center.add_child(panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.18, 1)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# 标题
	var title: Label = Label.new()
	title.text = "首次游戏，请设置昵称"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 输入框
	var nick_input: LineEdit = LineEdit.new()
	nick_input.name = "NickInput"
	nick_input.placeholder_text = "输入昵称（最多12字符）"
	nick_input.max_length = 12
	nick_input.custom_minimum_size = Vector2(300, 40)
	nick_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nick_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(nick_input)

	# 必填提示
	var hint_label: Label = Label.new()
	hint_label.text = "必须输入昵称，不能为空"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_label)

	# 按钮
	var confirm_btn: Button = Button.new()
	confirm_btn.text = "确定"
	confirm_btn.custom_minimum_size = Vector2(160, 42)
	confirm_btn.add_theme_font_size_override("font_size", 18)
	confirm_btn.disabled = true
	vbox.add_child(confirm_btn)

	# 实时验证：有内容时启用按钮
	nick_input.text_changed.connect(func(_text: String):
		confirm_btn.disabled = nick_input.text.strip_edges() == ""
	)

	# 确认事件
	confirm_btn.pressed.connect(func():
		var nick: String = nick_input.text.strip_edges()
		if nick == "":
			return
		GameSettings.set_value("game", "nickname", nick)
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)

	# 回车确认（按钮启用时才生效）
	nick_input.text_submitted.connect(func(_text: String):
		if not confirm_btn.disabled:
			confirm_btn.pressed.emit()
	)

	# 聚焦输入框
	nick_input.grab_focus()


# 平滑插值
func ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
