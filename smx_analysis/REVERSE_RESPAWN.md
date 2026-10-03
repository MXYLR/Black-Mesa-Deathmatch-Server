# BM 死亡重生机制研究 (HL2DM vs Black Mesa Deathmatch)

> 结论先行:**Black Mesa Deathmatch 的重生机制与 HL2DM (hl2mp) 是同一套代码**。
> BMS 基于 2018 版 Source 引擎的 `hl2mp` 分支 (见 `C:/tmp/se2018_hl2/game/*/hl2mp`)，
> 重生逻辑与官方 SDK2013 的 `hl2mp` 逐行等价。唯一实质差异在 **bot** (见 §5)。
> 本项目的 `fast_spawn` / `bms_match` 插件是在这条原生链之上用 SourceMod 强行覆盖重生时序。

---

## 1. 完整链路总览

```
击杀 → Event_Killed()           player.cpp:1299(hl2mp)/1222(se2018)
        ├─ CreateRagdollEntity()  (hl2mp_ragdoll 实体, 非客户端 ragdoll)
        └─ CBasePlayer::Event_Killed()
              └─ m_flDeathTime = gpGlobals->curtime   player.cpp:1746
              └─ m_lifeState = LIFE_DYING

死亡状态机 → CBasePlayer::PlayerDeathThink()          player.cpp:2093  (每 0.1s tick)
        LIFE_DYING   : 死亡动画 ≤ 60 帧(≈1s) → LIFE_DEAD
        LIFE_DEAD    : 等所有按键松开 → FPlayerCanRespawn()==true → LIFE_RESPAWNABLE
        +3s(DEATH_ANIMATION_TIME) → StartObserverMode(死亡镜头)
                        ↑ 但 hl2mp 有 m_bEnterObserver 门, 死亡超时**不进**观察者
        重生触发 : 任意按键按下  **或**  mp_forcerespawn>0 && curtime > m_flDeathTime+5s

重生 → respawn(this, !IsObserver())                   hl2_client.cpp:127
        └─ (deathmatch) pEdict->Spawn()
              ├─ g_pGameRules->GetPlayerSpawnSpot(this)   player.cpp:5097
              │     └─ EntSelectSpawnPoint() 随机挑 info_player_deathmatch
              ├─ StopObserverMode()  (若 team != SPECTATOR)
              └─ g_pGameRules->PlayerSpawn(this)
```

---

## 2. 死亡状态机 (DeathThink) 逐行

`CBasePlayer::PlayerDeathThink` (SDK2013 `src/game/server/player.cpp:2093`):

| 阶段 | 条件 | 动作 |
|---|---|---|
| 死亡动画 | `m_lifeState == LIFE_DYING` | `StudioFrameAdvance()` + `m_iRespawnFrames++`; `<60` 帧直接 return (约 1 秒) |
| 转入死透 | 动画结束 | `m_lifeState = LIFE_DEAD`, `m_flDeathAnimTime = curtime` |
| 等待按键松开 | `LIFE_DEAD` 且 `fAnyButtonDown` | return (必须等玩家松开按键) |
| 可重生 | `FPlayerCanRespawn(this)` | `m_lifeState = LIFE_RESPAWNABLE` (multiplay 恒返回 true, 见 §7) |
| 死亡镜头 | `curtime > m_flDeathTime + 3s` 且 `!IsObserver()` | `StartObserverMode(m_iObserverLastMode)` |
| **重生触发** | 任意按键 **或** `mp_forcerespawn>0 && curtime > m_flDeathTime+5s` | `respawn(this, !IsObserver())` |

**关键常量 / cvar:**

```cpp
// baseplayer_shared.h:33
#define DEATH_ANIMATION_TIME    3.0f   // 死亡镜头超时, 但 hl2mp 被 m_bEnterObserver 门挡掉
// game.cpp:36
ConVar forcerespawn( "mp_forcerespawn", "1", FCVAR_NOTIFY );  // 默认 5s 强逼重生
```

**hl2mp 的覆盖** (`hl2mp_player.cpp:632`, se2018 同):

```cpp
void CHL2MP_Player::PlayerDeathThink()
{
    if( !IsObserver() )
    {
        BaseClass::PlayerDeathThink();
    }
}
```

