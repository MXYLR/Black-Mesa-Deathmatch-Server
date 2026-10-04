#pragma semicolon 1
#pragma newdecls required

/*
 * tau_mp.smx — 单人战役的几处调整：
 *   1. tau cannon 拥有「多人模式」行为：
 *        tau_mp_gaussjump  1 = 高斯跳（补 FireBeam）
 *        tau_mp_nocooldown 1 = 右键无冷却（补 ChargeFire）—— ⚠ 卡枪根因未定论，见下
 *   2. 跌落伤害封顶 10 HP
 *
 * ⚠ 2026-10-04 未定论：把 ChargeFire 的 je 抹成 NOP 之后实测出现过
 *   「按住右键几发 → 高斯枪模型消失 → 读档模型回来但 HUD 消失，无法开火、无法切枪」。
 *   逆向后的差异只有一处：单人分支写两个状态计时器
 *     call 0x1048fa80(0xB5, 0.0f)  → 先 SendWeaponAnim，成功才写 this+0x49c 和 this+0x4a0
 *   多人分支只
 *     SendWeaponAnim(0xB5) + 0x1048fc50(curtime, 0) → 只写 this+0x4a0
 *   （0x10108010 与 vtable+0x400 是同一个函数，已核实，不是 override 差异。）
 *   即：走多人分支 = 跳掉单人那套「攻击后冷却」的状态机，并让副攻冷却恒等于 curtime。
 *   于是按住右键时每个 tick 都会重入 ChargeFire。**是否真由它引起，尚未实锤。**
 *
 *   ⚠ 更正（2026-10-04 反汇编复核）：先前记的「bms_weapon_tauStuckFix.smx 依赖已删除的
 *   m_bInTauAttack → 静默失效 → 没有兜底」是**错的**。该插件只读
 *   CBasePlayer/m_iAmmo 与 CBaseCombatWeapon/m_iPrimaryAmmoType，两者在现代 server.dll
 *   都还在、两个类也都还注册为 ServerClass → **插件是活的**。它的全部行为 =
 *   右键第一 tick 且手持 weapon_tau 时把备用弹药补到 3，
 *   **不碰 viewmodel/HUD/武器状态**，不是模型/HUD 消失的元凶。
 *   不过它和 nocooldown 有耦合：nocooldown 让备弹狂掉，会反复把玩家推进
 *   「备弹 < 3」这个 regime，也就是这个 2018 插件第一次被高频触发。
 *   → 复现/排查卡枪时建议同时把 bms_weapon_tauStuckFix.smx 改名停用，两个一起验。
 *
 *   ⚠ 另一次「游戏崩溃了」（2026-10-04）已查清**与 tau 无关**：当时 nocooldown 是关的，
 *   元凶是自定义准星客户端 mod 的字形路径（该 mod 现已整体卸载）。
 *   出问题就 tau_mp_nocooldown 0（改 cvar 会自动还原原始字节，不用重启）。
 *
 * 背景（逆向结论，见 smx_analysis/REVERSE_TAU.md）：
 *   BM 单人/多人共用同一份 server.dll，差异 = cfg（skill.cfg vs
 *   config_deathmatch.cfg）+ 代码里的 IsMultiplayer 分支。
 *   tau 里只有两处该分支，两处都是
 *        mov ecx,[g_pGameRules] ; mov eax,[ecx] ; mov eax,[eax+0x88] ; call eax
 *   然后 test al,al / je <单人路径>：
 *
 *   1. CWeapon_Tau::FireBeam @0x1048C8D8  (je 0x1048C9BC)
 *      单人路径执行 `mov dword ptr [ebp-0x18], 0` 把击退的垂直分量清零
 *      → 单人「高斯跳」被代码级禁用，纯 ConVar 改不出来。
 *      多人路径保留三轴击退 = 高斯跳。这段只是算一个速度冲量
 *      （合流后 call 0x1011d7e0），不碰 viewmodel / HUD / 武器状态，风险低。
 *
 *   2. CWeapon_Tau::ChargeFire @0x1048D840  (je 0x1048D879)
 *      单人路径把副攻冷却设成「curtime + 开火动画时长」→ 右键开完炮有硬直；
 *      多人路径只 SendWeaponAnim(0xB5) + 副攻冷却 = curtime → 立即可再射。
 *      **这条疑与卡枪有关，尚未实锤**（详见上面的 2026-10-04 记录）。
 *
 * 做法：
 *   用 gamedata 里的签名拿到这两条 je 指令的运行时地址（见 tau_mp.games.txt），
 *   校验首字节后把 je 就地抹成 NOP —— 只改内存，不落盘、不改 cfg。
 *   于是引擎在这两处永远走「多人路径」，行为就是引擎自己的多人代码，
 *   而不是插件重写的一份近似物理/冷却。插件卸载时还原原字节。
 *
 *   ⚠ 签名必须抗重定位：GameConfGetAddress 扫的是**已加载**的模块，绝对地址类指令的
 *   imm32 在加载时会被改写。FireBeam 那条 je 后面紧跟 `cmp ecx, 0x110FA098`，其 imm32
 *   必须用 \x2A 通配 —— v1.1.0 就是漏了这点，磁盘上命中、运行时失配，高斯跳因此没生效
 *   （日志 "cannot find TauFireBeamMPBranch"）。校验用 smx_analysis/sig_check.py。
 *
 *   另一条路（挂 CMultiplayRules::IsMultiplayer 的 gamerules 钩子）在 BM 单人下走不通：
 *   DHooks 的 HookGamerules 依赖 sdktools gamedata 的 GameRulesProxy 键，那里写的是
 *   CBM_MP_GameRulesProxy，而单人战役用的是 CBM_SP_GameRulesProxy → 取不到 gamerules
 *   指针，报 "Could not get gamerules pointer"。本插件因此完全不依赖 DHooks。
 *
 * 另外把 tau 的三个参数 ConVar 钉成多人原生数值（单人 skill.cfg 写的是单人值）：
 *   sk_weapon_tau_charge_max_velocity        650 → 850
 *   sk_weapon_tau_full_charge_time           1.5 → 1.25
 *   sk_weapon_tau_full_charge_required_ammo   12 → 11
 *   （sk_weapon_tau_beam_charged_dmg 单人多人同为 120，无需改）
 *
 * 跌落伤害：
 *   BM 在 CGameMovement 里算摔伤（函数 0x101D1FA0）：
 *       damage = sv_falldamagescale × gamerules->FlPlayerFallDamage(player)
 *       damage <= 0 直接跳过；否则构造 CTakeDamageInfo(..., DMG_FALL) 调 player->TakeDamage()
 *   即摔伤和普通伤害共用同一条 TakeDamage 管线、带 DMG_FALL(0x20) 标志。
 *   链路已逐字节核实：TakeDamage(0x1011C1A0) 在 0x1011C39C 虚派发 vtable+0x110，
 *   而 sdkhooks.games/game.bms.txt 里 OnTakeDamage 的 windows 偏移正是 68 号 = 0x110
 *   → SDKHooks 的 OnTakeDamage 钩子确实能拦到摔伤，把伤害压到上限。
 *   sv_falldamagescale 只是倍率（0 = 免伤），表达不了「封顶 N HP」，所以必须钩伤害。
 *   注意引擎在 damage <= 0 时根本不调 TakeDamage —— 不足以掉血的轻摔仍是 0 伤害，
 *   这里也**只封顶、不抬升**：原本掉 2 点的轻摔还是 2 点，只有超过上限的才被压到
 *   tau_mp_falldamage_hp。即「怎么摔最多掉 N HP」，而不是「一摔就掉 N HP」。
 *
 * ✅ 2026-10-04 实测实锤（v1.3.3）：封顶逐次生效，链路与上面推断完全一致，不用再怀疑代码。
 *   bm_c2a5a 上连摔 5 次的日志（hp = hook 触发时、扣血前的血量）：
 *     hp=91 dmg=46.72 type=0x20 fall=1 -> capped 46.72 -> 10.00  -> 81
 *     hp=81 dmg=63.61 type=0x20 fall=1 -> capped 63.61 -> 10.00  -> 71
 *     hp=71 dmg= 6.51 type=0x20 fall=1 -> 未超上限，按 6.51 扣     -> 64
 *     hp=64 dmg=36.08 type=0x20 fall=1 -> capped 36.08 -> 10.00  -> 54
 *     hp=54 dmg=50.17 type=0x20 fall=1 -> capped 50.17 -> 10.00  -> 44
 *   每次恰好 10（或原值），全程无 player_death。OnTakeDamageAlive 收到的是**已封顶**的
 *   10.00 → 两条链共享同一份 CTakeDamageInfo，封顶幂等、不叠加。
 *   ⇒「高处摔下来摔死」不是封顶失效。若日后复现，先看 [OnTakeDamage] 行的 type：
 *   **只有 DMG_FALL(0x20) 进封顶**；DMG_GENERIC 的坑洞 trigger_hurt、爆炸物自伤都不管
 *   （用户已确认榴弹自伤属正常伤害，不需要封）。
 *
 * v1.3.2/1.3.3 新增：
 *   - OnMapStart 下一帧给所有在场客户端补挂钩子。换图/读档会重建实体、SDKHooks 的
 *     entity hook 随之被清掉，而 listen server 的本地玩家不一定再触发
 *     OnClientPutInServer —— 只挂那一处的话，读档后封顶会**静默失效**。
 *   - tau_mp_damagelog（默认 0）：诊断开关。1 = 把每一次摔伤、以及任何达到致死量的
 *     伤害（钩子名 / hook 时血量 / 伤害 / 类型 / fall 位 / inflictor 类名 / attacker）
 *     和 player_death 写进 SM 日志。排查「摔死了」这类问题先开它。
 */

