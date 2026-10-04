#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <admin>
#include <adminmenu>
#include <topmenus>
#include <clientprefs>
#include <cstrike>
#include <geoip>
#include <mapchooser>
#include <nextmap>

public Plugin myinfo = {
	name = "T",
	author = "T",
	description = "T",
	version = "1",
	url = ""
};
/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Communication Plugin

 * Provides fucntionality for controlling communication on the server

 *

 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.

 * =============================================================================

 *

 * This program is free software; you can redistribute it and/or modify it under

 * the terms of the GNU General Public License, version 3.0, as published by the

 * Free Software Foundation.

 * 1

 * This program is distributed in the hope that it will be useful, but WITHOUT

 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS

 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more

 * details.

 *

 * You should have received a copy of the GNU General Public License along with

 * this program.  If not, see <http://www.gnu.org/licenses/>.

 *

 * As a special exception, AlliedModders LLC gives you permission to link the

 * code of this program (as well as its derivative works) to "Half-Life 2," the

 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software

 * by the Valve Corporation.  You must obey the GNU General Public License in

 * all respects for all other code used.  Additionally, AlliedModders LLC grants

 * this exception to all derivative works.  AlliedModders LLC defines further

 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),

 * or <http://www.sourcemod.net/license.php>.

 *

 * Version: $Id$

 */



#include <sourcemod>

#include <sdktools>

#undef REQUIRE_PLUGIN

#include <adminmenu>



#pragma semicolon 1

#pragma newdecls required



public Plugin mod_basecomm_myinfo =

{

	name = "Basic Comm Control",

	author = "AlliedModders LLC",

	description = "Provides methods of controlling communication.",

	version = SOURCEMOD_VERSION,

	url = "http://www.sourcemod.net/"

};



enum struct mod_basecomm_PlayerState {

	bool isMuted; // Is the player muted?

	bool isGagged; // Is the player gagged?

	int gagTarget;

}



mod_basecomm_PlayerState mod_basecomm_playerstate[MAXPLAYERS+1];



ConVar mod_basecomm_g_Cvar_Deadtalk;				// Holds the handle for sm_deadtalk

ConVar mod_basecomm_g_Cvar_Alltalk;				// Holds the handle for sv_alltalk

bool mod_basecomm_g_Hooked = false;				// Tracks if we've hooked events for deadtalk



TopMenu mod_basecomm_hTopMenu;




/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Basecomm

 * Part of Basecomm plugin, menu and other functionality.

 *

 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.

 * =============================================================================

 *

 * This program is free software; you can redistribute it and/or modify it under

 * the terms of the GNU General Public License, version 3.0, as published by the

 * Free Software Foundation.

 * 

 * This program is distributed in the hope that it will be useful, but WITHOUT

 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS

 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more

 * details.

 *

 * You should have received a copy of the GNU General Public License along with

 * this program.  If not, see <http://www.gnu.org/licenses/>.

 *

 * As a special exception, AlliedModders LLC gives you permission to link the

 * code of this program (as well as its derivative works) to "Half-Life 2," the

 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software

 * by the Valve Corporation.  You must obey the GNU General Public License in

 * all respects for all other code used.  Additionally, AlliedModders LLC grants

 * this exception to all derivative works.  AlliedModders LLC defines further

 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),

 * or <http://www.sourcemod.net/license.php>.

 *

 * Version: $Id$

 */



enum mod_basecomm_CommType

{

	mod_basecomm_CommType_Mute,

	mod_basecomm_CommType_UnMute,

	mod_basecomm_CommType_Gag,

	mod_basecomm_CommType_UnGag,

	mod_basecomm_CommType_Silence,

	CommType_UnSilence

};



void mod_basecomm_DisplayGagTypesMenu(int client)

