# Black Mesa SourceMod 插件集

Black Mesa(黑山起源)的 **SourceMod 插件与配置集合**,整理自一台实际在跑的死亡竞赛服务器。
仓库里装了三块**互不依赖**的内容,可以只取其中一块用:

| 部分 | 内容 | 从哪看 |
|---|---|---|
| **① 死亡竞赛服务器**(主体) | 35 个 SourceMod 模块合并编译成单个 `BMAG.smx`,另有 4 个独立第三方插件单独加载 | [目录结构](#目录结构) · [部署](#部署) · [从源码构建](#五从源码构建) |
| **② 单人战役插件** | 让单人剧情的 tau 炮拿到多人模式能力(`campaign/tau_mp/`)、溅射半径还原 HL1(`campaign/hl1tau/`) | [四、独立插件](#四独立插件) |
| **③ 配置备份** | 服务器 `cfg/`、SourceMod `configs/`、MOTD 页面 | [⚠️ 部署前必改清单](#️-部署前必改清单) |

> **想直接开服** → 先过一遍 [⚠️ 部署前必改清单](#️-部署前必改清单):配置里还带着原服的服务器名、群号、域名和占位 SteamID。
> **想改插件** → [五、从源码构建](#五从源码构建),`merge.py` 把 35 个模块合并成一个 `BMAG.sp` 再交给 spcomp 编译。
> **只想抄某个功能** → [一、`bms_match`](#一bms_match--比赛插件自研) 是自研比赛插件,[二、其它自研模块](#二其它自研--深度改造模块) 列了 9 个深度改造模块。

源码、合并器与逆向笔记全部在本仓库内,可直接重建。

单人战役那两个插件是各自独立的小项目,放在 `campaign/` 下:

| 项目 | 内容 |
|---|---|
| `campaign/tau_mp/` | `plugins/tau_mp.smx`、`tau_mp.sp`、`gamedata/tau_mp.games.txt`、`REVERSE_TAU.md` |
| `campaign/hl1tau/` | `plugins/hl1tau.smx`、`hl1tau.sp` |

本文件中提到这两个插件时,路径都指上面这张表。**唯一不入库**的是 `client_mod/`(自定义准星客户端 mod,已搁置)。

---

## 目录

- [⚠️ 部署前必改清单](#️-部署前必改清单)
- [目录结构](#目录结构)
- [部署](#部署) · [启动](#启动) · [RCON](#rcon)
- [权限标志](#权限标志)
- [一、`bms_match` — 比赛插件(自研)](#一bms_match--比赛插件自研)
- [二、其它自研 / 深度改造模块](#二其它自研--深度改造模块)
- [三、SourceMod 官方模块](#三sourcemod-官方模块)
- [四、独立插件](#四独立插件)
- [五、从源码构建](#五从源码构建)
- [六、已知问题](#六已知问题)

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
| `cfg/server.cfg` | `sv_downloadurl`、`sm_motd_url` | 换成你的域名;**没有 FastDL 就把 `sv_downloadurl` 整行注释掉**(玩家回退 srcds 直传,慢但能连)。`sm_motd_url` 需由插件创建才生效 —— 见[已知问题](#六已知问题) |
| `cfg/server.cfg` | `is_weaponfix_saddr` | 填**外网玩家能连到的**公网 `IP:端口`,不能留 `127.0.0.1`,否则武器动画修复静默失效 |
| `cfg/server.cfg` | `rcon_password` | **该文件里没有这一行**,需自行在启动参数加 `+rcon_password "你的密码"`,且**绝不要提交进 git** |
| `configs/admins.cfg` | `identity`(两条 `STEAM_0:x:1000000xx`) | 换成真实 SteamID,否则你没有任何管理员权限 |
| `configs/databases.cfg` | **本仓库没有这个文件** | 只有 `clientprefs`、SQL 管理员等用到数据库时才需要自建(里面是数据库密码,故意不入库) |
| `configs/advertisements.txt` | 两条 `chat` 文案 | 原服的群号和 B 站账号,换成你的 |
| `smx_analysis/src/scripting/configs/bms_match.cfg` | `SourceTV` → `DownloadBase` | 改成你的地址,或留空 `""`(录像仍会录,只是下载链接不可用) |
| `smx_analysis/src/scripting/cfg/mapcycle_*.txt` | 地图名单 | 删掉你服务器上**没有**的地图,否则换图失败 |
| `motd/index.html` | QQ 群 / B 站 / Discord / 服务器列表 | 每个字符串在**中文 / English / русский 三个语言段各出现一次**,三处都要改 |

**辅助脚本里的路径也是硬编码的**,换机器要改(不改不影响开服,只影响你跑这些脚本):

| 文件 | 硬编码内容 |
|---|---|
| `smx_analysis/watch_launch.ps1` | `F:\BMServer\srcds.exe`、`F:\BMServer\bms\console.log` |
| `smx_analysis/src/scripting/compile_all.sh` | `SPCOMP="/c/tmp/smx_analysis/dl/..."`(该路径在本仓库里**并不存在**,见 [从源码构建](#五从源码构建)) |

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
│   ├── bms_rpgReloadFix.smx      第三方:RPG 换弹修复
│   ├── bms_weapon_tauStuckFix.smx 第三方:tau 低弹药卡枪修复
│   ├── is_weaponfx.smx           第三方:武器动画预热
│   ├── is_bms_fix_timelimit.smx  第三方:回合时限/倒计时修复(bms_match 的计时器沿用同一机制)
│   └── disabled/                 停用插件(basebans、nextmap、randomcycle、spawn_marker、
│                                 classicmovement、sm_realbhop、xms、admin-sql-* 等 9 个)
├── smx_analysis/                 构建流水线与源码
│   ├── merge.py                  把 35 个模块源码合并成 BMAG.sp(唯一的构建入口)
│   ├── fix_merge.py              merge.py 的补丁工具
│   ├── sig_check.py              签名抗重定位校验(见"从源码构建")
│   ├── rcon.py                   RCON 调试客户端(凭据走环境变量)
│   ├── bisect_compile.py         二分定位编译失败的模块
│   ├── bctest.sp                 最小插件骨架,用于冒烟验证编译/加载链路
│   ├── mvf.html / mvf_wb.html    missing_viewmodel_fix 的参考来源抓取
│   │                             (mvf_wb.html 是 AlliedModders 原帖存档;
│   │                              mvf.html 只抓到了 Cloudflare 拦截页,无内容)
│   ├── *.ps1                     启动/崩溃诊断辅助脚本(check_crash、evt、proc、
│   │                             test_launch、watch_launch)
│   ├── REVERSE_*.md              引擎逆向笔记(见下)
│   ├── dl/sm-win/                下载的 SourceMod 工具链(含 spcomp.exe)
│   ├── out/                      逆向与探测过程留下的证据 dump(probe*.txt、
│   │                             crosshair_*、wpn_dump、*_binscan 等)
│   ├── .gitignore                本目录的忽略规则
│   └── src/scripting/
│       ├── plugins/              模块源码 + 未编入 BMAG 的独立插件源码
│       ├── include/              编译用 SourceMod include(与生产服务器版本一致)
│       ├── BMAG/                 merge.py 产物(BMAG.sp 与各模块副本为生成物不入库,BMAG.smx 入库)
│       ├── compile_all.sh        逐个编译 plugins/*.sp 的批处理脚本(路径硬编码,见上)
│       ├── configs/              插件配置(bms_match.cfg、bms_webpanel.html)
│       ├── cfg/                  地图池(mapcycle_*.txt)与比赛用 cfg
│       └── translations/         各插件短语文件(**运行时读取,不编进 BMAG.smx**)
├── campaign/                     单人战役(SP)专用的两个独立小项目
│   ├── tau_mp/                   高斯跳 + 右键无冷却 + 跌落伤害封顶(含 REVERSE_TAU.md)
│   └── hl1tau/                   高斯炮溅射半径还原 HL1
├── bms_match_delivery/           2026-08-23 的旧交付包归档(留档)
├── cfg/                          服务器 cfg/ 备份(server.cfg、autoexec、listenserver、
│                                 banned_*、chapter*.cfg 等)
├── configs/                      SourceMod configs/ 备份(admins、advertisements、
│                                 admin_levels/groups/overrides、maplists、core、geoip 等)
├── motd/                         MOTD 页面
└── README.md
```

`.gitignore` 现在只排除两类东西:`merge.py` 生成的中间产物 `smx_analysis/src/scripting/BMAG/*.sp`
(可由 `merge.py` 重组),以及暂时搁置的自定义准星客户端 mod `client_mod/` 与 `REVERSE_CROSSHAIR.md`。
下载的工具链与证据 dump(`smx_analysis/dl/`、`smx_analysis/out/`)、旧交付包归档 `bms_match_delivery/`
与单人战役的 `campaign/` 均已入库留档。

> **2026-10-04 清理**:2022 年上传的原始逐插件 smx(`plugins/<模块名>.smx`)、已被 `BMAG.smx` 取代的
> 旧版平铺产物(`smx_analysis/plugins/`、`smx_analysis/partial.sp`、`smx_analysis/bctest.smx`)
> 以及与本目录内容重复的 `bms_match_delivery.7z` 已从仓库移除(共 87 个文件 / 约 1.2 MB)。
> 当前构建与部署都不依赖它们:`merge.py` 合并的是 `src/scripting/plugins/` 下的源码,
> `bisect_compile.py` 的 `partial.sp` 是运行时生成而非读取仓库里那份。
> 需要查旧版逐插件产物时,翻 `2026-10-04` 之前的提交历史即可。

### 逆向笔记(`smx_analysis/REVERSE_*.md`)

这些文档记录了本仓库所有非平凡修改所依据的引擎级证据(反汇编地址、签名、调用链),**改动相关代码前请先读**:

| 文件 | 内容 |
|---|---|
| `REVERSE_RESPAWN.md` | 死亡竞赛重生机制、复活点选择为何失效 |
| `REVERSE_TIMER.md` | 回合计时器与 `mp_restartgame` 通道 |
| `REVERSE_VGUI.md` | VGUIMenu 面板与无线电菜单 |
| `REVERSE_WALLPEN.md` | 弹道穿墙与玻璃穿透 |

> `REVERSE_TAU.md`(tau 炮单人/多人分支、高斯跳、跌落伤害链路)属单人战役部分,
> 已随 `tau_mp` 一起移到 `campaign/tau_mp/`。

---

## 部署

服务器是 steamcmd 安装的 srcds,根目录记为 `%SRV%`(即含 `srcds.exe` 的那一层)。
把对应文件复制进去即可:

```bat
set SRV=<你的 srcds 根目录>
copy /Y plugins\BMAG.smx            %SRV%\bms\addons\sourcemod\plugins\
copy /Y plugins\bms_rpgReloadFix.smx       %SRV%\bms\addons\sourcemod\plugins\
copy /Y plugins\bms_weapon_tauStuckFix.smx %SRV%\bms\addons\sourcemod\plugins\
copy /Y plugins\is_weaponfx.smx            %SRV%\bms\addons\sourcemod\plugins\
copy /Y plugins\is_bms_fix_timelimit.smx   %SRV%\bms\addons\sourcemod\plugins\
copy /Y smx_analysis\src\scripting\translations\*.txt %SRV%\bms\addons\sourcemod\translations\
copy /Y smx_analysis\src\scripting\configs\bms_match.cfg %SRV%\bms\addons\sourcemod\configs\
copy /Y smx_analysis\src\scripting\cfg\*.txt             %SRV%\bms\cfg\
copy /Y smx_analysis\src\scripting\cfg\*.cfg             %SRV%\bms\cfg\
```

> 除 `BMAG.smx` 外的四个 `.smx` 是**独立第三方插件,不在 BMAG 里,必须单独拷**(清单见
> [四、独立插件](#四独立插件))。其中 `is_weaponfx.smx` 还需在 `server.cfg` 里显式设
> `is_weaponfix_saddr`(默认值会被当成"未配置"而自我禁用);`is_bms_fix_timelimit.smx`
> 负责让 `mp_timelimit` 在新地图加载后仍能生效 —— 漏了它,非比赛期间的回合时限就不对。

> `translations\*.txt` 那行别漏:**这三份短语文件是运行时读取的,不编进 `BMAG.smx`**
> (`bms_match.phrases.txt`、`fast_spawn.phrases.txt`、`spawn_marker.phrases.txt`)。
> 漏了的话聊天框里所有 `[比赛]` 提示都会显示成短语键名。改文案(不动代码)
> 只需重传这三个文件 + 换图或 `sm plugins reload BMAG`,不必重新编译。

> **另:SourceMod 全新安装自带的 `plugins/nextmap.smx` 要停用**(移到 `plugins/disabled/`)。
> 本服换图由 `bms_match` 的投票 + 核心的 `sm_nextmap` 决定;nextmap 插件会按 `mapcyclefile`
> 自动推进 `sm_nextmap`,和投票结果打架。仓库里那份就在 `plugins/disabled/nextmap.smx`。
> (注:`SetNextMap` / `GetNextMap` 是 **SourceMod 核心**提供的 native,不是 nextmap.smx ——
> 所以停用它**不会**让 BMAG 加载失败。)

单人战役环境是另一套 `addons/sourcemod`(Steam 客户端目录下的 Black Mesa),
需要的是 `tau_mp.smx` + `hl1tau.smx` + `tau_mp.games.txt` —— 这三样属单人战役专用,
放在本仓库 `campaign/` 下。

复制后重启服务器,或在服务器控制台执行 `sm plugins reload BMAG`。
**新增**的独立插件(如 `is_bms_fix_timelimit`)SourceMod 只在地图切换时才自动加载,
要么换一次图,要么控制台 `sm plugins load is_bms_fix_timelimit`。

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

> `o`–`t` 是留给自定义权限用的空位,本仓库未占用。

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

地图池文件放在 `bms/cfg/` 下,由各模式的 `Mapcycle` 键引用。`ffa` 与 `tdm` 各 12 张官方 DM 图,
两份名单当前完全相同:
`dm_boom`、`dm_bounce`、`dm_chopper`、`dm_crossfire`、`dm_gasworks`、`dm_lambdabunker`、
`dm_power`、`dm_rail`、`dm_stack`、`dm_stalkyard`、`dm_subtransit`、`dm_undertow`。

---

## 二、其它自研 / 深度改造模块

以下 9 个模块都**编译在 `BMAG.smx` 内部**(见 [五、从源码构建](#五从源码构建)),不能单独加载。
`spawn_distribute`、`textmsg_fix` 为自研;其余基于 AlliedModders 社区插件,按本服需要做过适配或实质改造
(`fast_spawn`、`speclist` 源自 Alienmario,`SpecDetails` 源自 wribit,`missing_viewmodel_fix` 源自 ch4os + SHUFEN,
`advertisements` 源自 Tsunami;各文件头部保留原作者声明)。

| 模块 | 一句话 | 详见 |
|---|---|---|
| `fast_spawn` | 零秒重生,不等原生按键或 5 秒 `mp_forcerespawn` | 下节 |
| `spawn_distribute` | 复活点均匀分配,修原生同点堆人 | 下节 |
| `textmsg_fix` | CP936 下 UTF-8 中文消息导致的 `_vsnprintf` 崩溃 | 下节 |
| `adv-weapon_cleaner` | 掉落武器清扫 | 下节 |
| `SpecDetails` | 观察者详情 | 下节 |
| `speclist` | 观战者列表 | 下节 |
| `missing_viewmodel_fix` | 切队/切观察后重建 viewmodel | 下节 |
| `advertisements` | 轮播广告 | 下节 |
| `sm_noearbleed` | 去掉爆炸耳鸣/压耳声 | 下节 |

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

> 本服 `cfg/server.cfg` 里显式设了 `sm_fastspawn 1` + `sm_fastspawn_time 0.0`(即最激进档)。

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
参考来源存档在 `smx_analysis/mvf_wb.html`(AlliedModders 原帖)。

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

> 本服 `cfg/server.cfg` 里把 `sm_advertisements_interval` 改成了 **600**(10 分钟一条),
> 不是上面表里的插件默认值 30。

### `sm_noearbleed` — 去除耳鸣/压耳声

无命令,仅 `sm_noearbleed_version`。挂 `OnTakeDamage` 把 `DMG_BLAST` 改成 `DMG_GENERIC` 以去掉爆炸耳鸣效果(不改伤害数值)。

---

## 三、SourceMod 官方模块

下面 25 个模块绝大多数是 SourceMod 自带的官方插件(少数为社区插件,如 `connectmessage`、
`showhealth`、`teamjoinblocker`),同样**都编译在 `BMAG.smx` 内部**,不能单独加载。

它们的**命令与 ConVar 全部是 SourceMod 上游默认值**。本服 `cfg/server.cfg` 里针对插件 ConVar
只额外设了 `sm_fastspawn`、`sm_fastspawn_time`、`sm_advertisements_interval` 三项,且都属
[第二节](#二其它自研--深度改造模块)的模块(另有几条没有任何模块提供的设置,见[已知问题](#六已知问题)),
所以这里不再逐条抄表 —— 要查某个命令属于哪个模块、什么权限、什么默认值,
直接看 `smx_analysis/src/scripting/plugins/<模块>.sp`,或 SourceMod 官方 wiki。
下表只列**模块作用**与**本服的偏离点**。

| 模块 | 作用 | 本服注意 |
|---|---|---|
| `admin-flatfile` | 从 `configs/admins.cfg` / `admin_groups.cfg` / `admin_overrides.cfg` 读管理员 | 本服**唯一**的管理员来源(不用 SQL) |
| `admincheats` | `sm_admin_cheats_level` 控制执行作弊命令所需权限 | |
| `adminhelp` | `sm_help` / `sm_searchcmd` 查命令 | |
| `adminmenu` | `sm_admin` 打开管理员菜单 | |
| `antiflood` | 聊天刷屏限制(`sm_flood_time`) | |
| `basechat` | 管理员聊天命令(`sm_say` / `sm_csay` / `sm_hsay` / `sm_msay` / `sm_tsay` / `sm_chat` / `sm_psay`) | 本服多处 `sm_say` 用来在开服时播报设置 |
| `basecomm` | 禁言/禁麦(`sm_gag` / `sm_mute` / `sm_silence` 及解除) | **SourceBans 移除后,禁言禁麦仍由它提供,不受影响** |
| `basecommands` | 基础管理命令(`sm_kick` / `sm_map` / `sm_rcon` / `sm_cvar` / `sm_execcfg` / `sm_cancelvote` / `sm_who` / `sm_reloadadmins` 等) | `rcon_password` 被本模块保护,禁止通过 `sm_cvar` 读取 |
| `basetriggers` | 聊天触发词(`timeleft` / `nextmap` / `motd` / `ff`) | |
| `basevotes` | 投票(`sm_vote` / `sm_voteban` / `sm_votekick` / `sm_votemap`) | `sm_voteban` 已改走 SourceMod 核心的**本地封禁**(写服务器自己的封禁名单),不再进 SourceBans 数据库 |
| `clientprefs` | 客户端 cookie(`sm_cookies` / `sm_settings`) | 需要数据库才会持久化(见 `configs/databases.cfg`) |
| `connectmessage` | 玩家加入/离开时聊天框提示 | 社区插件 |
| `funcommands` | 娱乐命令(`sm_beacon` / `sm_blind` / `sm_burn` / `sm_drug` / `sm_freeze` / `sm_gravity` / `sm_noclip` / 各种炸弹) | |
| `funvotes` | 娱乐投票(`sm_votealltalk` / `sm_voteburn` / `sm_voteff` / `sm_votegravity` / `sm_voteslay`) | |
| `mapchooser` | 结束换图投票、`sm_setnextmap` | **本服在 `OnConfigsExecuted` 里强制 `sm_mapvote_endvote 0`**,避免结束换图投票覆盖 `sm_nextmap` |
| `motd-fixer` | 延时打开 MOTD(引擎自带 MOTD 触发有时序问题) | 社区插件 |
| `nominations` | 地图提名(`sm_nominate`) | |
| `pause` | 暂停/继续服务器(`sm_pause` / `sm_unpause` / `sm_setpause`) | 聊天里的 `!pause` / `!unpause` 由 `bms_match` 接管,两者不要混用 |
| `playercommands` | `sm_slap` / `sm_slay` / `sm_rename` | |
| `reservedslots` | 预留通道(`sm_reserve_*` / `sm_hide_slots`) | 本服 `maxplayers 8`,`sm_reserved_slots` 为 0(未启用预留) |
| `rockthevote` | RTV 换图(`sm_rtv`) | |
| `showhealth` | 屏幕上显示血量 | 社区插件 |
| `sounds` | `sm_play` 播放声音 | |
| `sql-admin-manager` | SQL 管理员增删改(`sm_sql_*`) | 本服管理员走 `admin-flatfile`,这些命令是备用 |
| `teamjoinblocker` | 换边封锁(`sm_toggle_join` / `sm_a`) | 社区插件 |

---

## 四、独立插件

### 单人战役插件(独立小项目)

tau 炮在单人战役里是"阉割版":没有高斯跳、副攻有硬直 —— 这两条分支写死在 `server.dll` 里
(按 `IsMultiplayer()` 判),纯 ConVar 改不出来。两个插件各自独立,只服务单机剧情,
放在本仓库 `campaign/` 下:

| 项目 | 做什么 |
|---|---|
| `campaign/tau_mp/` | 让单人 tau 拥有多人模式的**高斯跳**与**右键无冷却**(在两处 `je` 指令上就地 `NOP`、卸载时还原原字节),并把**跌落伤害封顶**在 10 HP |
| `campaign/hl1tau/` | 把 tau 的溅射半径还原成 HL1 的值 |

`campaign/tau_mp/` 里另有签名文件 `gamedata/tau_mp.games.txt` 与逆向笔记 `REVERSE_TAU.md`。

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
| `is_bms_fix_timelimit.smx` | 回合时限/倒计时修复(BM 只在地图加载时读一次 `mp_timelimit`,运行期 `SetInt` 无效;它走 `mp_round_time` 实体的加时输入 —— `bms_match` 的计时器沿用同一机制) |

### 未编入 BMAG 的模块

以下 7 个模块的源码保留在 `smx_analysis/src/scripting/plugins/`,但**不在 `merge.py` 的
MODULES 列表中,不会编译进 `BMAG.smx`**:

| 模块 | 为什么不在 BMAG 里 |
|---|---|
| `basebans` | 封禁命令(本地封禁,不依赖数据库);需要时启用 `plugins/disabled/basebans.smx` |
| `nextmap` | 换图由 `bms_match` 的投票 + SourceMod 核心的 `sm_nextmap` 负责 |
| `randomcycle` | 同上,随机换图走 `bms_match` 的 `!runrandom` |
| `spawn_cap` | 功能已被 `spawn_distribute` 取代(且原版会踢 bot) |
| `spawn_marker` | 训练用工具,见上一节;默认停用 |
| `admin-sql-prefetch` | SQL 管理员预取;本服管理员走 `admin-flatfile` |
| `admin-sql-threaded` | SQL 管理员;同上 |

`plugins/disabled/` 里还有几个连源码都没有的: `classicmovement`(经典移动)、
`sm_realbhop`(真 bhop)、`xms`(hl2dm 的比赛插件,`bms_match` 的参考实现)。

> **SourceBans++ 已移除(2026-10-04)**:`sbpp_*` 六个模块连同 `configs/sourcebans/` 和 `sourcebanspp.inc`
> / `sourcecomms.inc` 一起从仓库删除,`BMAG.smx` 已重编译(41 → 35 个模块)。
> **因此 BMAG 现在不再提供任何封禁命令**
> (`sm_ban` / `sm_addban` / `sm_unban` / `sm_banip` 全部消失);禁言禁麦不受影响,仍由 `basecomm` 提供。
> `basevotes` 的 `sm_voteban` 也还在,但它改走 SourceMod 核心的本地封禁(写进服务器自己的封禁名单),
> 不再进 SourceBans 数据库。
> 需要本地封禁命令的话,启用 `plugins/disabled/basebans.smx` 即可 —— 它是独立插件,不需要数据库。

---

## 五、从源码构建

```bash
cd smx_analysis
python merge.py          # 生成 src/scripting/BMAG/BMAG.sp(35 模块合并)
```

然后用 spcomp 编译(编译器随仓库放在 `dl/sm-win/` 下):

```bash
./dl/sm-win/addons/sourcemod/scripting/spcomp.exe \
  -i "src/scripting/include" \
  -o "src/scripting/BMAG/BMAG.smx" \
  "src/scripting/BMAG/BMAG.sp"
```

基线:**48 个警告、0 个错误**(删掉 SourceBans++ 之前是 50)。
这套命令已于 2026-10-04 在本仓库复跑验证过,警告数与上述基线一致。

> `src/scripting/compile_all.sh` 是构建者留下的"逐个编译 `plugins/*.sp`"批处理脚本,
> 里面的 `SPCOMP` 路径硬编码成 `/c/tmp/smx_analysis/...`,**在本仓库里并不存在**,
> 直接跑会全部失败 —— 要批量编单个插件,把那一行改成 `smx_analysis/dl/...` 的真实路径即可。
> 合并构建走上面的 `merge.py`,不依赖这个脚本。

`merge.py` 只桥接**精确的** SourceMod forward 名,`bms_match` 用自己的 `Bms_` 前缀实现生命周期回调,
靠 `FORWARD_ALIASES` 映射回标准名 —— 改动 forward 命名时务必同步该表,否则回调会静默失效。

**注意事项**:

- spcomp 输出**不是字节可复现的**(内嵌路径/时间戳/哈希表序),判断新旧请以功能验证或日志为准,不要比对 MD5
- 编译用的 `include/` 必须与生产服务器一致:旧版 `sourcemod.inc` 的 `StoreToAddress` 只有 3 个参数,会编译报错
- **签名必须抗重定位** —— `GameConfGetAddress` 扫的是已加载内存,含绝对地址(`imm32`)的签名会因 base relocation 在运行时失配(磁盘命中、内存不命中,静默不生效)。用 `smx_analysis/sig_check.py` 校验(结论出自单人战役 `tau_mp` 的签名,该插件在 `campaign/tau_mp/`)
- 单人战役那两个插件的源码在 `campaign/` 里(不在 `src/scripting/plugins/`),因此 `merge.py` 和上面的编译命令都不涉及它们;单独编译见 `campaign/` 里各自的源码

---

## 六、已知问题

- **启动间歇卡死**:Steam 客户端注入的 `crashhandler.dll` 与加载器竞态,约一半概率卡在进程早期(35MB、无端口)。**没有稳的根治办法,用外部脚本兜底** —— 检测 27015 端口,没起来就杀掉进程重启;退出 Steam 后启动大概率一次成功。
- **关窗时退出码 -1073740791**:服务器已走完干净关机(日志已落盘),随后 Steam 的 crashhandler 在清理阶段 fail-fast —— 无害,可忽略。
- **`Unknown command heartbeat`**:Black Mesa 引擎在 `mp_restartgame` 时自发执行 GoldSrc 遗留命令产生的噪音,无害。
- **`cfg/server.cfg` 里有 3 条没有任何模块提供的设置**:`sm_blockcommand "spec_mode 7"`、`sm_downloader_enabled "1"`、`sm_motd_url "..."` —— 全仓库(连自带的 SourceMod 官方包 `smx_analysis/dl/`)都搜不到创建它们的代码,应是原服插件集里没随仓库一起归档的那部分留下的。
  - 前两条会在开服日志里报 `Unknown command`,**不影响运行**,可删可留。
  - `sm_motd_url` 稍特殊:`motd-fixer` 会用 `FindConVar` 读它,但读不到就回退到 `cfg/motd.txt`、再回退到默认 MOTD 面板(见 `plugins/motd-fixer.sp` 的 `OpenMOTD()`)。所以**在你装上创建该 cvar 的插件之前,改它不会生效**,MOTD 实际走的是 `cfg/motd.txt`。
- **`configs/admins.cfg` 里的 SteamID 是占位值**,部署前必须换成真实 SteamID。