即:**一旦玩家进入观察者模式, 原生的按键/5s 重生逻辑就不再运行**。观察者模式下重生走另一条路 (见 §3)。

---

## 3. 观察者模式门控 (hl2mp 特有)

`CHL2MP_Player::StartObserverMode` (`hl2mp_player.cpp:1628`, se2018 `1551`):

```cpp
bool CHL2MP_Player::StartObserverMode(int mode)
{
    // we only want to go into observer mode if the player asked to, not on a death timeout
    if ( m_bEnterObserver == true )
    {
        VPhysicsDestroyObject();
        return BaseClass::StartObserverMode( mode );
    }
    return false;
}
```

`m_bEnterObserver` 只在 `State_Enter_OBSERVER_MODE()` 里被置 `true` (`hl2mp_player.cpp:1655`),
也就是玩家**主动**观战 (`spectate` 命令 / `jointeam 1`) 时才进观察者。

**推论 (对本项目很关键):**
- 玩家被击杀后**不会**自动进死亡镜头观察者 (base 的 `+3s StartObserverMode` 被此门挡掉)。
- 玩家保持 `LIFE_RESPAWNABLE`, 靠 **按键或 5s forcerespawn** 重生。
- 主动观战 = `ChangeTeam(TEAM_SPECTATOR)` + `StartObserverMode(OBS_MODE_ROAMING)`
  (见 `player.cpp:6579` 附近 `spectate` 命令处理), 走 `mp_allowspectators` 门控。

`OBS_MODE` 枚举 (`shareddefs.h:493`):

| 值 | 名称 | 含义 |
|---|---|---|
| 0 | NONE | 非观察 |
| 1 | DEATHCAM | 死亡镜头 (瞬态) |
| 2 | FREEZECAM | 冻结帧 (瞬态) |
| 3 | FIXED | 固定机位 (主动观战) |
| 4 | IN_EYE | 第一人称跟随 |
| 5 | CHASE | 第三人称跟随 |
| 6 | POI | PASSTIME 兴趣点 |
| 7 | ROAMING | 自由漫游 |

`fast_spawn` 的 `FS_IsRespawnEligible` 正是用 `m_iObserverMode >= 3` 判定"主动观战", 不拉回比赛。

---

## 4. 出生点选择 (SpawnSpot)

`CBasePlayer::EntSelectSpawnPoint` (`player.cpp:4924`) — deathmatch 分支:

1. 从 `g_pLastSpawn` 起随机前跳 1~5 步 `info_player_deathmatch` 实体。
2. 循环检查 `g_pGameRules->IsSpawnPointValid(pSpot, this)` (排除被占/被挡的点)。
3. 全部无效时: 对第一个出生点 128 半径内的其他玩家 `TakeDamage(300)` 清场, 强制占点。

`CBasePlayer::Spawn` (`player.cpp:5028`) 关键顺序:
`SharedSpawn()` → 清 flags → `GetPlayerSpawnSpot()` → `StopObserverMode()`(非观战) → `g_pGameRules->PlayerSpawn(this)` → 发 `player_spawn` 事件。

> 注意 `player_spawn` 游戏事件在 `CBasePlayer::Spawn` 内触发 (非 `#if TF_DLL` 才发)。
> `fast_spawn` 用 `player_death` 记死亡时间, 用 `DispatchSpawn()` (SDK 的 Spawn 封装) 强制重生。

---

## 4b. BM 2026 与 2018 的差异: IsSpawnPointValid 被 override 坏掉 (叠人真根因)

§4 的 `EntSelectSpawnPoint` 描述来自 2018 泄漏源码, **BM 2026 的 `server.dll` 实际二进制与之分叉**, 是"叠人 + 原地复活"的真根因 (2026-08-29 逆向实锤, 3-agent 工作流 RTTI 反推 vtable + 独立签名扫描双路一致):

