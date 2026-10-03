# server.dll / engine.dll 计时器与重启机制逆向结论(2026-08-24)

工具:pefile + capstone,对 F:\BMServer\bms\bin\server.dll 与 F:\BMServer\bin\engine.dll 静态分析。
所有地址为 PE 首选基址 0x10000000 下的 VA(未重定位;相对偏移可靠)。

## 1. CRoundTime 实体(mp_round_time)

- 类名实锤:RTTI `.?AVCRoundTime@@` @0x10827620;datamap dataClassName="CRoundTime" @0x1068ef74。
- 实体工厂 `LINK_ENTITY_TO_CLASS("mp_round_time")` @0x10014a90,类名字符串 @0x1068f3a0。
- **datamap 字段**(typedescription 数组在 .data 0x107f1260 起,共 5 项):
  - `m_iWarmupTime`-like @0x1068f2bc(字段偏移 0x358)
  - **`m_iRoundTime` @0x1068f2d8 = FIELD_INTEGER(5),实体偏移 0x35c(860)** ← Prop_Data 可读写实锤
  - `RoundTime` @0x1068f2e8(网络名/第二时间字段)
  - 输入条目见下。
- **输入表**(datamap 内 FIELD_INPUT 条目,{输入名, 处理函数}):
  | 输入名 | 处理函数 | 生效状态门 |
  |---|---|---|
  | `AddRoundTime` @0x1068f308 | 0x10324210 | **状态==2(回合进行中)** |
  | `RemoveRoundTime` @0x1068f330 | 0x10324330 | 状态==2 |
  | `AddWarmupTime` @0x1068f354 | 0x103242a0 | 状态==0(warmup) |
- 输入处理:读 variant(要求类型 5=FIELD_INTEGER,即 **SetVariantInt + AcceptEntityInput 是正确调用方式**),值<=0 时钳为 0,再调时间调整函数(修正 m_iRoundTime)。
- 状态门实现:`mov eax,[g+0x40]`(0x1035bd30),g = 全局对象 [0x1086c5cc](12+ 处游戏代码引用,判断 vtable+0x88 布尔有效性)。
  **含义:AddRoundTime/RemoveRoundTime 只在回合进行中生效;warmup 期只有 AddWarmupTime 生效。**

## 2. mp_timelimit 与倒计时

- 注册 @0x1000ae40:ConVar(name="mp_timelimit", value="0", flags=0x2100=NOTIFY|REPLICATED, help="game time per map in seconds", **变更回调=0x101d4e20**),对象 0x10871188。
- 变更回调 0x101d4e20:读自身值 → 按预计算 hash(0x1081e53c/0x1081f8ec)遍历实体链表(0x10590163,SEH 保护的链表查找)→ 命中后调实体 vtable+0x240 或 +0x260。
- **实证**:地图倒计时由 mp_round_time 实体 m_iRoundTime 驱动,引擎只在换图时读一次 mp_timelimit(16:25 广告 14:29=15 分钟图加载后 31 秒)。运行期 SetInt 对已加载地图的倒计时无效 → **必须用 AddRoundTime/RemoveRoundTime 输入改倒计时**(= is_bms_fix_timelimit 插件机制,已实锤其正确性)。
- 插件对策(Bms_AdjustRoundTimer):读 m_iRoundTime 当前值(Prop_Data)算 diff,正发 AddRoundTime、负发 RemoveRoundTime;幂等,restart 是否重读 cvar 两分支都收敛到目标值。

## 3. mp_restartgame / mp_restartgame_immediate

- server.dll 注册:均为 **ConVar**(非 ConCommand),4 参 ctor 0x1052ea10(ret 0x10,无静态变更回调):
  - mp_restartgame:对象 0x108713e0,help "If non-zero, game will restart in the specified number of seconds"(值=延迟秒数,0x10638eb8)
  - mp_restartgame_immediate:对象 0x10871458,help "If non-zero, game will restart immediately"(0x10638f0c)
  - 均 flags=4(FCVAR_GAMEDLL),默认值 "0"。
