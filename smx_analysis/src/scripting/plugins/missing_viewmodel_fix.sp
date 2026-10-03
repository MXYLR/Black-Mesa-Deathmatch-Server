#pragma semicolon 1

#include <sourcemod>
#define CS_TEAM_SPECTATOR 1

public Plugin myinfo =
{
	name = "Missing ViewModel Fix",
	author = "ch4os + SHUFEN from POSSESSION.tokyo",
	description = "Prevents missing viewmodel when being spectated",
	version = "1.1",
	url = "https://forums.alliedmods.net/"
};

bool g_bSpecJoinPending[MAXPLAYERS + 1];

public void OnPluginStart()
{
	AddCommandListener(Command_SpecMode, "client_specmode");
	AddCommandListener(Command_JoinTeam, "jointeam");

	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
}

public void OnClientDisconnect(int client)
{
	g_bSpecJoinPending[client] = false;
}

public Action Command_JoinTeam(int client, const char[] command, int args)
{
	// BM 2026: the client "cl_spec_mode 6" → "client_specmode 6" echo this
	// interception depended on never completes (the client never echoes the
	// command back), so every jointeam 1 (spectator entry) was permanently
	// blocked. Neutered - jointeam now flows to the engine's own
	// HandleCommand_JoinTeam path (mp_allowspectators gate + ChangeTeam);
	// bms_match's Bms_ListenCmd_Team owns the match-side team gates. Module
	// stays in the merge list as a skeleton so the merged build is unchanged.
	return Plugin_Continue;
}

public Action Command_SpecMode(int client, const char[] command, int args)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	if (!g_bSpecJoinPending[client])
	{
		return Plugin_Continue;
	}

	char arg[4];
	GetCmdArg(1, arg, sizeof(arg));

	if (StringToInt(arg) == 6)
	{
		g_bSpecJoinPending[client] = false;
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client && IsClientInGame(client))
	{
		g_bSpecJoinPending[client] = false;
	}

	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client && IsClientInGame(client))
	{
		g_bSpecJoinPending[client] = false;
	}

	return Plugin_Continue;
}
