# Black Mesa 死亡竞赛服务器

Black Mesa(黑山起源)死亡竞赛专用服务器的插件与配置集合。

服务器启用的 **35 个 SourceMod 模块被合并编译成单个 `BMAG.smx`**(SourceMod 官方插件 + 社区插件 + 自研 `bms_match` 比赛插件),
另有若干**独立插件**(`tau_mp`、`hl1tau`、`spawn_marker` 等)单独加载。

源码、合并器与逆向笔记全部在本仓库内,可直接重建。

---

## ⚠️ 部署前必改清单

本仓库是从一台**已经在跑的**服务器上整理出来的,配置里仍带着原服的服务器名、
群号、域名、账号和**占位 SteamID**。直接照抄开服,你的服务器会顶着别人的名字、
把玩家引到别人的群和网站,而你本人拿不到任何管理员权限。

下表是全部需要动手的地方;每个文件的顶部也都写了同样的提示,
搜 `>>>` 就能在文件里定位到具体那一行。

| 文件 | 改什么 | 怎么改 |
|---|---|---|
| `cfg/server.cfg` | `hostname`、`sv_region`、`tv_title`/`tv_name`、`maxplayers`、`sv_password` | 改成你自己服务器的信息 |
| `cfg/server.cfg` | `sv_downloadurl`、`sm_motd_url` | 换成你的域名;**没有 FastDL 就把 `sv_downloadurl` 整行注释掉**(玩家回退 srcds 直传,慢但能连) |
| `cfg/server.cfg` | `is_weaponfix_saddr` | 填**外网玩家能连到的**公网 `IP:端口`,不能留 `127.0.0.1`,否则武器动画修复静默失效 |
| `cfg/server.cfg` | `rcon_password` | **该文件里没有这一行**,需自行在启动参数加 `+rcon_password "你的密码"`,且**绝不要提交进 git** |
| `configs/admins.cfg` | `identity`(两条 `STEAM_0:x:1000000xx`) | 换成真实 SteamID,否则你没有任何管理员权限 |
| `configs/databases.cfg` | **本仓库没有这个文件** | 只有 `clientprefs`、SQL 管理员等用到数据库时才需要自建(里面是数据库密码,故意不入库) |
| `configs/advertisements.txt` | 两条 `chat` 文案 | 原服的群号和 B 站账号,换成你的 |
| `smx_analysis/src/scripting/configs/bms_match.cfg` | `SourceTV` → `DownloadBase` | 改成你的地址,或留空 `""`(录像仍会录,只是下载链接不可用) |
| `smx_analysis/src/scripting/cfg/mapcycle_*.txt` | 地图名单 | 删掉你服务器上**没有**的地图,否则换图失败 |
| `motd/index.html` | QQ 群 / B 站 / Discord / 服务器列表 | 三个语言段各出现一次,都要改 |

**不需要改**(照抄即可):`cfg/autoexec.cfg`、`cfg/listenserver.cfg`、
`configs/admin_levels.cfg`、`configs/admin_groups.cfg`、`configs/maplists.cfg`、
`configs/core.cfg`、`configs/player_models.cfg`、`configs/banreasons.txt` 等。

> `configs/core.cfg` 的 `ServerLang` 保持默认 `"en"` 即可,不用改 ——
> 各插件 `translations/*.phrases.txt` 的语言键写法不统一(`schinese` / `zh` / `en` 混用),
> `en` 是三份都有的一份,也是兜底档。

---

## 目录结构

```
├── plugins/                      服务器 plugins/ 目录的备份(部署产物)
│   ├── BMAG.smx                  35 模块合一插件 = 本仓库的主要产物
│   ├── tau_mp.smx                单人战役 tau 改造(独立插件)
│   ├── hl1tau.smx                HL1 高斯枪还原(独立插件)
│   ├── bms_rpgReloadFix.smx      第三方:RPG 换弹修复
│   ├── bms_weapon_tauStuckFix.smx 第三方:tau 低弹药卡枪修复
│   ├── is_weaponfx.smx           第三方:武器动画预热
│   ├── <官方插件>.smx            2022 年上传的原始逐插件版本(已被 BMAG 取代,留作参照)
│   └── disabled/                 停用插件(spawn_marker、nextmap、basebans、randomcycle 等)
├── smx_analysis/                 构建流水线与源码
│   ├── merge.py                  把 35 个模块源码合并成 BMAG.sp
│   ├── fix_merge.py              merge.py 的补丁工具
│   ├── sig_check.py              签名抗重定位校验(见"从源码构建")
│   ├── rcon.py                   RCON 调试客户端(凭据走环境变量)
│   ├── bisect_compile.py         二分定位编译失败的模块
│   ├── REVERSE_*.md              引擎逆向笔记(见下)
│   └── src/scripting/
│       ├── plugins/              **35 个模块源码 + 独立插件源码**
│       ├── include/              编译用 SourceMod include(与生产服务器版本一致)
│       ├── BMAG/                 merge.py 产物(BMAG.sp 为生成物不入库,BMAG.smx 入库)
│       ├── configs/              插件配置(bms_match.cfg、bms_webpanel.html)
│       ├── cfg/                  地图池与比赛用 cfg
│       └── gamedata/             插件 gamedata
├── cfg/ configs/ motd/           服务器其它配置备份
├── gamedata/tau_mp.games.txt     tau_mp 的签名文件(部署用)
└── README.md
```

