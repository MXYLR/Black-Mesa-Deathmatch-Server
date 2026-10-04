# BM DM 穿墙攻击逆向：除高斯枪以外的武器

> 问题：**除了高斯枪（weapon_tau），其它武器有没有穿墙攻击的可能？**
> DLL：`F:\BMServer\bms\bin\server.dll`（9,509,376 bytes，镜像基址 0x10000000）。
> 参考：`C:\tmp\sdk2013`（官方 SDK2013）、`C:\tmp\se2018_hl2`（2018 泄漏版 HL2，含 `proto_sniper.cpp`）。
> 工具：`smx_analysis/re_dll.py`，原始输出在 `smx_analysis/out/probe*.txt`。

---

## 0. 结论速查

| 机制 | 状态 | 适用武器 | 判定 |
|---|---|---|---|
| **玻璃穿透** | ✅ 活着的 | **所有 hitscan**（glock/mp5/shotgun/magnum/hgun/357/egon 直射/tau 直射） | 唯一"常时可用"的穿掩体机制 |
| MASK_SHOT 盲区（栅栏/playerclip） | ✅ 活着的 | 所有 hitscan | 不是穿墙，是"墙根本没挡" |
| 霰弹弹丸偏散布 | ✅ 活着的 | shotgun | 边缘可绕过薄掩体边角 |
| 爆炸物（frag/handgrenade/satchel/tripmine/RPG） | ❌ 无穿透 | — | 走 `IsExplosionTraceBlocked`，纯 LOS 判定 |
| 实体弹丸（弩箭/RPG 火箭/手雷本体） | ❌ 无穿透 | crossbow/rpg/frag | 命中即爆炸/插墙 |
| **NPC 狙击弹 `CSniperBullet`** | ⚠️ 存在但 NPC 专用 | NPC 狙击手 | 真穿透（最多 3 层/5 厚），玩家拿不到 |
| **`bullet_ff_through_walls` 多段弹道模块** | ❌ **死代码** | — | 在 vtable 槽 0x4CC，全 DLL+engine 无人派发 |
| 数据驱动穿透（`weapon_*.txt`） | ❌ 不存在 | — | BM 无武器脚本系统 |

**一句话**：BM DM 玩家手里**没有任何武器能穿透实心墙**；唯一真实存在的"隔物打击"是**玻璃**（`func_breakable` + material Y + 无 spawnflag 0x800），而它对**全部 hitscan 武器**都生效。真穿透代码在 DLL 里有两份，一份是 NPC 专用，一份是编译了但从没接线的死代码。

---

## 1. 玩家弹道路径 = 原版，没有加穿透

### 1.1 vtable 槽位（严格 RTTI 解析，`out/probe42.txt`）

```
.?AVCBasePlayer@@       vtable 0x1064be44   +0x1E8 = 0x1011e530  (原版 FireBullets)
.?AVCBlackMesaPlayer@@  vtable 0x10726358   +0x1E8 = 0x1047ea30  (BM 覆写)
.?AVCAI_BaseNPC@@       vtable 0x105d69d4   +0x1E8 = 0x10063db0  (bullseye 覆写)
.?AVCProtoSniper@@      vtable 0x1073d70c   +0x1E8 = 0x10063db0
```

### 1.2 `CBlackMesaPlayer::FireBullets` @ `0x1047ea30`（`out/probe43.txt`）

```
0x1047ea30  push ebp / mov ebp,esp / push esi / mov esi,ecx
0x1047ea36  call 0x10475e00                 ; 取 FX 接口
0x1047ea3b  ... push 1, push esi, call [eax] ; FX 通知（开火特效）
0x1047ea58  push [ebp+8] / mov ecx,esi / call 0x1011e530   ; ← 原版 CBaseEntity::FireBullets
0x1047ea62  mov ecx,[0x107d9968] / push esi / call [eax+4] ; FX 通知（收尾）
0x1047ea70  ret 4
```

**结论**：BM 对玩家弹道只包了两层特效通知，中间就是原版 `FireBullets`。**没有插入任何穿透逻辑。** 这解释了为什么所有非 tau 武器行为与原版 HL2 DM 一致。

### 1.3 `0x10063db0` 不是穿透（曾经的误判，已证伪）

它的 RTTI 常量是 `.?AVCBaseEntity@@` + `.?AVCNPC_Bullseye@@`，成功分支读 `byte [eax+0xe58]` 并把 `m_vecSpread` 清零（源全局 `0x1110c72c`）。这是 **HL2 bullseye 的"完美精度"覆写**，与穿透无关。