{

	Menu menu = new Menu(mod_basecomm_MenuHandler_GagTypes);

	int target = mod_basecomm_playerstate[client].gagTarget;

	

	char title[100];

	Format(title, sizeof(title), "%T: %N", "Choose Type", client, target);

	menu.SetTitle(title);

	menu.ExitBackButton = true;



	if (!mod_basecomm_playerstate[target].isMuted)

	{

		mod_basecomm_AddTranslatedMenuItem(menu, "0", "Mute Player", client);

	}

	else

	{

		mod_basecomm_AddTranslatedMenuItem(menu, "1", "UnMute Player", client);

	}

	

	if (!mod_basecomm_playerstate[target].isGagged)

	{

		mod_basecomm_AddTranslatedMenuItem(menu, "2", "Gag Player", client);

	}

	else

	{

		mod_basecomm_AddTranslatedMenuItem(menu, "3", "UnGag Player", client);

	}

	

	if (!mod_basecomm_playerstate[target].isMuted || !mod_basecomm_playerstate[target].isGagged)

	{

		mod_basecomm_AddTranslatedMenuItem(menu, "4", "Silence Player", client);

	}

	else

	{

		mod_basecomm_AddTranslatedMenuItem(menu, "5", "UnSilence Player", client);

	}

		

	menu.Display(client, MENU_TIME_FOREVER);

}



void mod_basecomm_AddTranslatedMenuItem(Menu menu, const char[] opt, const char[] phrase, int client)

{

	char buffer[128];

	Format(buffer, sizeof(buffer), "%T", phrase, client);

	menu.AddItem(opt, buffer);

}



void mod_basecomm_DisplayGagPlayerMenu(int client)

{

	Menu menu = new Menu(mod_basecomm_MenuHandler_GagPlayer);

	

	char title[100];

	Format(title, sizeof(title), "%T:", "Gag/Mute player", client);

	menu.SetTitle(title);

	menu.ExitBackButton = true;

	

	AddTargetsToMenu(menu, client, true, false);

	

	menu.Display(client, MENU_TIME_FOREVER);

}



public void mod_basecomm_AdminMenu_Gag(TopMenu topmenu, 

					  TopMenuAction action,

					  TopMenuObject object_id,

					  int param,

					  char[] buffer,

					  int maxlength)

{

	if (action == TopMenuAction_DisplayOption)

	{

		Format(buffer, maxlength, "%T", "Gag/Mute player", param);

	}

	else if (action == TopMenuAction_SelectOption)

	{

		mod_basecomm_DisplayGagPlayerMenu(param);

	}

}



public int mod_basecomm_MenuHandler_GagPlayer(Menu menu, MenuAction action, int param1, int param2)

{

	if (action == MenuAction_End)

	{

		delete menu;

	}

	else if (action == MenuAction_Cancel)

	{

		if (param2 == MenuCancel_ExitBack && mod_basecomm_hTopMenu)

		{

			mod_basecomm_hTopMenu.Display(param1, TopMenuPosition_LastCategory);

		}

	}

	else if (action == MenuAction_Select)

	{

		char info[32];

		int userid, target;

		

		menu.GetItem(param2, info, sizeof(info));

		userid = StringToInt(info);



		if ((target = GetClientOfUserId(userid)) == 0)

		{

			PrintToChat(param1, "[SM] %t", "Player no longer available");

		}

		else if (!CanUserTarget(param1, target))

		{

			PrintToChat(param1, "[SM] %t", "Unable to target");

		}

		else

		{

			mod_basecomm_playerstate[param1].gagTarget = GetClientOfUserId(userid);

			mod_basecomm_DisplayGagTypesMenu(param1);

		}

	}

}



public int mod_basecomm_MenuHandler_GagTypes(Menu menu, MenuAction action, int param1, int param2)