`.gitignore` 排除:交付包归档 `bms_match_delivery/`、`smx_analysis/dl/` 与 `smx_analysis/out/`(下载的工具与证据 dump,
体积大且可重新获取)、`merge.py` 生成的 `BMAG/BMAG.sp`、已被 `BMAG.smx` 取代的旧版平铺产物,
以及暂时搁置的自定义准星客户端 mod `client_mod/`。

### 逆向笔记(`smx_analysis/REVERSE_*.md`)

这些文档记录了本仓库所有非平凡修改所依据的引擎级证据(反汇编地址、签名、调用链),**改动相关代码前请先读**:

| 文件 | 内容 |
|---|---|
| `REVERSE_TAU.md` | tau 炮单人/多人分支、高斯跳、跌落伤害链路 |
| `REVERSE_RESPAWN.md` | 死亡竞赛重生机制、复活点选择为何失效 |
| `REVERSE_TIMER.md` | 回合计时器与 `mp_restartgame` 通道 |
| `REVERSE_VGUI.md` | VGUIMenu 面板与无线电菜单 |
| `REVERSE_WALLPEN.md` | 弹道穿墙与玻璃穿透 |

---

## 部署

服务器是 steamcmd 安装的 srcds,根目录记为 `%SRV%`(即含 `srcds.exe` 的那一层)。
把对应文件复制进去即可:

```bat
set SRV=<你的 srcds 根目录>
copy /Y plugins\BMAG.smx            %SRV%\bms\addons\sourcemod\plugins\
copy /Y plugins\tau_mp.smx          %SRV%\bms\addons\sourcemod\plugins\
copy /Y plugins\hl1tau.smx          %SRV%\bms\addons\sourcemod\plugins\
copy /Y gamedata\tau_mp.games.txt   %SRV%\bms\addons\sourcemod\gamedata\
copy /Y smx_analysis\src\scripting\translations\*.txt %SRV%\bms\addons\sourcemod\translations\
copy /Y smx_analysis\src\scripting\configs\bms_match.cfg %SRV%\bms\addons\sourcemod\configs\
copy /Y smx_analysis\src\scripting\cfg\*.txt             %SRV%\bms\cfg\
copy /Y smx_analysis\src\scripting\cfg\*.cfg             %SRV%\bms\cfg\
```

> `translations\*.txt` 那行别漏:**这三份短语文件是运行时读取的,不编进 `BMAG.smx`**。
> 漏了的话聊天框里所有 `[比赛]` 提示都会显示成短语键名。改文案(不动代码)
> 只需重传这三个文件 + 换图或 `sm plugins reload BMAG`,不必重新编译。

单人战役环境是另一套 `addons/sourcemod`(Steam 客户端目录下的 Black Mesa),
只部署 `tau_mp.smx` + `hl1tau.smx` + `tau_mp.games.txt`。

复制后重启服务器,或在服务器控制台执行 `sm plugins reload BMAG`。

### 启动

```bat
srcds.exe -game bms +map dm_boom +maxplayers 16 -condebug
```

日志追加写入 `bms\console.log`。建议让它随开机自动启动(计划任务或服务),
进程没起来时重启即可 —— 见"已知问题"里的启动竞态。

### RCON

`rcon_password` 需自行在**启动参数**里设置(例如 `+rcon_password "你的密码"`),
**不随本仓库分发**,`cfg/server.cfg` 里也没有这一行 —— 历史上曾经把密码写进该文件
并提交过,所以现在刻意不提供,避免再次泄露。
仓库内的调试客户端从环境变量读取连接信息:

```bash
RCON_HOST=127.0.0.1 RCON_PORT=27015 RCON_PASSWORD='<你的rcon密码>' python smx_analysis/rcon.py "sm plugins list"
```

客户端超时建议 ≥25 秒(该引擎 RCON 响应较慢)。

---

## 权限标志

下表用标志字母表示权限,与 `configs/admin_levels.cfg` 一致:

| 字母 | 权限 | 字母 | 权限 | 字母 | 权限 |
|---|---|---|---|---|---|
| a | 预留通道 | f | 处死 | k | 发起投票 |
| b | 通用管理 | g | 换图 | l | 设密码 |
| c | 踢人 | h | 修改 ConVar | m | RCON |
| d | 封禁 | i | 执行配置文件 | n | 作弊 |
| e | 解封 | j | 管理员聊天 | z | ROOT |

