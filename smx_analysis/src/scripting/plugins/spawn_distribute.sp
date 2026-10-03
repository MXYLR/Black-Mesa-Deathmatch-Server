#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

/*
 * spawn_distribute.sp — 复活点均匀分配
 *
 * 根因(2026-08-29 逆向实锤, 见 smx_analysis/REVERSE_RESPAWN.md):
 * BM 2026 的原生 IsSpawnPointValid(vtable+0x138) 与 HL2DM 原版完全不同:
 *   1) 第 3 个参数(flag)在整个函数里从不被读取([ebp+0x10] 零引用) →
 *      EntSelectSpawnPoint 里的两个循环(flag=1 / flag=0)是冗余的;
 *   2) 占用判定从原版"128 半径球内有其他玩家"改成了一条零长度 hull trace
 *      UTIL_TraceHull(spot, spot, hullMin, hullMax, 0x201400b=MASK_PLAYERSOLID),
 *      而 hullMin==hullMax==玩家 m_vecOrigin(退化成一个点), 几乎永远判定"空位";
 *   3) "击杀占位玩家清场"回退里多了一个同值守卫(occupant 与 spawner 的
 *      [entity+0x18]+6 相等就跳过 TakeDamage), 在 FFA(全员 team 0)下该守卫
 *      永远成立 → 清场回退彻底失效。
 * 三者叠加: 所有人都被原生选择丢到同一个(随机跳转后第一个)复活点 → 叠人;
 * 原生选择失败时连传送都不做 → 原地复活。
 *
 * 修法: 不碰原生选择, 在 player_spawn 事件里自己挑一个"空闲"复活点
 * TeleportEntity 过去。CBasePlayer::Spawn() 里 GetPlayerSpawnSpot(原生
 * SetLocalOrigin)先执行、player_spawn 事件最后才 fire, 所以这里传送能稳定
 * 覆盖原生选择结果。
 *
 * 二修(2026-08-29): 占用判定拆成两层——
 *   1) 时间层(对所有人): 同一点被分配后的 spawn_distribute_cooldown 秒内不再
 *      分配, 防"同一 tick 内多人生到同一点"。
 *   2) 位置层(只对真人): 半径 spawn_distribute_radius 内有"其他真人"即占用。
 *      这里刻意排除 bot —— 之前的实现用"位置判定对所有活人", 把"站在复活点上
 *      的静止 bot"误判为占用; 当 bot 数 ≈ 复活点数时真人只剩 1 个"空闲"点 →
 *      每次自杀都落在同一位置(用户实测)。bot 不参与位置判定后, 真人能把所有
 *      复活点都视为空闲、轮转遍历(代价: 可能生到静止 bot 附近, 属正常 DM)。
 *      真人之间仍互相阻挡, 避免真人叠真人。
 * 另加每人 g_iLastSpawn[](上次出生点索引), 保证连续两次位置不同(轮转被打乱
 * 也不回原点)。FindSpawn 四遍扫描: ①空闲且非上次点 → ②空闲(哪怕=上次点,
 * 宁可原地也不叠真人)→ ③非上次点(全满时保变化)→ ④只剩 1 点返回 0。
 */

#define MAX_SPAWNS 64

ConVar g_cvEnabled;
ConVar g_cvCooldown;
ConVar g_cvRadius;

int   g_iSpawnCount;
float g_vSpawnOrigin[MAX_SPAWNS][3];
float g_vSpawnAngle[MAX_SPAWNS][3];
float g_fUsedTime[MAX_SPAWNS];      // 每个复活点最后一次被分配的游戏时间
int   g_iLastSpawn[MAXPLAYERS + 1]; // 每个玩家上一次出生点索引(-1 = 无)
int   g_iRoundRobin;

