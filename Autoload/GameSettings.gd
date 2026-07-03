extends Node

# =============================================================================
# GameSettings - 全局设置管理器（Autoload）
# 负责所有设置的保存、加载、应用，以及多语言翻译
# =============================================================================

const SETTINGS_FILE: String = "user://settings.cfg"
var config: ConfigFile = ConfigFile.new()

# 当前语言: 0=中文, 1=English
var _lang: int = 0

# 默认设置
const DEFAULTS: Dictionary = {
	"video": {
		"resolution": "1280x720",
		"fullscreen": true,
		"vsync": true,
		"max_fps": 0
	},
	"audio": {
		"master_volume": 0.8,
		"bgm_volume": 0.6,
		"sfx_volume": 0.8
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"invert_y": false
	},
	"game": {
		"crosshair_style": 0,
		"crosshair_color": Color(0, 1, 0, 1),
		"show_fps": true,
		"language": 0,
		"high_wave": 0,
		"money": 0,
		"bot_difficulty": 1,
		"nickname": "",
		"xp": 0,
		"level": 1,
		"avatar": 0
	}
}

# =====================================================================
# 多语言翻译表
# =====================================================================
const TRANSLATIONS: Dictionary = {
	# --- 主菜单 ---
	"start_game": {"zh": "开始游戏", "en": "Start Game"},
	"settings": {"zh": "设置", "en": "Settings"},
	"quit_game": {"zh": "退出游戏", "en": "Quit"},
	"about_game": {"zh": "游戏介绍", "en": "About"},
	"about_subtitle": {"zh": "2D 俯视角射击游戏", "en": "2D Top-Down Shooter"},
	"about_studio": {"zh": "Vee Studio", "en": "Vee Studio"},
	"about_studio_label": {"zh": "开发工作室", "en": "Developed By"},
	"about_founder_label": {"zh": "创始人", "en": "Founder"},
	"about_modes_title": {"zh": "游戏模式", "en": "Game Modes"},
	"about_zombie_title": {"zh": "僵尸模式", "en": "Zombie Mode"},
	"about_zombie_desc": {"zh": "无尽的僵尸波次向你涌来！新增 3 种僵尸品种：速度型（快速冲刺，黄色眼睛）、坦克型（高血量重甲，红色眼睛）、爆炸型（死亡时自爆范围伤害，橙色眼睛）。每 5 波出现精英僵尸（500 血量，更凶猛），每 10 波迎来 BOSS「幽灵」（10000 血量，身披披风，攻击力极强，还会扔手雷！）。地图随机刷新金色宝箱，拾取获得 50-150 金钱，20-40 秒后重新生成。击杀普通僵尸 +5 XP，击杀精英 +35 XP，击杀 BOSS +75 XP。波次间隙可进入商店，用积累的金钱购买步枪（300 分）、狙击枪（500 分）、机枪（400 分）和手榴弹来武装自己。开局只有一把手枪和 0 颗手雷，活下来靠你的枪法和策略！\n僵尸联机合作：最多 4 人组队（红/蓝/黄/绿），合作抵御无限波次，击杀奖励 XP 全队共享，宝箱系统由房主统一同步。队友血量显示在左下角。", "en": "Endless zombie waves! 3 new zombie types: Runner (fast sprint, yellow eyes), Tank (heavy armor, high HP, red eyes), Bomber (explodes on death, orange eyes). Every 5th wave spawns Elite zombies (500 HP). Every 10th wave brings Boss 'Ghost' (10000 HP, cape, devastating attacks, throws grenades!). Treasure chests randomly spawn on the map — collect 50-150 money, respawns after 20-40s. Normal kill +5 XP, Elite +35 XP, Boss +75 XP. Between waves, visit shop for Rifle (300 pts), Sniper (500 pts), Machinegun (400 pts) and Grenades. Start with only a pistol — survive with skill!\nZombie Co-op: Up to 4 players (Red/Blue/Yellow/Green), XP shared across team. Chest system synced by host. Teammate HP at bottom-left."},
	"about_bot_title": {"zh": "BOT 对战模式", "en": "Bot Deathmatch"},
	"about_bot_desc": {"zh": "与 8 个 AI Bot 在战场上对决！击杀 Bot 获得人头和 +10 XP，按 E 键打开人头商店购买弹药、医疗包、伤害加成、无限子弹、核爆、手榴弹、狙击枪和机枪。开局自带手枪、步枪、狙击枪和 1 颗手雷。4 种难度可选：简单（Bot 站桩射击，非常新手友好）、普通、中等、困难（Bot 走位+躲子弹+换武器+撤退，高手挑战）。游戏积累 XP 可提升 16 级军衔，从列兵到上将。", "en": "Fight 8 AI Bots on the battlefield! Kill bots to earn heads and +10 XP, press E to open the Head Shop for ammo, medkits, damage boost, infinite ammo, nuke, grenades, sniper and machinegun. You start with Pistol, Rifle, Sniper and 1 grenade. 4 difficulty levels: Easy (bots stand & shoot, beginner-friendly), Normal, Medium, Hard (bots strafe, dodge, switch weapons, retreat — for pros). Earn XP to rank up through 16 military ranks from Private to General."},
	"about_multiplayer_title": {"zh": "联机模式", "en": "Multiplayer Mode"},
	"about_multiplayer_desc": {"zh": "局域网联机（UDP），支持三种模式：\n· 单挑模式 — 1v1 红蓝对决，先达到 25 击杀获胜，死亡后 3 秒重生。\n· 乱斗模式 — 3 人各打各的（红/蓝/黄），自由混战，击杀计分。\n· 僵尸合作 — 最多 4 人组队（红/蓝/黄/绿），合作抵御无限波次，死亡后可观战队友（按空格切换），全员阵亡才游戏结束。宝箱系统由房主同步。\n支持中途加入正在进行的游戏，玩家退出时全屏广播通知。首次游戏需设置昵称（永久保存），联机大厅可自由选色，颜色冲突不可开始游戏。房主可切换游戏模式。", "en": "LAN multiplayer (UDP), three modes:\n· Duel — 1v1 Red vs Blue, first to 25 kills wins, respawn after 3s.\n· Brawl — 3 players free-for-all (Red/Blue/Yellow), kill scoring.\n· Zombie Co-op — Up to 4 players (Red/Blue/Yellow/Green), fight endless waves together. Spectate teammates after death (Space to switch), game ends only when all dead. Chest system synced by host.\nSupports mid-game join. Player exit broadcasts notification. Set nickname on first launch (saved permanently). Pick colors freely in lobby, conflict prevents start. Host can switch game mode."},
	"about_weapons_title": {"zh": "武器介绍", "en": "Weapons"},
	"about_perks_title": {"zh": "特长系统", "en": "Perks"},
	"about_perks_desc": {"zh": "装备配置中可选 3 个特长（移动、防御、战斗各选 1 个），开局自动生效：\n· 轻装上阵 — 移动速度 +15%\n· 清道夫 — 击杀敌人掉落弹药补给包\n· 防弹衣 — 最大血量 100→130\n· 快速治疗 — 受伤 3 秒后自动回血（1HP/秒，上限 50%）\n· 爆炸抗性 — 爆炸伤害 -40%\n· 精准射击 — 武器散布 -25%\n· 弹药充沛 — 备用弹药 +50%\n· 快速换弹 — 换弹速度 +30%", "en": "Choose 3 perks (Movement, Defense, Combat — one each) in Loadout. Effects activate at game start:\n· Lightweight — Move speed +15%\n· Scavenger — Kill drops ammo pack\n· Armor — Max HP 100→130\n· Quick Heal — Auto heal after 3s (1HP/s, max 50%)\n· Explosion Resist — Explosion damage -40%\n· Precision — Weapon spread -25%\n· Ammo Surplus — Reserve ammo +50%\n· Fast Reload — Reload speed +30%"},
	"about_weapons_info": {"zh": "手枪 — 半自动，伤害 25，弹匣 12 发，射速快，按 1 切换。适合近距离应急。\n步枪 — 全自动，伤害 10，弹匣 30 发，按住鼠标连射，按 2 切换。僵尸模式需在商店购买解锁（300 分）。\n狙击枪 — 半自动，伤害 100（一枪一个！），弹匣 5 发，2 秒冷却，必须松开鼠标再按才能打下一枪，按 3 切换。散布为零，僵尸模式 500 分购买。\n刀 — 近战武器，挥刀有扇形冰蓝色拖尾特效，按 4 切换。贴脸秒杀利器。\n机枪 — 全自动，伤害 8，弹匣 100 发，4 秒换弹，按 5 切换。大弹匣低伤害，适合压制火力。僵尸模式 400 分购买。\n手榴弹 — 按 G 长按瞄准，松开投掷，范围伤害。僵尸模式商店购买，Bot 模式商店购买或开局自带 1 颗。", "en": "Pistol — Semi-auto, 25 damage, 12 rounds, fast fire rate, key 1. Good for close-range backup.\nRifle — Full-auto, 10 damage, 30 rounds, hold mouse to spray, key 2. Must buy in zombie mode shop (300 pts).\nSniper — Semi-auto, 100 damage (one-shot kill!), 5 rounds, 2s cooldown, must release & re-click to fire again, key 3. Zero spread. Zombie mode: 500 pts.\nKnife — Melee weapon, swing with icy blue trail effect, key 4. Deadly at point-blank range.\nMachinegun — Full-auto, 8 damage, 100 rounds, 4s reload, key 5. High capacity, low damage, great for suppression. Zombie mode: 400 pts.\nGrenade — Hold G to aim, release to throw, area damage. Buy in shop or start with 1 in Bot mode."},
	"about_controls_title": {"zh": "操作说明", "en": "Controls"},
	"about_controls_info": {"zh": "鼠标移动 — 控制方向和瞄准\n左键点击 — 射击\n1 / 2 / 3 / 4 / 5 — 切换武器（手枪/步枪/狙击枪/刀/机枪）\nG — 手榴弹（长按瞄准，松开投掷）\nE — 打开商店 / 交互\nESC — 暂停\nR — 换弹\nM — 切换小地图显示", "en": "Mouse move — Direction & aim\nLeft click — Shoot\n1 / 2 / 3 / 4 / 5 — Switch weapon (Pistol/Rifle/Sniper/Knife/Machinegun)\nG — Grenade (hold to aim, release to throw)\nE — Open shop / Interact\nESC — Pause\nR — Reload\nM — Toggle minimap"},
	"select_mode": {"zh": "选择模式", "en": "Select Mode"},
	"bot_mode": {"zh": "BOT 对战", "en": "Bot Deathmatch"},
	"bot_mode_desc": {"zh": "与 AI 敌人战斗", "en": "Fight against AI bots"},
	"zombie_mode": {"zh": "僵尸波次", "en": "Zombie Waves"},
	"zombie_mode_desc": {"zh": "无限波次生存挑战", "en": "Endless survival waves"},
	"back": {"zh": "返回", "en": "Back"},
	# --- 设置界面 ---
	"video_tab": {"zh": "视频", "en": "Video"},
	"audio_tab": {"zh": "音频", "en": "Audio"},
	"controls_tab": {"zh": "操控", "en": "Controls"},
	"gameplay_tab": {"zh": "玩法", "en": "Gameplay"},
	"resolution": {"zh": "分辨率", "en": "Resolution"},
	"fullscreen": {"zh": "全屏", "en": "Fullscreen"},
	"vsync": {"zh": "垂直同步", "en": "V-Sync"},
	"fps_limit": {"zh": "帧率限制", "en": "FPS Limit"},
	"no_limit": {"zh": "无限制", "en": "Unlimited"},
	"master_vol": {"zh": "主音量", "en": "Master Volume"},
	"bgm_vol": {"zh": "BGM音量", "en": "BGM Volume"},
	"sfx_vol": {"zh": "音效音量", "en": "SFX Volume"},
	"sensitivity": {"zh": "灵敏度", "en": "Sensitivity"},
	"invert_y": {"zh": "反转Y轴", "en": "Invert Y Axis"},
	"key_bindings": {"zh": "按键绑定（点击按钮后按下新按键）", "en": "Key Bindings (click then press new key)"},
	"crosshair_style": {"zh": "准星样式", "en": "Crosshair Style"},
	"crosshair_cross": {"zh": "十字", "en": "Cross"},
	"crosshair_dot": {"zh": "圆点", "en": "Dot"},
	"crosshair_ring": {"zh": "圆环", "en": "Ring"},
	"show_fps": {"zh": "显示FPS", "en": "Show FPS"},
	"language": {"zh": "语言", "en": "Language"},
	# --- 按键绑定 ---
	"move_up": {"zh": "前进", "en": "Move Up"},
	"move_down": {"zh": "后退", "en": "Move Down"},
	"move_left": {"zh": "左移", "en": "Move Left"},
	"move_right": {"zh": "右移", "en": "Move Right"},
	"shoot": {"zh": "射击", "en": "Shoot"},
	"reload": {"zh": "换弹", "en": "Reload"},
	"weapon_1": {"zh": "武器1", "en": "Weapon 1"},
	"weapon_2": {"zh": "武器2", "en": "Weapon 2"},
	"grenade": {"zh": "手榴弹", "en": "Grenade"},
	"not_set": {"zh": "未设置", "en": "Not Set"},
	"press_key": {"zh": "请按下按键...", "en": "Press a key..."},
	"mouse_left": {"zh": "鼠标左键", "en": "Mouse Left"},
	"mouse_right": {"zh": "鼠标右键", "en": "Mouse Right"},
	"mouse_middle": {"zh": "鼠标中键", "en": "Mouse Middle"},
	# --- 僵尸模式 ---
	"wave": {"zh": "波次: %d", "en": "Wave: %d"},
	"enemies_left": {"zh": "剩余敌人: %d", "en": "Enemies: %d"},
	"health": {"zh": "生命: %d", "en": "Health: %d"},
	"ammo": {"zh": "弹药: %d / %d", "en": "Ammo: %d / %d"},
	"shop_title": {"zh": "商店 - 波次间隙", "en": "Shop - Wave Break"},
	"balance": {"zh": "余额: %d", "en": "Balance: %d"},
	"upgrade_hp": {"zh": "升级最大生命 (%d)", "en": "Upgrade Max HP (%d)"},
	"upgrade_damage": {"zh": "升级伤害 (%d)", "en": "Upgrade Damage (%d)"},
	"buy_ammo": {"zh": "补充弹药 (%d)", "en": "Buy Ammo (%d)"},
	"buy_grenade": {"zh": "购买手榴弹 (%d)", "en": "Buy Grenade (%d)"},
	"buy_rifle": {"zh": "购买步枪 (%d)", "en": "Buy Rifle (%d)"},
	"rifle_owned": {"zh": "步枪 - 已购买", "en": "Rifle - Owned"},
	"boss_name": {"zh": "幽灵", "en": "Ghost"},
	"next_wave": {"zh": "继续下一波", "en": "Next Wave"},
	"you_died": {"zh": "你阵亡了！", "en": "You Died!"},
	"died_at_wave": {"zh": "你在第 %d 波阵亡", "en": "You died at Wave %d"},
	"highest_wave": {"zh": "最高波次: %d", "en": "Highest Wave: %d"},
	"restart": {"zh": "再开一局", "en": "Restart"},
	"return_menu": {"zh": "返回主菜单", "en": "Return to Menu"},
	# --- Bot模式 ---
	"kills": {"zh": "击杀: %d", "en": "Kills: %d"},
	"deaths": {"zh": "死亡: %d", "en": "Deaths: %d"},
	# --- ESC 退出确认 ---
	"exit_confirm": {"zh": "确定要退出到主菜单吗？", "en": "Return to main menu?"},
	"confirm_exit": {"zh": "确认退出", "en": "Confirm"},
	"cancel": {"zh": "取消", "en": "Cancel"},
	# --- 开场动画 ---
	"skip_hint": {"zh": "左键跳过", "en": "Click to skip"},
	# --- 暂停菜单 ---
	"pause_title": {"zh": "暂停", "en": "Paused"},
	"resume": {"zh": "继续游戏", "en": "Resume"},
	"switch_mode": {"zh": "换模式", "en": "Switch Mode"},
	# --- 核爆结束 ---
	"player_nuked": {"zh": "玩家已核爆", "en": "Player Nuked"},
	"game_over": {"zh": "游戏结束", "en": "Game Over"},
	"play_again": {"zh": "重玩", "en": "Play Again"},
	"return_to_menu": {"zh": "返回主菜单", "en": "Return to Menu"},
	# --- Bot模式额外 ---
	"deploy": {"zh": "部署", "en": "Deploy"},
	"quit": {"zh": "退出", "en": "Quit"},
	"shop_hint": {"zh": "按 E 打开商店", "en": "Press E to open shop"},
	"kill_notify": {"zh": "击杀 %s   +%d XP", "en": "Killed %s   +%d XP"},
	"enemy": {"zh": "敌人", "en": "Enemy"},
	"zombie_normal": {"zh": "普通僵尸", "en": "Zombie"},
		"zombie_elite": {"zh": "精英僵尸", "en": "Elite Zombie"},
		"zombie_runner": {"zh": "速度僵尸", "en": "Runner Zombie"},
		"zombie_tank": {"zh": "坦克僵尸", "en": "Tank Zombie"},
		"zombie_bomber": {"zh": "爆炸僵尸", "en": "Bomber Zombie"},
	# --- 难度选择 ---
	"select_difficulty": {"zh": "选择难度", "en": "Select Difficulty"},
	"difficulty_easy": {"zh": "简单", "en": "Easy"},
	"difficulty_normal": {"zh": "普通", "en": "Normal"},
	"difficulty_medium": {"zh": "中等", "en": "Medium"},
	"difficulty_hard": {"zh": "困难", "en": "Hard"},
	# --- 狙击枪 ---
	"weapon_3": {"zh": "武器3", "en": "Weapon 3"},
	"buy_sniper": {"zh": "购买狙击枪 (%d)", "en": "Buy Sniper (%d)"},
	"sniper_owned": {"zh": "狙击枪 — 已购买", "en": "Sniper — Owned"},
	"machinegun_owned": {"zh": "机枪 — 已购买", "en": "Machinegun — Owned"},

	"sniper": {"zh": "狙击枪", "en": "Sniper"},
	# --- 联机模式 ---
	"multiplayer_mode": {"zh": "联机模式", "en": "Multiplayer"},
	"multiplayer_desc": {"zh": "局域网联机对战", "en": "LAN multiplayer battles"},
	"create_room": {"zh": "创建房间", "en": "Create Room"},
	"join_room": {"zh": "加入房间", "en": "Join Room"},
	"room_name": {"zh": "房间名称", "en": "Room Name"},
	"enter_room_name": {"zh": "输入房间名称", "en": "Enter room name"},
	"duel_mode": {"zh": "单挑模式", "en": "1v1 Duel"},
	"brawl_mode": {"zh": "3人乱斗", "en": "3-Player Brawl"},
	"zombie_coop_mode": {"zh": "僵尸联机", "en": "Zombie Co-op"},
	"duel_desc": {"zh": "1v1 单挑，红蓝两队，不能同队，击杀计分", "en": "1v1 duel, Red vs Blue teams, cannot be on same team"},
	"brawl_desc": {"zh": "3人各打各的，颜色随机分配（红/蓝/黄），击杀计分", "en": "3 players, no teams, random colors (Red/Blue/Yellow)"},
	"zombie_coop_desc": {"zh": "和朋友一起打僵尸！合作生存", "en": "Fight zombies together! Co-op survival"},
	"double_click_to_join": {"zh": "双击房间可加入", "en": "Double-click a room to join"},
	"no_rooms_found": {"zh": "没有发现房间", "en": "No rooms found"},
	"refresh": {"zh": "刷新", "en": "Refresh"},
	"default_room_name": {"zh": "房间", "en": "Room"},
	"room_title": {"zh": "房间: %s", "en": "Room: %s"},
	"player_count": {"zh": "玩家: %d / %d", "en": "Players: %d / %d"},
	"you": {"zh": "你", "en": "You"},
	"player": {"zh": "玩家", "en": "Player"},
	"red_team": {"zh": "红队", "en": "Red Team"},
	"blue_team": {"zh": "蓝队", "en": "Blue Team"},
	"yellow_team": {"zh": "黄队", "en": "Yellow Team"},
	"green_team": {"zh": "绿队", "en": "Green Team"},
	"disband_room": {"zh": "解散房间", "en": "Disband Room"},
	"leave_room": {"zh": "离开房间", "en": "Leave Room"},
	"your_nickname": {"zh": "你的昵称", "en": "Your Nickname"},
	"enter_nickname": {"zh": "输入昵称...", "en": "Enter nickname..."},
	"default_nickname": {"zh": "玩家", "en": "Player"},
	"select_your_color": {"zh": "选择你的颜色", "en": "Select your color"},
	"color_conflict_warning": {"zh": "有玩家颜色冲突，请调整", "en": "Color conflict, please adjust"},
	"waiting_for_player": {"zh": "等待玩家加入...", "en": "Waiting for players..."},
	"waiting_for_ready": {"zh": "等待所有玩家准备...", "en": "Waiting for all players to ready..."},
	"ready": {"zh": "已准备", "en": "Ready"},
	"not_ready": {"zh": "未准备", "en": "Not Ready"},
	"ready_up": {"zh": "准备", "en": "Ready Up"},
	"cancel_ready": {"zh": "取消准备", "en": "Cancel Ready"},
	"kick": {"zh": "踢出", "en": "Kick"},
	"kicked_msg": {"zh": "你已被踢出房间", "en": "You have been kicked from the room"},
	"confirm_btn": {"zh": "确认", "en": "OK"},
	"waiting_for_host": {"zh": "等待房主开始...", "en": "Waiting for host to start..."},
	"same_team_warning": {"zh": "两队不能相同！", "en": "Teams cannot be the same!"},
	"ready_to_start": {"zh": "准备开始！", "en": "Ready to start!"},
	"respawning": {"zh": "3秒后重生...", "en": "Respawning in 3s..."},
	# --- 联机僵尸观战 ---
	"survived_to_wave": {"zh": "你撑到了第 %d 波", "en": "You survived to Wave %d"},
	"teammates_fighting": {"zh": "还有 %d 个队友正在战斗", "en": "%d teammate(s) still fighting"},
	"spectate": {"zh": "观战", "en": "Spectate"},
	"exit_game": {"zh": "退出游戏", "en": "Exit Game"},
	"all_dead": {"zh": "全员阵亡！", "en": "All Players Dead!"},
	"spectating_label": {"zh": "观战中: %s", "en": "Spectating: %s"},
	"spectate_switch_hint": {"zh": "按空格切换观战目标", "en": "Press Space to switch target"},
	"teammates": {"zh": "队友", "en": "Teammates"},
	# --- 单挑胜利/失败 ---
	"victory": {"zh": "你胜利！", "en": "Victory!"},
	"defeat": {"zh": "失败", "en": "Defeat"},
	"return_room": {"zh": "返回房间", "en": "Return to Room"},
	"duel_score_format": {"zh": "红队 %d : %d 蓝队", "en": "Red %d : %d Blue"},
	"first_to_25": {"zh": "先达到 25 击杀获胜", "en": "First to 25 kills wins"},
	"game_mode": {"zh": "游戏模式", "en": "Game Mode"},
	"mode_changed": {"zh": "房主已切换模式", "en": "Host changed mode"},
	# 装备配置
	"loadout": {"zh": "装备配置", "en": "Loadout"},
	"primary_weapon": {"zh": "主武器", "en": "Primary Weapon"},
	"perk_category_0": {"zh": "移动特长", "en": "Movement Perk"},
	"perk_category_1": {"zh": "防御特长", "en": "Defense Perk"},
	"perk_category_2": {"zh": "战斗特长", "en": "Combat Perk"},
	"perk_none": {"zh": "无", "en": "None"},
	# Perk 名称
	"perk_0_0": {"zh": "轻装上阵", "en": "Lightweight"},
	"perk_0_1": {"zh": "清道夫", "en": "Scavenger"},
	"perk_1_0": {"zh": "防弹衣", "en": "Armor"},
	"perk_1_1": {"zh": "快速治疗", "en": "Quick Heal"},
	"perk_1_2": {"zh": "爆炸抗性", "en": "Explosion Resist"},
	"perk_2_0": {"zh": "精准射击", "en": "Precision"},
	"perk_2_1": {"zh": "弹药充沛", "en": "Ammo Surplus"},
	"perk_2_2": {"zh": "快速换弹", "en": "Fast Reload"},
	# Perk 描述
	"perk_0_0_desc": {"zh": "移动速度 +15%", "en": "Move speed +15%"},
	"perk_0_1_desc": {"zh": "击杀敌人掉落弹药补给包", "en": "Kill drops ammo pack"},
	"perk_1_0_desc": {"zh": "最大血量 100→130", "en": "Max HP 100→130"},
	"perk_1_1_desc": {"zh": "受伤3秒后自动回血（1HP/秒，上限50%）", "en": "Auto heal after 3s (1HP/s, max 50%)"},
	"perk_1_2_desc": {"zh": "爆炸伤害 -40%", "en": "Explosion damage -40%"},
	"perk_2_0_desc": {"zh": "武器散布 -25%", "en": "Weapon spread -25%"},
	"perk_2_1_desc": {"zh": "备用弹药 +50%", "en": "Reserve ammo +50%"},
	"perk_2_2_desc": {"zh": "换弹速度 +30%", "en": "Reload speed +30%"},
	# 武器名称（HUD/商店/装备界面用，w_前缀避免与按键绑定weapon_x冲突）
	"w_pistol": {"zh": "手枪", "en": "Pistol"},
	"w_rifle": {"zh": "步枪", "en": "Rifle"},
	"w_sniper": {"zh": "狙击枪", "en": "Sniper"},
	"w_knife": {"zh": "刀", "en": "Knife"},
	"w_machinegun": {"zh": "机枪", "en": "Machinegun"},
	# 机枪商店
	"buy_machinegun": {"zh": "购买机枪 (%d)", "en": "Buy Machinegun (%d)"},
	"machinegun_cost": {"zh": "400 分", "en": "400 pts"},
	# --- 金钱/等级/XP ---
	"money_display": {"zh": "金钱: %d", "en": "Money: %d"},
	"boss_kill_notify": {"zh": "击杀 BOSS「幽灵」   +75 XP", "en": "Killed BOSS 'Ghost'   +75 XP"},
	"level_display": {"zh": "Lv.%d %s", "en": "Lv.%d %s"},
	"xp_display": {"zh": "XP: %d / %d", "en": "XP: %d / %d"},
	"player_info": {"zh": "%s  Lv.%d %s", "en": "%s  Lv.%d %s"},
	"max_level": {"zh": "已满级", "en": "MAX LEVEL"},
	# --- 退出广播/中途加入 ---
	"player_left_notify": {"zh": "%s 已退出游戏", "en": "%s left the game"},
	"in_game": {"zh": "在游戏中", "en": "In Game"},
	"join_mid_game": {"zh": "中途加入游戏", "en": "Join Game"},
	"game_in_progress": {"zh": "游戏进行中", "en": "Game In Progress"},
	"game_in_progress_hint": {"zh": "房间内正在进行游戏，点击下方按钮加入", "en": "A game is in progress, click below to join"},
}