聊天中输入 `!<命令>` 或 `/<命令>` 即可触发;控制台输入命令原名。

---

## 一、`bms_match` — 比赛插件(自研)

参考 hl2dm 的 xms 比赛插件、按 Black Mesa 引擎重写的比赛系统。
是 `BMAG.smx` 的一个模块,**不支持单独加载**。

### 玩家命令

| 命令 | 说明 |
|---|---|
| `!start` | 开始比赛。人数达到 `VoteMinPlayers` 时发起投票;否则(含 bot 时至少 2 人)直接开始 |
| `!cancel` | 取消比赛并恢复公服参数。比赛中需投票通过 |
| `!help` / `!commands` | 弹出比赛指令菜单(无线电菜单形式) |
| `!maplist` / `!list [模式]` | 查看地图池,`ffa` / `tdm` / `all`,默认当前模式 |
| `!run <地图>` / `!runnow <地图>` | 发起"换当前图"投票,支持 `模式:地图` 与缩写 |
| `!runnext <地图>` | 发起"设置下一张图"投票 |
| `!runrandom` | 从当前模式地图池随机抽 4 张发起换图投票 |
| `!shuffle` | 洗牌分队(仅 TDM) |
| `!invert` | 互换两队(仅 TDM) |
| `!yes` / `!no` / `!1`–`!5` | 投票表决 |
| `!pause` / `!unpause` | 暂停 / 继续服务器 |
| `!panel` / `!webpanel` | 打开游戏内网页控制台(见下) |
| `!vguitest` | 弹出测试用 VGUI 面板(比分板/隐藏变体,调试用) |

**聊天别名**:`!stop` → `!cancel`、`!join` → 加入人数较少的队伍、`!spec` → 观战、
`!next <图>` → `!runnext <图>`、`!random` → `!runrandom`。

`!run` 支持的地图缩写:`bunker`→`dm_lambdabunker`、`bounce`、`stalk`→`dm_stalkyard`、
`sub`→`dm_subtransit`、`gas`→`dm_gasworks`、`rail`、`crossfire`、`boom`。

### 管理员命令(需 b = 通用管理)

| 命令 | 说明 |
|---|---|
| `!forcespec <玩家>` | 强制某玩家转入观战 |
| `!allow <玩家>` | 放行某玩家加入比赛(解除开赛后的加入封锁) |
| `!starttest` | 启动一场 **1 分钟**的测试比赛,用于验证 SourceTV 录像链路 |

### ConVar

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_bms_webpanel_enabled` | 1 | 启用游戏内网页控制台(需要 socket 扩展) |
| `sm_bms_webpanel_host` | *(空)* | 面板 URL 中使用的 Host,留空 = `127.0.0.1` |
| `sm_bms_webpanel_port` | 28015 | 网页控制台监听端口 |

### 命令监听(拦截引擎命令)

插件挂在这些引擎命令上,按比赛状态放行或吞掉:

| 命令 | 比赛中的行为 |
|---|---|
| `jointeam` / `spectate` / `chooseteam` | 开赛后封锁换边;经 `!allow` 放行 |
| `pause` / `unpause` / `setpause` | 暂停状态与比赛状态机同步;吞掉引擎自身的回显以免二次派发 |
| `kill` / `explode` | 倒计时与赛后结算阶段禁止自杀绕过冻结 |
| `changelevel` / `changelevel_next` | 比赛中阻止手动换图,由插件统一发起投票 |

### 比赛流程

1. `!start` → 人数 < `VoteMinPlayers` 直接开始,否则发起投票
2. 进入 MatchWait:执行 `exec server_match`(重置时限/封顶/复活)→ 冻结玩家并剥离武器 → 4 秒倒计时
3. 进入 Match:计时开始,锁定队伍;参赛者掉线自动暂停;FFA 取最高击杀(平局比死亡数),TDM 比队伍分
4. 平分 → 自动加时(Overtime,每分钟续时直到分出胜负)
5. 结束:广播胜利与比分 → `exec server_match_post` 恢复公服参数 → 自动发起下一张图投票 → 引擎自然换图

比赛自动开启 SourceTV 录像,文件落在服务器本机的 `demos\` 目录(不提供下载)。

**单人战役地图会被自动跳过**:判据是地图名前缀 `bm_c<数字>`(78 张战役图全部命中,与 DM 图无冲突)。
命中时跳过队伍枚举、静默 1Hz 定时器、并关闭 `fast_spawn`。

### 配置(`configs/bms_match.cfg`)

| 键 | 默认 | 说明 |
|---|---|---|
| `VoteMinPlayers` / `VoteMaxTime` / `VoteCooldown` | 3 / 25 / 30 | 投票人数门槛、时限、冷却(秒) |
| `AutoVoting` | 1 | 比赛结束自动发起下一图投票 |
| `DefaultMode` / `RetainModes` | ffa / ffa,tdm | 默认模式 / 换图后保留的模式 |
| `PreMatchCommand` / `PostMatchCommand` | `exec server_match` / `exec server_match_post` | 开赛 / 赛后执行的 cfg |
| `Gamemodes` | — | 每模式:`Command`(如 `mp_teamplay 0`)、`Mapcycle`、`Defaultmap`、`Matchable`、`Overtime`、`MatchTimelimit` |
| `Maps` | — | `StripPrefix`(显示时去掉的图名前缀)、`DefaultModes`(通配映射)、`Abbreviations`(图名缩写) |

地图池文件放在 `bms/cfg/` 下,由各模式的 `Mapcycle` 键引用。默认各 12 张官方 DM 图:
`dm_boom`、`dm_bounce`、`dm_chopper`、`dm_crossfire`、`dm_gasworks`、`dm_lambdabunker`、
`dm_power`、`dm_rail`、`dm_stack`、`dm_stalkyard`、`dm_subtransit`、`dm_undertow`。

---

## 二、其它自研 / 深度改造模块

### `fast_spawn` — 零秒重生

死亡后立即重生,不等原生按键或 5 秒 `mp_forcerespawn`。

| 命令 | 权限 | 说明 |
|---|---|---|
| `fastspawn` / `sm_fs` | b | 查询或开关零秒重生 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_fastspawn` | 1 | 启用:死亡 `sm_fastspawn_time` 秒后重生 |
| `sm_fastspawn_batch` | 4 | 每个游戏 tick 最多重生几人(削平爆发重生;调小更平滑) |
| `sm_fastspawn_time` | 0.0 | 重生延迟秒数(0 = 立即) |

