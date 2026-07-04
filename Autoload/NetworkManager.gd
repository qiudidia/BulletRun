extends Node

# =============================================================================
# 网络管理器（Autoload）
# 管理 ENet 连接、UDP广播房间发现、玩家同步
# =============================================================================

# 网络常量
const SERVER_PORT: int = 7777
const BROADCAST_PORT: int = 7778
const MAX_PLAYERS_DUEL: int = 2      # 单挑模式最大玩家数
const MAX_PLAYERS_BRAWL: int = 3     # 3人乱斗最大玩家数
const MAX_PLAYERS_ZOMBIE: int = 4    # 僵尸联机最大玩家数（最多4人合作）

# 游戏模式枚举
enum GameMode {
	DUEL,      # 1v1 单挑
	BRAWL,     # 3人乱斗
	ZOMBIE,    # 僵尸联机
}

# 房间信息
var room_name: String = ""
var room_mode: GameMode = GameMode.DUEL
var is_host: bool = false

# 游戏进行中状态
var game_in_progress: bool = false      # 房间内是否有游戏正在进行
var game_in_progress_mode: int = 0      # 正在进行的游戏模式

# 连接状态
var connected: bool = false
var player_count: int = 0  # 当前房间内玩家数（含房主）
var max_players: int = 2   # 根据模式动态设定

# 玩家昵称
var player_name: String = ""  # 本地玩家的昵称
var player_names: Dictionary = {}  # peer_id → 昵称

# 玩家头像
var player_avatars: Dictionary = {}  # peer_id → avatar_id (0-15)

# 玩家准备状态
var player_ready: Dictionary = {}  # peer_id → bool

# 玩家颜色分配（所有模式自由选色）
# 单挑：红/蓝（不能同队）
# 乱斗：红/蓝/黄（不能同色）
# 僵尸：红/蓝/黄/绿（不能同色）
const TEAM_COLORS: Dictionary = {
	"red": Color(0.9, 0.2, 0.2, 1),
	"blue": Color(0.2, 0.4, 0.9, 1),
	"yellow": Color(0.9, 0.85, 0.2, 1),
	"green": Color(0.2, 0.7, 0.3, 1),
}

const DUEL_COLOR_OPTIONS: Array = ["red", "blue"]
const BRAWL_COLOR_OPTIONS: Array = ["red", "blue", "yellow"]
const ZOMBIE_COLOR_OPTIONS: Array = ["red", "blue", "yellow", "green"]

# 单挑模式的队伍分配
var duel_teams: Dictionary = {}  # peer_id → "red"/"blue"

# 乱斗模式的颜色分配（改为玩家自选）
var brawl_colors: Dictionary = {}  # peer_id → "red"/"blue"/"yellow"

# 僵尸模式的颜色分配（改为玩家自选）
var zombie_colors: Dictionary = {}  # peer_id → "red"/"blue"/"yellow"/"green"

# UDP广播（房间发现）
var broadcast_timer: float = 0.0
var broadcast_interval: float = 1.0  # 每秒广播一次房间信息
var udp_server: PacketPeerUDP = null  # 房主用来广播
var udp_client: PacketPeerUDP = null  # 客户端用来监听

# 发现的房间列表
var discovered_rooms: Dictionary = {}  # ip → {name, mode, players, max_players}

# 信号
signal room_created(room_name, mode)
signal room_joined(room_name, mode)
signal player_joined(peer_id)
signal player_left(peer_id)
signal connection_failed(reason)
signal room_list_updated(rooms)
signal game_start_requested(mode)
signal host_disconnected()
signal player_ready_changed(peer_id, ready)
signal room_mode_changed(mode)
signal kicked_from_room()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	# 房主：定期广播房间信息
	if is_host and connected:
		broadcast_timer += delta
		if broadcast_timer >= broadcast_interval:
			broadcast_timer = 0.0
			_broadcast_room()

	# 客户端：监听房间广播（仅在未加入房间时）
	if not is_host and not connected and udp_client:
		_receive_broadcasts()


