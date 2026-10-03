#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
	name = "fastspawn for players",
	author = "Alienmario",
	description = "Enables player respawn [sm_fastspawn_time] seconds after death",
	version = "1.0.0",
	url = "https://forums.alliedmods.net/"
};

ConVar g_hEnabled;
ConVar g_hRespawnTime;
ConVar g_hBatch;

float g_fDeathTime[MAXPLAYERS + 1];
int g_iBatchTick = -1;
int g_iBatchCount;

// 当前地图是不是单人战役: -1 = 还没判定, 0 = 不是, 1 = 是。见 FS_Campaign()。
int g_iMapCampaign = -1;

public void OnPluginStart()
{
	g_hEnabled = CreateConVar("sm_fastspawn", "1", "Enables player respawn [sm_fastspawn_time] seconds after death", FCVAR_NOTIFY);
	g_hRespawnTime = CreateConVar("sm_fastspawn_time", "0.0", "Sets how long to wait until player can respawn (0 = instant)", FCVAR_NOTIFY);
	g_hBatch = CreateConVar("sm_fastspawn_batch", "4", "Max players respawned per game tick (stagger burst respawns; lower = smoother but slower)", FCVAR_NOTIFY);

	HookEvent("player_death", Event_Death);
	HookEvent("player_spawn", Event_PlayerSpawn);

	AutoExecConfig(true, "fastspawn");
	LoadTranslations("fast_spawn.phrases");
	// NOTE: the console command is "fastspawn" (not sm_fastspawn) - the engine
	// refuses to link a cfg-set ConVar whose name is also a ConCommand
	// ("unable to link sm_fastspawn and sm_fastspawn because one or more is a
	// ConCommand"), which made server.cfg settings for the cvar unreliable.
	RegConsoleCmd("fastspawn", Cmd_FastSpawn, "Query or toggle fast spawn (admins)");
	RegConsoleCmd("sm_fs", Cmd_FastSpawn, "Query or toggle fast spawn (admins)");
}

public void OnConfigsExecuted()
{
	// 强制零秒重生:任何 cfg 的执行顺序/内容都无法把它改回非零。
	g_hRespawnTime.SetFloat(0.0);
}

// --------------------------------------------------------------- 单人战役判定
//
// 这套插件原本只为死亡竞赛写, 但同一个 SourceMod 装在两个环境里跑
// (单人战役 listen server + 死亡服), 而 fast_spawn 的每条行为都只在 DM 下成立:
//
//   * 单人战役里死亡 = 读档, 不是重生。零秒重生会把玩家从刚读的档里拽出来,
//     剥武器更会直接毁掉手上的装备。
//   * FS_OnTakeDamage 的「致死前先剥武器」是为 DM 的武器掉落问题写的。BMAG 与
//     tau_mp 都挂 SDKHook_OnTakeDamage, 回调按 SDKHook() 注册顺序=插件加载顺序
//     执行, 而 BMAG 字母序在前 → 它看到的是**未经 tau_mp 跌落伤害封顶**的原始
//     伤害。于是「高空落地本来最多只掉 10 HP」被 BMAG 判成致死, 武器先被
//     RemoveEntity 掉, tau_mp 再把伤害压到 10 → 玩家活着但两手空空。
//     实测现象就是「跌落伤害过大致死时武器模型消失」。
//
// 判据: 战役地图全部形如 bm_c<数字>*(bm_c0a0a … bm_c5a1a); DM 侧地图是
// dm_*/de_*/bm_bunnyrace_beta2, **没有任何地图以 bm_c<数字> 开头**, 所以前缀
// 匹配安全。判定写错时默认偏向 DM(即保留本插件原有行为)。
bool FS_Campaign()
{
	if (g_iMapCampaign == -1)
	{
		char sMap[PLATFORM_MAX_PATH];
		GetCurrentMap(sMap, sizeof(sMap));

		g_iMapCampaign = (strncmp(sMap, "bm_c", 4) == 0
			&& sMap[4] >= '0' && sMap[4] <= '9') ? 1 : 0;

		LogMessage("[fast_spawn] map \"%s\" -> %s", sMap, g_iMapCampaign
			? "singleplayer campaign: fast spawn disabled"
			: "deathmatch: fast spawn enabled");
	}

	return g_iMapCampaign == 1;
}