{

	if (action == MenuAction_End)

	{

		delete menu;

	}

	else if (action == MenuAction_Cancel)

	{

		if (param2 == MenuCancel_ExitBack && mod_basecomm_hTopMenu)

		{

			mod_basecomm_hTopMenu.Display(param1, TopMenuPosition_LastCategory);

		}

	}

	else if (action == MenuAction_Select)

	{

		char info[32];

		mod_basecomm_CommType type;

		

		menu.GetItem(param2, info, sizeof(info));

		type = view_as<mod_basecomm_CommType>(StringToInt(info));

		

		int target = mod_basecomm_playerstate[param1].gagTarget;

		

		char name[MAX_NAME_LENGTH];

		GetClientName(target, name, sizeof(name));



		switch (type)

		{

			case mod_basecomm_CommType_Mute:

			{

				mod_basecomm_PerformMute(param1, target);

				ShowActivity2(param1, "[SM] ", "%t", "Muted target", "_s", name);

			}

			case mod_basecomm_CommType_UnMute:

			{

				mod_basecomm_PerformUnMute(param1, target);

				ShowActivity2(param1, "[SM] ", "%t", "Unmuted target", "_s", name);

			}

			case mod_basecomm_CommType_Gag:

			{

				mod_basecomm_PerformGag(param1, target);

				ShowActivity2(param1, "[SM] ", "%t", "Gagged target", "_s", name);

			}

			case mod_basecomm_CommType_UnGag:

			{

				mod_basecomm_PerformUnGag(param1, target);

				ShowActivity2(param1, "[SM] ", "%t", "Ungagged target", "_s", name);

			}

			case mod_basecomm_CommType_Silence:

			{

				mod_basecomm_PerformSilence(param1, target);

				ShowActivity2(param1, "[SM] ", "%t", "Silenced target", "_s", name);

			}

			case CommType_UnSilence:

			{

				mod_basecomm_PerformUnSilence(param1, target);

				ShowActivity2(param1, "[SM] ", "%t", "Unsilenced target", "_s", name);

			}

		}

	}

}



void mod_basecomm_PerformMute(int client, int target, bool silent=false)

{

	mod_basecomm_playerstate[target].isMuted = true;

	SetClientListeningFlags(target, VOICE_MUTED);

	

	mod_basecomm_FireOnClientMute(target, true);

	

	if (!silent)

	{

		LogAction(client, target, "\"%L\" muted \"%L\"", client, target);

	}

}



void mod_basecomm_PerformUnMute(int client, int target, bool silent=false)

{

	mod_basecomm_playerstate[target].isMuted = false;

	if (mod_basecomm_g_Cvar_Deadtalk.IntValue == 1 && !IsPlayerAlive(target))

	{

		SetClientListeningFlags(target, VOICE_LISTENALL);

	}

	else if (mod_basecomm_g_Cvar_Deadtalk.IntValue == 2 && !IsPlayerAlive(target))

	{

		SetClientListeningFlags(target, VOICE_TEAM);

	}

	else

	{

		SetClientListeningFlags(target, VOICE_NORMAL);

	}

	

	mod_basecomm_FireOnClientMute(target, false);

	

	if (!silent)

	{

		LogAction(client, target, "\"%L\" unmuted \"%L\"", client, target);

	}

}



void mod_basecomm_PerformGag(int client, int target, bool silent=false)

{

	mod_basecomm_playerstate[target].isGagged = true;

	mod_basecomm_FireOnClientGag(target, true);

	

	if (!silent)

	{

		LogAction(client, target, "\"%L\" gagged \"%L\"", client, target);

	}

}



void mod_basecomm_PerformUnGag(int client, int target, bool silent=false)

{

	mod_basecomm_playerstate[target].isGagged = false;

	mod_basecomm_FireOnClientGag(target, false);

	

	if (!silent)

	{

		LogAction(client, target, "\"%L\" ungagged \"%L\"", client, target);

	}

}



void mod_basecomm_PerformSilence(int client, int target)

{

	if (!mod_basecomm_playerstate[target].isGagged)

	{

		mod_basecomm_playerstate[target].isGagged = true;

		mod_basecomm_FireOnClientGag(target, true);

	}

	

	if (!mod_basecomm_playerstate[target].isMuted)

	{

		mod_basecomm_playerstate[target].isMuted = true;

		SetClientListeningFlags(target, VOICE_MUTED);

		mod_basecomm_FireOnClientMute(target, true);

	}

	

	LogAction(client, target, "\"%L\" silenced \"%L\"", client, target);

}



