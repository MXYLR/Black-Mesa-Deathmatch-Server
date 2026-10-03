#pragma semicolon 1

#include <sourcemod>

public Plugin myinfo =
{
	name = "[Any?] Pause The Game",
	author = "Derek D. Howard (ddhoward)",
	description = "Lets admins pause the game.",
	version = "18.0114.0",
	url = "https://forums.alliedmods.net/showthread.php?t=263461"
};

ConVar g_hCvarSvPausable;

bool g_bPaused;
bool g_bPauseCmdHooked;
bool g_bConsoleUsedCommand;

public void OnPluginStart()
{
	g_hCvarSvPausable = FindConVar("sv_pausable");

	if (g_hCvarSvPausable == null)
	{
		LogError("pause.smx: Unable to find cvar sv_pausable");
		return;
	}

	HookConVarChange(g_hCvarSvPausable, OnSvPausableChange);

	if (AddCommandListener(listener_pause, "pause"))
	{
		g_bPauseCmdHooked = true;
	}
	else
	{
		LogError("UNABLE TO HOOK pause COMMAND, THIS PLUGIN IS NOT RECOMMENDED FOR THIS GAME.");
	}

	RegAdminCmd("sm_pause", Cmd_pause, ADMFLAG_GENERIC);
	RegAdminCmd("sm_setpause", Cmd_setpause, ADMFLAG_GENERIC);
	RegAdminCmd("sm_unpause", Cmd_unpause, ADMFLAG_GENERIC);
}

public void OnSvPausableChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, "1") && StrEqual(newValue, "0") && g_bPaused)
	{
		ServerCommand("pause");
	}
}

public Action listener_pause(int client, const char[] command, int args)
{
	if (client == 0)
	{
		if (g_bConsoleUsedCommand)
		{
			g_bConsoleUsedCommand = false;
		}
		else
		{
			g_bPaused = !g_bPaused;
		}
	}

	return Plugin_Continue;
}

public Action Cmd_pause(int client, int args)
{
	if (g_bPaused)
	{
		ReplyToCommand(client, "[SM] The game is already paused.");
		return Plugin_Handled;
	}

	return Cmd_pauseUnpause(client, true);
}

public Action Cmd_unpause(int client, int args)
{
	if (!g_bPaused)
	{
		ReplyToCommand(client, "[SM] The game is already unpaused.");
		return Plugin_Handled;
	}

	return Cmd_pauseUnpause(client, false);
}

public Action Cmd_setpause(int client, int args)
{
	return Cmd_pauseUnpause(client, !g_bPaused);
}

Action Cmd_pauseUnpause(int client, bool pause)
{
	if (g_hCvarSvPausable == null || !GetConVarBool(g_hCvarSvPausable))
	{
		ReplyToCommand(client, "[SM] Pausing the game is currently disabled.");
		return Plugin_Handled;
	}

	if (!IsPlayerPresent())
	{
		ReplyToCommand(client, "[SM] Cannot pause/unpause the game while no players are present.");
		return Plugin_Handled;
	}

	if (!CheckCommandAccess(client, "sm_pause", ADMFLAG_GENERIC))
	{
		ReplyToCommand(client, "[SM] You do not have permission to pause/unpause the game.");
		return Plugin_Handled;
	}

	if (pause)
	{
		g_bPaused = true;
		g_bConsoleUsedCommand = true;
		ServerCommand("pause");
		ShowActivity2(client, "[SM] ", "Paused the game");
	}
	else
	{
		g_bPaused = false;
		g_bConsoleUsedCommand = true;
		ServerCommand("unpause");
		ShowActivity2(client, "[SM] ", "Unpaused the game");
	}

	return Plugin_Handled;
}

bool IsPlayerPresent()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			return true;
		}
	}

	return false;
}
