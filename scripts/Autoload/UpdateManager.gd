extends Node
## 更新管理器（Autoload）
## 启动时自动检查GitHub Releases（含prerelease）
## 发现新版本时显示更新提示

signal update_available(latest_version: String, current_version: String, download_url: String)
signal update_not_available()
signal check_failed(reason: String)

@export var github_user: String = "qiudidia"
@export var github_repo: String = "BulletRun"
@export var check_on_startup: bool = true
@export var skip_version: String = ""

const FALLBACK_VERSION: String = "alpha3.8"

var http_request: HTTPRequest = null
var current_version: String = ""
var is_checking: bool = false


func _ready() -> void:
	current_version = _get_current_version()
	print("[UpdateManager] 当前版本: %s" % current_version)
	
	http_request = HTTPRequest.new()
	http_request.tls_options = TLSOptions.client_unsafe()
	http_request.timeout = 10.0
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	skip_version = GameSettings.get_value("game", "skip_update_version", "")
	
	if check_on_startup:
		get_tree().create_timer(2.0).timeout.connect(check_for_updates)


func check_for_updates() -> void:
	if is_checking:
		return
	
	is_checking = true
	
	var url: String = "https://api.github.com/repos/%s/%s/releases?per_page=1" % [github_user, github_repo]
	var headers: PackedStringArray = ["User-Agent: BulletRun/1.0", "Accept: application/vnd.github+json"]
	
	print("[UpdateManager] 检查更新: %s" % url)
	var err: int = http_request.request(url, headers)
	if err != OK:
		printerr("[UpdateManager] 请求发送失败: %d" % err)
		is_checking = false
		check_failed.emit("请求发送失败")
		return


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_checking = false
	
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("[UpdateManager] 网络请求失败: %d" % result)
		check_failed.emit("网络请求失败")
		return
	
	if response_code != 200:
		printerr("[UpdateManager] GitHub API错误: %d" % response_code)
		check_failed.emit("GitHub API返回错误: %d" % response_code)
		return
	
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		printerr("[UpdateManager] JSON解析失败")
		check_failed.emit("JSON解析失败")
		return
	
	var data: Dictionary
	if json.data is Array:
		var releases: Array = json.data
		if releases.is_empty():
			printerr("[UpdateManager] 没有找到任何Release")
			check_failed.emit("没有找到任何Release")
			return
		data = releases[0]
	elif json.data is Dictionary:
		data = json.data
	else:
		check_failed.emit("未知响应格式")
		return
	
	var latest_version: String = data.get("tag_name", "")
	
	if latest_version.is_empty():
		check_failed.emit("未找到版本信息")
		return
	
	print("[UpdateManager] 当前版本: %s, 最新版本: %s" % [current_version, latest_version])
	
	if skip_version == latest_version:
		print("[UpdateManager] 跳过版本: %s" % latest_version)
		update_not_available.emit()
		return
	
	if _compare_versions(latest_version, current_version) > 0:
		var download_url: String = _get_download_url(data)
		var changelog: String = data.get("body", "")
		
		print("[UpdateManager] 发现新版本: %s" % latest_version)
		update_available.emit(latest_version, current_version, download_url)
		
		_show_update_notification(latest_version, current_version, download_url, changelog)
	else:
		print("[UpdateManager] 已是最新版本")
		update_not_available.emit()


func _compare_versions(v1: String, v2: String) -> int:
	v1 = v1.lstrip("vV")
	v2 = v2.lstrip("vV")
	
	var nums1: Array = _extract_version_numbers(v1)
	var nums2: Array = _extract_version_numbers(v2)
	
	var max_len: int = max(nums1.size(), nums2.size())
	
	for i in range(max_len):
		var n1: int = nums1[i] if i < nums1.size() else 0
		var n2: int = nums2[i] if i < nums2.size() else 0
		
		if n1 > n2:
			return 1
		elif n1 < n2:
			return -1
	
	return 0


func _extract_version_numbers(s: String) -> Array:
	var regex: RegEx = RegEx.new()
	regex.compile("\\d+")
	var results: Array = regex.search_all(s)
	var nums: Array = []
	for r in results:
		nums.append(int(r.get_string()))
	return nums


func _get_download_url(data: Dictionary) -> String:
	var assets: Array = data.get("assets", [])
	
	for asset in assets:
		var name: String = asset.get("name", "").lower()
		if "win" in name or "windows" in name:
			return asset.get("browser_download_url", "")
	
	if assets.size() > 0:
		return assets[0].get("browser_download_url", "")
	
	return data.get("html_url", "")


func _get_current_version() -> String:
	var file: FileAccess = FileAccess.open("res://version.txt", FileAccess.READ)
	if file:
		var ver: String = file.get_line().strip_edges()
		if not ver.is_empty():
			return ver
	return FALLBACK_VERSION


func _show_update_notification(latest: String, current: String, url: String, _changelog: String) -> void:
	var existing: Node = get_tree().root.get_node_or_null("UpdateNotification")
	if existing:
		existing.queue_free()
	
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "UpdateNotification"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_top = 60
	panel.offset_bottom = 170
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.2, 0.97)
	style.border_color = Color(0.3, 0.7, 1.0, 0.9)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.content_margin_left = 20
	style.content_margin_right = 20
	panel.add_theme_stylebox_override("panel", style)
	
	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	panel.add_child(content)
	
	var icon: Label = Label.new()
	icon.text = "🔄"
	icon.add_theme_font_size_override("font_size", 32)
	content.add_child(icon)
	
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
	version_info.text = "当前版本: %s  →  最新版本: %s" % [current, latest]
	version_info.add_theme_font_size_override("font_size", 14)
	version_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	info_vbox.add_child(version_info)
	
	var btn_vbox: VBoxContainer = VBoxContainer.new()
	btn_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_vbox.add_theme_constant_override("separation", 6)
	content.add_child(btn_vbox)
	
	var download_btn: Button = Button.new()
	download_btn.text = "前往下载"
	download_btn.custom_minimum_size = Vector2(120, 35)
	download_btn.pressed.connect(func(): _on_download_pressed(url))
	download_btn.pressed.connect(UIAudio.play_click)
	btn_vbox.add_child(download_btn)
	
	var skip_btn: Button = Button.new()
	skip_btn.text = "跳过此版本"
	skip_btn.custom_minimum_size = Vector2(120, 30)
	skip_btn.add_theme_font_size_override("font_size", 12)
	skip_btn.pressed.connect(func(): _on_skip_pressed(latest, panel))
	skip_btn.pressed.connect(UIAudio.play_click)
	btn_vbox.add_child(skip_btn)
	
	var close_btn: Button = Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(120, 30)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): panel.queue_free())
	close_btn.pressed.connect(UIAudio.play_click)
	btn_vbox.add_child(close_btn)
	
	get_tree().root.add_child(panel)


func _on_download_pressed(url: String) -> void:
	print("[UpdateManager] 打开下载链接: %s" % url)
	OS.shell_open(url)


func _on_skip_pressed(version: String, panel: PanelContainer) -> void:
	skip_version = version
	GameSettings.set_value("game", "skip_update_version", version)
	panel.queue_free()
	print("[UpdateManager] 跳过版本: %s" % version)


func set_skip_version(version: String) -> void:
	skip_version = version


func get_current_version() -> String:
	return current_version