- **engine.dll 内建处理**(engine 侧有名字 0x1036065c/0x10360678):函数 0x101fc7xx 是 **edicts 告急监控**——free edicts 低于阈值时按等级 switch(0x101fc805 起):
  - 等级 2 → 查 "mp_restartgame" 置 1;若 gamedll 未注册,fallthrough 查 "mp_restartgame_immediate" 置 1
  - 等级 3/4/5 → 其他接口调用
  - 日志格式串 "Warning: free edicts below threshold. %i free edict%s remaining.\n" @0x10360618。
  **即:这两个 cvar 是 engine→gamedll 的重启请求通道(实体槽告急时引擎自动请求重启;玩家/插件手动置 1 走同一路径)。**
- 区别:mp_restartgame 值=延迟秒数(有等待期);immediate 立即(旧代码实测:mp_restartgame 的 restart 在比赛进行中才生效,即延迟路径)。
- 比赛重置对策:用 **mp_restartgame_immediate**(已部署),不再用带等待期的 mp_restartgame。

## 4. 对 bms_match 插件实现的确认

1. `HasEntProp/GetEntProp(ent, Prop_Data, "m_iRoundTime")` 可用(FIELD_INTEGER@0x35c 实锤)。
2. `SetVariantInt(n); AcceptEntityInput(timer, "AddRoundTime"/"RemoveRoundTime")` 正确;仅回合进行中生效 → 在 Match 状态调用 ✓(BmsT_Start 进 Match 时调用)。
3. MatchWait 阶段(4 秒倒计时)引擎可能仍在 warmup/等待(状态!=2)→ 输入可能被吞 → BmsT_AdjustRoundTimer 保留重试语义,Bms_OnMatchCancelled 恢复 iTimerBackup 同理。
4. mp_restartgame_immediate 语义实锤("restart immediately")。
5. mp_timelimit 运行期 SetInt 对已加载地图倒计时无效(实证),倒计时修复必须走输入;插件已实现。

## 5. SourceCoop 交叉验证(2026-08-24,C:/tmp/sourcecoop)

SourceCoop(Black Mesa 合作模式项目)对 BM 多人 gamerules 的逆向定义,与本文结论互证:

- **状态枚举实锤状态门含义**:`STATE_WARMUP=0, STATE_INTERMISSION=1, STATE_ROUND=2`
  (srccoop_api/typedef/bms/gamerules.inc)。本文逆向的"AddRoundTime 状态门==2"
  = 仅 STATE_ROUND(回合进行中)生效;==0(warmup)= AddWarmupTime 生效。
- **状态机网络属性**(gamerules 实体,SM 可 GameRules_Set/GetProp):
  `m_StateWarmup` / `m_StateIntermission` / `m_StateRound`,每个状态含
  [0]=DoneTime(float) / [1]=NextState / [2]=IsInIntermission;当前状态在 `m_nCurrentStateId`。
- SourceCoop 实战用法(manager.inc):等 N 秒 → `SetCurrentState(STATE_WARMUP)` +
  `SetStateEndTime(WARMUP, now+N+1.0)`;开赛 → `SetCurrentState(STATE_ROUND)` +
  `SetStateEndTime(ROUND, INT_MAX)`。
- **对未来插件的意义**:这是比"mp_timelimit 换图把戏"更直接的回合结束通道
  (把 STATE_ROUND 的 DoneTime 设到过去/近期即可让引擎自然走完回合计时)。
  当前 bms_match 的结束路径已验证可用,暂不切换;留档备查。
- 其他 BM 类定义参考:CBlackMesaPlayer / CBM_MP_GameRules / 武器类;
  gamedata 含 BM 专用键 `CParamsManager::m_bIsMultiplayer`(offset 72)。