#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.3.3"

// 多人原生数值 / 单人默认值（cfg/skill.cfg vs cfg/config_deathmatch.cfg）
#define TAU_MP_CHARGE_MAX_VELOCITY   850.0
#define TAU_SP_CHARGE_MAX_VELOCITY   650.0
#define TAU_MP_FULL_CHARGE_TIME      1.25
#define TAU_SP_FULL_CHARGE_TIME      1.5
#define TAU_MP_FULL_CHARGE_AMMO      11.0
#define TAU_SP_FULL_CHARGE_AMMO      12.0

#define PATCH_COUNT        2
#define PATCH_MAX_BYTES    6

Handle g_hConf;
ConVar g_cvEnable;
ConVar g_cvHook;
ConVar g_cvGaussJump;
ConVar g_cvNoCooldown;
ConVar g_cvValues;
ConVar g_cvFallDamage;
ConVar g_cvFallDamageHP;
ConVar g_cvDamageLog;

static const char g_sPatchKey[PATCH_COUNT][] =
{
	"TauFireBeamMPBranch",
	"TauChargeFireMPBranch"
};

// 期望的首字节：0F 84 (je rel32) / 74 xx (je rel8)
static const int g_iPatchHead[PATCH_COUNT] = { 0x0F, 0x74 };
static const int g_iPatchLen[PATCH_COUNT]  = { 6,    2    };

