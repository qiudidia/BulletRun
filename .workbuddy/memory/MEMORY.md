# MEMORY.md - Bullet Run 项目长期记忆

## 基本信息
- **项目**: Bullet Run | Godot 4.6 + GDScript 4 | 路径 `C:\Users\32577\Desktop\game\Bullet Run`
- **启动场景**: `res://scenes/intro/intro.tscn`（Intro→MainMenu→各模式）
- **Autoload**: GameSettings.gd（设置/多语言/音频总线）+ UIAudio.gd + BGMManager.gd（跨场景BGM）+ LoadoutManager.gd + NetworkManager.gd
- **视口**: 1280×720，mode=3 启动全屏，stretch=canvas_items（防像素化）

## 游戏模式
- **僵尸模式** `scenes/game/zombie_mode/zombie_game.tscn`：无限波次，每5波精英(500血/25攻/紫)，每10波BOSS"幽灵"(10000血/50攻/红/披风/连环8选手雷6秒CD)，波次间隙金钱商店。开局仅手枪+0手雷，步枪(300分)/狙击枪(500分)需商店购买(一次性)。BOSS出现时屏幕顶部显示血条。
- **Bot模式** `scenes/game/bot_mode/bot_game.tscn`：开局选4级难度，击杀计分，E键人头商店(弹药/医疗/伤害/无限子弹/核爆/手雷)。开局手枪+步枪+狙击枪+1手雷。max_bots=8。
- **联机**: ENet LAN(7777)+UDP广播房间发现(7778)。三模式：单挑DUEL(2人红蓝/DuelMap1600²)、乱斗BRAWL(3人红蓝黄/BrawlMap2000²)、僵尸合作ZOMBIE(4人红蓝黄绿/2400²)。自由选色，冲突不可开始。昵称≤12字符。

## 核心文件
- 玩家: scripts/Player.gd / MultiplayerPlayer.gd
- AI: scripts/ZombieAI.gd / BotAI.gd
- 地图: scripts/GameMap.gd / DuelMap.gd / BrawlMap.gd
- 商店: scripts/Shop.gd + ShopUI.gd
- 联机: Autoload/NetworkManager.gd + scripts/LobbyUI.gd + scenes/game/multiplayer/{Duel,Brawl,ZombieCoop}Game.gd
- UI: UI/Settings.gd, scripts/MainMenu.gd, scripts/Intro.gd

## 四武器系统 → 五武器系统
- 手枪(0)/步枪(1)/狙击枪(2)/刀(3)/机枪(4)，各自独立弹匣/伤害/速度/音效/视觉(代码绘制无外部图)。狙击枪: dmg100/rate2.0s/ammo5/reserve20/reload3.0s/半自动/spread0/speed1200。机枪: dmg8/rate0.08s/ammo100/reserve300/reload4.0s/全自动/spread0.08/speed900。weapon_4(键4)对应刀，weapon_5(键5)对应机枪。
- **半自动**: 手枪/狙击枪用 `_cooldown_ready`，须松开再按；步枪/机枪(自动)按住连射。
- **has_rifle/has_sniper/has_machinegun**: Bot模式按LoadoutManager配置决定；僵尸模式_ready()设false，商店购买后unlock；联机模式按配置。
- **图标映射**: IconType={PISTOL=0,RIFLE=1,GRENADE=2,SNIPER=3,KNIFE=4,MACHINEGUN=5}，武器槽索引→IconType用数组。Player:[0,1,3,4,5](5武器含刀)，MultiplayerPlayer:[0,1,3,5](4武器无机刀)。
- **MP武器索引差异**: Player weapons=[pistol(0),rifle(1),sniper(2),knife(3),machinegun(4)]; MultiplayerPlayer weapons=[pistol(0),rifle(1),sniper(2),machinegun(3)]无机刀。weapon_5→Player._switch_weapon(4), MP._switch_weapon(3)。

## 输入动作(project.godot)
- 移动WASD / shoot(鼠标左) / reload(R) / weapon_1-4(1234) / interact(E) / pause(ESC) / grenade(G) / toggle_minimap(M)

## Bot 难度(4级, BotAI._apply_difficulty 控制14参数)
- EASY: spd100/range400/shoot250/hp40/aim0.15/spread2.5x，不走位不躲避
- NORMAL: spd120/hp60/aim0.4/spread2x，有走位躲避无撤退无切武器
- MEDIUM: spd150/range500/shoot300/hp80/aim0.6/spread1.5x，全智能
- HARD: spd180/range600/shoot350/hp100/aim0.85/spread1.0x，全智能手雷2
- BotAI: 5状态机(PATROL/CHASE/SHOOT/COVER/RETREAT)，SHOOT时strafe+躲弹+预判，RETREAT血量<30%。三武器切换(远狙击/近手枪/中步枪)。防卡: 巡逻点相对当前位置(-300~300)，每秒移动<5px换方向。

