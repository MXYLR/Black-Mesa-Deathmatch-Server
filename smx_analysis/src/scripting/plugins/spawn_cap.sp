#pragma semicolon 1
#pragma newdecls required

/*
 * spawn_cap.sp — 复活点上限守卫
 *
 * 根因(2026-08-28 逆向实锤): 玩家数(含 bot) > 地图复活点数 时, BM 的
 * CHL2MP_Player::EntSelectSpawnPoint 遍历所有 info_player_deathmatch 都因
 * IsSpawnPointValid(128 半径内有其他玩家)返回 false; 原版 HL2DM 的"击杀第一个
 * 复活点玩家清场"回退在 BM 2026 里是一条死代码(该回退前有 [player+0x1f4]==1 的
 * 门, 且无有效空位时 spawn 选择失败)。于是玩家没被传送到复活点 → 原地复活、
 * 掉落武器累积(刷武器)、反复 spawn 失败(卡顿)。见 REVERSE_RESPAWN.md。
 *
 * 修法: 地图加载后统计 info_player_deathmatch(FFA)/info_player_start(兜底)
 * 复活点数, 若(真人 + bot)超过上限(复活点数 - 预留空位), 自动移除多余的 bot
 * (bot 可舍弃); 真人超员只告警不踢。
 */

#include <sourcemod>
#include <sdktools>

ConVar g_cvEnabled;
ConVar g_cvReserve;

public void OnPluginStart()
{
	CreateConVar("spawn_cap_version", "1.0.0", "spawn_cap version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cvEnabled = CreateConVar("spawn_cap_enabled", "1", "启用复活点上限守卫(1=玩家+bot 不得超过复活点数)", FCVAR_NOTIFY);
	g_cvReserve  = CreateConVar("spawn_cap_reserve", "1", "预留空位: 玩家+bot 上限 = 复活点数 - 该值(避免占满导致零秒重生瞬时争抢)", FCVAR_NOTIFY);
}

public void OnMapStart()
{
	// 实体全部 spawn 后再统计+执行(OnMapStart 时地图实体可能尚未全部创建)
	CreateTimer(1.0, Timer_Enforce, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientPutInServer(int client)
{
	// 中途 bot_add 加 bot 也实时兜底(下一帧再判, 避免与连接流程竞争)
	RequestFrame(Frame_Enforce);
}

int CountSpawnPoints()
{
	int count = 0;
	int ent = -1;

	while ((ent = FindEntityByClassname(ent, "info_player_deathmatch")) != -1)
	{
		count++;
	}

	// 某些地图/模式没有 deathmatch 复活点, 退回 info_player_start
	if (count == 0)
	{
		ent = -1;
		while ((ent = FindEntityByClassname(ent, "info_player_start")) != -1)
		{
			count++;
		}
	}

	return count;
}

int CountClients()
{
	int count = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		// SourceTV / Replay 是旁观者, 不占复活点, 也不该被踢; 只统计真人 + bot
		if (IsClientInGame(i) && !IsClientSourceTV(i) && !IsClientReplay(i))
		{
			count++;
		}
	}

	return count;
}

bool IsRealBot(int client)
{
	// IsFakeClient 对 SourceTV / Replay 也返回 true, 必须再排除它们
	// (踢 SourceTV 会让服务器崩溃)
	return IsClientInGame(client) && IsFakeClient(client)
		&& !IsClientSourceTV(client) && !IsClientReplay(client);
}

void EnforceCap()
{
	if (!g_cvEnabled.BoolValue)
	{
		return;
	}

	int spawns = CountSpawnPoints();
	if (spawns <= 0)
	{
		// 无法统计(地图没复活点), 不干预
		return;
	}

	int reserve = g_cvReserve.IntValue;
	if (reserve < 0)
	{
		reserve = 0;
	}

	int cap = spawns - reserve;
	if (cap < 1)
	{
		cap = 1;
	}

	int clients = CountClients();
	if (clients <= cap)
	{
		return;
	}

	int toKick = clients - cap;

	// 优先踢 bot(绝不动 SourceTV/Replay/真人)
	for (int i = 1; i <= MaxClients && toKick > 0; i++)
	{
		if (IsRealBot(i))
		{
			KickClient(i, "地图复活点不足, 自动移除多余 bot");
			toKick--;
		}
	}

	if (toKick > 0)
	{
		LogMessage("[spawn_cap] 警告: 真人超员 %d 人(复活点 %d, 上限 %d), 请减少人数", toKick, spawns, cap);
	}
	else
	{
		LogMessage("[spawn_cap] 复活点 %d, 上限 %d, 已移除 %d 个多余 bot", spawns, cap, clients - cap);
	}
}

void Frame_Enforce(any data)
{
	EnforceCap();
}

public Action Timer_Enforce(Handle timer)
{
	EnforceCap();
	return Plugin_Continue;
}