bool    g_bPatched[PATCH_COUNT];
Address g_aPatch[PATCH_COUNT];
int     g_iOrigLen[PATCH_COUNT];
int     g_iOrig[PATCH_COUNT][PATCH_MAX_BYTES];

public Plugin myinfo =
{
	name = "Tau Multiplayer Behavior",
	author = "MXYLR",
	description = "Singleplayer: tau cannon MP behavior (gauss jump; optional no-cooldown), fall damage capped at 10 HP",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("tau_mp_version", PLUGIN_VERSION, "tau_mp plugin version", FCVAR_DONTRECORD | FCVAR_NOTIFY);
	g_cvEnable = CreateConVar("tau_mp_enable", "1", "Master switch: 1 = enable everything this plugin does");
	g_cvHook   = CreateConVar("tau_mp_hook",   "1", "Master switch for the two tau code patches (gauss jump + no secondary cooldown)");
	g_cvGaussJump  = CreateConVar("tau_mp_gaussjump",  "1", "1 = patch FireBeam so the tau has the MP vertical recoil (gauss jump)");
	g_cvNoCooldown = CreateConVar("tau_mp_nocooldown", "1", "1 = patch ChargeFire so the tau secondary is never on cooldown (WARNING: see tau_mp.sp header)");
	g_cvValues = CreateConVar("tau_mp_values", "1", "1 = pin tau parameter ConVars to their multiplayer values");
	g_cvFallDamage   = CreateConVar("tau_mp_falldamage",    "1",    "1 = cap fall damage at tau_mp_falldamage_hp HP");
	g_cvFallDamageHP = CreateConVar("tau_mp_falldamage_hp", "10.0", "Fall damage cap: a fall costs at most this much HP (light falls are not raised to it)", 0, true, 0.0);
	g_cvDamageLog    = CreateConVar("tau_mp_damagelog",     "0",    "1 = log player damage / fall-cap decisions to the SM log (diagnostics)");

	AutoExecConfig(true, "tau_mp");

	HookEvent("player_death", Event_PlayerDeath);

	g_cvEnable.AddChangeHook(OnSettingChanged);
	g_cvHook.AddChangeHook(OnSettingChanged);
	g_cvGaussJump.AddChangeHook(OnSettingChanged);
	g_cvNoCooldown.AddChangeHook(OnSettingChanged);
	g_cvValues.AddChangeHook(OnSettingChanged);

	g_hConf = LoadGameConfigFile("tau_mp.games");
	if (g_hConf == null)
	{
		SetFailState("gamedata/tau_mp.games.txt not found");
	}

	ApplyAll();
}

