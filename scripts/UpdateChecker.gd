extends Node
## 更新检查器
## 检查GitHub Releases获取最新版本
## 如果发现新版本，显示更新提示

signal update_available(latest_version: String, download_url: String, changelog: String)
signal update_not_available()
signal update_check_failed(reason: String)

@export var github_user: String = "qiudidia"
@export var github_repo: String = "BulletRun"
@export var check_on_start: bool = true

var http_request: HTTPRequest = null
var current_version: String = ""


func _ready() -> void:
	current_version = _get_current_version()
	
	http_request = HTTPRequest.new()
	http_request.tls_options = TLSOptions.client_unsafe()
	http_request.timeout = 10.0
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	if check_on_start:
		check_for_updates()


func check_for_updates() -> void:
	var url: String = "https://api.github.com/repos/%s/%s/releases?per_page=1" % [github_user, github_repo]
	
	var headers: PackedStringArray = ["User-Agent: BulletRun-Game", "Accept: application/vnd.github+json"]
	
	http_request.request(url, headers)


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		update_check_failed.emit("网络请求失败")
		return
	
	if response_code != 200:
		update_check_failed.emit("GitHub API返回错误: %d" % response_code)
		return
	
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		update_check_failed.emit("JSON解析失败")
		return
	
	var data: Dictionary
	if json.data is Array:
		var releases: Array = json.data
		if releases.is_empty():
			update_check_failed.emit("没有找到任何Release")
			return
		data = releases[0]
	elif json.data is Dictionary:
		data = json.data
	else:
		update_check_failed.emit("未知响应格式")
		return
	
	var latest_version: String = data.get("tag_name", "")
	
	if latest_version.is_empty():
		update_check_failed.emit("未找到版本信息")
		return
	
	if _compare_versions(latest_version, current_version) > 0:
		var download_url: String = _get_download_url(data)
		var changelog: String = data.get("body", "")
		
		update_available.emit(latest_version, download_url, changelog)
	else:
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
		return file.get_line().strip_edges()
	return "v0.0.0"


func _exit_tree() -> void:
	if http_request and is_instance_valid(http_request):
		http_request.cancel_request()
		http_request.queue_free()