func _ready() -> void:
	load_settings()
	var raw_lang = get_value("game", "language", 0)
	if typeof(raw_lang) == TYPE_STRING:
		_lang = 0 if raw_lang == "zh" else 1
	else:
		_lang = int(raw_lang)
	# 启动时立即应用所有保存的设置
	apply_all_settings()


func load_settings() -> void:
	var err: int = config.load(SETTINGS_FILE)
	if err != OK:
		print("Settings file not found, using defaults")
		save_settings()

func save_settings() -> void:
	for section in DEFAULTS.keys():
		for key in DEFAULTS[section].keys():
			if not config.has_section_key(section, key):
				config.set_value(section, key, DEFAULTS[section][key])
	var err: int = config.save(SETTINGS_FILE)
	if err != OK:
		push_error("Failed to save settings: " + str(err))

func get_value(section: String, key: String, default = null):
	var val = null
	if config.has_section_key(section, key):
		val = config.get_value(section, key)
	if val == null:
		if section in DEFAULTS and key in DEFAULTS[section]:
			val = DEFAULTS[section][key]
		else:
			val = default
	return val

func set_value(section: String, key: String, value) -> void:
	config.set_value(section, key, value)
	save_settings()

func has_section(section: String) -> bool:
	return config.has_section(section)

# =====================================================================
# 多语言接口
# =====================================================================

