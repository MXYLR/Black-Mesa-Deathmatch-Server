#pragma semicolon 1
#pragma newdecls required

/*
 * hl1tau.smx — HL1 gauss 满蓄伤害 + 溅射半径 + 穿墙门槛还原（最小插件）
 *
 * BM 原生 weapon_tau 有三处数值被改写，本插件只改「开火前实时读」的原生 ConVar，
 * 不拦截原生开火（预测/音效/特效/伤害/bot 全走 BM 原生逻辑）：
 *
 *  1. 满蓄伤害：BM sk_weapon_tau_beam_charged_dmg=120，HL1=200。
 *     → 启动/换图时设 200（穿墙深度/溅射半径/命中伤害都基于它）。
 *  2. 溅射半径：BM 固定 sk_weapon_tau_beam_dmg_radius(64)，HL1 动态 = 伤害×2.5。
 *     → 开火前设 dmg_radius = charged_dmg × (t/charge_time) × hl1tau_splash_scale。
 *  3. 穿墙门槛：BM 固定 sk_weapon_tau_beam_penetration_depth(48)，HL1 = 伤害值
 *     （墙厚 < 伤害才穿）。→ 开火前设 penetration_depth = 当前伤害值。
 *
 *   - 主攻：dmg_radius=0、penetration_depth=0（HL1 主攻不溅射、不穿墙）
 *   - 副攻(蓄力松开)：dmg_radius=伤害×scale、penetration_depth=伤害
 *
 * 为什么「全局 ConVar」对多名人类玩家没有竞态：
 *   引擎按玩家逐个串行跑完整命令 —— PhysicsSimulate → PlayerRunCommand
 *   （SourceMod 的 OnPlayerRunCmd 钩点）→ RunCommand → RunPostThink
 *   → PostThink → ItemPostFrame（原生开火）。开火发生在这同一次 PlayerRunCommand
 *   调用内部、且紧跟在 OnPlayerRunCmd 之后；下一名玩家的命令要等上一名玩家整条
 *   命令（含开火）跑完才开始。所以「改 ConVar → 开火」天然按玩家隔离，已是逐玩家生效。
 *
 * 已知限制：
 *   - bot 绕过 OnPlayerRunCmd（BM 直调 PlayerRunCommand）→ bot 开火读到最近一名
 *     人类玩家遗留的 ConVar 值（非原生默认，也非 bot 自己的动态值）。
 *   - 只还原「满蓄伤害 + 溅射半径 + 穿墙门槛（能穿多厚）」；**穿墙后扣伤还原不了**：
 *     BM 穿透后伤害原样不减（penetration_bias 是死 ConVar，穿透逻辑零引用），
 *     HL1 是「伤害−=墙厚」。这一项需拦截原生伤害才能还原，本插件不做。
 *   - 过载/弹药/击退均不动。
 */

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "2.2.0"

#define IN_ATTACK   (1 << 0)
#define IN_ATTACK2  (1 << 11)

ConVar g_cvEnable;
ConVar g_cvScale;
ConVar g_cvPenetration;

bool  g_bCharging[MAXPLAYERS + 1];
float g_fChargeStart[MAXPLAYERS + 1];
int   g_iPrevButtons[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "HL1 Tau Splash Radius",
	author = "MXYLR",
	description = "Restore HL1 gauss charged-dmg + splash radius + wall-penetration via native ConVars",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("hl1tau_version", PLUGIN_VERSION, "hl1tau plugin version", FCVAR_DONTRECORD | FCVAR_NOTIFY);
	g_cvEnable = CreateConVar("hl1tau_enable", "1", "Enable HL1 gauss splash radius restore (0 = native BM fixed radius)", FCVAR_NOTIFY);
	g_cvScale  = CreateConVar("hl1tau_splash_scale", "2.5", "Splash radius = charge_dmg x scale (HL1 SP=2.5, MP=1.75)", FCVAR_NOTIFY);
	g_cvPenetration = CreateConVar("hl1tau_penetration", "1", "Restore HL1 wall-penetration threshold (depth = current charge dmg)", FCVAR_NOTIFY);

	AutoExecConfig(true, "hl1tau");

	// 满蓄伤害钉到 HL1 的 200（BM 默认 120），穿墙深度/溅射/命中伤害都基于它
	SetNativeChargedDmg(g_cvEnable.BoolValue ? 200.0 : 120.0);

	for (int i = 1; i <= MaxClients; i++)
	{
		HL1_Reset(i);
	}
}

