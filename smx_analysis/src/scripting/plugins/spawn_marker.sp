#pragma semicolon 1
#pragma newdecls required

/*
 * spawn_marker.smx — 训练用「敌人复活点显著标记」插件(独立,不并入 BMAG)
 *
 * 只观测原生复活、绝不改动复活逻辑(无 DispatchSpawn / 不改队 / 无伤害),
 * 故不影响比赛公平性。默认关闭,管理员按次开启,用于单人(打 bot)或双人(打搭档)训练。
 *
 * 原理:原生复活链 player.cpp:5028 `CBasePlayer::Spawn` → `GetPlayerSpawnSpot`
 * (即 EntSelectSpawnPoint 挑 info_player_deathmatch)→ 发 `player_spawn` 事件。
 * 我们在事件里读 GetClientAbsOrigin(target) = 引擎最终选定的精确复活点,画标记。
 * 真人、bot 都走 Spawn(),所以都触发 player_spawn。
 *
 * 标记 = 红色垂直光柱 + 地面光圈 + 顶部辉光(临时实体,life 秒后消失)。
 * 另有 `sm_spawnmap` 全图出生点常显(练习记点位)。
 */

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0.0"

ConVar g_cvEnabled;
ConVar g_cvLife;
ConVar g_cvSpawnMap;

int g_iTarget = -1;   // 显式目标 client index(-1 = 自动探测)
int g_iAdmin  = -1;   // 最近一次命令发起者(供"另一人类"自动探测)

int g_iBeamSprite = -1;
int g_iHaloSprite = -1;
int g_iGlowSprite = -1;

int g_iSpawnPoints[512];  // info_player_deathmatch 的 EntRef
int g_iSpawnCount;
Handle g_hSpawnMapTimer;

static const int g_MarkerColor[4] = { 255, 64, 64, 255 };   // 红
static const int g_MapColor[4]    = { 80, 200, 255, 180 };  // 淡蓝(常显半透明)

public Plugin myinfo =
{
	name = "Spawn Marker (training)",
	author = "MXYLR",
	description = "Mark the enemy's respawn point for solo/duo training",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	CreateConVar("sm_spawnmarker_version", PLUGIN_VERSION, "spawn_marker version", FCVAR_DONTRECORD | FCVAR_NOTIFY);
	g_cvEnabled  = CreateConVar("sm_spawnmarker_enabled", "0", "Enable enemy respawn-point marking (0 = off)", FCVAR_NOTIFY);
	g_cvLife     = CreateConVar("sm_spawnmarker_life", "5.0", "Marker lifetime in seconds", FCVAR_NOTIFY);
	g_cvSpawnMap = CreateConVar("sm_spawnmarker_spawnmap", "0", "Persistently show all deathmatch spawn points", FCVAR_NOTIFY);

	HookEvent("player_spawn", Event_PlayerSpawn);

	LoadTranslations("spawn_marker.phrases");

	RegAdminCmd("sm_spawnmarker", Cmd_SpawnMarker, ADMFLAG_GENERIC, "Toggle enemy respawn marker / set target");
	RegAdminCmd("sm_sm", Cmd_SpawnMarker, ADMFLAG_GENERIC, "Alias for sm_spawnmarker");
	RegAdminCmd("sm_spawnmap", Cmd_SpawnMap, ADMFLAG_GENERIC, "Toggle persistent spawn-point map");
}

public void OnMapStart()
{
	PrecacheSprites();

	// 换图:旧 timer 已被引擎杀死,旧 EntRef 全部失效
	g_hSpawnMapTimer = null;
	g_iSpawnCount = 0;
	RefreshSpawnPoints();

	if (g_cvSpawnMap.BoolValue)
	{
		g_hSpawnMapTimer = CreateTimer(1.0, Timer_SpawnMap, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnClientDisconnect(int client)
{
	if (client == g_iTarget)
	{
		g_iTarget = -1;
	}
}

// ---------------------------------------------------------------- 目标解析

int ResolveTarget()
{
	// 显式目标仍在线
	if (g_iTarget >= 1 && g_iTarget <= MaxClients && IsClientInGame(g_iTarget))
	{
		return g_iTarget;
	}

	// 自动:第一个 bot(单人训练)
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
		{
			return i;
		}
	}

	// 自动:双人训练,取与命令发起者不同的那个人类
	int admin = (g_iAdmin >= 1 && g_iAdmin <= MaxClients && IsClientInGame(g_iAdmin)) ? g_iAdmin : -1;
	int humanCount = 0;
	int otherHuman = -1;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			humanCount++;
			if (i != admin)
			{
				otherHuman = i;
			}
		}
	}
	if (humanCount == 2 && admin != -1 && otherHuman != -1)
	{
		return otherHuman;
	}

	return -1;
}

