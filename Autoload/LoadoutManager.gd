extends Node

# =============================================================================
# 装备配置管理器（Autoload）
# 管理5套装备配置，每套含主武器+3个特长
# 配置保存到 settings.cfg，特长效果由 Player/MultiplayerPlayer 读取
# =============================================================================

# Perk 定义
# 类别0（移动）: 0=轻装上阵(+15%速度), 1=清道夫(击杀掉弹药包)
# 类别1（防御）: 0=防弹衣(+30血), 1=快速治疗(自动回血), 2=爆炸抗性(-40%爆炸伤)
# 类别2（战斗）: 0=精准射击(-25%散布), 1=弹药充沛(+50%备弹), 2=快速换弹(+30%换弹速)

const MAX_LOADOUTS: int = 5

# 当前选中的配置索引
var current_loadout_index: int = 0

# 5套配置
var loadouts: Array = []

# 主武器选项: 1=步枪, 2=狙击枪, 4=机枪（对应Player weapons数组索引）
# Perk 选项: 类别0=[0,1], 类别1=[0,1,2], 类别2=[0,1,2]

func _ready() -> void:
	_load_loadouts()

func _load_loadouts() -> void:
	var saved: Variant = GameSettings.get_value("loadout", "loadouts", null)
	if saved and saved is Array and saved.size() > 0:
		loadouts = saved
	else:
		# 默认配置：5套预设
		loadouts = [
			{"name": "突击手", "primary_weapon": 1, "perks": [0, 0, 2]},   # 步枪+轻装上阵+防弹衣+快速换弹
			{"name": "狙击猎手", "primary_weapon": 2, "perks": [0, 1, 0]},   # 狙击+轻装上阵+快速治疗+精准射击
			{"name": "机枪堡垒", "primary_weapon": 4, "perks": [1, 0, 1]},   # 机枪+清道夫+防弹衣+弹药充沛
			{"name": "敏捷刺客", "primary_weapon": 1, "perks": [0, 2, 0]},   # 步枪+轻装上阵+爆炸抗性+精准射击
			{"name": "自定义", "primary_weapon": 1, "perks": [-1, -1, -1]},  # 默认无Perk
		]
	var idx: Variant = GameSettings.get_value("loadout", "current_index", 0)
	current_loadout_index = int(idx)

func _save_loadouts() -> void:
	GameSettings.set_value("loadout", "loadouts", loadouts)
	GameSettings.set_value("loadout", "current_index", current_loadout_index)
	GameSettings.save_settings()

func get_current_loadout() -> Dictionary:
	if loadouts.size() == 0 or current_loadout_index >= loadouts.size():
		return {"name": "默认", "primary_weapon": 1, "perks": [-1, -1, -1]}
	return loadouts[current_loadout_index]

func set_loadout(index: int, data: Dictionary) -> void:
	if index < 0 or index >= MAX_LOADOUTS:
		return
	# 确保 loadouts 数组够长
	while loadouts.size() <= index:
		loadouts.append({"name": "配置%d" % (loadouts.size() + 1), "primary_weapon": 1, "perks": [-1, -1, -1]})
	loadouts[index] = data
	_save_loadouts()

func select_loadout(index: int) -> void:
	if index < 0 or index >= loadouts.size():
		return
	current_loadout_index = index
	_save_loadouts()

func get_primary_weapon_index() -> int:
	return get_current_loadout().get("primary_weapon", 1)

func get_perks() -> Array:
	return get_current_loadout().get("perks", [-1, -1, -1])

# Perk 名称查询（供UI显示）
func get_perk_name(category: int, perk_index: int) -> String:
	var names: Dictionary = {
		# 类别0：移动
		[0, 0]: "轻装上阵",
		[0, 1]: "清道夫",
		# 类别1：防御
		[1, 0]: "防弹衣",
		[1, 1]: "快速治疗",
		[1, 2]: "爆炸抗性",
		# 类别2：战斗
		[2, 0]: "精准射击",
		[2, 1]: "弹药充沛",
		[2, 2]: "快速换弹",
	}
	var key: Array = [category, perk_index]
	if names.has(key):
		return GameSettings.t("perk_%d_%d" % [category, perk_index]) if GameSettings else names[key]
	return ""

func get_perk_desc(category: int, perk_index: int) -> String:
	var descs: Dictionary = {
		[0, 0]: "移动速度 +15%",
		[0, 1]: "击杀敌人掉落弹药补给包",
		[1, 0]: "最大血量 100→130",
		[1, 1]: "受伤3秒后自动回血（1HP/秒，上限50%）",
		[1, 2]: "爆炸伤害 -40%",
		[2, 0]: "武器散布 -25%",
		[2, 1]: "备用弹药 +50%",
		[2, 2]: "换弹速度 +30%",
	}
	var key: Array = [category, perk_index]
	if descs.has(key):
		return GameSettings.t("perk_%d_%d_desc" % [category, perk_index]) if GameSettings else descs[key]
	return ""

func get_weapon_name(weapon_index: int) -> String:
	var keys: Dictionary = {0: "w_pistol", 1: "w_rifle", 2: "w_sniper", 4: "w_machinegun"}
	if keys.has(weapon_index):
		return GameSettings.t(keys[weapon_index]) if GameSettings else keys[weapon_index]
	return ""

# 判断某主武器是否有步枪（根据配置）
func should_have_rifle() -> bool:
	return get_primary_weapon_index() == 1

func should_have_sniper() -> bool:
	return get_primary_weapon_index() == 2

func should_have_machinegun() -> bool:
	return get_primary_weapon_index() == 4