行为要点:

- 真人走 `OnPlayerRunCmd` 判定,`DispatchSpawn` 推迟到下一帧(避免在移动循环中途重入 `Spawn()` 导致"原地复活")
- bot 绕过 `OnPlayerRunCmd`,用 0.1 秒 timer 轮询模拟按键
- 致死伤害(`damage >= 血量`)时**先剥光武器再死**,避免掉落武器堆积;重生时给玩家加一帧 `FL_NOTARGET` 防止默认装备掉地上
- **单人战役地图与比赛期间自动关闭**(见 `bms_match` 一节):比赛期保留正常武器掉落,战役图避免误判高斯跳落地为致死

### `spawn_distribute` — 复活点均匀分配

BM 引擎原生的复活点选择链已损坏(`IsSpawnPointValid` 不读标旗、用零长度 trace 判定占用),
导致所有人被扔到同一个点。本模块不碰原生逻辑,在 `player_spawn` 事件里自己挑空闲点传送。

| ConVar | 默认 | 说明 |
|---|---|---|
| `spawn_distribute_enabled` | 1 | 开启(1 = 在 `player_spawn` 时挑空闲复活点传送) |
| `spawn_distribute_cooldown` | 2.0 | 同一点被分配后多少秒内不重复分配(0 = 关闭时间占用判定) |
| `spawn_distribute_radius` | 64.0 | 真人占用判定半径;范围内有**其他真人**即视为占用(bot 不参与) |

### `textmsg_fix` — 中文崩溃修复

修复 CP936 代码页下 UTF-8 中文消息尾字节悬空前导导致的 `_vsnprintf` fail-fast 崩溃。
无命令、无 ConVar,纯 Hook。

### `adv-weapon_cleaner` — 掉落武器清扫

| ConVar | 默认 | 说明 |
|---|---|---|
| `adv_weapon_cleaner_keep_map_weapons` | 1 | 是否保留地图固有武器(0 = 清,1 = 留) |
| `adv_weapon_cleaner_much_weapons` | 100 | 触发清理的武器数阈值(含玩家背包) |
| `adv_weapon_cleaner_remove_delay` | 20.0 | 玩家丢下武器后等待多久移除 |
| `adv_weapon_cleaner_remove_delay2` | 0.1 | 每把武器的递减延迟 |
| `adv_weapon_cleaner_sweep_interval` | 10.0 | 全量清扫间隔秒数(0 = 关闭清扫) |
| `adv_weapon_cleaner_version` | 1.0 | 版本号 |

只跟踪 `weapon_*`,不误删 `item_*`(充电器、道具)。判定依据是 `m_bRemoveable` 数据表字段。

