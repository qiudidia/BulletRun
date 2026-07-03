extends Area2D

# =============================================================================
# 弹药补给包（清道夫 Perk 掉落）
# 玩家走近自动拾取，补满当前武器弹药
# =============================================================================

var lifetime: float = 15.0  # 15秒后消失
var _elapsed: float = 0.0

func _ready() -> void:
	monitoring = true
	monitorable = true
	# 碰撞检测
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
	# 呼吸闪烁效果
	var vis: ColorRect = get_node_or_null("Vis")
	if vis:
		vis.modulate.a = 0.6 + sin(_elapsed * 3.0) * 0.3

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var player: Node = body
		if player.has_method("_refill_current_ammo"):
			player._refill_current_ammo()
		elif player.has("weapons"):
			var w: Dictionary = player.weapons[player.current_weapon_index]
			if w.has("max_ammo") and w.has("reserve_ammo"):
				var needed: int = w.max_ammo - w.current_ammo
				w.reserve_ammo += needed
				if player.has_method("_update_ammo_display"):
					player._update_ammo_display()
				if player.has_method("_update_weapon_ui"):
					player._update_weapon_ui()
		queue_free()
