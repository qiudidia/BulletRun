extends Node

# =============================================================================
# UI 音效管理器（Autoload）
# 负责主菜单、模式选择、设置等界面按钮的点击音效
# =============================================================================

var click_stream: AudioStream = null
var click_player: AudioStreamPlayer = null

func _ready() -> void:
	if ResourceLoader.exists("res://assets/dianjianjianyin.mp3"):
		click_stream = load("res://assets/dianjianjianyin.mp3")
		click_player = AudioStreamPlayer.new()
		click_player.name = "ClickSFX"
		click_player.bus = "SFX"
		click_player.volume_db = -10.0
		click_player.stream = click_stream
		add_child(click_player)

func play_click() -> void:
	if click_player and click_player.stream:
		click_player.play()