## 联机细节
- MultiplayerPlayer 基于 Player.gd + authority + RPC同步。Bullet/Grenade 有 owner_peer_id。
- **友军保护**: 子弹/手雷不打自己；僵尸模式不打队友；单挑不打同队；乱斗可打任何人(除自己)。
- **僵尸联机商店**: 本地独立购买(扣本地money/直接施效)，房主只控开关时机和波次。击杀奖励 _sync_kill_reward.rpc() 全员共享。Continue客户端禁用显示"等待房主"。
- **僵尸联机同步**: 房主在 `_spawn_wave_enemies` 中生成精确位置 → PackedFloat64Array → `_rpc_spawn_wave.rpc(spawn_data)` → 客户端 `_spawn_wave_from_data(spawn_data)` 在相同位置生成僵尸。僵尸AI在各客户端独立运行（追逐最近玩家，玩家位置已同步，大致保持一致）。
- **暂停同步**: 房主/客户端 _open_shop 都须 get_tree().paused=true。
- **观战**: 玩家死不全队结束。死亡面板"撑到X波"+[观战][退出]。观战摄像机top_level跟随存活队友，空格切换。_check_all_dead()才_game_over()。
- TEAM_COLORS: red(0.9,0.2,0.2)/blue(0.2,0.4,0.9)/yellow(0.9,0.85,0.2)/green(0.2,0.7,0.3)
- **game_in_progress**: NetworkManager追踪游戏进行中状态。3游戏场景_ready()调set_game_started(mode)，DuelGame返回房间调set_game_ended()。disconnect_network()含重置。RPC _sync_game_status同步。
- **退出广播**: _on_player_left()获取玩家名，_show_exit_notify()显示"xxx已退出游戏"（橙色24px，上滑淡出）。
- **中途加入**: LobbyUI检测game_in_progress→显示"在游戏中"状态+"中途加入游戏"按钮→点击加载对应游戏场景。UDP广播含in_game标志(6字段)。

## 僵尸系统
- ZombieAI.health_changed(current,max) 信号，take_damage时emit，ZombieGame连它更新BOSS血条。
- **BOSS手雷**: _boss_grenade_timer 每8秒向玩家扔(伤60/半径100/引信1.5s/预判)。Grenade.is_enemy_grenade=true伤玩家不伤僵尸，外观暗红。联机 _sync_enemy_grenade.rpc() 同步。
- 目标选择: _find_player()选距离最近的存活玩家(dead!=true)；_physics_process每3秒(_retarget_timer)重新评估目标，避免僵尸一直追远处目标忽略近处玩家。
- 爆炸桶: GameMap._spawn_barrels() 每桶30次找不与掩体重叠位置(60px缓冲)。

## 装备配置/特长系统 (新增)
- **LoadoutManager** (Autoload): 5套装备配置，每套含 primary_weapon(1=步枪/2=狙击枪/4=机枪) + perks[-1,-1,-1]。
- **Perk 3类别**: 移动[轻装上阵(+15%速度)/清道夫(击杀掉弹药包)]、防御[防弹衣(100→130血)/快速治疗(3秒后1HP/秒回血上限50%)/爆炸抗性(爆炸-40%)]、战斗[精准射击(散布-25%)/弹药充沛(备弹+50%)/快速换弹(换弹+30%)]。
- **_apply_perk_effects()**: 幂等设计，用 `_perks_applied` + `_orig_weapon_data` 防叠加；先 `max_health=100` 重置再应用；防弹衣 `current_health=mini(current_health+30,130)` 不免费治愈。
- **Scavenger(清道夫)**: 击杀敌人→`_spawn_ammo_pack(pos)` 创建 AmmoPack(Area2D 15秒寿命 金色弹药箱图标)；`_refill_current_ammo()` 补满当前武器reserve(最小=max_ammo*3)。MP版 `_refill_current_ammo` 末尾有 `_sync_ammo.rpc`。
- **爆炸抗性**: `take_damage(amount, is_explosion=true)` → `amount = int(amount * 0.6)`。Grenade.gd/Barrel.gd 爆炸伤害均传 `is_explosion=true`。
- **机枪音效**: mg_sfx=jiqiang.mp3, mg_reload_sfx=jiqianghuandan.mp3。Player.gd current_weapon_index==4播放; MP current_weapon_index==3播放。

## 已修复问题(接管后处理)
- ~~KillStreakUI.gd 死代码~~ → 已删除(07-01)
- ~~DuelGame.gd `_respawn_player()` 为 pass~~ → 已实现RPC同步(07-01)，BrawlGame.gd 同步补上
- ~~翻译键 back_to_menu 缺失~~ → BrawlGame.gd 改用 return_to_menu(07-01)
- ~~BGM跨场景重启~~ → BGMManager Autoload(07-01)
- ~~ZombieAI只追第一个玩家~~ → 改为选最近+3秒重评估(07-01)
- ~~联机武器UI弹药不更新~~ → _shoot/_reload_done 补 _update_weapon_ui()(07-01)
- ~~左上角弹药显示重复~~ → AmmoLabel从5个.tscn+7个.gd完全移除(07-02)，右下角武器UI已包含弹药信息
- ~~经验改名~~ → kill_notify中文从"经验"改为"XP"(07-02)