func get_language() -> int:
	return _lang

func set_language(lang: int) -> void:
	_lang = lang
	set_value("game", "language", lang)

func is_english() -> bool:
	return _lang == 1

# 翻译：t("key") 返回当前语言文本
# 支持格式化：t("wave", [current_wave])
func t(key: String, args: Array = []) -> String:
	var text: String = key
	if TRANSLATIONS.has(key):
		var lang_str: String = "en" if _lang == 1 else "zh"
		text = TRANSLATIONS[key].get(lang_str, key)
	if args.size() > 0:
		text = text % args
	return text

func apply_all_settings() -> void:
	var fullscreen: bool = get_value("video", "fullscreen", false)
	get_window().mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED

	var max_fps: int = get_value("video", "max_fps", 0)
	Engine.max_fps = max_fps

	var vsync: bool = get_value("video", "vsync", true)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	# 确保有 Master / BGM / SFX 三个音频总线
	_ensure_audio_buses()

	var master_vol: float = get_value("audio", "master_volume", 0.8)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_vol))

	var bgm_vol: float = get_value("audio", "bgm_volume", 0.6)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), linear_to_db(bgm_vol))

	var sfx_vol: float = get_value("audio", "sfx_volume", 0.8)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_vol))


func _ensure_audio_buses() -> void:
	# 如果只有 Master，添加 BGM 和 SFX 两个总线
	if AudioServer.bus_count <= 1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(1, "BGM")
		AudioServer.add_bus()
		AudioServer.set_bus_name(2, "SFX")
	# 校验名称（防止已有但索引不同）
	if AudioServer.get_bus_index("BGM") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "BGM")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")