# =============================================================================
# 创建房间（房主）
# =============================================================================
func create_room(r_name: String, mode: GameMode) -> void:
	room_name = r_name
	room_mode = mode
	is_host = true

	# 根据模式设定最大玩家数
	match mode:
		GameMode.DUEL:
			max_players = MAX_PLAYERS_DUEL
		GameMode.BRAWL:
			max_players = MAX_PLAYERS_BRAWL
		GameMode.ZOMBIE:
			max_players = MAX_PLAYERS_ZOMBIE

	# 创建ENet服务器
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(SERVER_PORT, max_players)
	if err != OK:
		connection_failed.emit("创建服务器失败: %d" % err)
		return

	multiplayer.multiplayer_peer = peer
	connected = true
	player_count = 1  # 房主自己

	# 房主自己就是peer_id=1
	var host_id: int = 1
	player_names[host_id] = player_name
	player_avatars[host_id] = GameSettings.get_avatar()
	player_ready[host_id] = false  # 房主默认未准备
	if mode == GameMode.DUEL:
		duel_teams[host_id] = "red"  # 房主默认红队，可切换
	elif mode == GameMode.BRAWL:
		brawl_colors[host_id] = "red"
	elif mode == GameMode.ZOMBIE:
		zombie_colors[host_id] = "blue"

	# 开始UDP广播
	_start_broadcast()

	room_created.emit(room_name, room_mode)


# =============================================================================
# 加入房间（客户端）
# =============================================================================
func join_room(ip: String) -> void:
	is_host = false

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip, SERVER_PORT)
	if err != OK:
		connection_failed.emit("连接失败: %d" % err)
		return

	multiplayer.multiplayer_peer = peer
	# 连接成功后会触发 _on_connected_to_server 信号
	# 停止监听广播
	stop_discovery()


# =============================================================================
# UDP广播系统（房间发现）
# =============================================================================
func start_discovery() -> void:
	# 开始监听局域网房间广播
	if udp_client:
		return
	udp_client = PacketPeerUDP.new()
	udp_client.bind(BROADCAST_PORT)
	discovered_rooms.clear()


func stop_discovery() -> void:
	# 停止监听
	if udp_client:
		udp_client.close()
		udp_client = null
	discovered_rooms.clear()
	room_list_updated.emit({})


func _start_broadcast() -> void:
	# 房主开始广播房间信息
	if udp_server:
		udp_server.close()
	udp_server = PacketPeerUDP.new()
	# 设置广播地址（向局域网所有机器广播）
	udp_server.set_broadcast_enabled(true)
	# 绑定到广播端口（发送端不需要bind，但需要设置目标地址）
	var err: int = udp_server.bind(BROADCAST_PORT + 1)  # 发送端用不同端口避免冲突
	if err != OK:
		push_warning("UDP广播绑定失败: %d" % err)


func _stop_broadcast() -> void:
	# 房主停止广播
	if udp_server:
		udp_server.close()
		udp_server = null


func _broadcast_room() -> void:
	# 向局域网广播房间信息
	if not udp_server:
		return
	# 构建房间信息字符串
	var mode_name: String = ""
	match room_mode:
		GameMode.DUEL: mode_name = "duel"
		GameMode.BRAWL: mode_name = "brawl"
		GameMode.ZOMBIE: mode_name = "zombie"

	var info: String = "BULLET_RUN_ROOM|%s|%s|%d|%d|%d" % [room_name, mode_name, player_count, max_players, 1 if game_in_progress else 0]
	var data: PackedByteArray = info.to_utf8_buffer()

	# 向广播地址发送
	udp_server.set_dest_address("255.255.255.255", BROADCAST_PORT)
	udp_server.put_packet(data)


func _receive_broadcasts() -> void:
	# 接收局域网房间广播
	if not udp_client:
		return
	while udp_client.get_available_packet_count() > 0:
		var data: PackedByteArray = udp_client.get_packet()
		var sender_ip: String = udp_client.get_packet_ip()
		var info: String = data.get_string_from_utf8()

		# 解析房间信息
		if not info.begins_with("BULLET_RUN_ROOM|"):
			continue
		var parts: Array = info.split("|")
		if parts.size() < 5:
			continue

		var r_name: String = parts[1]
		var r_mode_str: String = parts[2]
		var r_players: int = int(parts[3])
		var r_max: int = int(parts[4])
		var r_in_game: bool = false
		if parts.size() >= 6:
			r_in_game = (int(parts[5]) == 1)

		# 更新房间列表
		discovered_rooms[sender_ip] = {
			"name": r_name,
			"mode": r_mode_str,
			"players": r_players,
			"max_players": r_max,
			"ip": sender_ip,
			"in_game": r_in_game,
		}
		room_list_updated.emit(discovered_rooms)