1. **运行时 `IsSpawnPointValid` = `0x1035cc60`** (CBM_MP_GameRules 的 override, 覆盖基类 `CGameRules::IsSpawnPointValid` = `0x101ab0f0`; 后者 `ret 0xc` 3 参、读 flag, 由 CMultiplayRules 原样继承)。BM 的 override **从不读第 3 参 flag** (`[ebp+0x10]` 零引用), 改为:
   `dynamic_cast<CInfoMultiplayerSpawn*>(pSpot)` → `[spawn+0x354]` 使能字节 → `IsTriggered`(恒 true) → **零长度 `UTIL_TraceHull`**(start==end==复活点, 玩家 OBB mins/maxs 来自 `[player+0x14c]` CollisionProp, `MASK_PLAYERSOLID`=0x201400b, filter 跳过 pSpot+pPlayer)。
   二进制里唯一复活点类 = `CInfoMultiplayerSpawn` (无 CInfoPlayerDeathmatch/Start 类), 故 `EntSelectSpawnPoint` 的 LOOP1(flag=1)/LOOP2(flag=0) 运行时**完全等价**。
2. **基类 flag 语义 (仅 `0x101ab0f0`, 运行时被 override 成 no-op)**: `cmp byte[ebp+0x10],0 / je 0x101ab2ec` → flag=1=STRICT (128 半径球 `CEntitySphereQuery` 查占用, 有异队玩家 return false), flag=0=LENIENT (跳过球查只做 32 单元 box 查)。方向与 TF2 的 `bIgnorePlayers` **相反** (BM flag = "bCheckPlayers": true=查)。
3. **`[player+0x1f4]` = `m_iTeamNum`** (FIELD_INTEGER, DLL 自身两个 typedescription_t 均解码出 `{type=5, name="m_iTeamNum", offset=0x1f4=500}`), getter `0x10113cd0` = `mov eax,[ecx+0x1f4]; ret` = `GetTeamNumber()`。值 0=FFA/未分边, 1=观战, 2=Combine, 3=Rebels。
4. **击杀占位者回退被两道门锁死**: `EntSelectSpawnPoint` 末尾 `mov ecx,ebx; call 0x10113cd0; cmp eax,1; je 0x1022b722` (观战者 team1 → 直接 return 首个候选点、跳过击杀清场); 非观战者才进 sphere 查询 + `TakeDamage`(HL2DM 原版 300) 击杀占位者, 但 FFA 全员 team 0 时同队守卫 (occupant_team == spawner_team 就跳过) 又使击杀失效。

**净效果**: 零长度 trace 把每个候选点都判"被挡/startSolid" (或同队占用被判"空位", 此链接置信度中等, 依赖运行时复活点摆放/实体状态) → 两个循环耗尽 → 落到 `[player+0x1f4]==1` 门 → **所有人被扔到同一个 `pFirstSpot`** (`g_pLastSpawn` 按 `RandomInt(1,5)` 跳转后的那一个点) → 叠人; kill 自杀重生重走同一条链 → 又落 pFirstSpot → 观感"原地复活"。

**修法** = 新模块 `spawn_distribute.sp` (merged.smx 第 42 个模块): 不碰原生选择, 在 `player_spawn` 事件 (原生 `SetLocalOrigin` 之后 fire) 里自己挑空闲复活点 `TeleportEntity` 过去。详见 [[bms-respawn-reverse]]。

---

## 5. Black Mesa DM 特有: bot 重生

BMS 用的是 `hl2mp_bot_temp.cpp` (se2018 `game/server/hl2mp/hl2mp_bot_temp.cpp`), 不是官方 SDK2013 的 `bot/` 完整 bot 系统。

**bot 死亡 → 重生** (`hl2mp_bot_temp.cpp:378-393`):

```cpp
// Wait for Reinforcement wave
if ( !pBot->IsAlive() )
{
    // Try hitting my buttons occasionally
    if ( random->RandomInt( 0, 100 ) > 80 )   // 20% 概率每帧
    {
        if ( random->RandomInt( 0, 1 ) == 0 )
            buttons |= IN_JUMP;    // 模拟按跳跃键 → 触发 DeathThink 按键重生
        else
            buttons = 0;           // 模拟"松开所有键"
    }
}
```

即 bot 也是走 **同一套 `PlayerDeathThink` 按键重生** (或 5s `mp_forcerespawn`), 只是"按键"是随机模拟的。

**bot 的移动路径** (`hl2mp_bot_temp.cpp:159` `RunPlayerMove` → `:193` `fakeclient->PlayerRunCommand(...)`):

