extends Node
## 更新管理器（Autoload）
## 启动时自动检查GitHub Releases
## 发现新版本时显示更新提示

signal update_available(latest_version: String, current_version: String, download_url: String)
signal update_not_available()
signal check_failed(reason: String)

@export var github_user: String = "qiudidia"
@export var github_repo: String = "BulletRun"
@export var check_on_startup: bool = true        # 启动时自动检查
@export var skip_version: String = ""             # 跳过此版本的更新提示

var http_request: HTTPRequest = null
var current_version: String = ""
var is_checking: bool = false


func _ready() -> void:
	# 读取当前版本
	current_version = _get_current_version()
	
	# 创建HTTP请求节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	# 启动时自动检查
	if check_on_startup:
		check_for_updates()


func check_for_updates() -> void:
	# 检查更新（可手动调用）
	if is_checking:
		return
	
	is_checking = true
	
	var url: String = "https://api.github.com/repos/%s/%s/releases/latest" % [github_user, github_repo]
	var headers: PackedStringArray = ["User-Agent: BulletRun/1.0"]
	
	print("[UpdateManager] 检查更新: %s" % url)
	http_request.request(url, headers)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# 处理GitHub API响应
	is_checking = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("[UpdateManager] 网络请求失败: %d" % result)
		check_failed.emit("网络请求失败")
		return
	
	if response_code != 200:
		printerr("[UpdateManager] GitHub API错误: %d" % response_code)
		check_failed.emit("GitHub API返回错误: %d" % response_code)
		return
	
	# 解析JSON
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		printerr("[UpdateManager] JSON解析失败")
		check_failed.emit("JSON解析失败")
		return
	
	var data: Dictionary = json.data
	
	# 获取最新版本号
	var latest_version: String = data.get("tag_name", "")
	
	if latest_version.is_empty():
		check_failed.emit("未找到版本信息")
		return
	
	print("[UpdateManager] 当前版本: %s, 最新版本: %s" % [current_version, latest_version])
	
	# 检查是否跳过此版本
	if skip_version == latest_version:
		print("[UpdateManager] 跳过版本: %s" % latest_version)
		update_not_available.emit()
		return
	
	# 比较版本
	if _compare_versions(latest_version, current_version) > 0:
		# 发现新版本
		var download_url: String = _get_download_url(data)
		var changelog: String = data.get("body", "")
		
		print("[UpdateManager] 发现新版本: %s" % latest_version)
		update_available.emit(latest_version, current_version, download_url)
		
		# 显示更新提示
		_show_update_notification(latest_version, current_version, download_url, changelog)
	else:
		print("[UpdateManager] 已是最新版本")
		update_not_available.emit()


func _compare_versions(v1: String, v2: String) -> int:
	# 比较版本号
	# 返回: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
	v1 = v1.lstrip("vV")
	v2 = v2.lstrip("vV")
	
	var parts1: PackedStringArray = v1.split(".")
	var parts2: PackedStringArray = v2.split(".")
	
	var max_len: int = max(parts1.size(), parts2.size())
	
	for i in range(max_len):
		var num1: int = int(parts1[i]) if i < parts1.size() else 0
		var num2: int = int(parts2[i]) if i < parts2.size() else 0
		
		if num1 > num2:
			return 1
		elif num1 < num2:
			return -1
	
	return 0


func _get_download_url(data: Dictionary) -> String:
	# 获取下载URL
	var assets: Array = data.get("assets", [])
	
	if assets.size() > 0:
		return assets[0].get("browser_download_url", "")
	
	# 如果没有附件，返回Release页面URL
	return data.get("html_url", "")


func _get_current_version() -> String:
	# 读取本地版本文件
	var file: FileAccess = FileAccess.open("res://version.txt", FileAccess.READ)
	if file:
		return file.get_line().strip_edges()
	return "v0.0.0"


func _show_update_notification(latest: String, current: String, url: String, _changelog: String) -> void:
	# 显示更新提示UI
	# 创建提示面板
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "UpdateNotification"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 60
	panel.offset_bottom = 160
	
	# 样式
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.2, 0.95)
	style.border_color = Color(0.3, 0.7, 1.0, 0.8)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.content_margin_left = 20
	style.content_margin_right = 20
	panel.add_theme_stylebox_override("panel", style)
	
	# 内容容器
	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	panel.add_child(content)
	
	# 图标
	var icon: Label = Label.new()
	icon.text = "🔄"
	icon.add_theme_font_size_override("font_size", 32)
	content.add_child(icon)
	
	# 文字信息
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	content.add_child(info_vbox)
	
	var title: Label = Label.new()
	title.text = "发现新版本！"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0, 1))
	info_vbox.add_child(title)
	
	var version_info: Label = Label.new()
	version_info.text = "当前版本: %s → 最新版本: %s" % [current, latest]
	version_info.add_theme_font_size_override("font_size", 14)
	version_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	info_vbox.add_child(version_info)
	
	# 按钮容器
	var btn_vbox: VBoxContainer = VBoxContainer.new()
	btn_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_vbox.add_theme_constant_override("separation", 6)
	content.add_child(btn_vbox)
	
	# 下载按钮
	var download_btn: Button = Button.new()
	download_btn.text = "前往下载"
	download_btn.custom_minimum_size = Vector2(120, 35)
	download_btn.pressed.connect(func(): _on_download_pressed(url))
	download_btn.pressed.connect(UIAudio.play_click)
	btn_vbox.add_child(download_btn)
	
	# 跳过按钮
	var skip_btn: Button = Button.new()
	skip_btn.text = "跳过此版本"
	skip_btn.custom_minimum_size = Vector2(120, 30)
	skip_btn.add_theme_font_size_override("font_size", 12)
	skip_btn.pressed.connect(func(): _on_skip_pressed(latest, panel))
	skip_btn.pressed.connect(UIAudio.play_click)
	btn_vbox.add_child(skip_btn)
	
	# 添加到场景
	get_tree().root.add_child(panel)
	
	# 自动消失动画（10秒后）
	var tween: Tween = panel.create_tween()
	tween.tween_delay(10.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): panel.queue_free())


func _on_download_pressed(url: String) -> void:
	# 打开下载链接
	print("[UpdateManager] 打开下载链接: %s" % url)
	OS.shell_open(url)


func _on_skip_pressed(version: String, panel: PanelContainer) -> void:
	# 跳过此版本
	skip_version = version
	panel.queue_free()
	print("[UpdateManager] 跳过版本: %s" % version)


func set_skip_version(version: String) -> void:
	# 设置跳过版本（持久化）
	skip_version = version
	# TODO: 保存到配置文件


func get_current_version() -> String:
	# 获取当前版本（供外部调用）
	return current_version