# =============================================================================
# 网络事件回调
# =============================================================================
func _on_peer_connected(peer_id: int) -> void:
	player_count = multiplayer.get_peers().size() + 1  # +1 包含房主
	player_ready[peer_id] = false  # 新玩家默认未准备

	# 自动分配队伍/颜色（房主端执行）
	if is_host:
		if room_mode == GameMode.DUEL:
			# 单挑：新玩家分配到与房主不同队
			var host_team: String = duel_teams.get(1, "red")
			duel_teams[peer_id] = "blue" if host_team == "red" else "red"
		elif room_mode == GameMode.BRAWL:
			# 乱斗：分配到第一个未被占用的颜色
			var used: Array = brawl_colors.values()
			for c in BRAWL_COLOR_OPTIONS:
				if not c in used:
					brawl_colors[peer_id] = c
					break
		elif room_mode == GameMode.ZOMBIE:
			# 僵尸合作：分配到第一个未被占用的颜色
			var used: Array = zombie_colors.values()
			for c in ZOMBIE_COLOR_OPTIONS:
				if not c in used:
					zombie_colors[peer_id] = c
					break

	player_joined.emit(peer_id)

	# 房主通知新玩家房间模式和当前信息（含队伍/颜色、游戏状态）
	if is_host:
		_send_room_info.rpc_id(peer_id, room_mode, duel_teams, brawl_colors, zombie_colors, player_names, player_avatars, player_ready, game_in_progress, game_in_progress_mode)


func _on_peer_disconnected(peer_id: int) -> void:
	player_count = multiplayer.get_peers().size() + 1

	# 清除该玩家的队伍/颜色/昵称/头像/准备状态
	duel_teams.erase(peer_id)
	brawl_colors.erase(peer_id)
	zombie_colors.erase(peer_id)
	player_names.erase(peer_id)
	player_avatars.erase(peer_id)
	player_ready.erase(peer_id)

	player_left.emit(peer_id)


func _on_connected_to_server() -> void:
	connected = true
	# 客户端连接成功后，发送自己的昵称到房主
	var my_id: int = multiplayer.get_unique_id()
	player_names[my_id] = player_name
	player_avatars[my_id] = GameSettings.get_avatar()
	player_ready[my_id] = false
	_register_player_name.rpc_id(1, player_name, GameSettings.get_avatar())
	room_joined.emit(room_name, room_mode)


func _on_connection_failed() -> void:
	connected = false
	connection_failed.emit("连接服务器失败")


func _on_server_disconnected() -> void:
	connected = false
	host_disconnected.emit()


# =============================================================================
# RPC：房主向客户端发送房间信息
# =============================================================================
@rpc("authority", "call_remote", "reliable")
func _send_room_info(mode: int, teams: Dictionary, b_colors: Dictionary, z_colors: Dictionary, names: Dictionary, avatars: Dictionary, ready_states: Dictionary, in_game: bool, in_game_mode: int) -> void:
	room_mode = mode as GameMode
	duel_teams = teams
	brawl_colors = b_colors
	zombie_colors = z_colors
	player_names = names
	player_avatars = avatars
	player_ready = ready_states
	game_in_progress = in_game
	game_in_progress_mode = in_game_mode


@rpc("any_peer", "call_remote", "reliable")
func _register_player_name(p_name: String, avatar_id: int) -> void:
	# 客户端注册昵称和头像，房主记录并同步给所有客户端
	if not is_host:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	player_names[peer_id] = p_name
	player_avatars[peer_id] = avatar_id
	_sync_player_names.rpc(player_names, player_avatars)


@rpc("authority", "call_remote", "reliable")
func _sync_player_names(names: Dictionary, avatars: Dictionary) -> void:
	player_names = names
	player_avatars = avatars


# =============================================================================
# 队伍/颜色操作
# =============================================================================
func set_duel_team(peer_id: int, team: String) -> void:
	# 单挑模式切换队伍
	if room_mode != GameMode.DUEL:
		return
	if team != "red" and team != "blue":
		return
	duel_teams[peer_id] = team


func set_brawl_color(peer_id: int, color_name: String) -> void:
	# 乱斗模式选择颜色
	if room_mode != GameMode.BRAWL:
		return
	if not color_name in BRAWL_COLOR_OPTIONS:
		return
	# 检查该颜色是否已被其他人选了
	for pid in brawl_colors:
		if pid != peer_id and brawl_colors[pid] == color_name:
			return  # 该颜色已被占用
	brawl_colors[peer_id] = color_name


func set_zombie_color(peer_id: int, color_name: String) -> void:
	# 僵尸模式选择颜色
	if room_mode != GameMode.ZOMBIE:
		return
	if not color_name in ZOMBIE_COLOR_OPTIONS:
		return
	# 检查该颜色是否已被其他人选了
	for pid in zombie_colors:
		if pid != peer_id and zombie_colors[pid] == color_name:
			return
	zombie_colors[peer_id] = color_name


