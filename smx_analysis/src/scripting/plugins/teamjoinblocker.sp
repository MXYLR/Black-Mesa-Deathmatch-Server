#include <sourcemod>

public Plugin myinfo =
{
	name = "[ANY] Team Join Blocker",
	author = "sekm",
	description = "Toggles team joining.",
	version = "1.0",
	url = "https://steamcommunity.com/id/h5r/"
};

#define CHAT_PREFIX " \x04[TJB]\x01"

bool g_bCanJoin;

public void OnPluginStart()
{
	RegAdminCmd("sm_toggle_join", Command_ToggleJoin, ADMFLAG_KICK);
	RegAdminCmd("sm_a", Command_OpenAdminMenu, ADMFLAG_KICK);

	AddCommandListener(Command_BlockTeamJoin, "jointeam");
}

public void OnMapStart()
{
	g_bCanJoin = true;
}

public Action Command_ToggleJoin(int iClient, int iArgs)
{
	g_bCanJoin =! g_bCanJoin;

	PrintToChatAll("%s ADMIN: \x0E%N\x01 has %s \x01team join.", CHAT_PREFIX, iClient, g_bCanJoin ? "\x04enabled" : "\x02disabled");
	return Plugin_Handled;
}

public Action Command_OpenAdminMenu(int iClient, int iArgs)
{
	FakeClientCommandEx(iClient, "sm_admin");
	return Plugin_Handled;
}

public Action Command_BlockTeamJoin(int iClient, const char[] sName, int iArgs)
{
	switch (g_bCanJoin)
	{
		case false:
		{
			PrintToChat(iClient, "%s Team join is \x02disabled\x01.", CHAT_PREFIX);
			return Plugin_Stop;
		}
		case true:
		{
			return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}