# =====================================================================
# XP / 等级 / 军衔系统
# =====================================================================

# 16级军衔（等级=军衔级数）
const MAX_LEVEL: int = 16
const RANK_NAMES_ZH: Array = [
	"列兵", "一等兵", "下士", "中士", "上士",
	"军士长", "资深军士长", "少尉", "中尉", "上尉",
	"少校", "中校", "上校", "少将", "中将", "上将"
]
const RANK_NAMES_EN: Array = [
	"Private", "PFC", "Corporal", "Sergeant", "Staff Sgt",
	"Sgt 1st Class", "Master Sgt", "2nd Lt", "1st Lt", "Captain",
	"Major", "Lt Colonel", "Colonel", "Brig Gen", "Maj Gen", "General"
]

# 等级所需 XP：线性递增（50 + 50*level）
func xp_for_level(level: int) -> int:
	# Lv.1→2: 100, Lv.2→3: 150, Lv.3→4: 200, ... Lv.15→16: 800
	if level >= MAX_LEVEL:
		return 999999  # 已满级，不会再升级
	return 50 + 50 * level

func get_xp() -> int:
	return get_value("game", "xp", 0)

func get_level() -> int:
	return get_value("game", "level", 1)

func get_avatar() -> int:
	return get_value("game", "avatar", 0)