// 所有 fast_spawn 行为的统一闸门: cvar 开着 **且** 不在战役地图里。
bool FS_Active()
{
	return g_hEnabled.BoolValue && !FS_Campaign();
}

public Action Cmd_FastSpawn(int client, int args)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	char sArg[16];
	if (args >= 1)
	{
		GetCmdArg(1, sArg, sizeof(sArg));
	}

	// bare command: report current state to anyone
	if (!strlen(sArg))
	{
		if (g_hEnabled.BoolValue)
		{
			PrintToChat(client, "%t", "fs_status_on", g_hRespawnTime.FloatValue);
		}
		else
		{
			PrintToChat(client, "%t", "fs_status_off");
		}
		PrintToChat(client, "%t", "fs_usage");
		return Plugin_Handled;
	}

	if (!CheckCommandAccess(client, "fastspawn", ADMFLAG_GENERIC, true))
	{
		PrintToChat(client, "%t", "fs_no_admin");
		return Plugin_Handled;
	}

	bool bNew;
	if (StrEqual(sArg, "on", false) || StrEqual(sArg, "1", false) || StrEqual(sArg, "enable", false))
	{
		bNew = true;
	}
	else if (StrEqual(sArg, "off", false) || StrEqual(sArg, "0", false) || StrEqual(sArg, "disable", false))
	{
		bNew = false;
	}
	else if (StrEqual(sArg, "toggle", false))
	{
		bNew = !g_hEnabled.BoolValue;
	}
	else
	{
		PrintToChat(client, "%t", "fs_usage");
		return Plugin_Handled;
	}

	if (bNew == g_hEnabled.BoolValue)
	{
		if (g_hEnabled.BoolValue)
		{
			PrintToChat(client, "%t", "fs_status_on", g_hRespawnTime.FloatValue);
		}
		else
		{
			PrintToChat(client, "%t", "fs_status_off");
		}
		return Plugin_Handled;
	}

	g_hEnabled.SetInt(bNew ? 1 : 0);

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	PrintToChatAll("%t", bNew ? "fs_changed_on" : "fs_changed_off", sName);

	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	g_fDeathTime[client] = 0.0;
	SDKHook(client, SDKHook_OnTakeDamage, FS_OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	g_fDeathTime[client] = 0.0;
}

public Action Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client && IsClientInGame(client))
	{
		g_fDeathTime[client] = GetGameTime();
	}

	return Plugin_Continue;
}

// 重生刷默认装备时武器有几率掉地上的根因: GiveDefaultItems 在 player_spawn 之后
// (CHL2MP_Player::Spawn 里 BaseClass::Spawn() 返回后才调)刷武器, 走
// GiveNamedItem → DispatchSpawn → 武器 Spawn(FallInit) → Touch(this) →
// DefaultTouch → CHL2MP_Player::BumpWeapon。BumpWeapon 里有一道视线门:
//   if (!pWeapon->FVisible(this, MASK_SOLID) && !(GetFlags() & FL_NOTARGET))
//       return false;
// 当玩家被 spawn_distribute 传到静止 bot 身上(其位置占用判定刻意排除 bot, 见
// spawn_distribute.sp), 武器出生在 bot 的 bbox 里 → FVisible 从武器中心到玩家
// 眼睛的 trace 被 bot 挡住(startsolid)→ 返回 false → BumpWeapon 拒绝装备 →
// FallInit 的 FallThink 把武器掉到地上(有几率, 取决于是否恰好叠到 bot)。
// 其余门(IsAllowedToPickupWeapons/pOwner/Weapon_CanUse/CanHavePlayerItem)经
// 源码核对全部恒真, FVisible 是唯一会间歇失败的门。
// 修法: player_spawn 先于 GiveDefaultItems, 在这里给玩家挂 FL_NOTARGET, 使上面的
// 门第二项 !(FL_NOTARGET) 为 false → 整条门为 false → 绕过 FVisible 直接装备;
// 下一帧 RequestFrame 再清掉。FL_NOTARGET 只影响这一帧的视线/AI 判定, HL2MP
// 无 NPC 敌人(全是玩家), 无副作用。仅在 FS_Active() 为真时生效(与死亡前剥武器
// 的 FS_OnTakeDamage 一致; 比赛期 bms_match 置 sm_fastspawn=0, 单人战役由
// FS_Campaign() 关掉, 两种情况都不干预)。
public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!FS_Active())
	{
		return Plugin_Continue;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	SetEntityFlags(client, GetEntityFlags(client) | FL_NOTARGET);
	RequestFrame(FS_ClearNoTarget, GetClientUserId(client));

	return Plugin_Continue;
}