public void OnConfigsExecuted()
{
	// skill.cfg / server.cfg 都执行完了，这时再钉值才不会被覆盖回来
	ApplyAll();

	LogMessage("tau_mp: state enable=%d hook=%d gaussjump=%d nocooldown=%d values=%d falldamage=%d cap=%.1f log=%d",
		g_cvEnable.IntValue, g_cvHook.IntValue, g_cvGaussJump.IntValue,
		g_cvNoCooldown.IntValue, g_cvValues.IntValue,
		g_cvFallDamage.IntValue, g_cvFallDamageHP.FloatValue, g_cvDamageLog.IntValue);
}

public void OnPluginEnd()
{
	for (int i = 0; i < PATCH_COUNT; i++)
	{
		RestorePatch(i);
	}
}

public void OnSettingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ApplyAll();
}

void ApplyAll()
{
	ApplyPatch();
	ApplyValues();
}

// ---------------------------------------------------------------- 代码分支

// Address 是 enum tag，直接相加会退化成 int（warning 213），这里统一走一层转换
Address AddrAdd(Address base, int offset)
{
	return view_as<Address>(view_as<int>(base) + offset);
}

// 每处补丁有独立开关：0 = FireBeam(高斯跳) / 1 = ChargeFire(右键无冷却)。
// 分开是为了能单独关掉一条来定位问题（2026-10-04 的卡枪事故见文件头）。
bool PatchWanted(int i)
{
	if (!g_cvEnable.BoolValue || !g_cvHook.BoolValue)
	{
		return false;
	}
	return (i == 0) ? g_cvGaussJump.BoolValue : g_cvNoCooldown.BoolValue;
}

void ApplyPatch()
{
	for (int i = 0; i < PATCH_COUNT; i++)
	{
		bool want = PatchWanted(i);

		if (want && !g_bPatched[i])
		{
			TryPatch(i);
		}
		else if (!want && g_bPatched[i])
		{
			RestorePatch(i);
		}
	}
}