void mod_basecomm_PerformUnSilence(int client, int target)

{

	if (mod_basecomm_playerstate[target].isGagged)

	{

		mod_basecomm_playerstate[target].isGagged = false;

		mod_basecomm_FireOnClientGag(target, false);

	}

	

	if (mod_basecomm_playerstate[target].isMuted)

	{

		mod_basecomm_playerstate[target].isMuted = false;

		

		if (mod_basecomm_g_Cvar_Deadtalk.IntValue == 1 && !IsPlayerAlive(target))

		{

			SetClientListeningFlags(target, VOICE_LISTENALL);

		}

		else if (mod_basecomm_g_Cvar_Deadtalk.IntValue == 2 && !IsPlayerAlive(target))

		{

			SetClientListeningFlags(target, VOICE_TEAM);

		}

		else

		{

			SetClientListeningFlags(target, VOICE_NORMAL);

		}

		mod_basecomm_FireOnClientMute(target, false);

	}

	

	LogAction(client, target, "\"%L\" unsilenced \"%L\"", client, target);

}



public Action mod_basecomm_Command_Mute(int client, int args)

{	

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_mute <player>");

		return Plugin_Handled;

	}

	

	char arg[64];

	GetCmdArg(1, arg, sizeof(arg));

	

	char target_name[MAX_TARGET_LENGTH];

	int target_list[MAXPLAYERS], target_count;

	bool tn_is_ml;

	

	if ((target_count = ProcessTargetString(

			arg,

			client, 

			target_list, 

			MAXPLAYERS, 

			0,

			target_name,

			sizeof(target_name),

			tn_is_ml)) <= 0)

	{

		ReplyToTargetError(client, target_count);

		return Plugin_Handled;

	}



	for (int i = 0; i < target_count; i++)

	{

		int target = target_list[i];

		

		mod_basecomm_PerformMute(client, target);

	}

	

	if (tn_is_ml)

	{

		ShowActivity2(client, "[SM] ", "%t", "Muted target", target_name);

	}

	else

	{

		ShowActivity2(client, "[SM] ", "%t", "Muted target", "_s", target_name);

	}

	

	return Plugin_Handled;	

}



public Action mod_basecomm_Command_Gag(int client, int args)

{	

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_gag <player>");

		return Plugin_Handled;

	}

	

	char arg[64];

	GetCmdArg(1, arg, sizeof(arg));

	

	char target_name[MAX_TARGET_LENGTH];

	int target_list[MAXPLAYERS], target_count;

	bool tn_is_ml;

	

	if ((target_count = ProcessTargetString(

			arg,

			client, 

			target_list, 

			MAXPLAYERS, 

			0,

			target_name,

			sizeof(target_name),

			tn_is_ml)) <= 0)

	{

		ReplyToTargetError(client, target_count);

		return Plugin_Handled;

	}



	for (int i = 0; i < target_count; i++)

	{

		int target = target_list[i];

		

		mod_basecomm_PerformGag(client, target);

	}

	

	if (tn_is_ml)

	{

		ShowActivity2(client, "[SM] ", "%t", "Gagged target", target_name);

	}

	else

	{

		ShowActivity2(client, "[SM] ", "%t", "Gagged target", "_s", target_name);

	}

	

	return Plugin_Handled;	

}



public Action mod_basecomm_Command_Silence(int client, int args)

