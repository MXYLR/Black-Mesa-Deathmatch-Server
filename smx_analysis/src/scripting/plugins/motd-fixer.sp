#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>

public Plugin myinfo =
{
	name = "[BM] MOTD Fixer",
	author = "Drixevel",
	description = "Attempts to fix the MOTD system in Black Mesa.",
	version = "1.0.0",
	url = "https://drixevel.dev/"
};

ConVar convar_Enabled;
ConVar convar_Time;

Handle g_hClientCookie;

bool g_bClientPreference[MAXPLAYERS + 1];

public void OnPluginStart()
{
	CreateConVar("sm_motd_fixer_version", "1.0.0", "Version control for this plugin.", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_motd_fixer_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY);
	convar_Time = CreateConVar("sm_motd_fixer_time", "2.0", "How long should the delay be to open the MOTD?", FCVAR_NOTIFY);

	RegConsoleCmd("sm_motd", Command_MOTD);
	RegConsoleCmd("sm_url", Command_MOTD);

	g_hClientCookie = RegClientCookie("motd_fixer_show_motd", "Show MOTD on Connect", CookieAccess_Public);

	SetCookieMenuItem(CookieMenuHandler_MOTD, 0, "Show MOTD on Connect");

	AutoExecConfig(true, "motd-fixer");
}

public void OnClientPutInServer(int client)
{
	g_bClientPreference[client] = false;
}

public void OnClientCookiesCached(int client)
{
	OnHandleCookie(client);
}

public void OnHandleCookie(int client)
{
	char sValue[8];
	GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));

	g_bClientPreference[client] = (StringToInt(sValue) != 0);

	if (g_bClientPreference[client])
	{
		float fTime = convar_Time.FloatValue;
		CreateTimer(fTime, Timer_ShowMOTD, GetClientUserId(client));
	}
}

public void CookieMenuHandler_MOTD(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if (action == CookieMenuAction_DisplayOption)
	{
		char sValue[8];
		GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));

		Format(buffer, maxlen, "Show MOTD on Connect: %s", StringToInt(sValue) ? "On" : "Off");
	}
	else if (action == CookieMenuAction_SelectOption)
	{
		char sValue[8];
		GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));

		SetClientCookie(client, g_hClientCookie, StringToInt(sValue) ? "0" : "1");
		ShowCookieMenu(client);
	}
}

public Action Timer_ShowMOTD(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (client && IsClientInGame(client) && !IsFakeClient(client))
	{
		PrintToChat(client, "[SM] Opening the MOTD...");
		OpenMOTD(client);
	}

	return Plugin_Stop;
}

public Action Command_MOTD(int client, int args)
{
	if (!client)
	{
		return Plugin_Handled;
	}

	if (!convar_Enabled.BoolValue)
	{
		return Plugin_Handled;
	}

	OpenMOTD(client);
	return Plugin_Handled;
}

void OpenMOTD(int client)
{
	char sURL[256];
	sURL[0] = '\0';

	ConVar hUrl = FindConVar("sm_motd_url");

	if (hUrl != null)
	{
		GetConVarString(hUrl, sURL, sizeof(sURL));
	}

	if (!sURL[0])
	{
		File hFile = OpenFile("cfg/motd.txt", "rt");

		if (hFile != null)
		{
			hFile.ReadLine(sURL, sizeof(sURL));
			TrimString(sURL);
			delete hFile;
		}
	}

	if (!sURL[0])
	{
		ShowMOTDPanel(client, "Message of the Day", "motd", MOTDPANEL_TYPE_INDEX);
		return;
	}

	ShowMOTDPanel(client, "Message of the Day", sURL, MOTDPANEL_TYPE_URL);
}