func can_start_duel() -> bool:
	# 单挑模式是否可以开始（两人必须在不同队伍）
	if room_mode != GameMode.DUEL:
		return false
	if player_count < MAX_PLAYERS_DUEL:
		return false
	# 检查两人不在同一队伍
	var teams: Array = []
	for pid in duel_teams:
		teams.append(duel_teams[pid])
	if teams.size() < 2:
		return false
	return teams[0] != teams[1]


func get_player_color(peer_id: int) -> Color:
	# 获取指定玩家的颜色
	if room_mode == GameMode.DUEL:
		var team: String = duel_teams.get(peer_id, "blue")
		return TEAM_COLORS[team]
	elif room_mode == GameMode.BRAWL:
		var color_name: String = brawl_colors.get(peer_id, "blue")
		return TEAM_COLORS[color_name]
	elif room_mode == GameMode.ZOMBIE:
		# 僵尸合作模式：所有玩家同一颜色（队友），用名字标签区分
		return Color(0.2, 0.7, 0.3, 1)  # 绿色 = 幸存者
	else:
		return Color(0.2, 0.4, 0.9, 1)


func get_player_display_name(peer_id: int) -> String:
	# 获取玩家显示名称（昵称）
	var p_name: String = player_names.get(peer_id, "")
	if p_name == "":
		return GameSettings.t("player") + " #%d" % peer_id
	return p_name


func get_color_options() -> Array:
	# 获取当前模式可选颜色列表
	match room_mode:
		GameMode.DUEL: return DUEL_COLOR_OPTIONS
		GameMode.BRAWL: return BRAWL_COLOR_OPTIONS
		GameMode.ZOMBIE: return ZOMBIE_COLOR_OPTIONS
	return ["red", "blue"]


func get_mode_max_players(mode: GameMode) -> int:
	match mode:
		GameMode.DUEL: return MAX_PLAYERS_DUEL
		GameMode.BRAWL: return MAX_PLAYERS_BRAWL
		GameMode.ZOMBIE: return MAX_PLAYERS_ZOMBIE
	return 2


func get_mode_display_name(mode: GameMode) -> String:
	match mode:
		GameMode.DUEL: return GameSettings.t("duel_mode")
		GameMode.BRAWL: return GameSettings.t("brawl_mode")
		GameMode.ZOMBIE: return GameSettings.t("zombie_coop_mode")
	return ""


func get_local_player_id() -> int:
	return multiplayer.get_unique_id()


# =============================================================================
# 准备系统
# =============================================================================
func toggle_ready() -> void:
	# 本地玩家切换准备状态
	var my_id: int = multiplayer.get_unique_id()
	var current: bool = player_ready.get(my_id, false)
	var new_val: bool = not current
	player_ready[my_id] = new_val
	if is_host:
		# 房主直接广播给所有客户端
		_sync_player_ready.rpc(my_id, new_val)
	else:
		# 客户端请求房主切换
		_request_ready.rpc_id(1, new_val)
	player_ready_changed.emit(my_id, new_val)


func is_local_ready() -> bool:
	var my_id: int = multiplayer.get_unique_id()
	return player_ready.get(my_id, false)


func all_ready() -> bool:
	# 所有玩家是否都已准备
	for pid in player_names:
		if not player_ready.get(pid, false):
			return false
	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(value: bool) -> void:
	# 客户端请求切换准备状态
	if not is_host:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	player_ready[peer_id] = value
	# 广播给所有客户端（按个人同步，避免整个字典序列化问题）
	_sync_player_ready.rpc(peer_id, value)
	player_ready_changed.emit(peer_id, value)


@rpc("authority", "call_remote", "reliable")
func _sync_player_ready(peer_id: int, is_ready: bool) -> void:
	# 收到房主同步的某个玩家准备状态
	player_ready[peer_id] = is_ready
	player_ready_changed.emit(peer_id, is_ready)


@rpc("authority", "call_remote", "reliable")
func _sync_ready_states(ready_states: Dictionary) -> void:
	# 批量同步整个准备状态字典（仅在 _send_room_info 新玩家加入时使用）
	player_ready = ready_states
	# 通知UI更新
	var my_id: int = multiplayer.get_unique_id()
	player_ready_changed.emit(my_id, player_ready.get(my_id, false))