{	

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_silence <player>");

		return Plugin_Handled;

	}

	

	char arg[64];

	GetCmdArg(1, arg, sizeof(arg));

	

	char target_name[MAX_TARGET_LENGTH];

	int target_list[MAXPLAYERS], target_count;

	bool tn_is_ml;

	

	if ((target_count = ProcessTargetString(

			arg,

			client, 

			target_list, 

			MAXPLAYERS, 

			0,

			target_name,

			sizeof(target_name),

			tn_is_ml)) <= 0)

	{

		ReplyToTargetError(client, target_count);

		return Plugin_Handled;

	}



	for (int i = 0; i < target_count; i++)

	{

		int target = target_list[i];

		

		mod_basecomm_PerformSilence(client, target);

	}

	

	if (tn_is_ml)

	{

		ShowActivity2(client, "[SM] ", "%t", "Silenced target", target_name);

	}

	else

	{

		ShowActivity2(client, "[SM] ", "%t", "Silenced target", "_s", target_name);

	}

	

	return Plugin_Handled;	

}



public Action mod_basecomm_Command_Unmute(int client, int args)

{	

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_unmute <player>");

		return Plugin_Handled;

	}

	

	char arg[64];

	GetCmdArg(1, arg, sizeof(arg));

	

	char target_name[MAX_TARGET_LENGTH];

	int target_list[MAXPLAYERS], target_count;

	bool tn_is_ml;

	

	if ((target_count = ProcessTargetString(

			arg,

			client, 

			target_list, 

			MAXPLAYERS, 

			0,

			target_name,

			sizeof(target_name),

			tn_is_ml)) <= 0)

	{

		ReplyToTargetError(client, target_count);

		return Plugin_Handled;

	}



	for (int i = 0; i < target_count; i++)

	{

		int target = target_list[i];

		

		if (!mod_basecomm_playerstate[target].isMuted)

		{

			continue;

		}

		

		mod_basecomm_PerformUnMute(client, target);

	}

	

	if (tn_is_ml)

	{

		ShowActivity2(client, "[SM] ", "%t", "Unmuted target", target_name);

	}

	else

	{

		ShowActivity2(client, "[SM] ", "%t", "Unmuted target", "_s", target_name);

	}

	

	return Plugin_Handled;	

}



public Action mod_basecomm_Command_Ungag(int client, int args)

{	

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_ungag <player>");

		return Plugin_Handled;

	}

	

	char arg[64];

	GetCmdArg(1, arg, sizeof(arg));

	

	char target_name[MAX_TARGET_LENGTH];

	int target_list[MAXPLAYERS], target_count;

	bool tn_is_ml;

	

	if ((target_count = ProcessTargetString(

			arg,

			client, 

			target_list, 

			MAXPLAYERS, 

			0,

			target_name,

			sizeof(target_name),

			tn_is_ml)) <= 0)

	{

		ReplyToTargetError(client, target_count);

		return Plugin_Handled;

	}



	for (int i = 0; i < target_count; i++)

	{

		int target = target_list[i];

		

		mod_basecomm_PerformUnGag(client, target);

	}

	

	if (tn_is_ml)

	{

		ShowActivity2(client, "[SM] ", "%t", "Ungagged target", target_name);

	}

	else

	{

		ShowActivity2(client, "[SM] ", "%t", "Ungagged target", "_s", target_name);

	}

	

	return Plugin_Handled;	

}



public Action mod_basecomm_Command_Unsilence(int client, int args)

{	

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_unsilence <player>");

		return Plugin_Handled;

	}

	

	char arg[64];

	GetCmdArg(1, arg, sizeof(arg));

	

	char target_name[MAX_TARGET_LENGTH];

	int target_list[MAXPLAYERS], target_count;

	bool tn_is_ml;

	

	if ((target_count = ProcessTargetString(

			arg,

			client, 

			target_list, 

			MAXPLAYERS, 

			0,

			target_name,

			sizeof(target_name),

			tn_is_ml)) <= 0)

	{

		ReplyToTargetError(client, target_count);

		return Plugin_Handled;

	}



	for (int i = 0; i < target_count; i++)

	{

		int target = target_list[i];

		

		mod_basecomm_PerformUnSilence(client, target);

	}

	

	if (tn_is_ml)

	{

		ShowActivity2(client, "[SM] ", "%t", "Unsilenced target", target_name);

	}

	else

	{

		ShowActivity2(client, "[SM] ", "%t", "Unsilenced target", "_s", target_name);

	}

	

	return Plugin_Handled;	

}