void TryPatch(int i)
{
	Address addr = GameConfGetAddress(g_hConf, g_sPatchKey[i]);
	if (addr == Address_Null)
	{
		LogError("tau_mp: cannot find %s (wrong server.dll version?)", g_sPatchKey[i]);
		return;
	}

	int head = LoadFromAddress(addr, NumberType_Int8);
	if (head == 0x90)
	{
		// 已经是 NOP（例如插件重载、补丁仍在）：无需备份，避免把 NOP 当原字节记下来
		g_aPatch[i] = addr;
		g_bPatched[i] = true;
		return;
	}
	if (head != g_iPatchHead[i])
	{
		LogError("tau_mp: %s unexpected byte 0x%02X at %08X, patch skipped",
			g_sPatchKey[i], head, view_as<int>(addr));
		return;
	}

	int len = g_iPatchLen[i];
	for (int k = 0; k < len; k++)
	{
		g_iOrig[i][k] = LoadFromAddress(AddrAdd(addr, k), NumberType_Int8);
	}
	g_iOrigLen[i] = len;
	g_aPatch[i]   = addr;
	g_bPatched[i] = true;

	WriteNops(addr, len);

	LogMessage("tau_mp: patched %s at %08X (%d bytes) -> MP branch",
		g_sPatchKey[i], view_as<int>(addr), len);
}

void RestorePatch(int i)
{
	if (!g_bPatched[i])
	{
		return;
	}

	if (g_iOrigLen[i] > 0)
	{
		for (int k = 0; k < g_iOrigLen[i]; k++)
		{
			StoreToAddress(AddrAdd(g_aPatch[i], k), g_iOrig[i][k], NumberType_Int8, true);
		}
		g_iOrigLen[i] = 0;
		LogMessage("tau_mp: restored %s at %08X", g_sPatchKey[i], view_as<int>(g_aPatch[i]));
	}

	g_bPatched[i] = false;
}

void WriteNops(Address addr, int len)
{
	int off = 0;

	while (len - off >= 4)
	{
		StoreToAddress(AddrAdd(addr, off), 0x90909090, NumberType_Int32, true);
		off += 4;
	}
	if (len - off >= 2)
	{
		StoreToAddress(AddrAdd(addr, off), 0x9090, NumberType_Int16, true);
		off += 2;
	}
	while (off < len)
	{
		StoreToAddress(AddrAdd(addr, off), 0x90, NumberType_Int8, true);
		off++;
	}
}

// ---------------------------------------------------------------- 参数

void ApplyValues()
{
	bool mp = g_cvEnable.BoolValue && g_cvValues.BoolValue;

	SetTauFloat("sk_weapon_tau_charge_max_velocity",       mp ? TAU_MP_CHARGE_MAX_VELOCITY : TAU_SP_CHARGE_MAX_VELOCITY);
	SetTauFloat("sk_weapon_tau_full_charge_time",          mp ? TAU_MP_FULL_CHARGE_TIME    : TAU_SP_FULL_CHARGE_TIME);
	SetTauFloat("sk_weapon_tau_full_charge_required_ammo", mp ? TAU_MP_FULL_CHARGE_AMMO    : TAU_SP_FULL_CHARGE_AMMO);
}

void SetTauFloat(const char[] name, float value)
{
	ConVar c = FindConVar(name);
	if (c != null)
	{
		c.FloatValue = value;
	}
}

// ---------------------------------------------------------------- 跌落伤害

// 地图切换会重建所有实体, SDKHooks 的 entity hook 随之被清掉。listen server 的本地玩家
// 不一定会再触发一次 OnClientPutInServer (读档/换图都不重连), 所以这里下一帧补挂一遍。
// SDKHook 对同一 (entity, type) 是覆盖语义 → 重复调用幂等, 不会叠加回调。
public void OnMapStart()
{
	RequestFrame(RehookAllClients);
}