### `SpecDetails` — 观察者详情

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_specDetails_enabled` | 1 | 启用/关闭本插件 |

比赛期间自动禁用(避免面板风暴;面板更新有 5 秒冷却)。

### `speclist` — 观战者列表

无命令、无 ConVar。定时刷新观战者名单显示。

### `missing_viewmodel_fix` — 缺失持枪模型修复

无命令、无 ConVar。挂 `jointeam` 与 `client_specmode` 监听,在切换队伍/观察模式后重建 viewmodel。

### `advertisements` — 轮播广告

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_advertisements_reload` | b | 重新读取广告文件 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_advertisements_enabled` | 1 | 启用/关闭广告显示 |
| `sm_advertisements_file` | advertisements.txt | 广告文本文件 |
| `sm_advertisements_interval` | 30 | 广告间隔秒数 |
| `sm_advertisements_random` | 0 | 随机顺序播放 |

### `sm_noearbleed` — 去除耳鸣/压耳声

无命令,仅 `sm_noearbleed_version`。挂 `OnTakeDamage` 把 `DMG_BLAST` 改成 `DMG_GENERIC` 以去掉爆炸耳鸣效果(不改伤害数值)。

---

## 三、SourceMod 官方模块

### `admin-flatfile`
无命令、无 ConVar。读取 `configs/admins.cfg`、`admin_groups.cfg`、`admin_overrides.cfg`。

### `admincheats`
| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_admin_cheats_level` | 0 | 执行作弊命令所需的权限等级 |
| `sm_admin_cheats_version` | 0.2 | 版本号 |

### `adminhelp`
| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_help` | b | 显示 SourceMod 命令与说明 |
| `sm_searchcmd` | b | 搜索 SourceMod 命令 |

### `adminmenu`
| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_admin` | b | 打开管理员菜单 |

### `antiflood`
| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_flood_time` | 0.75 | 两条聊天消息之间允许的最短间隔(秒) |

### `basechat` — 管理员聊天

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_say <文本>` | j | 以管理员身份向所有人发消息 |
| `sm_csay <文本>` | j | 屏幕中央大字 |
| `sm_hsay <文本>` | j | HUD 提示文字 |
| `sm_msay <文本>` | j | 居中菜单式对话框 |
| `sm_tsay [颜色] <文本>` | j | 左上角提示 |
| `sm_chat <文本>` | j | 发到管理员聊天频道 |
| `sm_psay <玩家> <文本>` | j | 私聊 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_chat_mode` | 1 | 允许普通玩家向管理员聊天频道发消息 |

### `basecomm` — 禁言/禁麦

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_gag <玩家> [分钟]` | j | 禁止文字聊天 |
| `sm_mute <玩家> [分钟]` | j | 禁止语音 |
| `sm_silence <玩家> [分钟]` | j | 同时禁止文字与语音 |
| `sm_ungag <玩家>` | j | 解除文字禁言 |
| `sm_unmute <玩家>` | j | 解除语音禁麦 |
| `sm_unsilence <玩家>` | j | 同时解除两者 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_deadtalk` | 0 | 死亡玩家的聊天可见性(0 = 关闭,1 = 无视队伍) |

### `basecommands` — 基础管理命令

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_kick <玩家> [原因]` | c | 踢出玩家 |
| `sm_map <地图>` | g | 切换地图 |
| `sm_rcon <命令>` | m | 通过 RCON 执行服务器命令 |
| `sm_cvar <ConVar> [值]` | h | 读取/修改 ConVar |
| `sm_resetcvar <ConVar>` | h | 把 ConVar 恢复为默认值 |
| `sm_execcfg <文件>` | i | 执行 cfg 文件 |
| `sm_cancelvote` | k | 取消当前投票 |
| `sm_revote` | — | 重新发起上一次投票(仅限投票发起者) |
| `sm_who [玩家]` | b | 列出玩家及其权限 |
| `sm_reloadadmins` | d | 重新读取管理员配置 |

`rcon_password` 被本模块保护,禁止通过 `sm_cvar` 读取。

### `basetriggers` — 聊天触发词

| 命令 | 说明 |
|---|---|
| `timeleft` | 显示剩余时间 |
| `nextmap` | 显示下一张地图 |
| `motd` | 显示 MOTD |
| `ff` | 显示友军伤害状态 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_timeleft_interval` | 0.0 | 每隔 x 秒广播剩余时间(0 = 关闭) |
| `sm_trigger_show` | 0 | 触发词是否对全体玩家回显(0 = 只回触发者) |

### `basevotes` — 投票

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_vote <议题> [选项...]` | k | 发起自定义投票 |
| `sm_voteban <玩家> [原因]` | k+d | 发起封禁投票 |
| `sm_votekick <玩家> [原因]` | k+c | 发起踢人投票 |
| `sm_votemap <地图...>` | k+g | 发起换图投票 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_vote_ban` / `sm_vote_kick` / `sm_vote_map` | 0.60 | 各投票通过所需票数比例 |
| `sm_vote_show` | 1 | 是否显示各玩家的选择 |
| `sm_voteban_time` | 30 | 封禁时长(分钟) |

### `clientprefs`
| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_cookies <名称> [值]` | b | 读取/修改客户端 cookie |
| `sm_settings` | — | 打开玩家个人设置菜单 |