public void OnPluginStart()
{
	g_cvEnabled  = CreateConVar("spawn_distribute_enabled", "1", "复活点均匀分配(1=开启, player_spawn 时挑空闲复活点传送)", FCVAR_NOTIFY);
	g_cvCooldown = CreateConVar("spawn_distribute_cooldown", "2.0", "同一点被分配后多少秒内不重复分配(0=关闭时间占用判定)", FCVAR_NOTIFY);
	g_cvRadius   = CreateConVar("spawn_distribute_radius", "64.0", "真人占用判定半径(单位); 范围内有'其他真人'即视为占用(bot 不参与)", FCVAR_NOTIFY);

	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	// spawn_marker 已验证 OnMapStart 时 info_player_deathmatch 可直接枚举,
	// 但 spawn_cap 遇到过一次地图实体尚未全部创建的情况, 故立即收集一次 +
	// 延迟 1 秒兜底重收(覆盖实体迟到/插件后加复活点的边角, 幂等)。
	CollectSpawnPoints();
	ResetState();
	CreateTimer(1.0, Timer_Recollect, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Recollect(Handle timer)
{
	// 只重收实体, 不重置运行时状态: 否则会把开局 1 秒内已记录的
	// g_fUsedTime/g_iLastSpawn 清空, 冷却与"连续两次不同点"保证失效。
	CollectSpawnPoints();
	return Plugin_Continue;
}

void ResetState()
{
	g_iRoundRobin = 0;
	for (int i = 0; i < MAX_SPAWNS; i++)
	{
		g_fUsedTime[i] = -100000.0;
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iLastSpawn[i] = -1;
	}
}

public void OnClientPutInServer(int client)
{
	// 新玩家复用已断开玩家的客户端槽位时, 清掉残留的"上次出生点"索引
	g_iLastSpawn[client] = -1;
}

void CollectSpawnPoints()
{
	g_iSpawnCount = 0;

	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "info_player_deathmatch")) != -1 && g_iSpawnCount < MAX_SPAWNS)
	{
		if (GetEntPropVector(ent, Prop_Send, "m_vecOrigin", g_vSpawnOrigin[g_iSpawnCount]) > 0)
		{
			if (GetEntPropVector(ent, Prop_Send, "m_angRotation", g_vSpawnAngle[g_iSpawnCount]) <= 0)
			{
				g_vSpawnAngle[g_iSpawnCount][0] = 0.0;
				g_vSpawnAngle[g_iSpawnCount][1] = 0.0;
				g_vSpawnAngle[g_iSpawnCount][2] = 0.0;
			}
			g_iSpawnCount++;
		}
	}

	// 没有 deathmatch 复活点就退回 info_player_start
	if (g_iSpawnCount == 0)
	{
		ent = -1;
		while ((ent = FindEntityByClassname(ent, "info_player_start")) != -1 && g_iSpawnCount < MAX_SPAWNS)
		{
			if (GetEntPropVector(ent, Prop_Send, "m_vecOrigin", g_vSpawnOrigin[g_iSpawnCount]) > 0)
			{
				if (GetEntPropVector(ent, Prop_Send, "m_angRotation", g_vSpawnAngle[g_iSpawnCount]) <= 0)
				{
					g_vSpawnAngle[g_iSpawnCount][0] = 0.0;
					g_vSpawnAngle[g_iSpawnCount][1] = 0.0;
					g_vSpawnAngle[g_iSpawnCount][2] = 0.0;
				}
				g_iSpawnCount++;
			}
		}
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnabled.BoolValue || g_iSpawnCount <= 0)
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	// 观战者(team 1)没有 deathmatch 复活点, 不干预; 也不干预非存活状态
	if (!IsPlayerAlive(client) || GetClientTeam(client) == 1)
	{
		return Plugin_Continue;
	}

	int idx = FindSpawn(client);
	if (idx < 0)
	{
		return Plugin_Continue;
	}

	TeleportEntity(client, g_vSpawnOrigin[idx], g_vSpawnAngle[idx], NULL_VECTOR);
	g_fUsedTime[idx] = GetGameTime();
	g_iLastSpawn[client] = idx;
	g_iRoundRobin = (idx + 1) % g_iSpawnCount;

	return Plugin_Continue;
}

int FindSpawn(int client)
{
	int last = g_iLastSpawn[client];

	// 1) 最佳: 空闲 且 非上次出生点
	for (int i = 0; i < g_iSpawnCount; i++)
	{
		int idx = (g_iRoundRobin + i) % g_iSpawnCount;
		if (idx != last && IsSpawnFree(idx, client))
		{
			return idx;
		}
	}

	// 2) 次优: 空闲(哪怕=上次点)—— 宁可原地, 也不叠真人
	for (int i = 0; i < g_iSpawnCount; i++)
	{
		int idx = (g_iRoundRobin + i) % g_iSpawnCount;
		if (IsSpawnFree(idx, client))
		{
			return idx;
		}
	}

	// 3) 兜底: 非上次出生点(哪怕被占用)—— 全满时保证位置变化
	for (int i = 0; i < g_iSpawnCount; i++)
	{
		int idx = (g_iRoundRobin + i) % g_iSpawnCount;
		if (idx != last)
		{
			return idx;
		}
	}

	// 4) 只剩 1 个复活点: 无解
	return 0;
}

bool IsSpawnFree(int idx, int excludeClient)
{
	float now      = GetGameTime();
	float cooldown = g_cvCooldown.FloatValue;
	float radius   = g_cvRadius.FloatValue;
	if (radius < 0.0)
	{
		radius = 0.0;
	}

	// 时间层(对所有人): 最近被分配过(cooldown 内)→ 占用
	if (now - g_fUsedTime[idx] < cooldown)
	{
		return false;
	}

	// 位置层(只对真人): 半径内有"其他真人"→ 占用。bot 不参与, 避免静止 bot
	// 永久霸占复活点。
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i == excludeClient)
		{
			continue;
		}
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsFakeClient(i))
		{
			continue;
		}

		float origin[3];
		GetClientAbsOrigin(i, origin);
		if (GetVectorDistance(g_vSpawnOrigin[idx], origin, false) < radius)
		{
			return false;
		}
	}

	return true;
}
