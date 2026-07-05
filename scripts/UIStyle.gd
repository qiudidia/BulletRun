extends Node
## 通用UI样式工具
## 提供一致的科技战术风格样式，供全项目复用

const ACCENT_BLUE := Color(0.2, 0.5, 1.0, 1.0)
const ACCENT_GOLD := Color(1.0, 0.85, 0.3, 1.0)
const BG_DARK := Color(0.03, 0.04, 0.08, 1.0)
const PANEL_BG := Color(0.06, 0.08, 0.12, 0.95)
const PANEL_BORDER := Color(0.3, 0.5, 0.8, 0.6)


func create_panel_style(bg_color: Color = PANEL_BG, border_color: Color = PANEL_BORDER, border_width: int = 2, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.set("shadow_size", 0)
	return style


func create_button_style(normal_color: Color = Color(0.06, 0.08, 0.12, 0.9), border_color: Color = ACCENT_BLUE, hover_color: Color = Color(0.1, 0.15, 0.25, 0.9), accent: Color = ACCENT_BLUE) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.border_color = border_color
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = hover_color
	hover.border_color = accent
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 18
	hover.content_margin_right = 18
	hover.content_margin_top = 10
	hover.content_margin_bottom = 10
	
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = accent * 0.2 + Color(0.04, 0.06, 0.1, 0.9)
	pressed.border_color = accent
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	pressed.corner_radius_top_left = 6
	pressed.corner_radius_top_right = 6
	pressed.corner_radius_bottom_left = 6
	pressed.corner_radius_bottom_right = 6
	pressed.content_margin_left = 18
	pressed.content_margin_right = 18
	pressed.content_margin_top = 11
	pressed.content_margin_bottom = 9
	
	return {"normal": normal, "hover": hover, "pressed": pressed}


func apply_button_styles(btn: Button, styles: Dictionary) -> void:
	if styles.has("normal"):
		btn.add_theme_stylebox_override("normal", styles["normal"])
	if styles.has("hover"):
		btn.add_theme_stylebox_override("hover", styles["hover"])
	if styles.has("pressed"):
		btn.add_theme_stylebox_override("pressed", styles["pressed"])


func create_glow_button(text: String, icon: String, color: Color = ACCENT_BLUE, width: int = 280, height: int = 48, font_size: int = 18) -> Button:
	var btn := Button.new()
	btn.text = "  " + icon + "  " + text
	btn.custom_minimum_size = Vector2(width, height)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	
	var styles := create_button_style(
		Color(0.06, 0.08, 0.12, 0.9),
		color * 0.6,
		color * 0.15 + Color(0.06, 0.08, 0.12, 0.9),
		color
	)
	styles["normal"].border_color = color * 0.6
	apply_button_styles(btn, styles)
	return btn


func create_card_panel(title: String, color: Color = ACCENT_BLUE) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.1, 0.95)
	style.border_color = color * 0.4
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 4
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", style)
	
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", color)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(title_label)
	
	return card


func create_styled_slider(min_val: float, max_val: float, value: float, step: float = 1.0) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.12, 0.16, 1)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.set("expand_margin_left", 0)
	bg_style.set("expand_margin_right", 0)
	bg_style.set("expand_margin_top", 0)
	bg_style.set("expand_margin_bottom", 0)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.7, 1.0, 0.8)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	fill_style.set("expand_margin_left", 0)
	fill_style.set("expand_margin_right", 0)
	fill_style.set("expand_margin_top", 0)
	fill_style.set("expand_margin_bottom", 0)
	
	slider.add_theme_stylebox_override("slider", bg_style)
	slider.add_theme_stylebox_override("fill", fill_style)
	
	return slider


func create_styled_progress_bar(value: float = 0.0, color: Color = Color(0.3, 0.7, 1.0, 0.9)) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.value = value
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.14, 0.18, 1)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_stylebox_override("background", bg_style)
	
	return bar


func create_styled_option_button() -> OptionButton:
	var opt := OptionButton.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	opt.add_theme_stylebox_override("normal", style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.1, 0.14, 0.2, 0.9)
	hover_style.border_color = Color(0.4, 0.6, 1.0, 0.7)
	hover_style.border_width_left = 2
	hover_style.border_width_right = 2
	hover_style.border_width_top = 1
	hover_style.border_width_bottom = 2
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	hover_style.content_margin_left = 12
	hover_style.content_margin_right = 12
	hover_style.content_margin_top = 6
	hover_style.content_margin_bottom = 6
	opt.add_theme_stylebox_override("hover", hover_style)
	
	return opt


func create_styled_line_edit() -> LineEdit:
	var line := LineEdit.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	line.add_theme_stylebox_override("normal", style)
	
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	focus_style.border_color = Color(0.4, 0.6, 1.0, 0.8)
	focus_style.border_width_left = 2
	focus_style.border_width_right = 2
	focus_style.border_width_top = 1
	focus_style.border_width_bottom = 2
	focus_style.corner_radius_top_left = 6
	focus_style.corner_radius_top_right = 6
	focus_style.corner_radius_bottom_left = 6
	focus_style.corner_radius_bottom_right = 6
	focus_style.content_margin_left = 10
	focus_style.content_margin_right = 10
	focus_style.content_margin_top = 6
	focus_style.content_margin_bottom = 6
	line.add_theme_stylebox_override("focus", focus_style)
	
	return line


func create_styled_check_box() -> CheckBox:
	var cb := CheckBox.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	cb.add_theme_stylebox_override("normal", style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.1, 0.14, 0.2, 0.9)
	hover_style.border_color = Color(0.4, 0.6, 1.0, 0.7)
	hover_style.border_width_left = 2
	hover_style.border_width_right = 2
	hover_style.border_width_top = 2
	hover_style.border_width_bottom = 2
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	cb.add_theme_stylebox_override("hover", hover_style)
	
	return cb


func create_tab_style(active: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
		style.border_color = Color(0.3, 0.6, 1.0, 0.7)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 0
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
	else:
		style.bg_color = Color(0.05, 0.07, 0.1, 0.8)
		style.border_color = Color(0.2, 0.3, 0.5, 0.4)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