### `funcommands` — 娱乐命令

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_beacon <玩家>` | f | 目标身上产生光圈 |
| `sm_blind <玩家> [强度]` | f | 目标致盲 |
| `sm_burn <玩家> [时长]` | f | 点燃目标 |
| `sm_drug <玩家> [强度]` | f | 目标画面扭曲 |
| `sm_firebomb <玩家> [时长]` | f | 在目标身上装燃烧炸弹 |
| `sm_freeze <玩家> [时长]` | f | 冻结目标 |
| `sm_freezebomb <玩家> [时长]` | f | 在目标身上装冰冻炸弹 |
| `sm_gravity <玩家> <倍率>` | f | 修改目标重力 |
| `sm_noclip <玩家>` | f+n | 切换目标穿墙模式 |
| `sm_timebomb <玩家> [时长]` | f | 在目标身上装定时炸弹 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_beacon_radius` | 375 | `sm_beacon` 光圈半径 |
| `sm_burn_duration` | 20.0 | `sm_burn` 与燃烧炸弹默认时长 |
| `sm_firebomb_mode` | 0 | 燃烧炸弹目标:0 = 仅目标,1 = 目标队伍,2 = 所有人 |
| `sm_firebomb_radius` | 600 | 燃烧炸弹爆炸半径 |
| `sm_firebomb_ticks` | 10.0 | 燃烧炸弹引信时长 |
| `sm_freeze_duration` | 10.0 | `sm_freeze` 与冰冻炸弹默认时长 |
| `sm_freezebomb_mode` | 0 | 冰冻炸弹目标范围(同上) |
| `sm_freezebomb_radius` | 600 | 冰冻炸弹爆炸半径 |
| `sm_freezebomb_ticks` | 10.0 | 冰冻炸弹引信时长 |
| `sm_timebomb_mode` | 0 | 定时炸弹目标范围(同上) |
| `sm_timebomb_radius` | 600 | 定时炸弹爆炸半径 |
| `sm_timebomb_ticks` | 10.0 | 定时炸弹引信时长 |

### `funvotes` — 娱乐投票

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_votealltalk` | k | 全员语音投票 |
| `sm_voteburn` | k+f | 烧人投票 |
| `sm_voteff` | k | 友军伤害开关投票 |
| `sm_votegravity` | k | 重力修改投票 |
| `sm_voteslay` | k+f | 处死投票 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_vote_alltalk` / `sm_vote_burn` / `sm_vote_ff` / `sm_vote_gravity` / `sm_vote_slay` | 0.60 | 各投票通过所需票数比例 |
| `sm_vote_show` | 1 | 是否显示各玩家选择 |

### `mapchooser` — 结束换图投票

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_mapvote` | g | 立即发起换图投票 |
| `sm_setnextmap <地图>` | g | 直接设置下一张地图 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_mapvote_endvote` | 1 | 是否在回合结束时发起换图投票 |
| `sm_mapvote_start` | 3.0 | 剩余多少分钟时发起投票 |
| `sm_mapvote_startfrags` | 5.0 | 剩余多少击杀时发起投票 |
| `sm_mapvote_startround` | 2.0 | 剩余多少回合时发起投票(回合制地图设 0) |
| `sm_mapvote_voteduration` | 20 | 投票持续时间(秒) |
| `sm_mapvote_exclude` | 5 | 排除最近多少张已玩地图 |
| `sm_mapvote_include` | 5 | 投票中列入多少张地图 |
| `sm_mapvote_extend` | 0 | 每张图允许延长次数 |
| `sm_mapvote_dontchange` | 1 | 是否加入"不换图"选项 |
| `sm_mapvote_novote` | 1 | 无人投票时是否自动选图 |
| `sm_mapvote_runoff` | 0 | 是否举行决选投票 |
| `sm_mapvote_runoffpercent` | 50 | 得票低于该百分比时举行决选 |
| `sm_mapvote_persistentmaps` | 0 | 是否持久化保存已玩地图记录 |
| `sm_extendmap_timestep` | 15 | 每次延长增加的分钟数 |
| `sm_extendmap_roundstep` | 5 | 每次延长增加的回合数 |
| `sm_extendmap_fragstep` | 10 | 每次延长增加的击杀数 |

> 本服务器在 `OnConfigsExecuted` 中强制 `sm_mapvote_endvote 0`,避免结束换图投票覆盖 `sm_nextmap`。

### `nominations` — 地图提名

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_nominate [地图]` | — | 提名地图;不带参数时打开提名菜单 |
| `sm_nominate_addmap <地图>` | g | 直接加入提名列表 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_nominate_excludecurrent` | 1 | 提名列表排除当前地图 |
| `sm_nominate_excludeold` | 1 | 排除 mapchooser 已排除的旧地图 |
| `sm_nominate_maxfound` | 0 | 最多加入几个匹配结果(0 = 不限) |

