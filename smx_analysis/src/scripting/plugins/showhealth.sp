#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>

public Plugin myinfo =
{
	name = "Show Health",
	author = "Unknown",
	description = "Shows your health on the screen",
	version = "1.0.2",
	url = "https://forums.alliedmods.net/"
};

#define AREA_HINT 1
#define AREA_CENTER 2

ConVar g_hVersion;
ConVar g_hEnabled;
ConVar g_hOnHitOnly;
ConVar g_hTextArea;

Handle g_hCookieShowHealth;

float g_fLastHurt[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_hVersion = CreateConVar("sm_show_health_version", "1.0.2", "Show Health Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_hEnabled = CreateConVar("sm_show_health", "1", "Enabled/Disabled show health functionality, 0 = off/1 = on", FCVAR_NOTIFY);
	g_hOnHitOnly = CreateConVar("sm_show_health_on_hit_only", "0", "Defines the weather when to show a health text:\n0 = always show your health on a screen\n1 = show your health only when somebody hit you", FCVAR_NOTIFY);
	g_hTextArea = CreateConVar("sm_show_health_text_area", "1", "Defines the area for health text:\n 1 = in the hint text area\n 2 = in the center of the screen", FCVAR_NOTIFY);

	g_hCookieShowHealth = RegClientCookie("cookie_show_health", "Cookie Show Health", CookieAccess_Protected);

	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);

	AutoExecConfig(true, "showhealth");

	SetCookieMenuItem(CookieMenuHandler_ShowHealth, 0, "Show Health");
}

public void OnClientPutInServer(int client)
{
	g_fLastHurt[client] = 0.0;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client && IsClientInGame(client))
	{
		g_fLastHurt[client] = GetGameTime();
	}

	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client && IsClientInGame(client))
	{
		g_fLastHurt[client] = 0.0;
	}

	return Plugin_Continue;
}

public void CookieMenuHandler_ShowHealth(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if (action == CookieMenuAction_DisplayOption)
	{
		char cookieValue[8];
		GetClientCookie(client, g_hCookieShowHealth, cookieValue, sizeof(cookieValue));

		if (StrEqual(cookieValue, "off"))
		{
			Format(buffer, maxlen, "Show Health: Off");
		}
		else
		{
			Format(buffer, maxlen, "Show Health: On");
		}
	}
	else if (action == CookieMenuAction_SelectOption)
	{
		char cookieValue[8];
		GetClientCookie(client, g_hCookieShowHealth, cookieValue, sizeof(cookieValue));

		if (StrEqual(cookieValue, "off"))
		{
			SetClientCookie(client, g_hCookieShowHealth, "on");
		}
		else
		{
			SetClientCookie(client, g_hCookieShowHealth, "off");
		}

		ShowCookieMenu(client);
	}
}

bool IsShowHealthEnabledForClient(int client)
{
	char cookieValue[8];
	GetClientCookie(client, g_hCookieShowHealth, cookieValue, sizeof(cookieValue));

	if (StrEqual(cookieValue, "off"))
	{
		return false;
	}

	return true;
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_ShowHealth, _, TIMER_REPEAT);
}

public Action Timer_ShowHealth(Handle timer)
{
	if (!g_hEnabled.BoolValue)
	{
		return Plugin_Continue;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsPlayerAlive(client))
		{
			continue;
		}

		if (!IsShowHealthEnabledForClient(client))
		{
			continue;
		}

		if (g_hOnHitOnly.BoolValue && GetGameTime() - g_fLastHurt[client] > 5.0)
		{
			continue;
		}

		char buffer[64];
		Format(buffer, sizeof(buffer), "Show Health: %i", GetClientHealth(client));

		switch (g_hTextArea.IntValue)
		{
			case AREA_CENTER:
			{
				PrintCenterText(client, "%s", buffer);
			}
			default:
			{
				PrintHintText(client, "%s", buffer);
			}
		}
	}

	return Plugin_Continue;
}