```cpp
fakeclient->PlayerRunCommand( &cmd, MoveHelperServer() );  // 直接调用, 绕过引擎 RunPlayerMove
```

**这解释了 fast_spawn 的 bot 轮询补丁**: 真人玩家的 `OnPlayerRunCmd` (SourceMod forward) 挂在引擎
`RunPlayerMove` 链上; bot 直接 `PlayerRunCommand`, 不经过那条链, 所以 **bot 永不触发 SM 的
`OnPlayerRunCmd`**。因此 `fast_spawn.sp` 用 `CreateTimer(0.1, ...)` 单独轮询 bot 强制 `DispatchSpawn`。

---

## 6. fast_spawn 插件如何覆盖原生重生

原生链路 = 死亡后 **按键 或 5s 后** 才重生。`fast_spawn.sp` 把它压成 **0 秒**:

1. `player_death` → 记 `g_fDeathTime[client] = GetGameTime()`。
2. 真人: `OnPlayerRunCmd` 每帧检查 → 满足 `FS_IsRespawnEligible` 且到 `sm_fastspawn_time` → `DispatchSpawn(client)`。
3. bot: `Timer_RespawnBots` 每 0.1s 轮询 → 同上。

`FS_IsRespawnEligible` (`fast_spawn.sp:203`):

```sourcepawn
if (IsPlayerAlive(client)) return false;          // 还活着
if (GetClientTeam(client) == 1) return false;      // team 1 = 观战者(主动观战)
if (GetEntProp(client, Prop_Send, "m_iObserverMode") >= 3) return false;  // 主动观战镜头
```

**注释里的关键逆向结论** (BM DM 队伍语义):
- FFA 下参与者 = **team 0**, 主动/强制观战者被 `ChangeTeam` 移到 **team 1** 且永不"死亡"。
- 死亡瞬间 `m_iObserverMode` 是 `DEATHCAM(1)/FREEZECAM(2)` 瞬态 → 仍走零秒重生。
- 原版 (CS 语义 `team <= 1`) 判断会把 FFA 里所有 team 0 的死亡参与者全挡掉, 所以改成了 `team == 1`。

---

## 7. 关键函数 / cvar 速查表

| 项 | 值 / 定义 | 位置 |
|---|---|---|
| `DEATH_ANIMATION_TIME` | 3.0f | baseplayer_shared.h:33 |
| `mp_forcerespawn` | 默认 1 (5s 强逼) | game.cpp:36 |
| `FPlayerCanRespawn` | multiplay 恒 true | multiplay_gamerules.cpp:693 |
| `respawn()` | deathmatch→`Spawn()`; 否则整服 reload | hl2_client.cpp:127 |
| `StartObserverMode` 门 | `m_bEnterObserver` | hl2mp_player.cpp:1628 |
| `PlayerDeathThink` | 仅 `!IsObserver()` 才走 base | hl2mp_player.cpp:632 |
| `EntSelectSpawnPoint` | `info_player_deathmatch` 随机+验证 | player.cpp:4924 |
| `player_spawn` 事件 | `CBasePlayer::Spawn` 内触发 | player.cpp:5112 |
| `mp_teamplay` | 0=FFA, 1=TDM | 本项目 server.cfg:27 |

**FFA/TDM 队伍语义** (hl2mp_gamerules.cpp):
- FFA (`mp_teamplay 0`): 所有玩家 team 0, `PlayerRelationship` 恒 `GR_NOTTEAMMATE`。
- TDM (`mp_teamplay 1`): team 2=Combine(蓝), team 3=Rebels(红)。
- 观战恒为 team 1 (`TEAM_SPECTATOR`)。

---

## 8. 与项目的关联点

- `fast_spawn` / `sm_fastspawn_time 0` 覆盖的是 **§2 的"按键/5s"原生重生**, 不碰 `mp_forcerespawn`。
- `mp_forcerespawn 1` + `player_respawn_protection_time 0` 仍保留在 server.cfg, 是原生兜底。
- `bms_match` 比赛期间不再干预重生 (统一零秒, 见 [[merged-plugin-pitfalls]])。
- 观战链 (`jointeam 1` / `spectate`) 见 [[bms-match-vgui-page]] 与 `player.cpp:6579` 的 `spectate` 命令分支。
