#pragma semicolon 1

#include <sourcemod>
#include <geoip>

public Plugin myinfo =
{
	name = "Connect MSG",
	author = "Unknown",
	description = "Provides Info of the player when he joins",
	version = "1.0",
	url = "https://forums.alliedmods.net/"
};

ConVar g_hConnectMsg;
ConVar g_hDisconnectMsg;

char g_sCountry[MAXPLAYERS + 1][46];

public void OnPluginStart()
{
	g_hConnectMsg = CreateConVar("sm_connectmsg", "1", "Shows a connect message in the chat once a player joins.", FCVAR_NOTIFY);
	g_hDisconnectMsg = CreateConVar("sm_disconnectmsg", "1", "Shows a disconnect message in the chat once a player leaves.", FCVAR_NOTIFY);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (client < 1 || client > MaxClients)
	{
		return;
	}

	char ip[32];
	GetClientIP(client, ip, sizeof(ip));

	char ccode[3];

	if (GeoipCode2(ip, ccode))
	{
		Format(g_sCountry[client], sizeof(g_sCountry[]), "%s", ccode);
	}
	else
	{
		Format(g_sCountry[client], sizeof(g_sCountry[]), "Unknown Country");
	}
}

public void OnClientDisconnect(int client)
{
	if (!g_hDisconnectMsg.BoolValue || client < 1 || client > MaxClients)
	{
		return;
	}

	if (!IsClientInGame(client))
	{
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	char auth[32];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true);

	PrintToChatAll("[DISCONNECT] %s (%s) has left the server from [%s]", name, auth, g_sCountry[client]);
}

public void OnClientPostAdminCheck(int client)
{
	if (!g_hConnectMsg.BoolValue || client < 1 || client > MaxClients)
	{
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	char auth[32];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), true);

	PrintToChatAll("[CONNECT] %s (%s) has joined the server from [%s]", name, auth, g_sCountry[client]);
}
