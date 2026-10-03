#pragma semicolon 1

#include <sourcemod>
#include <admin>

public Plugin myinfo =
{
	name = "AdminCheats",
	author = "devicenull",
	description = "Allow admins to use cheat commands",
	version = "0.2",
	url = "http://www.sourcemod.net/"
};

#define MAX_COMMANDS 512
#define MAX_COMMAND_LENGTH 64

ConVar g_hCvarLevel;
ConVar g_hCvarVersion;

char g_CheatCommands[MAX_COMMANDS][MAX_COMMAND_LENGTH];
int g_CommandFlags[MAX_COMMANDS];
int g_NumCommands;

public void OnPluginStart()
{
	g_hCvarLevel = CreateConVar("sm_admin_cheats_level", "0", "Level required to execute cheat commands", FCVAR_PLUGIN | FCVAR_NOTIFY);
	g_hCvarVersion = CreateConVar("sm_admin_cheats_version", "0.2", "Version Information", FCVAR_PLUGIN | FCVAR_NOTIFY);

	LoadCheatCommands();
}

void LoadCheatCommands()
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/cheatcmds.txt");

	File hFile = OpenFile(path, "rt");

	if (hFile == null)
	{
		LogError("Unable to load cheat commands file %s", path);
		return;
	}

	char buffer[MAX_COMMAND_LENGTH];

	while (!hFile.EndOfFile() && ReadFileLine(hFile, buffer, sizeof(buffer)))
	{
		TrimString(buffer);

		if (buffer[0] == ';' || buffer[0] == '\0')
		{
			continue;
		}

		if (g_NumCommands >= MAX_COMMANDS)
		{
			LogError("[admincheats] WARNING: Too many cheat commands to hook them all, increase MAX_COMMANDS");
			break;
		}

		int flags = GetCommandFlags(buffer);

		if (flags & FCVAR_CHEAT)
		{
			g_CommandFlags[g_NumCommands] = flags;
			strcopy(g_CheatCommands[g_NumCommands], sizeof(g_CheatCommands[]), buffer);
			SetCommandFlags(buffer, flags & ~FCVAR_CHEAT);
			AddCommandListener(Listener_CheatCommand, buffer);
			g_NumCommands++;
		}
	}

	delete hFile;

	LogMessage("admincheats hooked %i commands", g_NumCommands);
}

public void OnPluginEnd()
{
	for (int i = 0; i < g_NumCommands; i++)
	{
		SetCommandFlags(g_CheatCommands[i], g_CommandFlags[i]);
	}

	LogMessage("admincheats unloaded, restoring cheat flags");
}

public Action Listener_CheatCommand(int client, const char[] command, int args)
{
	if (client == 0)
	{
		LogAction(client, -1, "CONSOLE ran cheat command '%s'", command);
		return Plugin_Continue;
	}

	if (IsClientInGame(client) && CanUseCheats(client))
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));

		char steamid[32];
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);

		LogAction(client, -1, "%s <%s> ran cheat command '%s'", name, steamid, command);
		return Plugin_Continue;
	}

	PrintToChat(client, " \x04[SM]\x01 was prevented from running cheat command '%s'", command);
	return Plugin_Handled;
}

bool CanUseCheats(int client)
{
	int level = g_hCvarLevel.IntValue;

	if (level == 0)
	{
		return true;
	}

	if (GetUserFlagBits(client) & level)
	{
		return true;
	}

	return false;
}