/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Basecomm

 * Part of Basecomm plugin, menu and other functionality.

 *

 * SourceMod (C)2004-2011 AlliedModders LLC.  All rights reserved.

 * =============================================================================

 *

 * This program is free software; you can redistribute it and/or modify it under

 * the terms of the GNU General Public License, version 3.0, as published by the

 * Free Software Foundation.

 * 

 * This program is distributed in the hope that it will be useful, but WITHOUT

 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS

 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more

 * details.

 *

 * You should have received a copy of the GNU General Public License along with

 * this program.  If not, see <http://www.gnu.org/licenses/>.

 *

 * As a special exception, AlliedModders LLC gives you permission to link the

 * code of this program (as well as its derivative works) to "Half-Life 2," the

 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software

 * by the Valve Corporation.  You must obey the GNU General Public License in

 * all respects for all other code used.  Additionally, AlliedModders LLC grants

 * this exception to all derivative works.  AlliedModders LLC defines further

 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),

 * or <http://www.sourcemod.net/license.php>.

 *

 * Version: $Id$

 */

 

 public int Native_IsClientGagged(Handle hPlugin, int numParams)

{

	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)

	{

		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);

	}

	

	if (!IsClientInGame(client))

	{

		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);

	}

	

	return mod_basecomm_playerstate[client].isGagged;

}



public int mod_basecomm_Native_IsClientMuted(Handle hPlugin, int numParams)

{

	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)

	{

		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);

	}

	

	if (!IsClientInGame(client))

	{

		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);

	}

	

	return mod_basecomm_playerstate[client].isMuted;

}



public int mod_basecomm_Native_SetClientGag(Handle hPlugin, int numParams)

{

	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)

	{

		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);

	}

	

	if (!IsClientInGame(client))

	{

		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);

	}

	

	bool gagState = GetNativeCell(2);

	

	if (gagState)

	{

		if (mod_basecomm_playerstate[client].isGagged)

		{

			return false;

		}

		

		mod_basecomm_PerformGag(-1, client, true);

	}

	else

	{

		if (!mod_basecomm_playerstate[client].isGagged)

		{

			return false;

		}

		

		mod_basecomm_PerformUnGag(-1, client, true);

	}

	

	return true;

}



public int mod_basecomm_Native_SetClientMute(Handle hPlugin, int numParams)

{

	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)

	{

		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);

	}

	

	if (!IsClientInGame(client))

	{

		return ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not in game", client);

	}

	

	bool muteState = GetNativeCell(2);

	

	if (muteState)

	{

		if (mod_basecomm_playerstate[client].isMuted)

		{

			return false;

		}

		

		mod_basecomm_PerformMute(-1, client, true);

	}

	else

	{

		if (!mod_basecomm_playerstate[client].isMuted)

		{

			return false;

		}

		

		mod_basecomm_PerformUnMute(-1, client, true);

	}

	

	return true;

}





/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Basecomm

 * Part of Basecomm plugin, menu and other functionality.

 *

 * SourceMod (C)2004-2011 AlliedModders LLC.  All rights reserved.

 * =============================================================================

 *

 * This program is free software; you can redistribute it and/or modify it under

 * the terms of the GNU General Public License, version 3.0, as published by the

 * Free Software Foundation.

 * 

 * This program is distributed in the hope that it will be useful, but WITHOUT

 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS

 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more

 * details.

 *

 * You should have received a copy of the GNU General Public License along with

 * this program.  If not, see <http://www.gnu.org/licenses/>.

 *

 * As a special exception, AlliedModders LLC gives you permission to link the

 * code of this program (as well as its derivative works) to "Half-Life 2," the

 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software

 * by the Valve Corporation.  You must obey the GNU General Public License in

 * all respects for all other code used.  Additionally, AlliedModders LLC grants

 * this exception to all derivative works.  AlliedModders LLC defines further

 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),

 * or <http://www.sourcemod.net/license.php>.

 *

 * Version: $Id$

 */

 