// 换图后 server.cfg 可能重执行，重新钉回 200（或禁用时回到 120）
public void OnMapStart()
{
	SetNativeChargedDmg(g_cvEnable.BoolValue ? 200.0 : 120.0);
}

public void OnClientDisconnect(int client)
{
	HL1_Reset(client);
}

void HL1_Reset(int client)
{
	g_bCharging[client] = false;
	g_fChargeStart[client] = 0.0;
	g_iPrevButtons[client] = 0;
}

// 读取原生 ConVar 当前值，失败返回默认
float NativeConvarFloat(const char[] name, float def)
{
	ConVar c = FindConVar(name);
	return (c != null) ? c.FloatValue : def;
}

// 写入原生溅射半径 ConVar（运行期实时生效）
void SetNativeSplashRadius(float radius)
{
	ConVar c = FindConVar("sk_weapon_tau_beam_dmg_radius");
	if (c != null)
	{
		c.FloatValue = radius;
	}
}

// 写入原生穿墙深度 ConVar（运行期实时生效）。HL1 门槛 =「墙厚 < 伤害」，
// 故把 depth 设成当前伤害值；主攻设 0（HL1 主攻不穿墙）。
void SetNativePenetrationDepth(float depth)
{
	ConVar c = FindConVar("sk_weapon_tau_beam_penetration_depth");
	if (c != null)
	{
		c.FloatValue = depth;
	}
}

// 写入原生满蓄伤害 ConVar（开火时实时读，运行期可改）。
// HL1 满蓄 200，BM 默认 120；穿墙深度/溅射半径/命中伤害都基于它，拉到 200 才对齐 HL1。
void SetNativeChargedDmg(float dmg)
{
	ConVar c = FindConVar("sk_weapon_tau_beam_charged_dmg");
	if (c != null)
	{
		c.FloatValue = dmg;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3],
	float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount,
	int &seed, int mouse[2])
{
	if (!g_cvEnable.BoolValue)
	{
		return Plugin_Continue;
	}

	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	// 仅接管 weapon_tau
	int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (activeWeapon == -1)
	{
		return Plugin_Continue;
	}
	char cls[32];
	GetEntityClassname(activeWeapon, cls, sizeof(cls));
	if (!StrEqual(cls, "weapon_tau"))
	{
		if (g_bCharging[client])
		{
			HL1_Reset(client);
		}
		return Plugin_Continue;
	}

	int prev = g_iPrevButtons[client];
	bool bAttack  = (buttons & IN_ATTACK)  != 0;
	bool bAttack2 = (buttons & IN_ATTACK2) != 0;
	bool bPrevAttack2 = (prev & IN_ATTACK2) != 0;

	// 副攻：按下开始蓄力
	if (bAttack2 && !bPrevAttack2)
	{
		g_bCharging[client] = true;
		g_fChargeStart[client] = GetGameTime();
	}

	// 副攻：松开开火 -> 计算 HL1 动态溅射半径
	if (!bAttack2 && bPrevAttack2 && g_bCharging[client])
	{
		float chargeTime = NativeConvarFloat("sk_weapon_tau_full_charge_time", 1.5);
		float fullDmg    = NativeConvarFloat("sk_weapon_tau_beam_charged_dmg", 200.0);
		if (chargeTime <= 0.0)
		{
			chargeTime = 1.5;
		}

		float t = GetGameTime() - g_fChargeStart[client];
		float frac = t / chargeTime;
		if (frac > 1.0)
		{
			frac = 1.0;
		}
		if (frac < 0.0)
		{
			frac = 0.0;
		}

		float radius = fullDmg * frac * g_cvScale.FloatValue;
		SetNativeSplashRadius(radius);
		if (g_cvPenetration.BoolValue)
		{
			SetNativePenetrationDepth(fullDmg * frac);
		}
		g_bCharging[client] = false;
	}

	// 主攻：HL1 无有效溅射、不穿墙 -> 0
	if (bAttack && !bAttack2 && !g_bCharging[client])
	{
		SetNativeSplashRadius(0.0);
		if (g_cvPenetration.BoolValue)
		{
			SetNativePenetrationDepth(0.0);
		}
	}

	g_iPrevButtons[client] = buttons;
	return Plugin_Continue;   // 不抑制原生开火，原生伤害/特效照旧
}