---

## 2. 玻璃穿透：唯一活着的"穿掩体"机制

位置：`0x1011e530`（原版 FireBullets）内的判定块 `0x1011f247`–`0x1011f3af`，实现函数 `0x10067c00`（与 HL2 `HandleShotImpactingGlass` 逐指令一致）。

**触发条件（三条全满足）**：

1. 命中的实体 `ClassMatches("func_breakable")`
2. 表面 `psurf->game.material == CHAR_TEX_GLASS`（`'Y'` = 0x59）
3. **没有** `SF_BREAK_NO_BULLET_PENETRATION (0x0800)` spawnflag
   （反汇编：`shr eax,0xb / test al,1 / cmove`）

**流程**：

- 命中点打 `GlassImpact` 特效，**当帧不画曳光弹**（tracer gate 在 `0x1011f2c4`）
- 从 `tr.endpos + vecDir * MAX_GLASS_PENETRATION_DEPTH(16.0f)` 反向 trace（MASK_SHOT）
- 三个提前退出：`startsolid` / `tr.fraction == 0` / `penetrationTrace.fraction == 1`
- 出口再打一次 `GlassImpact`
- **递归调用 `FireBullets`**：`m_vecSrc = penetrationTrace.endpos`，`m_vecSpread = vec3_origin`（无散布！），`m_flDistance = info.m_flDistance * (1 - tr.fraction)`

**要点**：

- 对**所有 hitscan 武器**生效，包括霰弹的每一颗弹丸（每颗独立走这条路径）
- 玻璃最厚 16 单位（可穿透部分）；实际受 `func_breakable` 的血量/厚度限制
- 穿过玻璃后**散布被清零** → 隔玻璃打人反而更准
- 玻璃本身会累积伤害破碎（`func_breakdmg_bullet` 可调）

**可操作性**：地图作者只要把一堵墙做成 `material == Y` 的 `func_breakable` 且不带 0x800，就是可穿墙。服务端无法在运行期改 material（是 BSP 里烘焙的），所以这不是一个"服务器开关"。

---

## 3. MASK_SHOT = 0x46004003 的盲区

```
MASK_SHOT = 0x46004003
          = CONTENTS_SOLID(0x1) | CONTENTS_WINDOW(0x2) | CONTENTS_MOVEABLE(0x4000)
          | CONTENTS_MONSTER(0x2000000) | CONTENTS_DEBRIS(0x4000000) | CONTENTS_HITBOX(0x40000000)
```

对照 `CONTENTS_*`：

| 内容类型 | 值 | MASK_SHOT 是否包含 | 子弹结果 |
|---|---|---|---|
| `CONTENTS_SOLID` | 0x1 | ✅ | **挡** |
| `CONTENTS_WINDOW` | 0x2 | ✅ | **挡**（除非走上面的玻璃分支） |
| `CONTENTS_GRATE` | 0x8 | ❌ | **穿过！** |
| `CONTENTS_PLAYERCLIP` | 0x10000 | ❌ | **穿过！** |

**实战含义**：

- **铁丝网 / 格栅 / 栅栏**（`CONTENTS_GRATE`）—— 子弹直接穿过去打到人。这是"合法"的原版行为，不是漏洞。
- **玩家隐形墙**（`playerclip`）—— 同样不挡子弹。地图里用来限制走位的隐形墙，**站着不动会被隔墙打死**。这可能是玩家感知最像"穿墙攻击"的现象。
- 反过来，`clip`（`CONTENTS_SOLID` 的 brush）会挡。

**排查建议**：如果服务器上有人报告"隔墙被打死"，优先检查该位置是不是 playerclip 或 grate 材质，而不是怀疑外挂——这两类在原版引擎里就不挡子弹。

---

## 4. 爆炸与实体弹丸：没有穿透

- **爆炸**（frag / handgrenade / satchel / tripmine / RPG 爆炸）：走 `IsExplosionTraceBlocked` / `UTIL_TraceLine` 做 LOS 判定。视线被挡就完全无伤害；只有爆炸球半径边缘会有"绕过薄墙角"的溢出（几何近似，非穿透）。
- **实体弹丸**（弩箭 `crossbow_bolt`、RPG 火箭、手雷本体、snark）：都是 `CBaseGrenade`/实体自身飞行 + `Touch` 触发，撞到即停，**没有多段 trace**。
- **egon / gluon**：射线直伤，同 hitscan 规则（含玻璃分支）。
- **tau**：唯一有专门 `CTauBeam::ProgressBeam` 穿透逻辑的武器（见 `REVERSE_TAU.md`，该笔记属单人战役部分、已移出本仓库到 `campaign/`），这正是问题里"除了高斯枪"的对照物。