int FirstBot()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
		{
			return i;
		}
	}
	return -1;
}

// ---------------------------------------------------------------- 复活事件

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cvEnabled.BoolValue)
	{
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	if (client != ResolveTarget())
	{
		return;
	}

	float origin[3];
	GetClientAbsOrigin(client, origin);
	DrawMarker(origin, g_MarkerColor);

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	PrintToChatAll("%t", "spm_spawned", sName);
}

// ---------------------------------------------------------------- 标记绘制

void PrecacheSprites()
{
	g_iBeamSprite = PrecacheSprite("sprites/laser.vmt", "sprites/laserbeam.vmt");
	g_iHaloSprite = PrecacheSprite("sprites/halo01.vmt", "sprites/glow01.vmt");
	g_iGlowSprite = PrecacheSprite("sprites/blueglow2.vmt", "sprites/glow01.vmt");
}

int PrecacheSprite(const char[] primary, const char[] fallback)
{
	int idx = PrecacheModel(primary, true);
	if (idx <= 0)
	{
		idx = PrecacheModel(fallback, true);
	}
	return idx;
}

void DrawMarker(float origin[3], const int color[4])
{
	float life = g_cvLife.FloatValue;
	if (life <= 0.0)
	{
		life = 5.0;
	}

	float top[3];
	float base[3];
	float glow[3];
	top[0] = origin[0];  top[1] = origin[1];  top[2] = origin[2] + 400.0;
	base[0] = origin[0]; base[1] = origin[1]; base[2] = origin[2] + 16.0;
	glow[0] = origin[0]; glow[1] = origin[1]; glow[2] = origin[2] + 48.0;

	// 垂直光柱
	if (g_iBeamSprite > 0)
	{
		TE_SetupBeamPoints(top, base, g_iBeamSprite, 0, 0, 0, life, 8.0, 8.0, 0, 0.0, color, 0);
		TE_SendToAll();
	}

	// 地面光圈
	if (g_iBeamSprite > 0 && g_iHaloSprite > 0)
	{
		TE_SetupBeamRingPoint(base, 10.0, 80.0, g_iBeamSprite, g_iHaloSprite, 0, 10, life, 10.0, 0.0, color, 10, 0);
		TE_SendToAll();
	}

	// 顶部辉光
	if (g_iGlowSprite > 0)
	{
		TE_SetupGlowSprite(glow, g_iGlowSprite, life, 1.5, 255);
		TE_SendToAll();
	}
}

// ---------------------------------------------------------------- 全图出生点常显

void RefreshSpawnPoints()
{
	g_iSpawnCount = 0;

	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "info_player_deathmatch")) != -1)
	{
		if (g_iSpawnCount < sizeof(g_iSpawnPoints))
		{
			g_iSpawnPoints[g_iSpawnCount++] = EntIndexToEntRef(ent);
		}
	}
}

