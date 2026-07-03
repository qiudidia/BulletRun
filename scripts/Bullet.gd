extends Area2D

# =============================================================================
# 子弹脚本
# 由玩家或敌人发射，检测碰撞造成伤害
#
# 碰撞逻辑：
#   子弹是 Area2D，通过 body_entered 检测 PhysicsBody（敌人/桶/墙）
#   通过 area_entered 检测其他 Area2D（手榴弹等）
# =============================================================================

signal bullet_hit(target)

@export var speed: float = 800.0
@export var damage: int = 20
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var shooter_is_player: bool = true
var shooter: Node = null  # 发射者引用（用于击杀归属）
var owner_peer_id: int = 0  # 联机模式下子弹所属玩家的 peer_id（用于区分友方/敌方）
var _dead: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if shooter_is_player:
		add_to_group("player_bullet")
	else:
		add_to_group("enemy_bullet")

	get_tree().create_timer(lifetime).timeout.connect(func():
		if is_instance_valid(self):
			call_deferred("queue_free")
	)

	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if _dead:
		return
	
	# 联机友军保护：子弹不能伤害发射者自己
	if body is CharacterBody2D and body.is_in_group("player"):
		if owner_peer_id != 0 and body.has_method("get_multiplayer_authority"):
			# 子弹碰到发射者自己 → 忽略（所有模式）
			if body.get_multiplayer_authority() == owner_peer_id:
				return
		# 僵尸联机模式：玩家子弹不应伤害其他玩家
		if NetworkManager.connected and NetworkManager.room_mode == NetworkManager.GameMode.ZOMBIE:
			return
		# 单挑模式：同队子弹不应伤害队友
		if NetworkManager.connected and NetworkManager.room_mode == NetworkManager.GameMode.DUEL:
			var shooter_team: String = NetworkManager.duel_teams.get(owner_peer_id, "red")
			var target_team: String = NetworkManager.duel_teams.get(body.get_multiplayer_authority(), "blue")
			if shooter_team == target_team:
				return
	
	# 优先检测：如果对方有 take_damage，就造成伤害
	if body.has_method("take_damage"):
		# 传递击杀归属：敌人/ZombieAI/BotAI/Barrel接受source参数，Player不接受
		if body.is_in_group("enemy") or body.is_in_group("bots") or body is Barrel:
			body.take_damage(damage, shooter)
		else:
			body.take_damage(damage)
		bullet_hit.emit(body)
		_dead = true
		call_deferred("queue_free")
		return
	
	# 打到墙/障碍物，直接消失
	if body is StaticBody2D:
		_dead = true
		call_deferred("queue_free")

func _on_area_entered(area: Area2D) -> void:
	if _dead:
		return
	# 检测手榴弹爆炸等
	if "Explosion" in area.name:
		_dead = true
		call_deferred("queue_free")