---

## 5. NPC 专用的真穿透：`CSniperBullet`

BM 里存在完整的穿透弹实现，来自 HL2 的 NPC 狙击手（`proto_sniper.cpp`）。

**注册与入口**（`out/probe14.txt` / `probe32.txt`）：

| 项 | 地址 |
|---|---|
| classname 字符串 `"tracerbullet"` | `0x106a9744`，ref @ `0x10484d9e`（spawn） |
| `CSniperBullet::Start` | `0x10351f30`（`ret 0x14`） |
| 变体（门控 `[esi+0x38d]`） | `0x104be900`（`ret 0x10`） |
| ammo 类型注册块 | `0x102cda08`–`0x102cda7a`（"sentry"/"50cal"/"SniperRound"/"SniperPenetratedRound"） |
| datamap 字段 | `m_AmmoType` `0x106a96d4`、`m_PenetratedAmmoType` `0x106a96e0`、`m_iImpacts` `0x106a96f8`、`m_vecDir` `0x106a9704`、`m_vecStart` `0x106a9728`、`m_Speed` `0x106a9720` |

**机制**（`BulletThink`，2018 源码 `proto_sniper.cpp:3195-3345`）：

- 每 tick 打一段 `GetOwnerEntity()->FireBullets(1, vecStart, m_vecDir, vec3_origin, flDist, m_AmmoType, 0)`
- 命中 NPC 或 `m_iImpacts == NUM_PENETRATIONS(3)` 就停
- 否则把游标 `vecCursor += m_vecDir * STEP_SIZE(2)` 向前推进，最多 `NUM_STEPS(6)` 步，期间只要求 `UTIL_PointContents == CONTENTS_SOLID`
- 重新开火，并用 `UTIL_Tracer(..., "StriderTracer")` 画曳光

**为什么玩家拿不到**：`"tracerbullet"` 的 spawn 点 `0x10484d9e` 属于 NPC 狙击逻辑；`CSniperBullet`/`CProtoSniper` 的 vtable 里**没有任何指向该穿透模块的指针**（`out/probe34.txt`），也没有玩家武器引用它。`m_PenetratedAmmoType` 连在 HL2 源码里都是**只写不读**的死字段，"SniperPenetratedRound" 只是弹药表里的一个条目。

---

## 6. 死代码：`bullet_ff_through_walls` 多段弹道模块

DLL 里有一套完整的"多段 trace 子弹"实现，但**从未接线**。

**ConVar 注册**（`out/probe33.txt`，`0x10016a80`）：

```asm
0x10016a80  push 0x2000                        ; FCVAR_ 标志
0x10016a8f  push 0x105c89cc ("")               ; 默认空字符串
            push 0x106a904c ("bullet_ff_through_walls")
            mov ecx, 0x108bc278
            call 0x1052ec80                    ; ConVar 构造
0x10016ab0  push 0x108bc304 / push 0x106a90c8 ("CTEWeaponBullets")
            mov ecx,0x108bc2f0 / call 0x1005ac00
```

**唯一消费者**在 `0x1034f250` 里：

```asm
mov eax,[0x108bc278]      ; ConVar 对象
mov eax,[eax+0x2c]        ; -> GetString()
call eax
test eax,eax / je ...     ; 空串 -> 跳过
movzx eax, word [eax+0x4c]; 表面 material
cmp eax, 0x47             ; CHAR_TEX_GRATE 'G'
```

**可达性证明（这是关键）**：

| 检查 | 结果 |
|---|---|
| `0x1034dd80`（模块入口）被引用 | **97 处，全在 `.rdata`** = 只是 vtable 槽位；`.text`/`.data` 里 0 处 |
| `0x1034f250` 被引用 | **0 处** |
| `0x1034fb10` 被引用 | **0 处** |
| 全 `.text` 扫描 `call [reg+0x4cc]` / `push` / `mov`（`out/probe44.txt`） | **0 命中** |
| `engine.dll` 扫描 `<op> [reg+0x4cc]` | **0 命中** |

而 `0x1034dd80` 占据 `CBasePlayer` / `CBlackMesaPlayer` / `CAI_BaseNPC` vtable 的 **slot 0x4CC（十进制 307）**，三张表共享 ⇒ 它是某个共同基类（`CBaseCombatCharacter` 层）的虚函数。**没有任何代码按这个槽号派发它**——server.dll 没有，engine.dll 也没有。