func add_xp(amount: int) -> void:
	var current_xp: int = get_xp() + amount
	var current_level: int = get_level()
	# 检查升级（满级后不再升级，XP溢出清零）
	while current_level < MAX_LEVEL and current_xp >= xp_for_level(current_level):
		current_xp -= xp_for_level(current_level)
		current_level += 1
	if current_level >= MAX_LEVEL:
		current_xp = 0  # 满级清零溢出XP
	set_value("game", "xp", current_xp)
	set_value("game", "level", current_level)

func get_player_name() -> String:
	var nick: String = get_value("game", "nickname", "")
	if nick == "":
		nick = t("default_nickname")
	return nick

func get_rank_name(level: int) -> String:
	# 返回军衔名称（中/英文自动根据语言选择）
	var idx: int = clampi(level - 1, 0, MAX_LEVEL - 1)
	if get_value("settings", "language", "zh") == "en":
		return RANK_NAMES_EN[idx]
	return RANK_NAMES_ZH[idx]

func get_level_progress() -> float:
	# 满级进度 = 1.0
	if get_level() >= MAX_LEVEL:
		return 1.0
	# 当前等级进度 (0.0~1.0)
	var current_xp: int = get_xp()
	var needed: int = xp_for_level(get_level())
	if needed <= 0:
		return 1.0
	return float(current_xp) / float(needed)