## XP/等级/军衔/头像系统 (07-02新增)
- **16级军衔**: 列兵→一等兵→下士→中士→上士→军士长→资深军士长→少尉→中尉→上尉→少校→中校→上校→少将→中将→上将
- **XP公式**: `50+50*level`（线性递增），Lv1→2=100, Lv15→16=800, 满级后溢出XP清零
- **GameSettings**: MAX_LEVEL=16, RANK_NAMES_ZH/EN, xp_for_level, get_xp/get_level/get_avatar/add_xp/get_level_progress/get_player_name/get_rank_name
- **击杀XP**: 僵尸普通+5/精英+35/BOSS+75; Bot+10
- **AvatarIcon.gd**: 16种代码绘制头像(0=蓝十字星..15=黑白棋盘格); avatar_clicked信号+_gui_input+_notification(hover高亮环)
- **MainMenu玩家面板**: 左上角PanelContainer + AvatarIcon48×48(可点击) + 名字+Lv.%d军衔名+XP进度条+XP数值
- **头像选择器**: 点击头像弹出4×4网格选择面板，选中保存到GameSettings
- **满级**: XP标签显示"已满级"，进度条100%
- **NetworkManager头像同步**: player_avatars字典 + _register_player_name含avatar_id + _send_room_info/_sync_player_names含avatars

## 待优化/技术债务
- 代码重复：MultiplayerPlayer.gd vs Player.gd 大量重复；_spawn_blood_vfx 在3个模式文件重复；各模式暂停菜单各自创建。合并风险高，暂不动。
- Console.gd：`~`键开发控制台(god_mode等作弊码)，仅Bot/Zombie接入，联机未接入。
- Minimap.gd：右上角小地图，M键(toggle_minimap)切换。Barrel.gd：爆炸桶0.5s延迟连锁爆炸。

## 已知坑点/约定
- **died 信号**: Player的died无参数；敌人/Bot的died(node)带参数。连接回调须严格匹配。
- Player死亡不自行重载场景，由游戏模式经 health_changed 处理，只发died信号+禁输入。
- 音频总线 Master/BGM/SFX 由 GameSettings._ensure_audio_buses() 运行时创建。
- GameMap._get_floor_node()（已重命名避免与局部变量重名）。
- 设置关闭后须调 _apply_language() 刷新多语言文本。
- Crosshair.gd 用 _draw() 统一绘制，update_crosshair(style,color) 是接口。
- **ammo_changed信号**: 仍存在但无外部连接者，BotGame._refill_ammo()后补调player._update_weapon_ui()确保UI更新。
- **击杀通知**: Bot/Duel/Brawl/Zombie/ZombieCoop模式均有 `_show_kill_notification(name, xp)` 金黄22px上滑淡出。BOSS击杀用独立 `_show_boss_kill_notification()` 红色28px。`kill_notify`翻译参数化为 `击杀 %s +%d XP`。

## Godot 4 踩坑
- Panel 无 color 属性，用 StyleBoxFlat + add_theme_stylebox_override("panel",style)。ColorRect/Polygon2D 的 color 合法。
- .gd 中 theme_override_constants/separation 非法(解析为除法)，用 add_theme_constant_override("separation",N)；.tscn 中合法。
- SIZE_FLAG_SHRINK_CENTER 不存在，用 SIZE_SHRINK_CENTER。
- CenterContainer 不能放 ScrollContainer 内；ScrollContainer直接子节点不能PRESET_FULL_RECT，用SIZE_EXPAND_FILL。
- Panel是Control非Container不自适应；卡片容器用PanelContainer，其内子节点不需PRESET_FULL_RECT。
- get_tree().paused=true 后 INHERIT 节点收不到 _input()，需 process_mode=ALWAYS 独立处理器监听ESC。
- GDScript 不支持 Python """ docstring，只能用 #。
- Object.get("prop") 不存在返回null，null==true为false，用于跨脚本安全访问(如 obj.get("dead"))。
- get_tree().current_scene.add_child 需 null 检查(场景切换中可能为null)。
- 死亡面板重生后必须清除 death_panel；远程玩家不应恢复 set_process_input(true)。
- 修改文件后务必二次确认目标内容(工具偶发显示错误文件名)。lint全绿≠语法正确，须人工检查。信号参数须与回调严格匹配。
- **僵尸模式金钱HUD**: MoneyHUDLabel节点在zombie_game.tscn和zombie_coop_game.tscn的UI下，金黄font_size=22
- **联机大厅玩家列表**: 用VBoxContainer+HBoxContainer行布局(每行AvatarIcon+文字)，替代旧的单Label多行文本

## 用户偏好
- 中文交流，简洁直接。期望一次性修复所有BUG，不喜欢AI自行编纂。修复后全面代码审查。
- 开发环境无外网，无法获取外部资源。
- 同时维护 UE4.27 FPS 项目，但电脑无 Visual Studio 不能编译C++。
