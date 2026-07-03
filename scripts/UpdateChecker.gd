extends Node
## 更新检查器
## 检查GitHub Releases获取最新版本
## 如果发现新版本，显示更新提示

signal update_available(latest_version: String, download_url: String, changelog: String)
signal update_not_available()
signal update_check_failed(reason: String)

@export var github_user: String = "你的用户名"  # 替换为你的GitHub用户名
@export var github_repo: String = "BulletRun"      # 替换为你的仓库名
@export var check_on_start: bool = true           # 启动时自动检查

var http_request: HTTPRequest = null
var current_version: String = ""


func _ready() -> void:
	# 读取当前版本
	current_version = _get_current_version()
	
	# 创建HTTP请求节点
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	# 如果设置了启动时检查，则自动检查
	if check_on_start:
		check_for_updates()


func check_for_updates() -> void:
	# 检查更新
	var url: String = "https://api.github.com/repos/%s/%s/releases/latest" % [github_user, github_repo]
	
	# 设置User-Agent（GitHub API要求）
	var headers: PackedStringArray = ["User-Agent: BulletRun-Game"]
	
	http_request.request(url, headers)


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# 处理GitHub API响应
	if result != HTTPRequest.RESULT_SUCCESS:
		update_check_failed.emit("网络请求失败")
		return
	
	if response_code != 200:
		update_check_failed.emit("GitHub API返回错误: %d" % response_code)
		return
	
	# 解析JSON
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		update_check_failed.emit("JSON解析失败")
		return
	
	var data: Dictionary = json.data
	
	# 获取最新版本号
	var latest_version: String = data.get("tag_name", "")
	
	if latest_version.is_empty():
		update_check_failed.emit("未找到版本信息")
		return
	
	# 比较版本
	if _compare_versions(latest_version, current_version) > 0:
		# 发现新版本
		var download_url: String = ""
		var assets: Array = data.get("assets", [])
		
		if assets.size() > 0:
			download_url = assets[0].get("browser_download_url", "")
		
		var changelog: String = data.get("body", "")
		
		update_available.emit(latest_version, download_url, changelog)
	else:
		update_not_available.emit()


func _compare_versions(v1: String, v2: String) -> int:
	# 比较版本号
	# 返回: 1 if v1 > v2, -1 if v1 < v2, 0 if equal
	# 移除'v'前缀
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


func _get_current_version() -> String:
	# 读取本地版本文件
	var file: FileAccess = FileAccess.open("res://version.txt", FileAccess.READ)
	if file:
		return file.get_line().strip_edges()
	return "v0.0.0"


func _exit_tree() -> void:
	# 清理HTTP请求节点
	if http_request and is_instance_valid(http_request):
		http_request.cancel_request()
		http_request.queue_free()