⇒ **结论：编译进了二进制但从未接线的 BM 内部残留（很可能来自早期"子弹穿透"实验或从别的分支带过来的代码）。运行时不可达。**

> ⚠️ 未解项：slot 0x4CC 的**虚函数名**尚未确定。用 SDK 头文件按 `virtual` 声明计数校准失败（`FireBullets` 数出来是局部 index 76，真实是 122），该方法不可靠，故留空。
>
> 可以直接试：`bullet_ff_through_walls` 若真无效，说明判断正确；若有效，说明上面某步漏了（预计无效）。

---

## 7. 数据驱动穿透：不存在

- BM 的 VPK 里**没有 `scripts/weapons/weapon_*.txt`**（`re_vpk.py` 扫描结果）——BM 没有 HL2 那套武器脚本系统。
- `penetration_*` KeyValues 在运行期**没有任何消费者**。
- `m_PenetratedAmmoType` 只写不读。

---

## 8. 服务端可用的杠杆

按"性价比"排序：

### 8.1 想**验证/排查**（零成本）
```
sv_showdebugtracers 1     # 蓝=客户端红=服务端轨迹
sv_showimpacts 1
sv_showdamage 1
```
玻璃测试：`func_breakable` + `func_breakdmg_bullet`，找一张有玻璃的地图对着打，观察
是否出现"命中玻璃 → 曳光消失一帧 → 玻璃后继续命中"。

### 8.2 想**给非 tau 武器加真穿透**（需要插件）
玩家路径确认是原版 `FireBullets`，所以只能：

- **方案 A：DHooks 挂 `0x1E8` 槽**（`CBaseEntity::FireBullets`），自己重实现多段 trace，
  在每段之间递归调用原函数。实现参考就是第 5 节的 `CSniperBullet::BulletThink`。
  - 风险：`0x1E8` 是 `CBaseEntity` 的虚函数，DHooks 需要能在 vtable 上定位；
    且每次开火递归，注意 `m_flDistance` 递减防死循环（原版玻璃分支就是这样做 `*(1-tr.fraction)`）。
- **方案 B：直接复用 `tracerbullet`**：插件 `CreateEntityByName("tracerbullet")`，
  设 `m_AmmoType`/`m_vecDir`/`m_vecStart`/`m_Speed`/`m_iImpacts`，让它自己跑。
  **风险高**：实体是 NPC 逻辑的一部分，owner 是 NPC 时才能正常走；
  玩家当 owner 时 `GetOwnerEntity()->FireBullets(...)` 会用玩家的弹药类型 —— 需要实测。
- **方案 C（最稳）**：不复用引擎，自己在插件里做多段 trace，
  逐段算 `TR_TraceRayFilter` + `TakeDamage`，绕开 DLL 的 `FireBullets` 完全自控。

### 8.3 想**削弱**（如果担心被利用）
- 玻璃穿墙是原版行为，且需要地图配合 → **不是作弊面**，不用管。
- 真正要担心的是 `CONTENTS_GRATE` / `playerclip` 盲区 → 这是地图设计问题，
  只能改 BSP（把 playerclip 换成 clip、把 grate 换成实心）或用插件在
  `OnTakeDamage` 里加一条射线复核（推荐：伤害前 `TR_TraceLine` 用 `MASK_SOLID`，
  被挡就 `return Plugin_Handled`）。这条思路可以同时封住"隔 playerclip 打死人"。

---

## 9. 未完成 / 待实测

1. **slot 0x4CC 的虚函数名** —— 计数法校准失败，需要 BM 自己的头文件或邻居槽位法。
2. **`bullet_ff_through_walls` 运行时行为** —— 静态分析结论是死代码；建议在测试机
   直接 `sm_cvar bullet_ff_through_walls 1` 打两枪看曳光是否分段（预计无变化）。
3. **`tracerbullet` 玩家 owner 可行性** —— 决定方案 B 是否成立。
4. **`sv_showdebugtracers` 玻璃穿透实测** —— 验证第 2 节流程与源码一致。

---

## 附：本轮新增的原始输出

- `out/probe42.txt` — 严格 RTTI → vtable 槽位表（关键证据）
- `out/probe43.txt` — `CBlackMesaPlayer::FireBullets` 全函数体
- `out/probe44.txt` — 全 `.text` 扫 `[reg+0x4cc]` 索引寻址（0 命中）
- `out/probe33.txt` — `bullet_ff_through_walls` ConVar 注册块 + 唯一消费者
- `out/probe31/32/34/37/38.txt` — 前序排查（含两次误判的证伪过程）
