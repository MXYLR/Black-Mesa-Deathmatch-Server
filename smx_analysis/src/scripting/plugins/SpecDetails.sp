#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "SpecDetails",
	author = "wribit",
	description = "while spectating, shows a panel with details about the person the spectator is watching",
	version = "1.1",
	url = "https://forums.alliedmods.net/"
};

ConVar g_CvarEnabled;

int g_kills[MAXPLAYERS + 1];
int g_deaths[MAXPLAYERS + 1];

int g_iLastObserverTarget[MAXPLAYERS + 1];
float g_fLastShown[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_CvarEnabled = CreateConVar("sm_specDetails_enabled", "1", "Enables(1) or disables(0) the plugin.", FCVAR_NOTIFY);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
}

public void OnClientPutInServer(int client)
{
	init_kd(client);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		init_kd(i);
	}

	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (victim && IsClientInGame(victim))
	{
		g_deaths[victim]++;
	}

	if (attacker && attacker != victim && IsClientInGame(attacker))
	{
		g_kills[attacker]++;
	}

	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	return Plugin_Continue;
}

void init_kd(int client)
{
	if (client < 1 || client > MaxClients)
	{
		return;
	}

	g_kills[client] = 0;
	g_deaths[client] = 0;
	g_iLastObserverTarget[client] = -1;
	g_fLastShown[client] = 0.0;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!g_CvarEnabled.BoolValue)
	{
		return;
	}

	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}

	if (!IsClientObserver(client))
	{
		g_iLastObserverTarget[client] = -1;
		return;
	}

	int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

	if (target == g_iLastObserverTarget[client])
	{
		return;
	}

	g_iLastObserverTarget[client] = target;

	if (target < 1 || target > MaxClients || !IsClientInGame(target) || IsClientObserver(target))
	{
		return;
	}

	// 5s per-spectator cooldown: with instant respawn the death-cam flicker
	// (alive -> observer -> alive) changes the observer target on every
	// death and would pop the panel constantly (e.g. right after killing a
	// bot). One panel per 5 seconds is plenty for the spectator UI.
	float fNow = GetGameTime();
	if (g_fLastShown[client] != 0.0 && fNow - g_fLastShown[client] < 5.0)
	{
		return;
	}

	ShowDetails(client, target);
}

void ShowDetails(int spectator, int target)
{
	g_fLastShown[spectator] = GetGameTime();

	int kills = g_kills[target];
	int deaths = g_deaths[target];
	int health = GetClientHealth(target);

	char weaponName[64];
	GetActiveWeaponName(target, weaponName, sizeof(weaponName));

	Handle panel = CreatePanel();
	DrawPanelText(panel, " ");
	DrawPanelText(panel, "---");

	char buffer[128];
	Format(buffer, sizeof(buffer), "Kills: %i", kills);
	DrawPanelText(panel, buffer);

	Format(buffer, sizeof(buffer), "Deaths: %i", deaths);
	DrawPanelText(panel, buffer);

	Format(buffer, sizeof(buffer), "Health: %i", health);
	DrawPanelText(panel, buffer);

	Format(buffer, sizeof(buffer), "Weapon: %s", weaponName);
	DrawPanelText(panel, buffer);

	DrawPanelText(panel, "---");
	DrawPanelText(panel, " ");

	SendPanelToClient(panel, spectator, PanelHandler, 3);
	CloseHandle(panel);
}

int PanelHandler(Menu menu, MenuAction action, int param1, int param2)
{
	return 0;
}

void GetActiveWeaponName(int client, char[] buffer, int maxlen)
{
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	if (weapon == -1 || !IsValidEdict(weapon))
	{
		Format(buffer, maxlen, "none");
		return;
	}

	char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));

	if (strncmp(classname, "weapon_", 7) == 0)
	{
		Format(buffer, maxlen, "%s", classname[7]);
	}
	else
	{
		Format(buffer, maxlen, "%s", classname);
	}
}