### `playercommands`
| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_slap <玩家> [伤害]` | f | 抽打目标 |
| `sm_slay <玩家>` | f | 处死目标 |
| `sm_rename <玩家> <新名字>` | f | 改名 |

### `reservedslots` — 预留通道

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_reserve_type` | 0 | 预留方式 |
| `sm_reserved_slots` | 0 | 预留玩家槽位数 |
| `sm_hide_slots` | 0 | 是否从最大人数中隐藏预留槽 |
| `sm_reserve_maxadmins` | 1 | 预留方式 2 下最多放行几名管理员 |
| `sm_reserve_kicktype` | 0 | 需要腾位时选择踢谁 |

### `rockthevote` — RTV 换图

| 命令 | 说明 |
|---|---|
| `sm_rtv` | 投票换图 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_rtv_initialdelay` | 30.0 | 开图后多少秒起允许 RTV |
| `sm_rtv_interval` | 240.0 | RTV 失败后再次发起的间隔(秒) |
| `sm_rtv_needed` | 0.60 | 通过所需的玩家比例 |
| `sm_rtv_minplayers` | 0 | 启用 RTV 所需的最少玩家数 |
| `sm_rtv_changetime` | 0 | 通过后何时换图(0 = 立即,1 = 回合结束) |
| `sm_rtv_postvoteaction` | 0 | 地图投票完成后如何处理 RTV(0 = 允许) |

### `sounds`
| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_play <玩家> <声音文件>` | b | 给玩家播放声音 |

### `sql-admin-manager` — SQL 管理员管理

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_sql_addadmin <名称> <授权> <等级/标志>` | z | 新增管理员 |
| `sm_sql_addgroup <组名> <等级>` | z | 新增权限组 |
| `sm_sql_deladmin <名称>` | z | 删除管理员 |
| `sm_sql_delgroup <组名>` | z | 删除权限组 |
| `sm_sql_setadmingroups <名称> <组...>` | z | 设置管理员的所属组 |
| `sm_create_adm_tables` | z | 创建管理员数据表 |
| `sm_update_adm_tables` | z | 更新管理员数据表结构 |

### `teamjoinblocker` — 换边封锁

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_toggle_join` | c | 开关换边封锁 |
| `sm_a` | c | 同上(快捷别名) |

挂 `jointeam` 监听,封锁期间拒绝玩家换边。

---


## 四、独立插件

### `tau_mp.smx` — 单人战役 tau 改造

让单人战役里的 tau 炮拥有多人模式的**高斯跳**与**右键无冷却**,并把**跌落伤害封顶**。
做法是在 gamedata 签名定位到的两处 `je` 指令上就地改内存(`NOP`),让引擎自己走多人代码路径 ——
不重写物理,不改 cfg,插件卸载时还原原字节。

| ConVar | 默认 | 说明 |
|---|---|---|
| `tau_mp_enable` | 1 | 总开关 |
| `tau_mp_hook` | 1 | 两条代码补丁的总开关 |
| `tau_mp_gaussjump` | 1 | 补 `FireBeam`:保留垂直击退 = 高斯跳 |
| `tau_mp_nocooldown` | 1 | 补 `ChargeFire`:副攻无冷却 |
| `tau_mp_values` | 1 | 把 tau 参数 ConVar 钉成多人数值 |
| `tau_mp_falldamage` | 1 | 启用跌落伤害封顶 |
| `tau_mp_falldamage_hp` | 10.0 | 跌落伤害上限:一次摔落**最多**扣这么多血(轻摔不会被抬到该值) |
| `tau_mp_damagelog` | 0 | 诊断开关:把摔伤与致死伤害写进 SM 日志 |

改动 ConVar 会立即生效(还原/重打补丁),无需重启或改 cfg。
相关逆向见 `smx_analysis/REVERSE_TAU.md`。

### `hl1tau.smx` — HL1 高斯枪还原

把 tau 炮的溅射半径还原成 HL1 的值。

| ConVar | 默认 | 说明 |
|---|---|---|
| `hl1tau_enable` | 1 | 启用溅射半径还原(0 = 用 BM 原生的固定半径) |
| `hl1tau_penetration` | 1 | 还原 HL1 穿墙阈值(穿透深度 = 当前蓄力伤害) |
| `hl1tau_splash_scale` | 2.5 | 溅射半径 = 蓄力伤害 × 该倍率(HL1 单人 2.5,多人 1.75) |

### `spawn_marker.smx` — 复活点标记(**默认停用**)

训练用工具:在 `player_spawn` 时标记真实落点。