public void RehookAllClients(any data)
{
	int n = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
			SDKHook(i, SDKHook_OnTakeDamageAlive, OnPlayerTakeDamageAlive);
			n++;
		}
	}

	LogMessage("tau_mp: map start, re-hooked %d in-game client(s)", n);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnPlayerTakeDamageAlive);

	LogMessage("tau_mp: hooked client %d (OnTakeDamage + OnTakeDamageAlive), falldamage=%d cap=%.1f",
		client, g_cvFallDamage.IntValue, g_cvFallDamageHP.FloatValue);
}

public void OnClientDisconnect(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnPlayerTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnPlayerTakeDamageAlive);
}

// 诊断: 记录每一次「摔伤」或「可能有杀伤力」的伤害, 以及封顶动作本身。
// 目的是回答: 摔伤到达 OnTakeDamage 了吗? 伤害/类型/当时血量是多少? 封顶执行了吗?
void LogDamage(const char[] hookName, int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!g_cvDamageLog.BoolValue)
	{
		return;
	}

	int health = IsClientInGame(victim) ? GetClientHealth(victim) : -1;

	if (!(damagetype & DMG_FALL) && damage < 15.0 && damage < float(health))
	{
		return;
	}

	char sInf[64] = "";
	if (inflictor > 0 && IsValidEntity(inflictor))
	{
		GetEntityClassname(inflictor, sInf, sizeof(sInf));
	}

	LogMessage("tau_mp: [%s] victim=%d hp=%d dmg=%.2f type=0x%X fall=%d inflictor=%d(%s) attacker=%d",
		hookName, victim, health, damage, damagetype,
		(damagetype & DMG_FALL) ? 1 : 0, inflictor, sInf, attacker);
}

public Action OnPlayerTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0)
	{
		return Plugin_Continue;
	}

	LogDamage("OnTakeDamage", victim, attacker, inflictor, damage, damagetype);

	if (!(damagetype & DMG_FALL))
	{
		return Plugin_Continue;
	}
	if (!g_cvEnable.BoolValue || !g_cvFallDamage.BoolValue)
	{
		return Plugin_Continue;
	}

	float cap = g_cvFallDamageHP.FloatValue;
	if (damage <= cap)
	{
		return Plugin_Continue;
	}

	LogMessage("tau_mp: [OnTakeDamage] fall damage capped %.2f -> %.2f", damage, cap);
	damage = cap;
	return Plugin_Changed;
}

// OnTakeDamage 与 OnTakeDamageAlive 是两条独立的 SDKHooks 链; 两条都试, 谁先接住谁生效
// (封顶是幂等的, 不会叠成 0)。这同时是诊断手段: 若只有 Alive 那条打印, 说明血伤在
// OnTakeDamage 之后被引擎重新处理过, 只挂 OnTakeDamage 就会漏掉摔伤。
public Action OnPlayerTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (damage <= 0.0 || !(damagetype & DMG_FALL))
	{
		return Plugin_Continue;
	}

	LogDamage("OnTakeDamageAlive", victim, attacker, inflictor, damage, damagetype);

	if (!g_cvEnable.BoolValue || !g_cvFallDamage.BoolValue)
	{
		return Plugin_Continue;
	}

	float cap = g_cvFallDamageHP.FloatValue;
	if (damage <= cap)
	{
		return Plugin_Continue;
	}

	LogMessage("tau_mp: [OnTakeDamageAlive] fall damage capped %.2f -> %.2f", damage, cap);
	damage = cap;
	return Plugin_Changed;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvDamageLog.BoolValue)
	{
		return Plugin_Continue;
	}

	char sWeapon[64];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));

	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (victim >= 1 && victim <= MaxClients && IsClientInGame(victim))
	{
		LogMessage("tau_mp: player_death victim=%d attacker=%d weapon=\"%s\"",
			victim, attacker, sWeapon);
	}

	return Plugin_Continue;
}