void mod_basecomm_FireOnClientMute(int client, bool muteState)

{

 	static GlobalForward hForward;

	

	if(hForward == null)

	{

		hForward = new GlobalForward("BaseComm_OnClientMute", ET_Ignore, Param_Cell, Param_Cell);

	}

	

	Call_StartForward(hForward);

	Call_PushCell(client);

	Call_PushCell(muteState);

	Call_Finish();

}

 

void mod_basecomm_FireOnClientGag(int client, bool gagState)

{

 	static GlobalForward hForward;

	

	if(hForward == null)

	{

		hForward = new GlobalForward("BaseComm_OnClientGag", ET_Ignore, Param_Cell, Param_Cell);

	}

	

	Call_StartForward(hForward);

	Call_PushCell(client);

	Call_PushCell(gagState);

	Call_Finish();

}






public APLRes mod_basecomm_AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)

{

	CreateNative("BaseComm_IsClientGagged", Native_IsClientGagged);

	CreateNative("BaseComm_IsClientMuted",  mod_basecomm_Native_IsClientMuted);

	CreateNative("BaseComm_SetClientGag",   mod_basecomm_Native_SetClientGag);

	CreateNative("BaseComm_SetClientMute",  mod_basecomm_Native_SetClientMute);

	RegPluginLibrary("basecomm");

	

	return APLRes_Success;

}



public void mod_basecomm_OnPluginStart()

{

	LoadTranslations("common.phrases");

	LoadTranslations("basecomm.phrases");

	

	mod_basecomm_g_Cvar_Deadtalk = CreateConVar("sm_deadtalk", "0", "Controls how dead communicate. 0 - Off. 1 - Dead players ignore teams. 2 - Dead players talk to living teammates.", 0, true, 0.0, true, 2.0);

	mod_basecomm_g_Cvar_Alltalk = FindConVar("sv_alltalk");

	

	RegAdminCmd("sm_mute", mod_basecomm_Command_Mute, ADMFLAG_CHAT, "sm_mute <player> - Removes a player's ability to use voice.");

	RegAdminCmd("sm_gag", mod_basecomm_Command_Gag, ADMFLAG_CHAT, "sm_gag <player> - Removes a player's ability to use chat.");

	RegAdminCmd("sm_silence", mod_basecomm_Command_Silence, ADMFLAG_CHAT, "sm_silence <player> - Removes a player's ability to use voice or chat.");

	

	RegAdminCmd("sm_unmute", mod_basecomm_Command_Unmute, ADMFLAG_CHAT, "sm_unmute <player> - Restores a player's ability to use voice.");

	RegAdminCmd("sm_ungag", mod_basecomm_Command_Ungag, ADMFLAG_CHAT, "sm_ungag <player> - Restores a player's ability to use chat.");

	RegAdminCmd("sm_unsilence", mod_basecomm_Command_Unsilence, ADMFLAG_CHAT, "sm_unsilence <player> - Restores a player's ability to use voice and chat.");	

	

	mod_basecomm_g_Cvar_Deadtalk.AddChangeHook(mod_basecomm_ConVarChange_Deadtalk);



	if (mod_basecomm_g_Cvar_Alltalk) {

		mod_basecomm_g_Cvar_Alltalk.AddChangeHook(mod_basecomm_ConVarChange_Alltalk);

	}

	

	/* Account for late loading */

	TopMenu topmenu;

	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))

	{

		mod_basecomm_OnAdminMenuReady(topmenu);

	}

}



public void mod_basecomm_OnAdminMenuReady(Handle aTopMenu)