| 命令 | 权限 | 说明 |
|---|---|---|
| `sm_spawnmarker` | b | 开关复活点标记 |
| `sm_spawnmap` | b | 开关全图复活点常显 |
| `sm_sm` | b | 快捷别名 |

| ConVar | 默认 | 说明 |
|---|---|---|
| `sm_spawnmarker_enabled` | 0 | 启用敌方复活点标记(0 = 关) |
| `sm_spawnmarker_life` | 5.0 | 标记存在时长(秒) |
| `sm_spawnmarker_spawnmap` | 0 | 持续显示所有死亡竞赛复活点 |

### 第三方插件(无源码)

| 插件 | 作用 |
|---|---|
| `bms_rpgReloadFix.smx` | RPG 换弹动画修复 |
| `bms_weapon_tauStuckFix.smx` | tau 低弹药卡枪修复:右键按下第一 tick 且手持 `weapon_tau` 时把备用弹药补到 3 |
| `is_weaponfx.smx` | 武器动画预热:玩家入服后假连 `is_weaponfix_saddr` 预缓存动画再重连(需在 `server.cfg` 显式设该地址,默认值会被视为"未配置"而自我禁用) |

### 未编入 BMAG 的模块

`basebans`、`nextmap`、`randomcycle`、`spawn_cap` 的源码保留在 `smx_analysis/src/scripting/plugins/`,
但**不在 `merge.py` 的 MODULES 列表中,不会编译进 `BMAG.smx`**(功能已被 `bms_match` / `spawn_distribute` 取代)。
对应 smx 放在 `plugins/disabled/`。

> **SourceBans++ 已移除(2026-10-04)**:`sbpp_*` 六个模块连同 `configs/sourcebans/` 和 `sourcebanspp.inc`
> / `sourcecomms.inc` 一起从仓库删除,`BMAG.smx` 已重编译。**因此 BMAG 现在不再提供任何封禁命令**
> (`sm_ban` / `sm_addban` / `sm_unban` / `sm_banip` 全部消失);禁言禁麦不受影响,仍由 `basecomm` 提供。
> `basevotes` 的 `sm_voteban` 也还在,但它改走 SourceMod 核心的本地封禁(写进服务器自己的封禁名单),
> 不再进 SourceBans 数据库。
> 需要本地封禁命令的话,启用 `plugins/disabled/basebans.smx` 即可 —— 它是独立插件,不需要数据库。

---

## 五、从源码构建

```bash
cd smx_analysis
python merge.py          # 生成 src/scripting/BMAG/BMAG.sp(41 模块合并)
```

然后用 spcomp 编译(编译器不入库,放在被忽略的 `dl/sm-win/` 下):

```bash
./dl/sm-win/addons/sourcemod/scripting/spcomp.exe \
  -i "src/scripting/include" \
  -o "src/scripting/BMAG/BMAG.smx" \
  "src/scripting/BMAG/BMAG.sp"
```

基线:**50 个警告、0 个错误**。

`merge.py` 只桥接**精确的** SourceMod forward 名,`bms_match` 用自己的 `Bms_` 前缀实现生命周期回调,
靠 `FORWARD_ALIASES` 映射回标准名 —— 改动 forward 命名时务必同步该表,否则回调会静默失效。

**注意事项**:

- spcomp 输出**不是字节可复现的**(内嵌路径/时间戳/哈希表序),判断新旧请以功能验证或日志为准,不要比对 MD5
- 编译用的 `include/` 必须与生产服务器一致:旧版 `sourcemod.inc` 的 `StoreToAddress` 只有 3 个参数,会编译报错
- `tau_mp` 的签名**必须抗重定位** —— `GameConfGetAddress` 扫的是已加载内存,含绝对地址(`imm32`)的签名会因 base relocation 在运行时失配(磁盘命中、内存不命中,静默不生效)。用 `smx_analysis/sig_check.py` 校验

---

## 六、已知问题

- **启动间歇卡死**:Steam 客户端注入的 `crashhandler.dll` 与加载器竞态,约一半概率卡在进程早期(35MB、无端口)。**没有稳的根治办法,用外部脚本兜底** —— 检测 27015 端口,没起来就杀掉进程重启;退出 Steam 后启动大概率一次成功。
- **关窗时退出码 -1073740791**:服务器已走完干净关机(日志已落盘),随后 Steam 的 crashhandler 在清理阶段 fail-fast —— 无害,可忽略。
- **`Unknown command heartbeat`**:Black Mesa 引擎在 `mp_restartgame` 时自发执行 GoldSrc 遗留命令产生的噪音,无害。
- **`plugins/` 中 2022 年的逐插件 smx 已过时**:当前部署的是合并后的 `BMAG.smx`,旧文件仅作参照,不要同时加载。
- **`configs/admins.cfg` 里的 SteamID 是占位值**,部署前必须换成真实 SteamID。