void FS_ClearNoTarget(any iUserID)
{
	int client = GetClientOfUserId(view_as<int>(iUserID));
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	SetEntityFlags(client, GetEntityFlags(client) & ~FL_NOTARGET);
}

// 致命一击到达时(在 CBaseCombatCharacter::Event_Killed 把 m_hActiveWeapon 掉到
// 地上之前)剥掉受害者全部武器, 让武器"被移除"而不是"被掉落"。根因: HL2DM 原生
// 死亡流程 Event_Killed 会调用 Weapon_Drop(m_hActiveWeapon)(basecombatcharacter.cpp),
// 0 秒重生下每次死亡都掉一把主动武器堆在地上, 直到 adv_weapon_cleaner 每 10s
// sweep 才清掉。这里在死亡前(OnTakeDamage 先于 Event_Killed)把武器剥光, 死亡时
// m_hActiveWeapon 已是 NULL → Weapon_Drop 空转 → 不落地。顺带修掉"非主动武器跨
// 死亡被保留"(PlayerDeathThink 被 Spawn 的 SetThink(NULL) 取消、RemoveAllItems
// 没跑)的问题, 让重生回到 HL2DM 正常语义: 死后武器清空、重生刷默认装备。
// 只在 FS_Active() 为真时生效 —— 比赛期 bms_match 把 sm_fastspawn 置 0(保留正常
// 掉落/拾取), 单人战役由 FS_Campaign() 关掉(这条剥武器正是「跌落致死时武器模型
// 消失」的元凶: 它在 tau_mp 把跌落伤害压到 10 HP 之前就判了致死)。
public Action FS_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!FS_Active())
	{
		return Plugin_Continue;
	}

	if (victim < 1 || victim > MaxClients || !IsClientInGame(victim))
	{
		return Plugin_Continue;
	}

	if (!IsPlayerAlive(victim))
	{
		return Plugin_Continue;
	}

	// BM DM 玩家出生无护甲(EquipSuit 只置 m_bWearingSuit, hl2mp 代码里从未给
	// m_ArmorValue 赋值), 所以 damage >= health 就是精确的致死判定, 无需考虑
	// HEV 减伤。
	if (damage >= float(GetClientHealth(victim)))
	{
		FS_StripWeapons(victim);
	}

	return Plugin_Continue;
}