## 6. mp_restartgame 通道死刑实锤 + 状态机 prop 通道上位(2026-08-24 晚)

**结论推翻第 3 节的"重启请求通道"假设。** 第 3 节只证明了 cvar 注册与 engine 的
edicts 告急监控会 FindConVar→SetValue(写方);本轮 xref 扫描(修正了"文件内立即数=
完整 VA 而非 RVA"的坑)证明 **server.dll 内两个 cvar 对象(0x108713E0/0x10871458)
与名字串(0x10638EFC/0x10638F38)的全部引用 = 注册 ctor(0x1000ADC2/0x1000ADF2)+
静态析构 thunk(0x105B3350/0x105B3360,一排 `mov ecx,<obj>; jmp 0x1052edf0`)——没有任何
代码读它们的值**。对照 2018 泄漏 hl2mp_gamerules.cpp:原版有
`CheckRestartGame()`(轮询 mp_restartgame.GetInt()>0 → m_flRestartGameTime +
m_bCompleteReset)+ `RestartGame()`(CleanUpMap + respawn 全员 + Reset);BM 的 dll
里 "Game will restart"/"RestartGame"/"CHL2MPRules" 串全部不存在——**BM 删掉了整个
重启轮询机制**。engine.dll 只引用两个名字串各一次(0x1036065C/0x10360678,告急监控
写方)。→ 带不带值、immediate 或延迟变体,ServerCommand 发这些 cvar 永远无效
(21:22 会话 40 秒吞输入即此)。

**替代通道(已部署,SourceCoop 生产验证的 BM API)**:
- gamerules 状态机类是 `CBM_MP_GameRules`(RTTI 0x00823E84)/`CBM_MP_Teamplay_GameRules`
  (0x00824FA0)/`CBM_MP_Coop_GameRules`,状态类 `CBM_GameRulesStateWarmup|Base|Round|Intermission`
  (0x00827418 起),NetworkVar 名 `m_StateWarmup/m_StateRound/m_StateIntermission@CBM_MP_GameRules`。
- SourceCoop 的 SetCurrentState/SetStateEndTime **纯 prop 实现**(无 SDKCall):
  `GameRules_SetProp("m_nCurrentStateId", 2)`(STATE_ROUND=2)+
  `GameRules_SetPropFloat("m_StateRound", GetGameTime()+N, 0)`(元素 0=DoneTime);
  元素序 STATE_ELEMENT_DONE_TIME=0/NEXT_STATE=1/IS_IN_INTERMISSION=2。
- HUD 倒计时与引擎自然回合结束读 `m_StateRound[0]` DoneTime——这就是 dm_crossfire
  engine_timeleft=-1 的原因(状态从未进 ROUND、DoneTime 从未设置)。
- 玩家重生:引擎重启同款 = `RemoveAllItems + respawn(pPlayer)`(泄漏 998-1040 行),
  SM 等价 = 剥武器 + `DispatchSpawn(client)`(对存活玩家直接 Spawn() 就是官方模式;
  本服 fast_spawn 插件同款调用,BM 已验证)。
- 实体 classname `"mp_round_time"` 在 dll 中恰好 1 次,插件 CreateEntityByName 用名正确;
  m_iRoundTime 直写 SetEntProp 作兜底(输入被吞时也保证收敛)。

**bms_match 改造(已部署)**:Bms_GameRestart(秒数) = 状态强制 ROUND + warmup DoneTime
置过去 + ROUND DoneTime=now+秒数;Bms_RefreshPlayers = 剥武器+解冻+DispatchSpawn 全员+
ResetScores(在 SetState(Match) 之后调用,避开 MatchWait 冻结钩子);Bms_AdjustRoundTimer
每调用同步 m_StateRound DoneTime,输入被吞时直写 m_iRoundTime 兜底;PostRestartFix 保留为
幂等安全网。取消比赛 Bms_GameRestart(0)→ 回退 mp_timelimit*60。