# =============================================================================
# 踢人系统
# =============================================================================
func kick_player(peer_id: int) -> void:
	# 房主踢出指定玩家
	if not is_host:
		return
	if peer_id == 1:
		return  # 不能踢自己
	# 先通知被踢玩家
	_notify_kicked.rpc_id(peer_id)
	# 清理数据
	duel_teams.erase(peer_id)
	brawl_colors.erase(peer_id)
	zombie_colors.erase(peer_id)
	player_names.erase(peer_id)
	player_ready.erase(peer_id)
	player_count = multiplayer.get_peers().size() + 1
	player_left.emit(peer_id)
	# 同步状态到剩余客户端（必须在断开之前发RPC，否则ENet报错）
	_sync_player_names.rpc(player_names, player_avatars)
	# 同步被踢玩家的准备状态为 false（虽然他们会被断开，但其他客户端需要更新UI）
	for pid in player_ready:
		_sync_player_ready.rpc(pid, player_ready[pid])
	# 最后断开该玩家（断开后无法再向其发送RPC）
	var enet_peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet_peer:
		enet_peer.disconnect_peer(peer_id)


@rpc("authority", "call_remote", "reliable")
func _notify_kicked() -> void:
	# 被踢的客户端收到通知
	kicked_from_room.emit()


# =============================================================================
# 房主开始游戏
# =============================================================================
@rpc("authority", "call_remote", "reliable")
func _notify_game_start(mode: int) -> void:
	# 客户端接收：房主通知所有玩家开始游戏
	game_start_requested.emit(mode as GameMode)


# =============================================================================
# 重置准备状态（游戏结束后回到等待房间时调用）
# =============================================================================
func reset_ready() -> void:
	# 重置所有玩家准备状态
	for pid in player_ready:
		player_ready[pid] = false
	if connected:
		# 按个人同步重置状态
		for pid in player_ready:
			_sync_player_ready.rpc(pid, false)
		player_ready_changed.emit(1, false)


# =============================================================================
# 房主切换房间模式
# =============================================================================
func change_room_mode(new_mode: GameMode) -> void:
	if not is_host:
		return
	room_mode = new_mode
	max_players = get_mode_max_players(new_mode)
	# 重置所有颜色分配（切换模式后重新分配）
	duel_teams.clear()
	brawl_colors.clear()
	zombie_colors.clear()
	# 重新分配房主默认颜色
	var host_id: int = 1
	if new_mode == GameMode.DUEL:
		duel_teams[host_id] = "red"
	elif new_mode == GameMode.BRAWL:
		brawl_colors[host_id] = "red"
	elif new_mode == GameMode.ZOMBIE:
		zombie_colors[host_id] = "blue"
	# 广播新房间信息
	_broadcast_room()
	# 同步给所有客户端
	_sync_room_mode.rpc(new_mode)


@rpc("authority", "call_remote", "reliable")
func _sync_room_mode(mode: int) -> void:
	room_mode = mode as GameMode
	max_players = get_mode_max_players(room_mode)
	room_mode_changed.emit(room_mode)

# =============================================================================
# 断开连接 / 解散房间
# =============================================================================
func disconnect_network() -> void:
	# 关闭网络连接，重置所有状态
	# 房主：解散房间（通知所有客户端后关闭服务器）
	# 客户端：离开房间（断开与服务器的连接）
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected = false
	is_host = false
	player_count = 0
	room_name = ""
	room_mode = GameMode.DUEL
	max_players = 2
	player_names.clear()
	player_avatars.clear()
	player_ready.clear()
	duel_teams.clear()
	brawl_colors.clear()
	zombie_colors.clear()
	game_in_progress = false
	game_in_progress_mode = 0
	_stop_broadcast()
	stop_discovery()


# =============================================================================
# 游戏进行中状态管理
# =============================================================================
func set_game_started(mode: int) -> void:
	# 游戏开始时调用（由游戏场景的 _ready 调用）
	game_in_progress = true
	game_in_progress_mode = mode
	# 房主同步状态到客户端
	if is_host and connected:
		_sync_game_status.rpc(true, mode)

func set_game_ended() -> void:
	# 游戏结束/返回房间时调用
	game_in_progress = false
	game_in_progress_mode = 0
	# 房主同步状态到客户端
	if is_host and connected:
		_sync_game_status.rpc(false, 0)


@rpc("authority", "call_remote", "reliable")
func _sync_game_status(in_game: bool, in_game_mode: int) -> void:
	game_in_progress = in_game
	game_in_progress_mode = in_game_mode
