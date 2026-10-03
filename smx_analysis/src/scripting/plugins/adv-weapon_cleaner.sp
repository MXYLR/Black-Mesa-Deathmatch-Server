#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
	name = "Adv Weapon Cleaner",
	author = "Unknown",
	description = "Removes dropped weapons to prevent weapon spam",
	version = "1.0",
	url = "https://forums.alliedmods.net/"
};

ConVar cvRemoveDelay;
ConVar cvRemoveDelay2;
ConVar cvMuchWeapons;
ConVar cvKeepMapWeapons;
ConVar cvSweepInterval;

ArrayList g_aWeapons;
ArrayList g_aDropTimes;

int g_iWeaponsOnGround;
float g_fLastSweep;

public void OnPluginStart()
{
	CreateConVar("adv_weapon_cleaner_version", "1.0", "Weapon Cleaner version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	cvRemoveDelay = CreateConVar("adv_weapon_cleaner_remove_delay", "20.0", "Time to wait before weapon gets removed when a player drops it.", FCVAR_NOTIFY);
	cvRemoveDelay2 = CreateConVar("adv_weapon_cleaner_remove_delay2", "0.1", "Reduced remove delay per weapon.", FCVAR_NOTIFY);
	cvMuchWeapons = CreateConVar("adv_weapon_cleaner_much_weapons", "100", "How much weapons have to be spawned (including each players inventory) before intensifying remove delay.", FCVAR_NOTIFY);
	cvKeepMapWeapons = CreateConVar("adv_weapon_cleaner_keep_map_weapons", "1", "0: Disable 1: Keep", FCVAR_NOTIFY);
	cvSweepInterval = CreateConVar("adv_weapon_cleaner_sweep_interval", "10.0", "Seconds between full sweeps of dropped weapons. 0 disables the sweep.", FCVAR_NOTIFY);

	g_aWeapons = new ArrayList();
	g_aDropTimes = new ArrayList();
	g_fLastSweep = GetGameTime();

	CreateTimer(0.1, Timer_Check, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	C_Event_MapStart(null, "", false);
}

public Action C_Event_MapStart(Event event, const char[] name, bool dontBroadcast)
{
	g_aWeapons.Clear();
	g_aDropTimes.Clear();
	g_iWeaponsOnGround = 0;
	g_fLastSweep = GetGameTime();

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= MaxClients)
	{
		return;
	}

	// Only track weapons. The original plugin also matched "item_*", which
	// swept the map's chargers (item_suitcharger / item_healthcharger),
	// health stations and other items — those must never be removed.
	if (strncmp(classname, "weapon_", 7) != 0)
	{
		return;
	}

	if (g_aWeapons.FindValue(entity) != -1)
	{
		return;
	}

	g_aWeapons.Push(entity);
	g_aDropTimes.Push(GetGameTime());
	g_iWeaponsOnGround++;
}

public void OnEntityDestroyed(int entity)
{
	int index = g_aWeapons.FindValue(entity);

	if (index != -1)
	{
		g_aWeapons.Erase(index);
		g_aDropTimes.Erase(index);
		g_iWeaponsOnGround--;
	}
}

public Action Timer_Check(Handle timer)
{
	bool bSweep = (cvSweepInterval.FloatValue > 0.0 && GetGameTime() - g_fLastSweep >= cvSweepInterval.FloatValue);

	if (bSweep)
	{
		g_fLastSweep = GetGameTime();
	}

	for (int i = g_aWeapons.Length - 1; i >= 0; i--)
	{
		int weapon = g_aWeapons.Get(i);

		if (!IsValidEdict(weapon))
		{
			g_aWeapons.Erase(i);
			g_aDropTimes.Erase(i);
			g_iWeaponsOnGround--;
			continue;
		}

		int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

		if (owner != -1)
		{
			// Held by someone: reset the drop timer so the remove countdown only
			// starts once the weapon actually leaves a player's hands.
			if (owner >= 1 && owner <= MaxClients)
			{
				g_aDropTimes.Set(i, GetGameTime());
			}

			continue;
		}

		// Weapon on the ground.
		//
		// Black Mesa (Source 2013 fork) has no m_hPrevOwner on weapons. The
		// CS:GO plugin this was ported from used it to tell a dropped weapon
		// from a map-placed one, but FindSendPropInfo("m_hPrevOwner") returns
		// -1 for every BM weapon, so that guard never fired and map weapons
		// were swept alongside dropped ones.
		//
		// The correct BM signal is m_bRemoveable: CBaseCombatWeapon::Drop()
		// sets it true ("fair game for removal when/if a game_weapon_manager
		// does a cleanup"), while Spawn() and OnPickedUp() set it false. So a
		// weapon on the ground with m_bRemoveable == true is one a player
		// dropped; false means the map (or game logic) placed it and it has
		// never been dropped.
		int iRemoveable = FindDataMapInfo(weapon, "m_bRemoveable");
		bool bDropped = (iRemoveable != -1 && GetEntData(weapon, iRemoveable, 1) != 0);

		if (cvKeepMapWeapons.BoolValue && !bDropped)
		{
			// Map-placed weapon, keep it.
			continue;
		}

		float fRemoveDelay = cvRemoveDelay.FloatValue;

		if (g_iWeaponsOnGround > cvMuchWeapons.IntValue)
		{
			fRemoveDelay = cvRemoveDelay2.FloatValue;
		}

		// Periodic sweep: on the sweep tick, clear every dropped weapon at once
		// so a kill/respawn burst can't pile up weapon props for remove_delay.
		if (bSweep)
		{
			fRemoveDelay = 0.0;
		}

		if (GetGameTime() - g_aDropTimes.Get(i) >= fRemoveDelay)
		{
			// Erase from the tracking arrays BEFORE RemoveEdict: RemoveEdict fires
			// OnEntityDestroyed synchronously, which also erases via FindValue. If
			// we erased after RemoveEdict we'd erase the same slot twice and hit an
			// out-of-bounds index on the second pass.
			g_aWeapons.Erase(i);
			g_aDropTimes.Erase(i);
			g_iWeaponsOnGround--;
			RemoveEdict(weapon);
		}
	}

	return Plugin_Continue;
}