{

	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);



	/* Block us from being called twice */

	if (topmenu == mod_basecomm_hTopMenu)

	{

		return;

	}

	

	/* Save the Handle */

	mod_basecomm_hTopMenu = topmenu;

	

	/* Build the "Player Commands" category */

	TopMenuObject player_commands = mod_basecomm_hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	

	if (player_commands != INVALID_TOPMENUOBJECT)

	{

		mod_basecomm_hTopMenu.AddItem("sm_gag", mod_basecomm_AdminMenu_Gag, player_commands, "sm_gag", ADMFLAG_CHAT);

	}

}



public void mod_basecomm_ConVarChange_Deadtalk(ConVar convar, const char[] oldValue, const char[] newValue)

{

	if (mod_basecomm_g_Cvar_Deadtalk.IntValue)

	{

		HookEvent("player_spawn", mod_basecomm_Event_PlayerSpawn, EventHookMode_Post);

		HookEvent("player_death", mod_basecomm_Event_PlayerDeath, EventHookMode_Post);

		mod_basecomm_g_Hooked = true;

	}

	else if (mod_basecomm_g_Hooked)

	{

		UnhookEvent("player_spawn", mod_basecomm_Event_PlayerSpawn);

		UnhookEvent("player_death", mod_basecomm_Event_PlayerDeath);		

		mod_basecomm_g_Hooked = false;

	}

}



public bool mod_basecomm_OnClientConnect(int client, char[] rejectmsg, int maxlen)

{

	mod_basecomm_playerstate[client].isGagged = false;

	mod_basecomm_playerstate[client].isMuted = false;

	

	return true;

}



public Action mod_basecomm_OnClientSayCommand(int client, const char[] command, const char[] sArgs)

{

	if (client && mod_basecomm_playerstate[client].isGagged)

	{

		return Plugin_Stop;

	}

	

	return Plugin_Continue;

}



public void mod_basecomm_ConVarChange_Alltalk(ConVar convar, const char[] oldValue, const char[] newValue)

{

	int mode = mod_basecomm_g_Cvar_Deadtalk.IntValue;

	

	for (int i = 1; i <= MaxClients; i++)

	{

		if (!IsClientInGame(i))

		{

			continue;

		}

		

		if (mod_basecomm_playerstate[i].isMuted)

		{

			SetClientListeningFlags(i, VOICE_MUTED);

		}

		else if (mod_basecomm_g_Cvar_Alltalk.BoolValue)

		{

			SetClientListeningFlags(i, VOICE_NORMAL);

		}

		else if (!IsPlayerAlive(i))

		{

			if (mode == 1)

			{

				SetClientListeningFlags(i, VOICE_LISTENALL);

			}

			else if (mode == 2)

			{

				SetClientListeningFlags(i, VOICE_TEAM);

			}

		}

	}

}



public void mod_basecomm_Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)

{

	int client = GetClientOfUserId(event.GetInt("userid"));

	

	if (!client)

	{

		return;	

	}

	

	if (mod_basecomm_playerstate[client].isMuted)

	{

		SetClientListeningFlags(client, VOICE_MUTED);

	}

	else

	{

		SetClientListeningFlags(client, VOICE_NORMAL);

	}

}



public void mod_basecomm_Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)

{

	int client = GetClientOfUserId(event.GetInt("userid"));

	

	if (!client)

	{

		return;	

	}

	

	if (mod_basecomm_playerstate[client].isMuted)

	{

		SetClientListeningFlags(client, VOICE_MUTED);

		return;

	}

	

	if (mod_basecomm_g_Cvar_Alltalk && mod_basecomm_g_Cvar_Alltalk.BoolValue)

	{

		SetClientListeningFlags(client, VOICE_NORMAL);

		return;

	}

	

	int mode = mod_basecomm_g_Cvar_Deadtalk.IntValue;

	if (mode == 1)

	{

		SetClientListeningFlags(client, VOICE_LISTENALL);

	}

	else if (mode == 2)

	{

		SetClientListeningFlags(client, VOICE_TEAM);

	}

}

