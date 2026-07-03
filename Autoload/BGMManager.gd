extends Node

# =============================================================================
# BGM 管理 Autoload
# 跨场景保持主界面背景音乐连续播放
# 在所有需要 BGM 的场景里调用 BGMManager.play_bgm()
# =============================================================================

var _player: AudioStreamPlayer = null
var _stream_path: String = "res://assets/zhujiemian.mp3"

func play_bgm() -> void:
	# 如果已经在播放，什么都不做
	if _player and _player.playing:
		return

	if not _player:
		_player = AudioStreamPlayer.new()
		_player.name = "BGM"
		_player.bus = "BGM"
		_player.volume_db = -6.0
		add_child(_player)

	if not _player.stream:
		var stream: AudioStream = load(_stream_path)
		if stream:
			_player.stream = stream

	if not _player.playing:
		_player.play()


func stop_bgm() -> void:
	if _player:
		_player.stop()