void FS_StripWeapons(int client)
{
	for (int slot = 0; slot <= 5; slot++)
	{
		int weapon;
		while ((weapon = GetPlayerWeaponSlot(client, slot)) != -1)
		{
			RemovePlayerItem(client, weapon);
			RemoveEntity(weapon);
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!FS_Active())
	{
		return Plugin_Continue;
	}

	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	if (!FS_IsRespawnEligible(client))
	{
		return Plugin_Continue;
	}

	if (g_fDeathTime[client] > 0.0 && GetGameTime() - g_fDeathTime[client] >= g_hRespawnTime.FloatValue)
	{
		// Stagger burst respawns: at most sm_fastspawn_batch players respawn per
		// game tick. A kill burst (many deaths in one tick) would otherwise fire
		// N DispatchSpawn calls in a single tick and spike the server. Deferred
		// players keep their death time and retry on the next tick.
		int iTick = GetGameTickCount();
		int iBatch = g_hBatch.IntValue;

		if (iBatch <= 0)
		{
			iBatch = 1;
		}

		if (iTick != g_iBatchTick)
		{
			g_iBatchTick = iTick;
			g_iBatchCount = 0;
		}

		if (g_iBatchCount >= iBatch)
		{
			return Plugin_Continue;
		}

		g_iBatchCount++;
		g_fDeathTime[client] = 0.0;
		// Defer the real DispatchSpawn to a frame boundary. Calling Spawn()
		// re-entrantly from OnPlayerRunCmd (i.e. inside PhysicsSimulate /
		// PlayerRunCommand) makes the death->alive transition land in the same
		// client update as the death, so the client interpolates back to the
		// death origin instead of snapping to the spawn point ("respawn in
		// place"), and the whole loadout give runs mid-movement (lag / weapon
		// spawn spam). RequestFrame runs at the start of the next frame,
		// outside the movement loop.
		RequestFrame(FS_RespawnFrame, GetClientUserId(client));
	}

	return Plugin_Continue;
}

// Deferred respawn target for human players (see OnPlayerRunCmd). Runs at a
// frame boundary, outside PlayerRunCommand/PhysicsSimulate, so Spawn() is not
// re-entrant. Re-validate eligibility: the player may have died again,
// disconnected, or been respawned by another plugin in the meantime.
void FS_RespawnFrame(any iUserID)
{
	int client = GetClientOfUserId(view_as<int>(iUserID));

	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	if (!FS_IsRespawnEligible(client))
	{
		return;
	}

	DispatchSpawn(client);
}

public void OnMapStart()
{
	// 换图后判据要重算(缓存跨图会错判)
	g_iMapCampaign = -1;

	// Server-side bots never fire OnPlayerRunCmd (they call PlayerRunCommand
	// directly, bypassing the engine's RunPlayerMove - cf. hl2mp_bot_temp.cpp),
	// so poll them on a timer for instant respawns as well.
	CreateTimer(0.1, Timer_RespawnBots, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RespawnBots(Handle timer)
{
	if (!FS_Active())
	{
		return Plugin_Continue;
	}

	// Batch-cap bot respawns the same way human respawns are capped, so a burst
	// of bot deaths can't all DispatchSpawn in the same timer tick either.
	int iBatch = g_hBatch.IntValue;

	if (iBatch <= 0)
	{
		iBatch = 1;
	}

	int iSpawned = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (iSpawned >= iBatch)
		{
			break;
		}

		if (!IsClientInGame(i) || !IsFakeClient(i) || !FS_IsRespawnEligible(i))
		{
			continue;
		}

		if (g_fDeathTime[i] > 0.0 && GetGameTime() - g_fDeathTime[i] >= g_hRespawnTime.FloatValue)
		{
			g_fDeathTime[i] = 0.0;
			DispatchSpawn(i);
			iSpawned++;
		}
	}

	return Plugin_Continue;
}

// Dead players keep their team in BM DM (hl2mp semantics: participants are
// team 0 in FFA, voluntary/forced spectators are moved to team 1 by
// ChangeTeam and never die). The original check (GetClientTeam <= 1, CS
// semantics where team 0 = unassigned/spectator) blocked every dead
// participant on team 0 - instant respawn never fired for anyone.
bool FS_IsRespawnEligible(int client)
{
	if (IsPlayerAlive(client))
	{
		return false;
	}

	if (GetClientTeam(client) == 1)
	{
		return false;
	}

	// 主动观战(FIXED=3/IN_EYE=4/CHASE=5/POI=6/ROAMING=7)不允许被零秒重生
	// 拉回比赛;死亡镜头(DEATHCAM=1/FREEZECAM=2)是临死瞬间的过渡状态,
	// 仍走零秒重生。
	if (GetEntProp(client, Prop_Send, "m_iObserverMode") >= 3)
	{
		return false;
	}

	return true;
}