public Action Timer_SpawnMap(Handle timer)
{
	for (int i = 0; i < g_iSpawnCount; i++)
	{
		int ent = EntRefToEntIndex(g_iSpawnPoints[i]);
		if (ent == INVALID_ENT_REFERENCE)
		{
			continue;
		}

		float origin[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
		DrawSmallMarker(origin);
	}

	return Plugin_Continue;
}

void DrawSmallMarker(float origin[3])
{
	float base[3];
	float glow[3];
	base[0] = origin[0]; base[1] = origin[1]; base[2] = origin[2] + 8.0;
	glow[0] = origin[0]; glow[1] = origin[1]; glow[2] = origin[2] + 24.0;

	if (g_iBeamSprite > 0 && g_iHaloSprite > 0)
	{
		TE_SetupBeamRingPoint(base, 6.0, 20.0, g_iBeamSprite, g_iHaloSprite, 0, 5, 1.0, 4.0, 0.0, g_MapColor, 5, 0);
		TE_SendToAll();
	}

	if (g_iGlowSprite > 0)
	{
		TE_SetupGlowSprite(glow, g_iGlowSprite, 1.0, 0.6, 160);
		TE_SendToAll();
	}
}

void SetSpawnMap(bool on)
{
	g_cvSpawnMap.SetInt(on ? 1 : 0);

	if (on)
	{
		RefreshSpawnPoints();
		if (g_hSpawnMapTimer == null)
		{
			g_hSpawnMapTimer = CreateTimer(1.0, Timer_SpawnMap, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	else
	{
		if (g_hSpawnMapTimer != null)
		{
			KillTimer(g_hSpawnMapTimer);
			g_hSpawnMapTimer = null;
		}
	}
}

// ---------------------------------------------------------------- 命令

public Action Cmd_SpawnMarker(int client, int args)
{
	g_iAdmin = client;

	char arg[64];
	arg[0] = '\0';
	if (args >= 1)
	{
		GetCmdArg(1, arg, sizeof(arg));
	}

	if (arg[0] == '\0')
	{
		ReportStatus(client);
		return Plugin_Handled;
	}

	if (StrEqual(arg, "on", false) || StrEqual(arg, "1", false) || StrEqual(arg, "enable", false))
	{
		g_cvEnabled.SetInt(1);
		PrintToChat(client, "%t", "spm_on");
		return Plugin_Handled;
	}

	if (StrEqual(arg, "off", false) || StrEqual(arg, "0", false) || StrEqual(arg, "disable", false))
	{
		g_cvEnabled.SetInt(0);
		PrintToChat(client, "%t", "spm_off");
		return Plugin_Handled;
	}

	if (StrEqual(arg, "none", false) || StrEqual(arg, "clear", false))
	{
		g_iTarget = -1;
		PrintToChat(client, "%t", "spm_target_auto");
		return Plugin_Handled;
	}

	// bot 别名(@bot/@bots 不是单目标 token,手动取第一个 bot)
	if (StrEqual(arg, "bot", false) || StrEqual(arg, "@bot", false) || StrEqual(arg, "@bots", false))
	{
		int bot = FirstBot();
		if (bot == -1)
		{
			PrintToChat(client, "%t", "spm_target_none");
			return Plugin_Handled;
		}
		g_iTarget = bot;
		char bname[MAX_NAME_LENGTH];
		GetClientName(bot, bname, sizeof(bname));
		PrintToChat(client, "%t", "spm_target_set", bname);
		return Plugin_Handled;
	}

	// 按名字 / #userid 解析单个目标(允许 bot、允许死亡态)
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg, client, target_list, MAXPLAYERS,
			COMMAND_FILTER_NO_MULTI,
			target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	g_iTarget = target_list[0];
	char tname[MAX_NAME_LENGTH];
	GetClientName(g_iTarget, tname, sizeof(tname));
	PrintToChat(client, "%t", "spm_target_set", tname);
	return Plugin_Handled;
}

public Action Cmd_SpawnMap(int client, int args)
{
	g_iAdmin = client;

	bool on = !g_cvSpawnMap.BoolValue;
	SetSpawnMap(on);

	if (on)
	{
		if (g_iSpawnCount == 0)
		{
			PrintToChat(client, "%t", "spm_map_none");
		}
		else
		{
			PrintToChat(client, "%t", "spm_map_on", g_iSpawnCount);
		}
	}
	else
	{
		PrintToChat(client, "%t", "spm_map_off");
	}

	return Plugin_Handled;
}

void ReportStatus(int client)
{
	if (g_cvEnabled.BoolValue)
	{
		PrintToChat(client, "%t", "spm_on");
	}
	else
	{
		PrintToChat(client, "%t", "spm_off");
	}

	int target = ResolveTarget();
	if (target != -1)
	{
		char tname[MAX_NAME_LENGTH];
		GetClientName(target, tname, sizeof(tname));
		PrintToChat(client, "%t", "spm_target_set", tname);
	}
	else
	{
		PrintToChat(client, "%t", "spm_target_auto");
	}

	PrintToChat(client, "%t", "spm_usage");
}
