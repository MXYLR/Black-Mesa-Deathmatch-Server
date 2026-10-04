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
#include <sourcebanspp>
#include <sourcecomms>

public Plugin myinfo =
{
	name = "T",
	author = "T",
	description = "T",
	version = "1",
	url = ""
};


// API forwards
forward TopMenu mod_adminmenu_GetAdminTopMenu();
forward int mod_adminmenu_AddTargetsToMenu(Handle menu, int source_client, bool in_game_only=true, bool alive_only=false);
forward int mod_adminmenu_AddTargetsToMenu2(Handle menu, int source_client, int flags);
forward TopMenu mod_topmenus_FromHandle(Handle handle);
forward bool mod_topmenus_LoadConfig(const char[] file, char[] error, int maxlength);
forward TopMenuObject mod_topmenus_AddCategory(const char[] name, TopMenuHandler handler, const char[] cmdname = "", int flags = 0, const char[] info_string = "");
forward TopMenuObject mod_topmenus_AddItem(const char[] name, TopMenuHandler handler, TopMenuObject parent, const char[] cmdname = "", int flags = 0, const char[] info_string = "");
forward int mod_topmenus_GetInfoString(TopMenuObject parent, char[] buffer, int maxlength);
forward int mod_topmenus_GetObjName(TopMenuObject topobj, char[] buffer, int maxlength);
forward void mod_topmenus_Remove(TopMenuObject topobj);
forward bool mod_topmenus_Display(int client, TopMenuPosition position);
forward bool mod_topmenus_DisplayCategory(TopMenuObject category, int client);
forward TopMenuObject mod_topmenus_FindCategory(const char[] name);
forward TopMenu mod_topmenus_CreateTopMenu(TopMenuHandler handler);
forward bool mod_topmenus_LoadTopMenuConfig(Handle topmenu, const char[] file, char[] error, int maxlength);
forward TopMenuObject mod_topmenus_AddToTopMenu(Handle topmenu, const char[] name, TopMenuObjectType type, TopMenuHandler handler, TopMenuObject parent, const char[] cmdname="", int flags=0, const char[] info_string="");
forward int mod_topmenus_GetTopMenuInfoString(Handle topmenu, TopMenuObject parent, char[] buffer, int maxlength);
forward int mod_topmenus_GetTopMenuObjName(Handle topmenu, TopMenuObject topobj, char[] buffer, int maxlength);
forward void mod_topmenus_RemoveFromTopMenu(Handle topmenu, TopMenuObject topobj);
forward bool mod_topmenus_DisplayTopMenu(Handle topmenu, int client, TopMenuPosition position);
forward bool mod_topmenus_DisplayTopMenuCategory(Handle topmenu, TopMenuObject category, int client);
forward TopMenuObject mod_topmenus_FindTopMenuCategory(Handle topmenu, const char[] name);
forward void mod_topmenus_SetTopMenuTitleCaching(Handle topmenu, bool cache_titles);
forward NominateResult mod_mapchooser_NominateMap(const char[] map, bool force, int owner);
forward bool mod_mapchooser_RemoveNominationByMap(const char[] map);
forward bool mod_mapchooser_RemoveNominationByOwner(int owner);
forward void mod_mapchooser_GetExcludeMapList(ArrayList array);
forward void mod_mapchooser_GetNominatedMapList(ArrayList maparray, ArrayList ownerarray = null);
forward bool mod_mapchooser_CanMapChooserStartVote();
forward void mod_mapchooser_InitiateMapChooserVote(MapChange when, ArrayList inputarray=null);
forward bool mod_mapchooser_HasEndOfMapVoteFinished();
forward bool mod_mapchooser_EndOfMapVoteEnabled();

// Modules


// ---- admincheats ----
#pragma semicolon 1

#include <sourcemod>
#include <admin>

public Plugin mod_admincheats_myinfo =
{
	name = "AdminCheats",
	author = "devicenull",
	description = "Allow admins to use cheat commands",
	version = "0.2",
	url = "http://www.sourcemod.net/"
};

#define mod_admincheats_MAX_COMMANDS 512
#define mod_admincheats_MAX_COMMAND_LENGTH 64

ConVar mod_admincheats_g_hCvarLevel;
ConVar mod_admincheats_g_hCvarVersion;

char mod_admincheats_g_CheatCommands[mod_admincheats_MAX_COMMANDS][mod_admincheats_MAX_COMMAND_LENGTH];
int mod_admincheats_g_CommandFlags[mod_admincheats_MAX_COMMANDS];
int mod_admincheats_g_NumCommands;

public void mod_admincheats_OnPluginStart()
{
	mod_admincheats_g_hCvarLevel = CreateConVar("sm_admin_cheats_level", "0", "Level required to execute cheat commands", FCVAR_PLUGIN | FCVAR_NOTIFY);
	mod_admincheats_g_hCvarVersion = CreateConVar("sm_admin_cheats_version", "0.2", "Version Information", FCVAR_PLUGIN | FCVAR_NOTIFY);

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

	char buffer[mod_admincheats_MAX_COMMAND_LENGTH];

	while (!hFile.EndOfFile() && ReadFileLine(hFile, buffer, sizeof(buffer)))
	{
		TrimString(buffer);

		if (buffer[0] == ';' || buffer[0] == '\0')
		{
			continue;
		}

		if (mod_admincheats_g_NumCommands >= mod_admincheats_MAX_COMMANDS)
		{
			LogError("[admincheats] WARNING: Too many cheat commands to hook them all, increase MAX_COMMANDS");
			break;
		}

		int flags = GetCommandFlags(buffer);

		if (flags & FCVAR_CHEAT)
		{
			mod_admincheats_g_CommandFlags[mod_admincheats_g_NumCommands] = flags;
			strcopy(mod_admincheats_g_CheatCommands[mod_admincheats_g_NumCommands], sizeof(mod_admincheats_g_CheatCommands[]), buffer);
			SetCommandFlags(buffer, flags & ~FCVAR_CHEAT);
			AddCommandListener(mod_admincheats_Listener_CheatCommand, buffer);
			mod_admincheats_g_NumCommands++;
		}
	}

	delete hFile;

	LogMessage("admincheats hooked %i commands", mod_admincheats_g_NumCommands);
}

public void mod_admincheats_OnPluginEnd()
{
	for (int i = 0; i < mod_admincheats_g_NumCommands; i++)
	{
		SetCommandFlags(mod_admincheats_g_CheatCommands[i], mod_admincheats_g_CommandFlags[i]);
	}

	LogMessage("admincheats unloaded, restoring cheat flags");
}

public Action mod_admincheats_Listener_CheatCommand(int client, const char[] command, int args)
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
	int level = mod_admincheats_g_hCvarLevel.IntValue;

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


// ---- admin-flatfile ----
/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Admin File Reader Plugin

 * Manages the standard flat files for admins.  This is the file to compile.

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



/* We like semicolons */

#pragma semicolon 1



#include <sourcemod>



public Plugin mod_admin_flatfile_myinfo = 

{

	name = "Admin File Reader",

	author = "AlliedModders LLC",

	description = "Reads admin files",

	version = SOURCEMOD_VERSION,

	url = "http://www.sourcemod.net/"

};



/** Various parsing globals */

bool mod_admin_flatfile_g_LoggedFileName = false;       /* Whether or not the file name has been logged */

int mod_admin_flatfile_g_ErrorCount = 0;                /* Current error count */

int mod_admin_flatfile_g_IgnoreLevel = 0;               /* Nested ignored section count, so users can screw up files safely */

int mod_admin_flatfile_g_CurrentLine = 0;               /* Current line we're on */

char mod_admin_flatfile_g_Filename[PLATFORM_MAX_PATH];  /* Used for error messages */




/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Admin File Reader Plugin

 * Reads overrides from the admin_levels.cfg file.  Do not compile

 * this directly.

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



enum mod_admin_flatfile_OverrideState

{

	OverrideState_None,

	OverrideState_Levels,

	OverrideState_Overrides,

}



static SMCParser mod_admin_flatfile_g_hOldOverrideParser;

static SMCParser mod_admin_flatfile_g_hNewOverrideParser;

static mod_admin_flatfile_OverrideState mod_admin_flatfile_g_OverrideState = OverrideState_None;



public SMCResult mod_admin_flatfile_ReadOldOverrides_NewSection(SMCParser smc, const char[] name, bool opt_quotes)

{

	if (mod_admin_flatfile_g_IgnoreLevel)

	{

		mod_admin_flatfile_g_IgnoreLevel++;

		return SMCParse_Continue;

	}

	

	if (mod_admin_flatfile_g_OverrideState == OverrideState_None)

	{

		if (StrEqual(name, "Levels"))

		{

			mod_admin_flatfile_g_OverrideState = OverrideState_Levels;

		} else {

			mod_admin_flatfile_g_IgnoreLevel++;

		}

	} else if (mod_admin_flatfile_g_OverrideState == OverrideState_Levels) {

		if (StrEqual(name, "Overrides"))

		{

			mod_admin_flatfile_g_OverrideState = OverrideState_Overrides;

		} else {

			mod_admin_flatfile_g_IgnoreLevel++;

		}

	} else {

		mod_admin_flatfile_g_IgnoreLevel++;

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadNewOverrides_NewSection(SMCParser smc, const char[] name, bool opt_quotes)

{

	if (mod_admin_flatfile_g_IgnoreLevel)

	{

		mod_admin_flatfile_g_IgnoreLevel++;

		return SMCParse_Continue;

	}

	

	if (mod_admin_flatfile_g_OverrideState == OverrideState_None)

	{

		if (StrEqual(name, "Overrides"))

		{

			mod_admin_flatfile_g_OverrideState = OverrideState_Overrides;

		} else {

			mod_admin_flatfile_g_IgnoreLevel++;

		}

	} else {

		mod_admin_flatfile_g_IgnoreLevel++;

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadOverrides_KeyValue(SMCParser smc, 

										const char[] key, 

										const char[] value,

										bool key_quotes, 

										bool value_quotes)

{

	if (mod_admin_flatfile_g_OverrideState != OverrideState_Overrides || mod_admin_flatfile_g_IgnoreLevel)

	{

		return SMCParse_Continue;

	}

	

	int flags = ReadFlagString(value);

	

	if (key[0] == '@')

	{

		AddCommandOverride(key[1], Override_CommandGroup, flags);

	} else {

		AddCommandOverride(key, Override_Command, flags);

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadOldOverrides_EndSection(SMCParser smc)

{

	/* If we're ignoring, skip out */

	if (mod_admin_flatfile_g_IgnoreLevel)

	{

		mod_admin_flatfile_g_IgnoreLevel--;

		return SMCParse_Continue;

	}

	

	if (mod_admin_flatfile_g_OverrideState == OverrideState_Levels)

	{

		mod_admin_flatfile_g_OverrideState = OverrideState_None;

	} else if (mod_admin_flatfile_g_OverrideState == OverrideState_Overrides) {

		/* We're totally done parsing */

		mod_admin_flatfile_g_OverrideState = OverrideState_Levels;

		return SMCParse_Halt;

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadNewOverrides_EndSection(SMCParser smc)

{

	/* If we're ignoring, skip out */

	if (mod_admin_flatfile_g_IgnoreLevel)

	{

		mod_admin_flatfile_g_IgnoreLevel--;

		return SMCParse_Continue;

	}

	

	if (mod_admin_flatfile_g_OverrideState == OverrideState_Overrides)

	{

		mod_admin_flatfile_g_OverrideState = OverrideState_None;

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadOverrides_CurrentLine(SMCParser smc, const char[] line, int lineno)

{

	mod_admin_flatfile_g_CurrentLine = lineno;

	

	return SMCParse_Continue;

}



static void mod_admin_flatfile_InitializeOverrideParsers()

{

	if (!mod_admin_flatfile_g_hOldOverrideParser)

	{

		mod_admin_flatfile_g_hOldOverrideParser = new SMCParser();

		mod_admin_flatfile_g_hOldOverrideParser.OnEnterSection = mod_admin_flatfile_ReadOldOverrides_NewSection;

		mod_admin_flatfile_g_hOldOverrideParser.OnKeyValue = mod_admin_flatfile_ReadOverrides_KeyValue;

		mod_admin_flatfile_g_hOldOverrideParser.OnLeaveSection = mod_admin_flatfile_ReadOldOverrides_EndSection;

		mod_admin_flatfile_g_hOldOverrideParser.OnRawLine = mod_admin_flatfile_ReadOverrides_CurrentLine;

	}

	if (!mod_admin_flatfile_g_hNewOverrideParser)

	{

		mod_admin_flatfile_g_hNewOverrideParser = new SMCParser();

		mod_admin_flatfile_g_hNewOverrideParser.OnEnterSection = mod_admin_flatfile_ReadNewOverrides_NewSection;

		mod_admin_flatfile_g_hNewOverrideParser.OnKeyValue = mod_admin_flatfile_ReadOverrides_KeyValue;

		mod_admin_flatfile_g_hNewOverrideParser.OnLeaveSection = mod_admin_flatfile_ReadNewOverrides_EndSection;

		mod_admin_flatfile_g_hNewOverrideParser.OnRawLine = mod_admin_flatfile_ReadOverrides_CurrentLine;

	}

}



void InternalReadOverrides(SMCParser parser, const char[] file)

{

	BuildPath(Path_SM, mod_admin_flatfile_g_Filename, sizeof(mod_admin_flatfile_g_Filename), file);

	

	/* Set states */

	InitGlobalStates();

	mod_admin_flatfile_g_OverrideState = OverrideState_None;

		

	SMCError err = parser.ParseFile(mod_admin_flatfile_g_Filename);

	if (err != SMCError_Okay)

	{

		char buffer[64];

		if (parser.GetErrorString(err, buffer, sizeof(buffer)))

		{

			ParseError("%s", buffer);

		} else {

			ParseError("Fatal parse error");

		}

	}

}



void ReadOverrides()

{

	mod_admin_flatfile_InitializeOverrideParsers();

	InternalReadOverrides(mod_admin_flatfile_g_hOldOverrideParser, "configs/admin_levels.cfg");

	InternalReadOverrides(mod_admin_flatfile_g_hNewOverrideParser, "configs/admin_overrides.cfg");

}





/**

 * vim: set ts=4 sw=4 tw=99 noet :

 * =============================================================================

 * SourceMod Admin File Reader Plugin

 * Reads the admin_groups.cfg file.  Do not compile this directly.

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



enum mod_admin_flatfile_GroupState

{

	GroupState_None,

	GroupState_Groups,

	GroupState_InGroup,

	GroupState_Overrides,

}



enum mod_admin_flatfile_GroupPass

{

	GroupPass_Invalid,

	GroupPass_First,

	GroupPass_Second,

}



static SMCParser mod_admin_flatfile_g_hGroupParser;

static GroupId mod_admin_flatfile_g_CurGrp = INVALID_GROUP_ID;

static mod_admin_flatfile_GroupState mod_admin_flatfile_g_GroupState = GroupState_None;

static mod_admin_flatfile_GroupPass mod_admin_flatfile_g_GroupPass = GroupPass_Invalid;

static bool mod_admin_flatfile_g_NeedReparse = false;



public SMCResult mod_admin_flatfile_ReadGroups_NewSection(SMCParser smc, const char[] name, bool opt_quotes)

{

	if (mod_admin_flatfile_g_IgnoreLevel)

	{

		mod_admin_flatfile_g_IgnoreLevel++;

		return SMCParse_Continue;

	}

	

	if (mod_admin_flatfile_g_GroupState == GroupState_None)

	{

		if (StrEqual(name, "Groups"))

		{

			mod_admin_flatfile_g_GroupState = GroupState_Groups;

		} else {

			mod_admin_flatfile_g_IgnoreLevel++;

		}

	} else if (mod_admin_flatfile_g_GroupState == GroupState_Groups) {

		if ((mod_admin_flatfile_g_CurGrp = CreateAdmGroup(name)) == INVALID_GROUP_ID)

		{

			mod_admin_flatfile_g_CurGrp = FindAdmGroup(name);

		}

		mod_admin_flatfile_g_GroupState = GroupState_InGroup;

	} else if (mod_admin_flatfile_g_GroupState == GroupState_InGroup) {

		if (StrEqual(name, "Overrides"))

		{

			mod_admin_flatfile_g_GroupState = GroupState_Overrides;

		} else {

			mod_admin_flatfile_g_IgnoreLevel++;

		}

	} else {

		mod_admin_flatfile_g_IgnoreLevel++;

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadGroups_KeyValue(SMCParser smc, 

										const char[] key, 

										const char[] value, 

										bool key_quotes, 

										bool value_quotes)

{

	if (mod_admin_flatfile_g_CurGrp == INVALID_GROUP_ID || mod_admin_flatfile_g_IgnoreLevel)

	{

		return SMCParse_Continue;

	}

	

	AdminFlag flag;

	

	if (mod_admin_flatfile_g_GroupPass == GroupPass_First)

	{

		if (mod_admin_flatfile_g_GroupState == GroupState_InGroup)

		{

			if (StrEqual(key, "flags"))

			{

				int len = strlen(value);

				for (int i=0; i<len; i++)

				{

					if (!FindFlagByChar(value[i], flag))

					{

						continue;

					}

					mod_admin_flatfile_g_CurGrp.SetFlag(flag, true);

				}

			} else if (StrEqual(key, "immunity")) {

				mod_admin_flatfile_g_NeedReparse = true;

			}

		} else if (mod_admin_flatfile_g_GroupState == GroupState_Overrides) {

			OverrideRule rule = Command_Deny;

			

			if (StrEqual(value, "allow", false))

			{

				rule = Command_Allow;

			}

			

			if (key[0] == '@')

			{

				mod_admin_flatfile_g_CurGrp.AddCommandOverride(key[1], Override_CommandGroup, rule);

			} else {

				mod_admin_flatfile_g_CurGrp.AddCommandOverride(key, Override_Command, rule);

			}

		}

	} else if (mod_admin_flatfile_g_GroupPass == GroupPass_Second

			   && mod_admin_flatfile_g_GroupState == GroupState_InGroup) {

		/* Check for immunity again, core should handle double inserts */

		if (StrEqual(key, "immunity"))

		{

			/* If it's a value we know about, use it */

			if (StrEqual(value, "*"))

			{

				mod_admin_flatfile_g_CurGrp.ImmunityLevel = 2;

			} else if (StrEqual(value, "$")) {

				mod_admin_flatfile_g_CurGrp.ImmunityLevel = 1;

			} else {

				int level;

				if (StringToIntEx(value, level))

				{

					mod_admin_flatfile_g_CurGrp.ImmunityLevel = level;

				} else {

					GroupId id;

					if (value[0] == '@')

					{

						id = FindAdmGroup(value[1]);

					} else {

						id = FindAdmGroup(value);

					}

					if (id != INVALID_GROUP_ID)

					{

						mod_admin_flatfile_g_CurGrp.AddGroupImmunity(id);

					} else {

						ParseError("Unable to find group: \"%s\"", value);

					}

				}

			}

		}

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadGroups_EndSection(SMCParser smc)

{

	/* If we're ignoring, skip out */

	if (mod_admin_flatfile_g_IgnoreLevel)

	{

		mod_admin_flatfile_g_IgnoreLevel--;

		return SMCParse_Continue;

	}

	

	if (mod_admin_flatfile_g_GroupState == GroupState_Overrides)

	{

		mod_admin_flatfile_g_GroupState = GroupState_InGroup;

	} else if (mod_admin_flatfile_g_GroupState == GroupState_InGroup) {

		mod_admin_flatfile_g_GroupState = GroupState_Groups;

		mod_admin_flatfile_g_CurGrp = INVALID_GROUP_ID;

	} else if (mod_admin_flatfile_g_GroupState == GroupState_Groups) {

		mod_admin_flatfile_g_GroupState = GroupState_None;

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadGroups_CurrentLine(SMCParser smc, const char[] line, int lineno)

{

	mod_admin_flatfile_g_CurrentLine = lineno;

	

	return SMCParse_Continue;

}



static void mod_admin_flatfile_InitializeGroupParser()

{

	if (!mod_admin_flatfile_g_hGroupParser)

	{

		mod_admin_flatfile_g_hGroupParser = new SMCParser();

		mod_admin_flatfile_g_hGroupParser.OnEnterSection = mod_admin_flatfile_ReadGroups_NewSection;

		mod_admin_flatfile_g_hGroupParser.OnKeyValue = mod_admin_flatfile_ReadGroups_KeyValue;

		mod_admin_flatfile_g_hGroupParser.OnLeaveSection = mod_admin_flatfile_ReadGroups_EndSection;

		mod_admin_flatfile_g_hGroupParser.OnRawLine = mod_admin_flatfile_ReadGroups_CurrentLine;

	}

}



static void mod_admin_flatfile_InternalReadGroups(const char[] path, mod_admin_flatfile_GroupPass pass)

{

	/* Set states */

	InitGlobalStates();

	mod_admin_flatfile_g_GroupState = GroupState_None;

	mod_admin_flatfile_g_CurGrp = INVALID_GROUP_ID;

	mod_admin_flatfile_g_GroupPass = pass;

	mod_admin_flatfile_g_NeedReparse = false;

		

	SMCError err = mod_admin_flatfile_g_hGroupParser.ParseFile(path);

	if (err != SMCError_Okay)

	{

		char buffer[64];

		if (mod_admin_flatfile_g_hGroupParser.GetErrorString(err, buffer, sizeof(buffer)))

		{

			ParseError("%s", buffer);

		} else {

			ParseError("Fatal parse error");

		}

	}

}



void ReadGroups()

{

	mod_admin_flatfile_InitializeGroupParser();

	

	BuildPath(Path_SM, mod_admin_flatfile_g_Filename, sizeof(mod_admin_flatfile_g_Filename), "configs/admin_groups.cfg");

	

	mod_admin_flatfile_InternalReadGroups(mod_admin_flatfile_g_Filename, GroupPass_First);

	if (mod_admin_flatfile_g_NeedReparse)

	{

		mod_admin_flatfile_InternalReadGroups(mod_admin_flatfile_g_Filename, GroupPass_Second);

	}

}





/**

 * vim: set ts=4 sw=4 tw=99 noet :

 * =============================================================================

 * SourceMod Admin File Reader Plugin

 * Reads the admins.cfg file.  Do not compile this directly.

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



enum mod_admin_flatfile_UserState

{

	UserState_None,

	UserState_Admins,

	UserState_InAdmin,

}



static SMCParser mod_admin_flatfile_g_hUserParser;

static mod_admin_flatfile_UserState mod_admin_flatfile_g_UserState = UserState_None;

static char mod_admin_flatfile_g_CurAuth[64];

static char mod_admin_flatfile_g_CurIdent[64];

static char mod_admin_flatfile_g_CurName[64];

static char mod_admin_flatfile_g_CurPass[64];

static ArrayList mod_admin_flatfile_g_GroupArray;

static int mod_admin_flatfile_g_CurFlags;

static int mod_admin_flatfile_g_CurImmunity;



public SMCResult mod_admin_flatfile_ReadUsers_NewSection(SMCParser smc, const char[] name, bool opt_quotes)

{

	if (mod_admin_flatfile_g_IgnoreLevel)

	{

		mod_admin_flatfile_g_IgnoreLevel++;

		return SMCParse_Continue;

	}

	

	if (mod_admin_flatfile_g_UserState == UserState_None)

	{

		if (StrEqual(name, "Admins"))

		{

			mod_admin_flatfile_g_UserState = UserState_Admins;

		}

		else

		{

			mod_admin_flatfile_g_IgnoreLevel++;

		}

	}

	else if (mod_admin_flatfile_g_UserState == UserState_Admins)

	{

		mod_admin_flatfile_g_UserState = UserState_InAdmin;

		strcopy(mod_admin_flatfile_g_CurName, sizeof(mod_admin_flatfile_g_CurName), name);

		mod_admin_flatfile_g_CurAuth[0] = '\0';

		mod_admin_flatfile_g_CurIdent[0] = '\0';

		mod_admin_flatfile_g_CurPass[0] = '\0';

		mod_admin_flatfile_g_GroupArray.Clear();

		mod_admin_flatfile_g_CurFlags = 0;

		mod_admin_flatfile_g_CurImmunity = 0;

	}

	else

	{

		mod_admin_flatfile_g_IgnoreLevel++;

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadUsers_KeyValue(SMCParser smc, 

									const char[] key, 

									const char[] value, 

									bool key_quotes, 

									bool value_quotes)

{

	if (mod_admin_flatfile_g_UserState != UserState_InAdmin || mod_admin_flatfile_g_IgnoreLevel)

	{

		return SMCParse_Continue;

	}

	

	if (StrEqual(key, "auth"))

	{

		strcopy(mod_admin_flatfile_g_CurAuth, sizeof(mod_admin_flatfile_g_CurAuth), value);

	}

	else if (StrEqual(key, "identity"))

	{

		strcopy(mod_admin_flatfile_g_CurIdent, sizeof(mod_admin_flatfile_g_CurIdent), value);

	}

	else if (StrEqual(key, "password")) 

	{

		strcopy(mod_admin_flatfile_g_CurPass, sizeof(mod_admin_flatfile_g_CurPass), value);

	} 

	else if (StrEqual(key, "group")) 

	{

		GroupId id = FindAdmGroup(value);

		if (id == INVALID_GROUP_ID)

		{

			ParseError("Unknown group \"%s\"", value);

		}



		mod_admin_flatfile_g_GroupArray.Push(id);

	} 

	else if (StrEqual(key, "flags")) 

	{

		int len = strlen(value);

		AdminFlag flag;

		

		for (int i = 0; i < len; i++)

		{

			if (!FindFlagByChar(value[i], flag))

			{

				ParseError("Invalid flag detected: %c", value[i]);

			}

			else

			{

				mod_admin_flatfile_g_CurFlags |= FlagToBit(flag);

			}

		}

	} 

	else if (StrEqual(key, "immunity")) 

	{

		mod_admin_flatfile_g_CurImmunity = StringToInt(value);

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadUsers_EndSection(SMCParser smc)

{

	if (mod_admin_flatfile_g_IgnoreLevel)

	{

		mod_admin_flatfile_g_IgnoreLevel--;

		return SMCParse_Continue;

	}

	

	if (mod_admin_flatfile_g_UserState == UserState_InAdmin)

	{

		/* Dump this user to memory */

		if (mod_admin_flatfile_g_CurIdent[0] != '\0' && mod_admin_flatfile_g_CurAuth[0] != '\0')

		{

			AdminFlag flags[26];

			AdminId id;

			int i, num_groups, num_flags;

			

			if ((id = FindAdminByIdentity(mod_admin_flatfile_g_CurAuth, mod_admin_flatfile_g_CurIdent)) == INVALID_ADMIN_ID)

			{

				id = CreateAdmin(mod_admin_flatfile_g_CurName);

				if (!id.BindIdentity(mod_admin_flatfile_g_CurAuth, mod_admin_flatfile_g_CurIdent))

				{

					RemoveAdmin(id);

					ParseError("Failed to bind auth \"%s\" to identity \"%s\"", mod_admin_flatfile_g_CurAuth, mod_admin_flatfile_g_CurIdent);

					return SMCParse_Continue;

				}

			}

			

			num_groups = mod_admin_flatfile_g_GroupArray.Length;

			for (i = 0; i < num_groups; i++)

			{

				id.InheritGroup(mod_admin_flatfile_g_GroupArray.Get(i));

			}

			

			id.SetPassword(mod_admin_flatfile_g_CurPass);

			if (id.ImmunityLevel < mod_admin_flatfile_g_CurImmunity)

			{

				id.ImmunityLevel = mod_admin_flatfile_g_CurImmunity;

			}

			

			num_flags = FlagBitsToArray(mod_admin_flatfile_g_CurFlags, flags, sizeof(flags));

			for (i = 0; i < num_flags; i++)

			{

				id.SetFlag(flags[i], true);

			}

		}

		else

		{

			ParseError("Failed to create admin: did you forget either the auth or identity properties?");

		}

		

		mod_admin_flatfile_g_UserState = UserState_Admins;

	}

	else if (mod_admin_flatfile_g_UserState == UserState_Admins)

	{

		mod_admin_flatfile_g_UserState = UserState_None;

	}

	

	return SMCParse_Continue;

}



public SMCResult mod_admin_flatfile_ReadUsers_CurrentLine(SMCParser smc, const char[] line, int lineno)

{

	mod_admin_flatfile_g_CurrentLine = lineno;

	

	return SMCParse_Continue;

}



static void mod_admin_flatfile_InitializeUserParser()

{

	if (!mod_admin_flatfile_g_hUserParser)

	{

		mod_admin_flatfile_g_hUserParser = new SMCParser();

		mod_admin_flatfile_g_hUserParser.OnEnterSection = mod_admin_flatfile_ReadUsers_NewSection;

		mod_admin_flatfile_g_hUserParser.OnKeyValue = mod_admin_flatfile_ReadUsers_KeyValue;

		mod_admin_flatfile_g_hUserParser.OnLeaveSection = mod_admin_flatfile_ReadUsers_EndSection;

		mod_admin_flatfile_g_hUserParser.OnRawLine = mod_admin_flatfile_ReadUsers_CurrentLine;

		

		mod_admin_flatfile_g_GroupArray = new ArrayList();

	}

}



void ReadUsers()

{

	mod_admin_flatfile_InitializeUserParser();

	

	BuildPath(Path_SM, mod_admin_flatfile_g_Filename, sizeof(mod_admin_flatfile_g_Filename), "configs/admins.cfg");



	/* Set states */

	InitGlobalStates();

	mod_admin_flatfile_g_UserState = UserState_None;

		

	SMCError err = mod_admin_flatfile_g_hUserParser.ParseFile(mod_admin_flatfile_g_Filename);

	if (err != SMCError_Okay)

	{

		char buffer[64];

		if (mod_admin_flatfile_g_hUserParser.GetErrorString(err, buffer, sizeof(buffer)))

		{

			ParseError("%s", buffer);

		}

		else

		{

			ParseError("Fatal parse error");

		}

	}

}





/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Admin File Reader Plugin

 * Reads the admins.cfg file.  Do not compile this directly.

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



public void mod_admin_flatfile_ReadSimpleUsers()

{

	BuildPath(Path_SM, mod_admin_flatfile_g_Filename, sizeof(mod_admin_flatfile_g_Filename), "configs/admins_simple.ini");

	

	File file = OpenFile(mod_admin_flatfile_g_Filename, "rt");

	if (!file)

	{

		ParseError("Could not open file!");

		return;

	}

	

	while (!file.EndOfFile())

	{

		char line[255];

		if (!file.ReadLine(line, sizeof(line)))

			break;

		

		/* Trim comments */

		int len = strlen(line);

		bool ignoring = false;

		for (int i=0; i<len; i++)

		{

			if (ignoring)

			{

				if (line[i] == '"')

					ignoring = false;

			} else {

				if (line[i] == '"')

				{

					ignoring = true;

				} else if (line[i] == ';') {

					line[i] = '\0';

					break;

				} else if (line[i] == '/'

							&& i != len - 1

							&& line[i+1] == '/')

				{

					line[i] = '\0';

					break;

				}

			}

		}

		

		TrimString(line);

		

		if ((line[0] == '/' && line[1] == '/')

			|| (line[0] == ';' || line[0] == '\0'))

		{

			continue;

		}

	

		ReadAdminLine(line);

	}

	

	file.Close();

}



void DecodeAuthMethod(const char[] auth, char method[32], int &offset)

{

	if ((StrContains(auth, "STEAM_") == 0) || (strncmp("0:", auth, 2) == 0) || (strncmp("1:", auth, 2) == 0))

	{

		// Steam2 Id

		strcopy(method, sizeof(method), AUTHMETHOD_STEAM);

		offset = 0;

	}

	else if (!strncmp(auth, "[U:", 3) && auth[strlen(auth) - 1] == ']')

	{

		// Steam3 Id

		strcopy(method, sizeof(method), AUTHMETHOD_STEAM);

		offset = 0;

	}

	else

	{

		if (auth[0] == '!')

		{

			strcopy(method, sizeof(method), AUTHMETHOD_IP);

			offset = 1;

		}

		else

		{

			strcopy(method, sizeof(method), AUTHMETHOD_NAME);

			offset = 0;

		}

	}

}



void ReadAdminLine(const char[] line)

{

	bool is_bound;

	AdminId admin;

	char auth[64];

	char auth_method[32];

	int idx, cur_idx, auth_offset;

	

	if ((cur_idx = BreakString(line, auth, sizeof(auth))) == -1)

	{

		/* This line is bad... we need at least two parameters */

		return;

	}

	

	idx = cur_idx;

	

	/* Check if we can bind beforehand */

	DecodeAuthMethod(auth, auth_method, auth_offset);

	if ((admin = FindAdminByIdentity(auth_method, auth[auth_offset])) == INVALID_ADMIN_ID)

	{

		/* There is no binding, create the admin */

		admin = CreateAdmin();

	}

	else

	{

		is_bound = true;

	}

	

	/* Read flags */

	char flags[64];	

	cur_idx = BreakString(line[idx], flags, sizeof(flags));

	idx += cur_idx;



	/* Read immunity level, if any */

	int level, flag_idx;



	if ((flag_idx = StringToIntEx(flags, level)) > 0)

	{

		admin.ImmunityLevel = level;

		if (flags[flag_idx] == ':')

		{

			flag_idx++;

		}

	}



	if (flags[flag_idx] == '@')

	{

		GroupId gid = FindAdmGroup(flags[flag_idx + 1]);

		if (gid == INVALID_GROUP_ID)

		{

			ParseError("Invalid group detected: %s", flags[flag_idx + 1]);

			return;

		}

		admin.InheritGroup(gid);

	}

	else

	{

		int len = strlen(flags[flag_idx]);

		bool is_default = false;

		for (int i=0; i<len; i++)

		{

			if (!level && flags[flag_idx + i] == '$')

			{

				admin.ImmunityLevel = 1;

			} else {

				AdminFlag flag;

				

				if (!FindFlagByChar(flags[flag_idx + i], flag))

				{

					ParseError("Invalid flag detected: %c", flags[flag_idx + i]);

					continue;

				}

				admin.SetFlag(flag, true);

			}

		}

		

		if (is_default)

		{

			GroupId gid = FindAdmGroup("Default");

			if (gid != INVALID_GROUP_ID)

			{

				admin.InheritGroup(gid);

			}

		}

	}

	

	/* Lastly, is there a password? */

	if (cur_idx != -1)

	{

		char password[64];

		BreakString(line[idx], password, sizeof(password));

		admin.SetPassword(password);

	}

	

	/* Now, bind the identity to something */

	if (!is_bound)

	{

		if (!admin.BindIdentity(auth_method, auth[auth_offset]))

		{

			/* We should never reach here */

			RemoveAdmin(admin);

			ParseError("Failed to bind identity %s (method %s)", auth[auth_offset], auth_method);			

		}

	}

}






public void mod_admin_flatfile_OnRebuildAdminCache(AdminCachePart part)

{

	if (part == AdminCache_Overrides)

	{

		ReadOverrides();

	} else if (part == AdminCache_Groups) {

		ReadGroups();

	} else if (part == AdminCache_Admins) {

		ReadUsers();

		mod_admin_flatfile_ReadSimpleUsers();

	}

}



void ParseError(const char[] format, any ...)

{

	char buffer[512];

	

	if (!mod_admin_flatfile_g_LoggedFileName)

	{

		LogError("Error(s) detected parsing %s", mod_admin_flatfile_g_Filename);

		mod_admin_flatfile_g_LoggedFileName = true;

	}

	

	VFormat(buffer, sizeof(buffer), format, 2);

	

	LogError(" (line %d) %s", mod_admin_flatfile_g_CurrentLine, buffer);

	

	mod_admin_flatfile_g_ErrorCount++;

}



void InitGlobalStates()

{

	mod_admin_flatfile_g_ErrorCount = 0;

	mod_admin_flatfile_g_IgnoreLevel = 0;

	mod_admin_flatfile_g_CurrentLine = 0;

	mod_admin_flatfile_g_LoggedFileName = false;

}



// ---- adminhelp ----
/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Admin Help Plugin

 * Displays and searches SourceMod commands and descriptions.

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



#pragma semicolon 1



#include <sourcemod>



#pragma newdecls required



#define mod_adminhelp_COMMANDS_PER_PAGE	10



public Plugin mod_adminhelp_myinfo = 

{

	name = "Admin Help",

	author = "AlliedModders LLC",

	description = "Display command information",

	version = SOURCEMOD_VERSION,

	url = "http://www.sourcemod.net/"

};



public void mod_adminhelp_OnPluginStart()

{

	LoadTranslations("common.phrases");

	LoadTranslations("adminhelp.phrases");

	RegConsoleCmd("sm_help", mod_adminhelp_HelpCmd, "Displays SourceMod commands and descriptions");

	RegConsoleCmd("sm_searchcmd", mod_adminhelp_HelpCmd, "Searches SourceMod commands");

}



public Action mod_adminhelp_HelpCmd(int client, int args)

{

	if (client && !IsClientInGame(client))

	{

		return Plugin_Handled;

	}

	

	char arg[64], CmdName[20];

	int PageNum = 1;

	bool DoSearch;



	GetCmdArg(0, CmdName, sizeof(CmdName));



	if (args >= 1)

	{

		GetCmdArg(1, arg, sizeof(arg));

		StringToIntEx(arg, PageNum);

		PageNum = (PageNum <= 0) ? 1 : PageNum;

	}



	DoSearch = (strcmp("sm_help", CmdName) == 0) ? false : true;



	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)

	{

		ReplyToCommand(client, "[SM] %t", "See console for output");

	}



	char Name[64];

	char Desc[255];

	char NoDesc[128];

	int Flags;

	Handle CmdIter = GetCommandIterator();



	FormatEx(NoDesc, sizeof(NoDesc), "%T", "No description available", client);



	if (DoSearch)

	{

		int i = 1;

		while (ReadCommandIterator(CmdIter, Name, sizeof(Name), Flags, Desc, sizeof(Desc)))

		{

			if ((StrContains(Name, arg, false) != -1) && CheckCommandAccess(client, Name, Flags))

			{

				PrintToConsole(client, "[%03d] %s - %s", i++, Name, (Desc[0] == '\0') ? NoDesc : Desc);

			}

		}



		if (i == 1)

		{

			PrintToConsole(client, "%t", "No matching results found");

		}

	} else {

		PrintToConsole(client, "%t", "SM help commands");		



		/* Skip the first N commands if we need to */

		if (PageNum > 1)

		{

			int i;

			int EndCmd = (PageNum-1) * mod_adminhelp_COMMANDS_PER_PAGE - 1;

			for (i=0; ReadCommandIterator(CmdIter, Name, sizeof(Name), Flags, Desc, sizeof(Desc)) && i<EndCmd; )

			{

				if (CheckCommandAccess(client, Name, Flags))

				{

					i++;

				}

			}



			if (i == 0)

			{

				PrintToConsole(client, "%t", "No commands available");

				delete CmdIter;

				return Plugin_Handled;

			}

		}



		/* Start printing the commands to the client */

		int i;

		int StartCmd = (PageNum-1) * mod_adminhelp_COMMANDS_PER_PAGE;

		for (i=0; ReadCommandIterator(CmdIter, Name, sizeof(Name), Flags, Desc, sizeof(Desc)) && i<mod_adminhelp_COMMANDS_PER_PAGE; )

		{

			if (CheckCommandAccess(client, Name, Flags))

			{

				i++;

				PrintToConsole(client, "[%03d] %s - %s", i+StartCmd, Name, (Desc[0] == '\0') ? NoDesc : Desc);

			}

		}



		if (i == 0)

		{

			PrintToConsole(client, "%t", "No commands available");

		} else {

			PrintToConsole(client, "%t", "Entries n - m in page k", StartCmd+1, i+StartCmd, PageNum);

		}



		/* Test if there are more commands available */

		if (ReadCommandIterator(CmdIter, Name, sizeof(Name), Flags, Desc, sizeof(Desc)) && CheckCommandAccess(client, Name, Flags))

		{

			PrintToConsole(client, "%t", "Type sm_help to see more", PageNum+1);

		}

	}



	delete CmdIter;



	return Plugin_Handled;

}



// ---- adminmenu ----
/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Admin Menu Plugin

 * Creates the base admin menu, for plugins to add items to.

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



#pragma semicolon 1



#include <sourcemod>

#include <topmenus>



#pragma newdecls required



public Plugin mod_adminmenu_myinfo = 

{

	name = "Admin Menu",

	author = "AlliedModders LLC",

	description = "Administration Menu",

	version = SOURCEMOD_VERSION,

	url = "http://www.sourcemod.net/"

};



/* Forwards */

GlobalForward mod_adminmenu_hOnAdminMenuReady;

GlobalForward mod_adminmenu_hOnAdminMenuCreated;



/* Menus */

TopMenu mod_adminmenu_hAdminMenu;



/* Top menu objects */

TopMenuObject mod_adminmenu_obj_playercmds = INVALID_TOPMENUOBJECT;

TopMenuObject mod_adminmenu_obj_servercmds = INVALID_TOPMENUOBJECT;

TopMenuObject mod_adminmenu_obj_votingcmds = INVALID_TOPMENUOBJECT;




// vim: set noet:
#define mod_adminmenu_NAME_LENGTH 64
#define mod_adminmenu_CMD_LENGTH 255

#define mod_adminmenu_ARRAY_STRING_LENGTH 32

enum mod_adminmenu_struct GroupCommands
{
	ArrayList groupListName;
	ArrayList groupListCommand;
}

GroupCommands mod_adminmenu_g_groupList;
int mod_adminmenu_g_groupCount;

SMCParser mod_adminmenu_g_configParser;

enum mod_adminmenu_struct Places
{
	int category;
	int item;
	int replaceNum;
}

char mod_adminmenu_g_command[MAXPLAYERS+1][mod_adminmenu_CMD_LENGTH];
Places mod_adminmenu_g_currentPlace[MAXPLAYERS+1];

/**
 * What to put in the 'info' menu field (for PlayerList and Player_Team menus only)
 */
enum mod_adminmenu_PlayerMethod
{		
	ClientId,				/** Client id number ( 1 - Maxplayers) */
	UserId,					/** Client userid */
	Name,					/** Client Name */
	SteamId,				/** Client Steamid */
	IpAddress,				/** Client's Ip Address */
	UserId2					/** Userid (not prefixed with #) */
};

enum mod_adminmenu_ExecuteType
{
	Execute_Player,
	Execute_Server
}

enum mod_adminmenu_SubMenu_Type
{
	SubMenu_Group,
	SubMenu_GroupPlayer,
	SubMenu_Player,
	SubMenu_MapCycle,
	SubMenu_List,
	SubMenu_OnOff	
}

enum mod_adminmenu_struct Item
{
	char cmd[256];
	mod_adminmenu_ExecuteType execute;
	ArrayList submenus;
}

enum mod_adminmenu_struct Submenu
{
	mod_adminmenu_SubMenu_Type type;
	char title[32];
	mod_adminmenu_PlayerMethod method;
	int listcount;
	DataPack listdata;
}

ArrayList mod_adminmenu_g_DataArray;

void BuildDynamicMenu()
{
	Item itemInput;
	mod_adminmenu_g_DataArray = new ArrayList(sizeof(itemInput));
	
	char executeBuffer[32];
	
	KeyValues kvMenu = new KeyValues("Commands");
	kvMenu.SetEscapeSequences(true); 
	
	char file[256];
	
	/* As a compatibility shim, we use the old file if it exists. */
	BuildPath(Path_SM, file, 255, "configs/dynamicmenu/menu.ini");
	if (FileExists(file))
	{
		LogError("Warning! configs/dynamicmenu/menu.ini is now configs/adminmenu_custom.txt.");
		LogError("Read the 1.0.2 release notes, as the dynamicmenu folder has been removed.");
	}
	else
	{
		BuildPath(Path_SM, file, 255, "configs/adminmenu_custom.txt");
	}
	
	FileToKeyValues(kvMenu, file);
	
	char name[mod_adminmenu_NAME_LENGTH];
	char buffer[mod_adminmenu_NAME_LENGTH];
		
	if (!kvMenu.GotoFirstSubKey())
		return;
	
	char admin[30];
	
	TopMenuObject categoryId;
	
	do
	{		
		kvMenu.GetSectionName(buffer, sizeof(buffer));

		kvMenu.GetString("admin", admin, sizeof(admin),"sm_admin");
				
		if ((categoryId = mod_adminmenu_hAdminMenu.mod_topmenus_FindCategory(buffer)) == INVALID_TOPMENUOBJECT)
		{
			categoryId = mod_adminmenu_hAdminMenu.mod_topmenus_AddCategory(buffer,
							mod_adminmenu_DynamicMenuCategoryHandler,
							admin,
							ADMFLAG_GENERIC,
							name);

		}

		char category_name[mod_adminmenu_NAME_LENGTH];
		strcopy(category_name, sizeof(category_name), buffer);
		
		if (!kvMenu.GotoFirstSubKey())
		{
			return;
		}
		
		do
		{		
			kvMenu.GetSectionName(buffer, sizeof(buffer));
			
			kvMenu.GetString("admin", admin, sizeof(admin),"");
			
			if (admin[0] == '\0')
			{
				//No 'admin' keyvalue was found
				//Use the first argument of the 'cmd' string instead
				
				char temp[64];
				kvMenu.GetString("cmd", temp, sizeof(temp),"");
				
				BreakString(temp, admin, sizeof(admin));
			}
			
			
			kvMenu.GetString("cmd", itemInput.cmd, sizeof(itemInput.cmd));	
			kvMenu.GetString("execute", executeBuffer, sizeof(executeBuffer));
			
			if (StrEqual(executeBuffer, "server"))
			{
				itemInput.execute = Execute_Server;
			}
			else //assume player type execute
			{
				itemInput.execute = Execute_Player;
			}
								
			/* iterate all submenus and load data into itemInput.submenus (ArrayList) */
			
			int count = 1;
			char countBuffer[10] = "1";
			
			char inputBuffer[48];
			
			while (kvMenu.JumpToKey(countBuffer))
			{
				Submenu submenuInput;
					
				if (count == 1)
				{
					itemInput.submenus = new ArrayList(sizeof(submenuInput));	
				}
					
				kvMenu.GetString("type", inputBuffer, sizeof(inputBuffer));
					
				if (strncmp(inputBuffer,"group",5)==0)
				{	
					if (StrContains(inputBuffer, "player") != -1)
					{			
						submenuInput.type = SubMenu_GroupPlayer;
					}
					else
					{
						submenuInput.type = SubMenu_Group;
					}
				}			
				else if (StrEqual(inputBuffer,"mapcycle"))
				{
					submenuInput.type = SubMenu_MapCycle;
					
					kvMenu.GetString("path", inputBuffer, sizeof(inputBuffer),"mapcycle.txt");
					
					submenuInput.listdata = new DataPack();
					submenuInput.listdata.WriteString(inputBuffer);
					submenuInput.listdata.Reset();
				}
				else if (StrContains(inputBuffer, "player") != -1)
				{			
					submenuInput.type = SubMenu_Player;
				}
				else if (StrEqual(inputBuffer,"onoff"))
				{
					submenuInput.type = SubMenu_OnOff;
				}		
				else //assume 'list' type
				{
					submenuInput.type = SubMenu_List;
					
					submenuInput.listdata = new DataPack();
					
					char temp[6];
					char value[64];
					char text[64];
					char subadm[30];	//  same as "admin", cf. line 110
					int i=1;
					bool more = true;
					
					int listcount = 0;
								
					do
					{
						Format(temp,3,"%i",i);
						kvMenu.GetString(temp, value, sizeof(value), "");
						
						Format(temp,5,"%i.",i);
						kvMenu.GetString(temp, text, sizeof(text), value);
						
						Format(temp,5,"%i*",i);
						kvMenu.GetString(temp, subadm, sizeof(subadm),"");	
						
						if (value[0]=='\0')
						{
							more = false;
						}
						else
						{
							listcount++;
							submenuInput.listdata.WriteString(value);
							submenuInput.listdata.WriteString(text);
							submenuInput.listdata.WriteString(subadm);
						}
						
						i++;
										
					} while (more);
					
					submenuInput.listdata.Reset();
					submenuInput.listcount = listcount;
				}
				
				if ((submenuInput.type == SubMenu_Player) || (submenuInput.type == SubMenu_GroupPlayer))
				{
					kvMenu.GetString("method", inputBuffer, sizeof(inputBuffer));
					
					if (StrEqual(inputBuffer, "clientid"))
					{
						submenuInput.method = ClientId;
					}
					else if (StrEqual(inputBuffer, "steamid"))
					{
						submenuInput.method = SteamId;
					}
					else if (StrEqual(inputBuffer, "userid2"))
					{
						submenuInput.method = UserId2;
					}
					else if (StrEqual(inputBuffer, "userid"))
					{
						submenuInput.method = UserId;
					}
					else if (StrEqual(inputBuffer, "ip"))
					{
						submenuInput.method = IpAddress;
					}
					else
					{
						submenuInput.method = Name;
					}				
				}
				
				kvMenu.GetString("title", inputBuffer, sizeof(inputBuffer));
				strcopy(submenuInput.title, sizeof(submenuInput.title), inputBuffer);
					
				count++;
				Format(countBuffer, sizeof(countBuffer), "%i", count);
					
				itemInput.submenus.PushArray(submenuInput);
				
				kvMenu.GoBack();	
			}
				
			/* Save this entire item into the global items array and add it to the menu */
				
			int location = mod_adminmenu_g_DataArray.PushArray(itemInput);
			
			char locString[10];
			IntToString(location, locString, sizeof(locString));

			if (mod_adminmenu_hAdminMenu.mod_topmenus_AddItem(buffer,
				mod_adminmenu_DynamicMenuItemHandler,
  				categoryId,
  				admin,
  				ADMFLAG_GENERIC,
  				locString) == INVALID_TOPMENUOBJECT)
			{
				LogError("Duplicate command name \"%s\" in adminmenu_custom.txt category \"%s\"", buffer, category_name);
			}
		
		} while (kvMenu.GotoNextKey());
		
		kvMenu.GoBack();
		
	} while (kvMenu.GotoNextKey());
	
	delete kvMenu;
}

void ParseConfigs()
{
	if (!mod_adminmenu_g_configParser)
		mod_adminmenu_g_configParser = new SMCParser();
	
	mod_adminmenu_g_configParser.OnEnterSection = mod_adminmenu_NewSection;
	mod_adminmenu_g_configParser.OnKeyValue = mod_adminmenu_KeyValue;
	mod_adminmenu_g_configParser.OnLeaveSection = mod_adminmenu_EndSection;
	
	delete mod_adminmenu_g_groupList.groupListName;
	delete mod_adminmenu_g_groupList.groupListCommand;
	
	mod_adminmenu_g_groupList.groupListName = new ArrayList(mod_adminmenu_ARRAY_STRING_LENGTH);
	mod_adminmenu_g_groupList.groupListCommand = new ArrayList(mod_adminmenu_ARRAY_STRING_LENGTH);
	
	char configPath[256];
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/dynamicmenu/adminmenu_grouping.txt");
	if (FileExists(configPath))
	{
		LogError("Warning! configs/dynamicmenu/adminmenu_grouping.txt is now configs/adminmenu_grouping.txt.");
		LogError("Read the 1.0.2 release notes, as the dynamicmenu folder has been removed.");
	}
	else
	{
		BuildPath(Path_SM, configPath, sizeof(configPath), "configs/adminmenu_grouping.txt");
	}
	
	if (!FileExists(configPath))
	{
		LogError("Unable to locate admin menu groups file: %s", configPath);
			
		return;		
	}
	
	int line;
	SMCError err = mod_adminmenu_g_configParser.ParseFile(configPath, line);
	if (err != SMCError_Okay)
	{
		char error[256];
		SMC_GetErrorString(err, error, sizeof(error));
		LogError("Could not parse file (line %d, file \"%s\"):", line, configPath);
		LogError("Parser encountered error: %s", error);
	}
	
	return;
}

public SMCResult mod_adminmenu_NewSection(SMCParser smc, const char[] name, bool opt_quotes)
{

}

public SMCResult mod_adminmenu_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	mod_adminmenu_g_groupList.groupListName.PushString(key);
	mod_adminmenu_g_groupList.groupListCommand.PushString(value);
}

public SMCResult mod_adminmenu_EndSection(SMCParser smc)
{
	mod_adminmenu_g_groupCount = mod_adminmenu_g_groupList.groupListName.Length;
}

public void mod_adminmenu_DynamicMenuCategoryHandler(TopMenu topmenu, 
						TopMenuAction action,
						TopMenuObject object_id,
						int param,
						char[] buffer,
						int maxlength)
{
	if ((action == TopMenuAction_DisplayTitle) || (action == TopMenuAction_DisplayOption))
	{
		topmenu.mod_topmenus_GetObjName(object_id, buffer, maxlength);
	}
}

public void mod_adminmenu_DynamicMenuItemHandler(TopMenu topmenu, 
					  TopMenuAction action,
					  TopMenuObject object_id,
					  int param,
					  char[] buffer,
					  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		topmenu.mod_topmenus_GetObjName(object_id, buffer, maxlength);
	}
	else if (action == TopMenuAction_SelectOption)
	{	
		char locString[10];
		topmenu.mod_topmenus_GetInfoString(object_id, locString, sizeof(locString));
		
		int location = StringToInt(locString);
		
		Item output;
		mod_adminmenu_g_DataArray.GetArray(location, output);
		
		strcopy(mod_adminmenu_g_command[param], sizeof(mod_adminmenu_g_command[]), output.cmd);
					
		mod_adminmenu_g_currentPlace[param].item = location;
		mod_adminmenu_g_currentPlace[param].replaceNum = 1;
		
		mod_adminmenu_ParamCheck(param);
	}
}

public void mod_adminmenu_ParamCheck(int client)
{
	char buffer[6];
	char buffer2[6];
	
	Item outputItem;
	Submenu outputSubmenu;
	
	mod_adminmenu_g_DataArray.GetArray(mod_adminmenu_g_currentPlace[client].item, outputItem);
		
	if (mod_adminmenu_g_currentPlace[client].replaceNum < 1)
	{
		mod_adminmenu_g_currentPlace[client].replaceNum = 1;
	}
	
	Format(buffer, 5, "#%i", mod_adminmenu_g_currentPlace[client].replaceNum);
	Format(buffer2, 5, "@%i", mod_adminmenu_g_currentPlace[client].replaceNum);
	
	if (StrContains(mod_adminmenu_g_command[client], buffer) != -1 || StrContains(mod_adminmenu_g_command[client], buffer2) != -1)
	{
		outputItem.submenus.GetArray(mod_adminmenu_g_currentPlace[client].replaceNum - 1, outputSubmenu);
		
		Menu itemMenu = new Menu(mod_adminmenu_Menu_Selection);
		itemMenu.ExitBackButton = true;
			
		if ((outputSubmenu.type == SubMenu_Group) || (outputSubmenu.type == SubMenu_GroupPlayer))
		{	
			char nameBuffer[mod_adminmenu_ARRAY_STRING_LENGTH];
			char commandBuffer[mod_adminmenu_ARRAY_STRING_LENGTH];
		
			for (int i = 0; i<mod_adminmenu_g_groupCount; i++)
			{			
				mod_adminmenu_g_groupList.groupListName.GetString(i, nameBuffer, sizeof(nameBuffer));
				mod_adminmenu_g_groupList.groupListCommand.GetString(i, commandBuffer, sizeof(commandBuffer));
				itemMenu.mod_topmenus_AddItem(commandBuffer, nameBuffer);
			}
		}
		
		if (outputSubmenu.type == SubMenu_MapCycle)
		{	
			char path[200];
			outputSubmenu.listdata.ReadString(path, sizeof(path));
			outputSubmenu.listdata.Reset();
		
			File file = OpenFile(path, "rt");
			char readData[128];
			
			if (file)
			{
				while (!file.EndOfFile() && file.ReadLine(readData, sizeof(readData)))
				{
					TrimString(readData);
					
					if (IsMapValid(readData))
					{
						itemMenu.mod_topmenus_AddItem(readData, readData);
					}
				}
			}
		}
		else if ((outputSubmenu.type == SubMenu_Player) || (outputSubmenu.type == SubMenu_GroupPlayer))
		{
			mod_adminmenu_PlayerMethod playermethod = outputSubmenu.method;
		
			char nameBuffer[MAX_NAME_LENGTH];
			char infoBuffer[32];
			char temp[4];
			
			//loop through players. Add name as text and name/userid/steamid as info
			for (int i=1; i<=MaxClients; i++)
			{
				if (IsClientInGame(i))
				{			
					GetClientName(i, nameBuffer, sizeof(nameBuffer));
					
					switch (playermethod)
					{
						case UserId:
						{
							int userid = GetClientUserId(i);
							Format(infoBuffer, sizeof(infoBuffer), "#%i", userid);
							itemMenu.mod_topmenus_AddItem(infoBuffer, nameBuffer);	
						}
						case UserId2:
						{
							int userid = GetClientUserId(i);
							Format(infoBuffer, sizeof(infoBuffer), "%i", userid);
							itemMenu.mod_topmenus_AddItem(infoBuffer, nameBuffer);							
						}
						case SteamId:
						{
							if (GetClientAuthId(i, AuthId_Steam2, infoBuffer, sizeof(infoBuffer)))
								itemMenu.mod_topmenus_AddItem(infoBuffer, nameBuffer);
						}	
						case IpAddress:
						{
							GetClientIP(i, infoBuffer, sizeof(infoBuffer));
							itemMenu.mod_topmenus_AddItem(infoBuffer, nameBuffer);							
						}
						case Name:
						{
							itemMenu.mod_topmenus_AddItem(nameBuffer, nameBuffer);
						}	
						default: //assume client id
						{
							Format(temp,3,"%i",i);
							itemMenu.mod_topmenus_AddItem(temp, nameBuffer);						
						}								
					}
				}
			}
		}
		else if (outputSubmenu.type == SubMenu_OnOff)
		{
			itemMenu.mod_topmenus_AddItem("1", "On");
			itemMenu.mod_topmenus_AddItem("0", "Off");
		}		
		else
		{
			char value[64];
			char text[64];
					
			char admin[mod_adminmenu_NAME_LENGTH];
			
			for (int i=0; i<outputSubmenu.listcount; i++)
			{
				outputSubmenu.listdata.ReadString(value, sizeof(value));
				outputSubmenu.listdata.ReadString(text, sizeof(text));
				outputSubmenu.listdata.ReadString(admin, sizeof(admin));
				
				if (CheckCommandAccess(client, admin, 0))
				{
					itemMenu.mod_topmenus_AddItem(value, text);
				}
			}
			
			outputSubmenu.listdata.Reset();
		}
		
		itemMenu.SetTitle(outputSubmenu.title);
		
		itemMenu.mod_topmenus_Display(client, MENU_TIME_FOREVER);
	}
	else
	{	
		//nothing else need to be done. Run teh command.
		
		mod_adminmenu_hAdminMenu.mod_topmenus_Display(client, TopMenuPosition_LastCategory);
		
		char unquotedCommand[mod_adminmenu_CMD_LENGTH];
		UnQuoteString(mod_adminmenu_g_command[client], unquotedCommand, sizeof(unquotedCommand), "#@");
		
		if (outputItem.execute == Execute_Player) // assume 'player' type execute option
		{
			FakeClientCommand(client, unquotedCommand);
		}
		else // assume 'server' type execute option
		{
			InsertServerCommand(unquotedCommand);
			ServerExecute();
		}

		mod_adminmenu_g_command[client][0] = '\0';
		mod_adminmenu_g_currentPlace[client].replaceNum = 1;
	}
}

public int mod_adminmenu_Menu_Selection(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	
	if (action == MenuAction_Select)
	{
		char unquotedinfo[mod_adminmenu_NAME_LENGTH];
 
		/* Get item info */
		bool found = menu.GetItem(param2, unquotedinfo, sizeof(unquotedinfo));
		
		if (!found)
		{
			return 0;
		}
		
		char info[mod_adminmenu_NAME_LENGTH*2+1];
		QuoteString(unquotedinfo, info, sizeof(info), "#@");
		
		
		char buffer[6];
		char infobuffer[mod_adminmenu_NAME_LENGTH+2];
		Format(infobuffer, sizeof(infobuffer), "\"%s\"", info);
		
		Format(buffer, 5, "#%i", mod_adminmenu_g_currentPlace[param1].replaceNum);
		ReplaceString(mod_adminmenu_g_command[param1], sizeof(mod_adminmenu_g_command[]), buffer, infobuffer);
		//replace #num with the selected option (quoted)
		
		Format(buffer, 5, "@%i", mod_adminmenu_g_currentPlace[param1].replaceNum);
		ReplaceString(mod_adminmenu_g_command[param1], sizeof(mod_adminmenu_g_command[]), buffer, info);
		//replace @num with the selected option (unquoted)
		
		// Increment the parameter counter.
		mod_adminmenu_g_currentPlace[param1].replaceNum++;
		
		mod_adminmenu_ParamCheck(param1);
	}
	
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		//client exited we should go back to submenu i think
		mod_adminmenu_hAdminMenu.mod_topmenus_Display(param1, TopMenuPosition_LastCategory);
	}

	return 0;
}

stock bool QuoteString(char[] input, char[] output, int maxlen, char[] quotechars)
{
	int count = 0;
	int len = strlen(input);
	
	for (int i=0; i<len; i++)
	{
		output[count] = input[i];
		count++;
		
		if (count >= maxlen)
		{
			/* Null terminate for safety */
			output[maxlen-1] = 0;
			return false;	
		}
		
		if (FindCharInString(quotechars, input[i]) != -1 || input[i] == '\\')
		{
			/* This char needs escaping */
			output[count] = '\\';
			count++;
			
			if (count >= maxlen)
			{
				/* Null terminate for safety */
				output[maxlen-1] = 0;
				return false;	
			}		
		}
	}
	
	output[count] = 0;
	
	return true;
}

stock bool UnQuoteString(char[] input, char[] output, int maxlen, char[] quotechars)
{
	int count = 1;
	int len = strlen(input);
	
	output[0] = input[0];
	
	for (int i=1; i<len; i++)
	{
		output[count] = input[i];
		count++;
		
		if (input[i+1] == '\\' && (input[i] == '\\' || FindCharInString(quotechars, input[i]) != -1))
		{
			/* valid quotechar followed by a backslash - Skip */
			i++; 
		}
		
		if (count >= maxlen)
		{
			/* Null terminate for safety */
			output[maxlen-1] = 0;
			return false;	
		}
	}
	
	output[count] = 0;
	
	return true;
}





public APLRes mod_adminmenu_AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)

{

	CreateNative("GetAdminTopMenu", mod_adminmenu___GetAdminTopMenu);

	CreateNative("AddTargetsToMenu", mod_adminmenu___AddTargetsToMenu);

	CreateNative("AddTargetsToMenu2", mod_adminmenu___AddTargetsToMenu2);

	RegPluginLibrary("adminmenu");

	return APLRes_Success;

}



public void mod_adminmenu_OnPluginStart()

{

	LoadTranslations("common.phrases");

	LoadTranslations("adminmenu.phrases");

	

	mod_adminmenu_hOnAdminMenuCreated = new GlobalForward("OnAdminMenuCreated", ET_Ignore, Param_Cell);

	mod_adminmenu_hOnAdminMenuReady = new GlobalForward("OnAdminMenuReady", ET_Ignore, Param_Cell);



	RegAdminCmd("sm_admin", mod_adminmenu_Command_DisplayMenu, ADMFLAG_GENERIC, "Displays the admin menu");

}



public void mod_adminmenu_OnConfigsExecuted()

{

	char path[PLATFORM_MAX_PATH];

	char error[256];

	

	BuildPath(Path_SM, path, sizeof(path), "configs/adminmenu_sorting.txt");

	

	if (!mod_adminmenu_hAdminMenu.mod_topmenus_LoadConfig(path, error, sizeof(error)))

	{

		LogError("Could not load admin menu config (file \"%s\": %s)", path, error);

		return;

	}

}



public void mod_adminmenu_OnMapStart()

{

	ParseConfigs();

}



public void mod_adminmenu_OnAllPluginsLoaded()

{

	mod_adminmenu_hAdminMenu = new TopMenu(mod_adminmenu_DefaultCategoryHandler);

	

	mod_adminmenu_obj_playercmds = mod_adminmenu_hAdminMenu.mod_topmenus_AddCategory("PlayerCommands", mod_adminmenu_DefaultCategoryHandler);

	mod_adminmenu_obj_servercmds = mod_adminmenu_hAdminMenu.mod_topmenus_AddCategory("ServerCommands", mod_adminmenu_DefaultCategoryHandler);

	mod_adminmenu_obj_votingcmds = mod_adminmenu_hAdminMenu.mod_topmenus_AddCategory("VotingCommands", mod_adminmenu_DefaultCategoryHandler);

		

	BuildDynamicMenu();

	

	Call_StartForward(mod_adminmenu_hOnAdminMenuCreated);

	Call_PushCell(mod_adminmenu_hAdminMenu);

	Call_Finish();

	

		mod_basecomm_OnAdminMenuReady(mod_adminmenu_hAdminMenu);
	mod_basecommands_OnAdminMenuReady(mod_adminmenu_hAdminMenu);
	mod_basevotes_OnAdminMenuReady(mod_adminmenu_hAdminMenu);
	mod_funcommands_OnAdminMenuReady(mod_adminmenu_hAdminMenu);
	mod_funvotes_OnAdminMenuReady(mod_adminmenu_hAdminMenu);
	mod_playercommands_OnAdminMenuReady(mod_adminmenu_hAdminMenu);
	mod_sbpp_comms_OnAdminMenuReady(mod_adminmenu_hAdminMenu);
	mod_sbpp_main_OnAdminMenuReady(mod_adminmenu_hAdminMenu);

}



public void mod_adminmenu_DefaultCategoryHandler(TopMenu topmenu, 

						TopMenuAction action,

						TopMenuObject object_id,

						int param,

						char[] buffer,

						int maxlength)

{

	if (action == TopMenuAction_DisplayTitle)

	{

		if (object_id == INVALID_TOPMENUOBJECT)

		{

			Format(buffer, maxlength, "%T:", "Admin Menu", param);

		}

		else if (object_id == mod_adminmenu_obj_playercmds)

		{

			Format(buffer, maxlength, "%T:", "Player Commands", param);

		}

		else if (object_id == mod_adminmenu_obj_servercmds)

		{

			Format(buffer, maxlength, "%T:", "Server Commands", param);

		}

		else if (object_id == mod_adminmenu_obj_votingcmds)

		{

			Format(buffer, maxlength, "%T:", "Voting Commands", param);

		}

	}

	else if (action == TopMenuAction_DisplayOption)

	{

		if (object_id == mod_adminmenu_obj_playercmds)

		{

			Format(buffer, maxlength, "%T", "Player Commands", param);

		}

		else if (object_id == mod_adminmenu_obj_servercmds)

		{

			Format(buffer, maxlength, "%T", "Server Commands", param);

		}

		else if (object_id == mod_adminmenu_obj_votingcmds)

		{

			Format(buffer, maxlength, "%T", "Voting Commands", param);

		}

	}

}



public any mod_adminmenu___GetAdminTopMenu(Handle plugin, int numParams)

{

	return mod_adminmenu_hAdminMenu;

}



public int mod_adminmenu___AddTargetsToMenu(Handle plugin, int numParams)

{

	bool alive_only = false;

	

	if (numParams >= 4)

	{

		alive_only = GetNativeCell(4);

	}

	

	return UTIL_AddTargetsToMenu(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), alive_only);

}



public int mod_adminmenu___AddTargetsToMenu2(Handle plugin, int numParams)

{

	return UTIL_AddTargetsToMenu2(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3));

}



public Action mod_adminmenu_Command_DisplayMenu(int client, int args)

{

	if (client == 0)

	{

		ReplyToCommand(client, "[SM] %t", "Command is in-game only");

		return Plugin_Handled;

	}

	

	mod_adminmenu_hAdminMenu.mod_topmenus_Display(client, TopMenuPosition_Start);

	return Plugin_Handled;

}



stock int UTIL_AddTargetsToMenu2(Menu menu, int source_client, int flags)

{

	char user_id[12];

	char name[MAX_NAME_LENGTH];

	char display[MAX_NAME_LENGTH+12];

	

	int num_clients;

	

	for (int i = 1; i <= MaxClients; i++)

	{

		if (!IsClientConnected(i) || IsClientInKickQueue(i))

		{

			continue;

		}

		

		if (((flags & COMMAND_FILTER_NO_BOTS) == COMMAND_FILTER_NO_BOTS)

			&& IsFakeClient(i))

		{

			continue;

		}

		

		if (((flags & COMMAND_FILTER_CONNECTED) != COMMAND_FILTER_CONNECTED)

			&& !IsClientInGame(i))

		{

			continue;

		}

		

		if (((flags & COMMAND_FILTER_ALIVE) == COMMAND_FILTER_ALIVE) 

			&& !IsPlayerAlive(i))

		{

			continue;

		}

		

		if (((flags & COMMAND_FILTER_DEAD) == COMMAND_FILTER_DEAD)

			&& IsPlayerAlive(i))

		{

			continue;

		}

		

		if ((source_client && ((flags & COMMAND_FILTER_NO_IMMUNITY) != COMMAND_FILTER_NO_IMMUNITY))

			&& !CanUserTarget(source_client, i))

		{

			continue;

		}

		

		IntToString(GetClientUserId(i), user_id, sizeof(user_id));

		GetClientName(i, name, sizeof(name));

		Format(display, sizeof(display), "%s (%s)", name, user_id);

		menu.mod_topmenus_AddItem(user_id, display);

		num_clients++;

	}

	

	return num_clients;

}



stock int UTIL_AddTargetsToMenu(Menu menu, int source_client, bool in_game_only, bool alive_only)

{

	int flags = 0;

	

	if (!in_game_only)

	{

		flags |= COMMAND_FILTER_CONNECTED;

	}

	

	if (alive_only)

	{

		flags |= COMMAND_FILTER_ALIVE;

	}

	

	return UTIL_AddTargetsToMenu2(menu, source_client, flags);

}



// ---- advertisements ----
#include <sourcemod>

#undef REQUIRE_PLUGIN

#include <mapchooser>



#pragma newdecls required

#pragma semicolon 1




StringMap mod_advertisements_g_hChatColors;

void AddChatColors()
{
    if (!mod_advertisements_g_hChatColors) {
        mod_advertisements_g_hChatColors = new StringMap();
    }

    mod_advertisements_AddChatColor("default", "\x01");
    mod_advertisements_AddChatColor("teamcolor", "\x03");

    switch (GetEngineVersion()) {
        case Engine_CSS, Engine_DODS, Engine_HL2DM, Engine_Insurgency, Engine_SDK2013, Engine_TF2: {
            mod_advertisements_AddChatColor("aliceblue", "\x07F0F8FF");
            mod_advertisements_AddChatColor("allies", "\x074D7942");
            mod_advertisements_AddChatColor("ancient", "\x07EB4B4B");
            mod_advertisements_AddChatColor("antiquewhite", "\x07FAEBD7");
            mod_advertisements_AddChatColor("aqua", "\x0700FFFF");
            mod_advertisements_AddChatColor("aquamarine", "\x077FFFD4");
            mod_advertisements_AddChatColor("arcana", "\x07ADE55C");
            mod_advertisements_AddChatColor("axis", "\x07FF4040");
            mod_advertisements_AddChatColor("azure", "\x07007FFF");
            mod_advertisements_AddChatColor("beige", "\x07F5F5DC");
            mod_advertisements_AddChatColor("bisque", "\x07FFE4C4");
            mod_advertisements_AddChatColor("black", "\x07000000");
            mod_advertisements_AddChatColor("blanchedalmond", "\x07FFEBCD");
            mod_advertisements_AddChatColor("blue", "\x0799CCFF");
            mod_advertisements_AddChatColor("blueviolet", "\x078A2BE2");
            mod_advertisements_AddChatColor("brown", "\x07A52A2A");
            mod_advertisements_AddChatColor("burlywood", "\x07DEB887");
            mod_advertisements_AddChatColor("cadetblue", "\x075F9EA0");
            mod_advertisements_AddChatColor("chartreuse", "\x077FFF00");
            mod_advertisements_AddChatColor("chocolate", "\x07D2691E");
            mod_advertisements_AddChatColor("collectors", "\x07AA0000");
            mod_advertisements_AddChatColor("common", "\x07B0C3D9");
            mod_advertisements_AddChatColor("community", "\x0770B04A");
            mod_advertisements_AddChatColor("coral", "\x07FF7F50");
            mod_advertisements_AddChatColor("cornflowerblue", "\x076495ED");
            mod_advertisements_AddChatColor("cornsilk", "\x07FFF8DC");
            mod_advertisements_AddChatColor("corrupted", "\x07A32C2E");
            mod_advertisements_AddChatColor("crimson", "\x07DC143C");
            mod_advertisements_AddChatColor("cyan", "\x0700FFFF");
            mod_advertisements_AddChatColor("darkblue", "\x0700008B");
            mod_advertisements_AddChatColor("darkcyan", "\x07008B8B");
            mod_advertisements_AddChatColor("darkgoldenrod", "\x07B8860B");
            mod_advertisements_AddChatColor("darkgray", "\x07A9A9A9");
            mod_advertisements_AddChatColor("darkgrey", "\x07A9A9A9");
            mod_advertisements_AddChatColor("darkgreen", "\x07006400");
            mod_advertisements_AddChatColor("darkkhaki", "\x07BDB76B");
            mod_advertisements_AddChatColor("darkmagenta", "\x078B008B");
            mod_advertisements_AddChatColor("darkolivegreen", "\x07556B2F");
            mod_advertisements_AddChatColor("darkorange", "\x07FF8C00");
            mod_advertisements_AddChatColor("darkorchid", "\x079932CC");
            mod_advertisements_AddChatColor("darkred", "\x078B0000");
            mod_advertisements_AddChatColor("darksalmon", "\x07E9967A");
            mod_advertisements_AddChatColor("darkseagreen", "\x078FBC8F");
            mod_advertisements_AddChatColor("darkslateblue", "\x07483D8B");
            mod_advertisements_AddChatColor("darkslategray", "\x072F4F4F");
            mod_advertisements_AddChatColor("darkslategrey", "\x072F4F4F");
            mod_advertisements_AddChatColor("darkturquoise", "\x0700CED1");
            mod_advertisements_AddChatColor("darkviolet", "\x079400D3");
            mod_advertisements_AddChatColor("deeppink", "\x07FF1493");
            mod_advertisements_AddChatColor("deepskyblue", "\x0700BFFF");
            mod_advertisements_AddChatColor("dimgray", "\x07696969");
            mod_advertisements_AddChatColor("dimgrey", "\x07696969");
            mod_advertisements_AddChatColor("dodgerblue", "\x071E90FF");
            mod_advertisements_AddChatColor("exalted", "\x07CCCCCD");
            mod_advertisements_AddChatColor("firebrick", "\x07B22222");
            mod_advertisements_AddChatColor("floralwhite", "\x07FFFAF0");
            mod_advertisements_AddChatColor("forestgreen", "\x07228B22");
            mod_advertisements_AddChatColor("frozen", "\x074983B3");
            mod_advertisements_AddChatColor("fuchsia", "\x07FF00FF");
            mod_advertisements_AddChatColor("fullblue", "\x070000FF");
            mod_advertisements_AddChatColor("fullred", "\x07FF0000");
            mod_advertisements_AddChatColor("gainsboro", "\x07DCDCDC");
            mod_advertisements_AddChatColor("genuine", "\x074D7455");
            mod_advertisements_AddChatColor("ghostwhite", "\x07F8F8FF");
            mod_advertisements_AddChatColor("gold", "\x07FFD700");
            mod_advertisements_AddChatColor("goldenrod", "\x07DAA520");
            mod_advertisements_AddChatColor("gray", "\x07CCCCCC");
            mod_advertisements_AddChatColor("grey", "\x07CCCCCC");
            mod_advertisements_AddChatColor("green", "\x073EFF3E");
            mod_advertisements_AddChatColor("greenyellow", "\x07ADFF2F");
            mod_advertisements_AddChatColor("haunted", "\x0738F3AB");
            mod_advertisements_AddChatColor("honeydew", "\x07F0FFF0");
            mod_advertisements_AddChatColor("hotpink", "\x07FF69B4");
            mod_advertisements_AddChatColor("immortal", "\x07E4AE33");
            mod_advertisements_AddChatColor("indianred", "\x07CD5C5C");
            mod_advertisements_AddChatColor("indigo", "\x074B0082");
            mod_advertisements_AddChatColor("ivory", "\x07FFFFF0");
            mod_advertisements_AddChatColor("khaki", "\x07F0E68C");
            mod_advertisements_AddChatColor("lavender", "\x07E6E6FA");
            mod_advertisements_AddChatColor("lavenderblush", "\x07FFF0F5");
            mod_advertisements_AddChatColor("lawngreen", "\x077CFC00");
            mod_advertisements_AddChatColor("legendary", "\x07D32CE6");
            mod_advertisements_AddChatColor("lemonchiffon", "\x07FFFACD");
            mod_advertisements_AddChatColor("lightblue", "\x07ADD8E6");
            mod_advertisements_AddChatColor("lightcoral", "\x07F08080");
            mod_advertisements_AddChatColor("lightcyan", "\x07E0FFFF");
            mod_advertisements_AddChatColor("lightgoldenrodyellow", "\x07FAFAD2");
            mod_advertisements_AddChatColor("lightgray", "\x07D3D3D3");
            mod_advertisements_AddChatColor("lightgrey", "\x07D3D3D3");
            mod_advertisements_AddChatColor("lightgreen", "\x0799FF99");
            mod_advertisements_AddChatColor("lightpink", "\x07FFB6C1");
            mod_advertisements_AddChatColor("lightsalmon", "\x07FFA07A");
            mod_advertisements_AddChatColor("lightseagreen", "\x0720B2AA");
            mod_advertisements_AddChatColor("lightskyblue", "\x0787CEFA");
            mod_advertisements_AddChatColor("lightslategray", "\x07778899");
            mod_advertisements_AddChatColor("lightslategrey", "\x07778899");
            mod_advertisements_AddChatColor("lightsteelblue", "\x07B0C4DE");
            mod_advertisements_AddChatColor("lightyellow", "\x07FFFFE0");
            mod_advertisements_AddChatColor("lime", "\x0700FF00");
            mod_advertisements_AddChatColor("limegreen", "\x0732CD32");
            mod_advertisements_AddChatColor("linen", "\x07FAF0E6");
            mod_advertisements_AddChatColor("magenta", "\x07FF00FF");
            mod_advertisements_AddChatColor("maroon", "\x07800000");
            mod_advertisements_AddChatColor("mediumaquamarine", "\x0766CDAA");
            mod_advertisements_AddChatColor("mediumblue", "\x070000CD");
            mod_advertisements_AddChatColor("mediumorchid", "\x07BA55D3");
            mod_advertisements_AddChatColor("mediumpurple", "\x079370D8");
            mod_advertisements_AddChatColor("mediumseagreen", "\x073CB371");
            mod_advertisements_AddChatColor("mediumslateblue", "\x077B68EE");
            mod_advertisements_AddChatColor("mediumspringgreen", "\x0700FA9A");
            mod_advertisements_AddChatColor("mediumturquoise", "\x0748D1CC");
            mod_advertisements_AddChatColor("mediumvioletred", "\x07C71585");
            mod_advertisements_AddChatColor("midnightblue", "\x07191970");
            mod_advertisements_AddChatColor("mintcream", "\x07F5FFFA");
            mod_advertisements_AddChatColor("mistyrose", "\x07FFE4E1");
            mod_advertisements_AddChatColor("moccasin", "\x07FFE4B5");
            mod_advertisements_AddChatColor("mythical", "\x078847FF");
            mod_advertisements_AddChatColor("navajowhite", "\x07FFDEAD");
            mod_advertisements_AddChatColor("navy", "\x07000080");
            mod_advertisements_AddChatColor("normal", "\x07B2B2B2");
            mod_advertisements_AddChatColor("oldlace", "\x07FDF5E6");
            mod_advertisements_AddChatColor("olive", "\x079EC34F");
            mod_advertisements_AddChatColor("olivedrab", "\x076B8E23");
            mod_advertisements_AddChatColor("orange", "\x07FFA500");
            mod_advertisements_AddChatColor("orangered", "\x07FF4500");
            mod_advertisements_AddChatColor("orchid", "\x07DA70D6");
            mod_advertisements_AddChatColor("palegoldenrod", "\x07EEE8AA");
            mod_advertisements_AddChatColor("palegreen", "\x0798FB98");
            mod_advertisements_AddChatColor("paleturquoise", "\x07AFEEEE");
            mod_advertisements_AddChatColor("palevioletred", "\x07D87093");
            mod_advertisements_AddChatColor("papayawhip", "\x07FFEFD5");
            mod_advertisements_AddChatColor("peachpuff", "\x07FFDAB9");
            mod_advertisements_AddChatColor("peru", "\x07CD853F");
            mod_advertisements_AddChatColor("pink", "\x07FFC0CB");
            mod_advertisements_AddChatColor("plum", "\x07DDA0DD");
            mod_advertisements_AddChatColor("powderblue", "\x07B0E0E6");
            mod_advertisements_AddChatColor("purple", "\x07800080");
            mod_advertisements_AddChatColor("rare", "\x074B69FF");
            mod_advertisements_AddChatColor("red", "\x07FF4040");
            mod_advertisements_AddChatColor("rosybrown", "\x07BC8F8F");
            mod_advertisements_AddChatColor("royalblue", "\x074169E1");
            mod_advertisements_AddChatColor("saddlebrown", "\x078B4513");
            mod_advertisements_AddChatColor("salmon", "\x07FA8072");
            mod_advertisements_AddChatColor("sandybrown", "\x07F4A460");
            mod_advertisements_AddChatColor("seagreen", "\x072E8B57");
            mod_advertisements_AddChatColor("seashell", "\x07FFF5EE");
            mod_advertisements_AddChatColor("selfmade", "\x0770B04A");
            mod_advertisements_AddChatColor("sienna", "\x07A0522D");
            mod_advertisements_AddChatColor("silver", "\x07C0C0C0");
            mod_advertisements_AddChatColor("skyblue", "\x0787CEEB");
            mod_advertisements_AddChatColor("slateblue", "\x076A5ACD");
            mod_advertisements_AddChatColor("slategray", "\x07708090");
            mod_advertisements_AddChatColor("slategrey", "\x07708090");
            mod_advertisements_AddChatColor("snow", "\x07FFFAFA");
            mod_advertisements_AddChatColor("springgreen", "\x0700FF7F");
            mod_advertisements_AddChatColor("steelblue", "\x074682B4");
            mod_advertisements_AddChatColor("strange", "\x07CF6A32");
            mod_advertisements_AddChatColor("tan", "\x07D2B48C");
            mod_advertisements_AddChatColor("teal", "\x07008080");
            mod_advertisements_AddChatColor("thistle", "\x07D8BFD8");
            mod_advertisements_AddChatColor("tomato", "\x07FF6347");
            mod_advertisements_AddChatColor("turquoise", "\x0740E0D0");
            mod_advertisements_AddChatColor("uncommon", "\x07B0C3D9");
            mod_advertisements_AddChatColor("unique", "\x07FFD700");
            mod_advertisements_AddChatColor("unusual", "\x078650AC");
            mod_advertisements_AddChatColor("valve", "\x07A50F79");
            mod_advertisements_AddChatColor("vintage", "\x07476291");
            mod_advertisements_AddChatColor("violet", "\x07EE82EE");
            mod_advertisements_AddChatColor("wheat", "\x07F5DEB3");
            mod_advertisements_AddChatColor("white", "\x07FFFFFF");
            mod_advertisements_AddChatColor("whitesmoke", "\x07F5F5F5");
            mod_advertisements_AddChatColor("yellow", "\x07FFFF00");
            mod_advertisements_AddChatColor("yellowgreen", "\x079ACD32");
        }
        case Engine_Left4Dead, Engine_Left4Dead2: {
            mod_advertisements_AddChatColor("lightgreen", "\x03");
            mod_advertisements_AddChatColor("yellow", "\x04");
            mod_advertisements_AddChatColor("green", "\x05");
        }
        case Engine_CSGO: {
            mod_advertisements_AddChatColor("red", "\x07");
            mod_advertisements_AddChatColor("lightred", "\x0F");
            mod_advertisements_AddChatColor("darkred", "\x02");
            mod_advertisements_AddChatColor("bluegrey", "\x0A");
            mod_advertisements_AddChatColor("blue", "\x0B");
            mod_advertisements_AddChatColor("darkblue", "\x0C");
            mod_advertisements_AddChatColor("purple", "\x03");
            mod_advertisements_AddChatColor("orchid", "\x0E");
            mod_advertisements_AddChatColor("yellow", "\x09");
            mod_advertisements_AddChatColor("gold", "\x10");
            mod_advertisements_AddChatColor("lightgreen", "\x05");
            mod_advertisements_AddChatColor("green", "\x04");
            mod_advertisements_AddChatColor("lime", "\x06");
            mod_advertisements_AddChatColor("grey", "\x08");
            mod_advertisements_AddChatColor("grey2", "\x0D");
        }
        default: {
            mod_advertisements_AddChatColor("lightgreen", "\x03");
            mod_advertisements_AddChatColor("green", "\x04");
            mod_advertisements_AddChatColor("olive", "\x05");
        }
    }

    mod_advertisements_AddChatColor("engine 1", "\x01");
    mod_advertisements_AddChatColor("engine 2", "\x02");
    mod_advertisements_AddChatColor("engine 3", "\x03");
    mod_advertisements_AddChatColor("engine 4", "\x04");
    mod_advertisements_AddChatColor("engine 5", "\x05");
    mod_advertisements_AddChatColor("engine 6", "\x06");
    mod_advertisements_AddChatColor("engine 7", "\x07");
    mod_advertisements_AddChatColor("engine 8", "\x08");
    mod_advertisements_AddChatColor("engine 9", "\x09");
    mod_advertisements_AddChatColor("engine 10", "\x0A");
    mod_advertisements_AddChatColor("engine 11", "\x0B");
    mod_advertisements_AddChatColor("engine 12", "\x0C");
    mod_advertisements_AddChatColor("engine 13", "\x0D");
    mod_advertisements_AddChatColor("engine 14", "\x0E");
    mod_advertisements_AddChatColor("engine 15", "\x0F");
    mod_advertisements_AddChatColor("engine 16", "\x10");
}

static void mod_advertisements_AddChatColor(const char[] name, const char[] color)
{
    mod_advertisements_g_hChatColors.SetString(name, color);
}

static int mod_advertisements_PreFormat(char[] buffer, int maxlength)
{
    if (GetEngineVersion() == Engine_CSGO) {
        return FormatEx(buffer, maxlength, " %c", 1);
    }

    return FormatEx(buffer, maxlength, "%c", 1);
}

void ProcessChatColors(const char[] message, char[] buffer, int maxlength)
{
    char name[32], color[10];
    int buf_idx = mod_advertisements_PreFormat(buffer, maxlength);
    int i, name_len;

    while (message[i] && buf_idx < maxlength - 1) {
        if (message[i] != '{' || (name_len = FindCharInString(message[i + 1], '}')) == -1) {
            buffer[buf_idx++] = message[i++];
            continue;
        }

        strcopy(name, name_len + 1, message[i + 1]);

        if (name[0] == '#') {
            buf_idx += FormatEx(buffer[buf_idx], maxlength - buf_idx, "%c%s", (name_len == 9) ? 8 : 7, name[1]);
        } else if (mod_advertisements_g_hChatColors.GetString(name, color, sizeof(color))) {
            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, color);
        } else {
            buf_idx += FormatEx(buffer[buf_idx], maxlength - buf_idx, "{%s}", name);
        }

        i += name_len + 2;
    }

    buffer[buf_idx] = '\0';
}

void SayText2(int client, const char[] message)
{
    Handle msg = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);

    if (GetUserMessageType() == UM_Protobuf) {
        Protobuf pb = UserMessageToProtobuf(msg);
        pb.SetInt("ent_idx", client);
        pb.SetBool("chat", true);
        pb.SetString("msg_name", message);
        pb.AddString("params", "");
        pb.AddString("params", "");
        pb.AddString("params", "");
        pb.AddString("params", "");
    } else {
        BfWrite bf = UserMessageToBfWrite(msg);
        bf.WriteByte(client);
        bf.WriteByte(true);
        bf.WriteString(message);
    }

    EndMessage();
}




StringMap mod_advertisements_g_hTopColors;

void AddTopColors()
{
    if (!mod_advertisements_g_hTopColors) {
        mod_advertisements_g_hTopColors = new StringMap();
    }

    AddTopColor("aliceblue", "F0F8FF");
    AddTopColor("allies", "4D7942");
    AddTopColor("ancient", "EB4B4B");
    AddTopColor("antiquewhite", "FAEBD7");
    AddTopColor("aqua", "00FFFF");
    AddTopColor("aquamarine", "7FFFD4");
    AddTopColor("arcana", "ADE55C");
    AddTopColor("axis", "FF4040");
    AddTopColor("azure", "007FFF");
    AddTopColor("beige", "F5F5DC");
    AddTopColor("bisque", "FFE4C4");
    AddTopColor("black", "000000");
    AddTopColor("blanchedalmond", "FFEBCD");
    AddTopColor("blue", "99CCFF");
    AddTopColor("blueviolet", "8A2BE2");
    AddTopColor("brown", "A52A2A");
    AddTopColor("burlywood", "DEB887");
    AddTopColor("cadetblue", "5F9EA0");
    AddTopColor("chartreuse", "7FFF00");
    AddTopColor("chocolate", "D2691E");
    AddTopColor("collectors", "AA0000");
    AddTopColor("common", "B0C3D9");
    AddTopColor("community", "70B04A");
    AddTopColor("coral", "FF7F50");
    AddTopColor("cornflowerblue", "6495ED");
    AddTopColor("cornsilk", "FFF8DC");
    AddTopColor("corrupted", "A32C2E");
    AddTopColor("crimson", "DC143C");
    AddTopColor("cyan", "00FFFF");
    AddTopColor("darkblue", "00008B");
    AddTopColor("darkcyan", "008B8B");
    AddTopColor("darkgoldenrod", "B8860B");
    AddTopColor("darkgray", "A9A9A9");
    AddTopColor("darkgrey", "A9A9A9");
    AddTopColor("darkgreen", "006400");
    AddTopColor("darkkhaki", "BDB76B");
    AddTopColor("darkmagenta", "8B008B");
    AddTopColor("darkolivegreen", "556B2F");
    AddTopColor("darkorange", "FF8C00");
    AddTopColor("darkorchid", "9932CC");
    AddTopColor("darkred", "8B0000");
    AddTopColor("darksalmon", "E9967A");
    AddTopColor("darkseagreen", "8FBC8F");
    AddTopColor("darkslateblue", "483D8B");
    AddTopColor("darkslategray", "2F4F4F");
    AddTopColor("darkslategrey", "2F4F4F");
    AddTopColor("darkturquoise", "00CED1");
    AddTopColor("darkviolet", "9400D3");
    AddTopColor("deeppink", "FF1493");
    AddTopColor("deepskyblue", "00BFFF");
    AddTopColor("dimgray", "696969");
    AddTopColor("dimgrey", "696969");
    AddTopColor("dodgerblue", "1E90FF");
    AddTopColor("exalted", "CCCCCD");
    AddTopColor("firebrick", "B22222");
    AddTopColor("floralwhite", "FFFAF0");
    AddTopColor("forestgreen", "228B22");
    AddTopColor("frozen", "4983B3");
    AddTopColor("fuchsia", "FF00FF");
    AddTopColor("fullblue", "0000FF");
    AddTopColor("fullred", "FF0000");
    AddTopColor("gainsboro", "DCDCDC");
    AddTopColor("genuine", "4D7455");
    AddTopColor("ghostwhite", "F8F8FF");
    AddTopColor("gold", "FFD700");
    AddTopColor("goldenrod", "DAA520");
    AddTopColor("gray", "CCCCCC");
    AddTopColor("grey", "CCCCCC");
    AddTopColor("green", "3EFF3E");
    AddTopColor("greenyellow", "ADFF2F");
    AddTopColor("haunted", "38F3AB");
    AddTopColor("honeydew", "F0FFF0");
    AddTopColor("hotpink", "FF69B4");
    AddTopColor("immortal", "E4AE33");
    AddTopColor("indianred", "CD5C5C");
    AddTopColor("indigo", "4B0082");
    AddTopColor("ivory", "FFFFF0");
    AddTopColor("khaki", "F0E68C");
    AddTopColor("lavender", "E6E6FA");
    AddTopColor("lavenderblush", "FFF0F5");
    AddTopColor("lawngreen", "7CFC00");
    AddTopColor("legendary", "D32CE6");
    AddTopColor("lemonchiffon", "FFFACD");
    AddTopColor("lightblue", "ADD8E6");
    AddTopColor("lightcoral", "F08080");
    AddTopColor("lightcyan", "E0FFFF");
    AddTopColor("lightgoldenrodyellow", "FAFAD2");
    AddTopColor("lightgray", "D3D3D3");
    AddTopColor("lightgrey", "D3D3D3");
    AddTopColor("lightgreen", "99FF99");
    AddTopColor("lightpink", "FFB6C1");
    AddTopColor("lightsalmon", "FFA07A");
    AddTopColor("lightseagreen", "20B2AA");
    AddTopColor("lightskyblue", "87CEFA");
    AddTopColor("lightslategray", "778899");
    AddTopColor("lightslategrey", "778899");
    AddTopColor("lightsteelblue", "B0C4DE");
    AddTopColor("lightyellow", "FFFFE0");
    AddTopColor("lime", "00FF00");
    AddTopColor("limegreen", "32CD32");
    AddTopColor("linen", "FAF0E6");
    AddTopColor("magenta", "FF00FF");
    AddTopColor("maroon", "800000");
    AddTopColor("mediumaquamarine", "66CDAA");
    AddTopColor("mediumblue", "0000CD");
    AddTopColor("mediumorchid", "BA55D3");
    AddTopColor("mediumpurple", "9370D8");
    AddTopColor("mediumseagreen", "3CB371");
    AddTopColor("mediumslateblue", "7B68EE");
    AddTopColor("mediumspringgreen", "00FA9A");
    AddTopColor("mediumturquoise", "48D1CC");
    AddTopColor("mediumvioletred", "C71585");
    AddTopColor("midnightblue", "191970");
    AddTopColor("mintcream", "F5FFFA");
    AddTopColor("mistyrose", "FFE4E1");
    AddTopColor("moccasin", "FFE4B5");
    AddTopColor("mythical", "8847FF");
    AddTopColor("navajowhite", "FFDEAD");
    AddTopColor("navy", "000080");
    AddTopColor("normal", "B2B2B2");
    AddTopColor("oldlace", "FDF5E6");
    AddTopColor("olive", "9EC34F");
    AddTopColor("olivedrab", "6B8E23");
    AddTopColor("orange", "FFA500");
    AddTopColor("orangered", "FF4500");
    AddTopColor("orchid", "DA70D6");
    AddTopColor("palegoldenrod", "EEE8AA");
    AddTopColor("palegreen", "98FB98");
    AddTopColor("paleturquoise", "AFEEEE");
    AddTopColor("palevioletred", "D87093");
    AddTopColor("papayawhip", "FFEFD5");
    AddTopColor("peachpuff", "FFDAB9");
    AddTopColor("peru", "CD853F");
    AddTopColor("pink", "FFC0CB");
    AddTopColor("plum", "DDA0DD");
    AddTopColor("powderblue", "B0E0E6");
    AddTopColor("purple", "800080");
    AddTopColor("rare", "4B69FF");
    AddTopColor("red", "FF4040");
    AddTopColor("rosybrown", "BC8F8F");
    AddTopColor("royalblue", "4169E1");
    AddTopColor("saddlebrown", "8B4513");
    AddTopColor("salmon", "FA8072");
    AddTopColor("sandybrown", "F4A460");
    AddTopColor("seagreen", "2E8B57");
    AddTopColor("seashell", "FFF5EE");
    AddTopColor("selfmade", "70B04A");
    AddTopColor("sienna", "A0522D");
    AddTopColor("silver", "C0C0C0");
    AddTopColor("skyblue", "87CEEB");
    AddTopColor("slateblue", "6A5ACD");
    AddTopColor("slategray", "708090");
    AddTopColor("slategrey", "708090");
    AddTopColor("snow", "FFFAFA");
    AddTopColor("springgreen", "00FF7F");
    AddTopColor("steelblue", "4682B4");
    AddTopColor("strange", "CF6A32");
    AddTopColor("tan", "D2B48C");
    AddTopColor("teal", "008080");
    AddTopColor("thistle", "D8BFD8");
    AddTopColor("tomato", "FF6347");
    AddTopColor("turquoise", "40E0D0");
    AddTopColor("uncommon", "B0C3D9");
    AddTopColor("unique", "FFD700");
    AddTopColor("unusual", "8650AC");
    AddTopColor("valve", "A50F79");
    AddTopColor("vintage", "476291");
    AddTopColor("violet", "EE82EE");
    AddTopColor("wheat", "F5DEB3");
    AddTopColor("white", "FFFFFF");
    AddTopColor("whitesmoke", "F5F5F5");
    AddTopColor("yellow", "FFFF00");
    AddTopColor("yellowgreen", "9ACD32");
}

void AddTopColor(const char[] sName, const char[] sColor)
{
    int aColor[4];
    ParseColor(sColor, aColor);

    mod_advertisements_g_hTopColors.SetArray(sName, aColor, sizeof(aColor));
}

void ParseColor(const char[] sColor, int aColor[4])
{
    int iColor = StringToInt(sColor, 16);
    aColor[0]  = iColor >> 16;
    aColor[1]  = iColor >> 8 & 255;
    aColor[2]  = iColor & 255;
    aColor[3]  = 255;
}

void ParseTopColor(const char[] sText, int &iStart, int aColor[4])
{
    int iEnd = StrContains(sText, "}");
    if (sText[0] != '{' || iEnd == -1) {
        return;
    }

    char sColor[32];
    strcopy(sColor, iEnd, sText[1]);
    if (sColor[0] == '#') {
        ParseColor(sColor[1], aColor);
    } else {
        mod_advertisements_g_hTopColors.GetArray(sColor, aColor, sizeof(aColor));
    }
    iStart = iEnd + 1;
}





#define mod_advertisements_PL_VERSION	"2.1.2"



public Plugin mod_advertisements_myinfo =

{

    name        = "Advertisements",

    author      = "Tsunami",

    description = "Display advertisements",

    version     = mod_advertisements_PL_VERSION,

    url         = "http://www.tsunami-productions.nl"

};





enum mod_advertisements_struct Advertisement

{

    char center[1024];

    char chat[2048];

    char hint[1024];

    char menu[1024];

    char top[1024];

    bool adminsOnly;

    bool hasFlags;

    int flags;

}





/**

 * Globals

 */

bool mod_advertisements_g_bMapChooser;

bool mod_advertisements_g_bSayText2;

int mod_advertisements_g_iCurrentAd;

ArrayList mod_advertisements_g_hAdvertisements;

ConVar mod_advertisements_g_hEnabled;

ConVar mod_advertisements_g_hFile;

ConVar mod_advertisements_g_hInterval;

ConVar mod_advertisements_g_hRandom;

Handle mod_advertisements_g_hTimer;





/**

 * Plugin Forwards

 */

public void mod_advertisements_OnPluginStart()

{

    CreateConVar("sm_advertisements_version", mod_advertisements_PL_VERSION, "Display advertisements", FCVAR_NOTIFY);

    mod_advertisements_g_hEnabled  = CreateConVar("sm_advertisements_enabled",  "1",                  "Enable/disable displaying advertisements.");

    mod_advertisements_g_hFile     = CreateConVar("sm_advertisements_file",     "advertisements.txt", "File to read the advertisements from.");

    mod_advertisements_g_hInterval = CreateConVar("sm_advertisements_interval", "30",                 "Number of seconds between advertisements.");

    mod_advertisements_g_hRandom   = CreateConVar("sm_advertisements_random",   "0",                  "Enable/disable random advertisements.");



    mod_advertisements_g_hFile.AddChangeHook(mod_advertisements_ConVarChanged_File);

    mod_advertisements_g_hInterval.AddChangeHook(mod_advertisements_ConVarChanged_Interval);



    mod_advertisements_g_bMapChooser = LibraryExists("mapchooser");

    mod_advertisements_g_bSayText2 = GetUserMessageId("SayText2") != INVALID_MESSAGE_ID;

    mod_advertisements_g_hAdvertisements = new ArrayList(sizeof(Advertisement));



    RegServerCmd("sm_advertisements_reload", mod_advertisements_Command_ReloadAds, "Reload the advertisements");



    AddChatColors();

    AddTopColors();



}



public void mod_advertisements_OnConfigsExecuted()

{

    ParseAds();

    RestartTimer();

}



public void mod_advertisements_OnLibraryAdded(const char[] name)

{

    if (StrEqual(name, "mapchooser")) {

        mod_advertisements_g_bMapChooser = true;

    }

}



public void mod_advertisements_OnLibraryRemoved(const char[] name)

{

    if (StrEqual(name, "mapchooser")) {

        mod_advertisements_g_bMapChooser = false;

    }

}





/**

 * ConVar Changes

 */

public void mod_advertisements_ConVarChanged_File(ConVar convar, const char[] oldValue, const char[] newValue)

{

    ParseAds();

}



public void mod_advertisements_ConVarChanged_Interval(ConVar convar, const char[] oldValue, const char[] newValue)

{

    RestartTimer();

}





/**

 * Commands

 */

public Action mod_advertisements_Command_ReloadAds(int args)

{

    ParseAds();

    return Plugin_Handled;

}





/**

 * Menu Handlers

 */

public int mod_advertisements_MenuHandler_DoNothing(Menu menu, MenuAction action, int param1, int param2) { return 0; }





/**

 * Timers

 */

public Action mod_advertisements_Timer_DisplayAd(Handle timer, Handle data)

{

    if (!mod_advertisements_g_hEnabled.BoolValue) {

        return;

    }



    Advertisement ad;

    mod_advertisements_g_hAdvertisements.GetArray(mod_advertisements_g_iCurrentAd, ad);

    char message[1024];



    if (ad.center[0]) {

        ProcessVariables(ad.center, message, sizeof(message));



        for (int i = 1; i <= MaxClients; i++) {

            if (IsValidClient(i, ad)) {

                PrintCenterText(i, "%s", message);



                DataPack hCenterAd;

                CreateDataTimer(1.0, mod_advertisements_Timer_CenterAd, hCenterAd, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

                hCenterAd.WriteCell(i);

                hCenterAd.WriteString(message);

            }

        }

    }

    if (ad.chat[0]) {

        bool teamColor[10];

        char messages[10][1024];

        int messageCount = ExplodeString(ad.chat, "\n", messages, sizeof(messages), sizeof(messages[]));



        for (int idx; idx < messageCount; idx++) {

            teamColor[idx] = StrContains(messages[idx], "{teamcolor}", false) != -1;

            if (teamColor[idx] && !mod_advertisements_g_bSayText2) {

                SetFailState("This game does not support {teamcolor}");

            }



            ProcessChatColors(messages[idx], message, sizeof(message));

            ProcessVariables(message, messages[idx], sizeof(messages[]));

        }



        for (int i = 1; i <= MaxClients; i++) {

            if (IsValidClient(i, ad)) {

                for (int idx; idx < messageCount; idx++) {

                    if (teamColor[idx]) {

                        SayText2(i, messages[idx]);

                    } else {

                        PrintToChat(i, "%s", messages[idx]);

                    }

                }

            }

        }

    }

    if (ad.hint[0]) {

        ProcessVariables(ad.hint, message, sizeof(message));



        for (int i = 1; i <= MaxClients; i++) {

            if (IsValidClient(i, ad)) {

                PrintHintText(i, "%s", message);

            }

        }

    }

    if (ad.menu[0]) {

        ProcessVariables(ad.menu, message, sizeof(message));



        Panel hPl = new Panel();

        hPl.DrawText(message);

        hPl.CurrentKey = 10;



        for (int i = 1; i <= MaxClients; i++) {

            if (IsValidClient(i, ad)) {

                hPl.Send(i, mod_advertisements_MenuHandler_DoNothing, 10);

            }

        }



        delete hPl;

    }

    if (ad.top[0]) {

        int iStart    = 0,

            aColor[4] = {255, 255, 255, 255};



        ParseTopColor(ad.top, iStart, aColor);

        ProcessVariables(ad.top[iStart], message, sizeof(message));



        KeyValues hKv = new KeyValues("Stuff", "title", message);

        hKv.SetColor4("color", aColor);

        hKv.SetNum("level",    1);

        hKv.SetNum("time",     10);



        for (int i = 1; i <= MaxClients; i++) {

            if (IsValidClient(i, ad)) {

                CreateDialog(i, hKv, DialogType_Msg);

            }

        }



        delete hKv;

    }



    if (++mod_advertisements_g_iCurrentAd >= mod_advertisements_g_hAdvertisements.Length) {

        mod_advertisements_g_iCurrentAd = 0;

    }

    return Plugin_Continue;

}



public Action mod_advertisements_Timer_CenterAd(Handle timer, DataPack pack)

{

    char message[1024];

    static int iCount = 0;



    pack.Reset();

    int iClient = pack.ReadCell();

    pack.ReadString(message, sizeof(message));



    if (!IsClientInGame(iClient) || ++iCount >= 5) {

        iCount = 0;

        return Plugin_Stop;

    }



    PrintCenterText(iClient, "%s", message);

    return Plugin_Continue;

}





/**

 * Functions

 */

bool IsValidClient(int client, Advertisement ad)

{

    return IsClientInGame(client) && !IsFakeClient(client)

        && ((!ad.adminsOnly && !(ad.hasFlags && (GetUserFlagBits(client) & (ad.flags|ADMFLAG_ROOT))))

            || (ad.adminsOnly && (GetUserFlagBits(client) & (ADMFLAG_GENERIC|ADMFLAG_ROOT))));

}



void ParseAds()

{

    mod_advertisements_g_iCurrentAd = 0;

    mod_advertisements_g_hAdvertisements.Clear();



    char sFile[64], sPath[PLATFORM_MAX_PATH];

    mod_advertisements_g_hFile.GetString(sFile, sizeof(sFile));

    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/%s", sFile);



    if (!FileExists(sPath)) {

        SetFailState("File Not Found: %s", sPath);

    }



    KeyValues hConfig = new KeyValues("Advertisements");

    hConfig.SetEscapeSequences(true);

    hConfig.ImportFromFile(sPath);

    hConfig.GotoFirstSubKey();



    Advertisement ad;

    char flags[22];

    do {

        hConfig.GetString("center", ad.center, sizeof(Advertisement::center));

        hConfig.GetString("chat",   ad.chat,   sizeof(Advertisement::chat));

        hConfig.GetString("hint",   ad.hint,   sizeof(Advertisement::hint));

        hConfig.GetString("menu",   ad.menu,   sizeof(Advertisement::menu));

        hConfig.GetString("top",    ad.top,    sizeof(Advertisement::top));

        hConfig.GetString("flags",  flags,     sizeof(flags), "none");

        ad.adminsOnly = StrEqual(flags, "");

        ad.hasFlags   = !StrEqual(flags, "none");

        ad.flags      = ReadFlagString(flags);



        mod_advertisements_g_hAdvertisements.PushArray(ad);

    } while (hConfig.GotoNextKey());



    if (mod_advertisements_g_hRandom.BoolValue) {

        mod_advertisements_g_hAdvertisements.Sort(Sort_Random, Sort_Integer);

    }



    delete hConfig;

}



void ProcessVariables(const char[] message, char[] buffer, int maxlength)

{

    char name[64], value[256];

    int buf_idx, i, name_len;

    ConVar hConVar;



    while (message[i] && buf_idx < maxlength - 1) {

        if (message[i] != '{' || (name_len = FindCharInString(message[i + 1], '}')) == -1) {

            buffer[buf_idx++] = message[i++];

            continue;

        }



        strcopy(name, name_len + 1, message[i + 1]);



        if (StrEqual(name, "currentmap", false)) {

            GetCurrentMap(value, sizeof(value));

            GetMapDisplayName(value, value, sizeof(value));

            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);

        }

        else if (StrEqual(name, "nextmap", false)) {

            if (mod_advertisements_g_bMapChooser && mod_mapchooser_EndOfMapVoteEnabled() && !mod_mapchooser_HasEndOfMapVoteFinished()) {

                buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, "Pending Vote");

            } else {

                GetNextMap(value, sizeof(value));

                GetMapDisplayName(value, value, sizeof(value));

                buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);

            }

        }

        else if (StrEqual(name, "date", false)) {

            FormatTime(value, sizeof(value), "%m/%d/%Y");

            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);

        }

        else if (StrEqual(name, "time", false)) {

            FormatTime(value, sizeof(value), "%I:%M:%S%p");

            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);

        }

        else if (StrEqual(name, "time24", false)) {

            FormatTime(value, sizeof(value), "%H:%M:%S");

            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);

        }

        else if (StrEqual(name, "timeleft", false)) {

            int mins, secs, timeleft;

            if (GetMapTimeLeft(timeleft) && timeleft > 0) {

                mins = timeleft / 60;

                secs = timeleft % 60;

            }



            buf_idx += FormatEx(buffer[buf_idx], maxlength - buf_idx, "%d:%02d", mins, secs);

        }

        else if ((hConVar = FindConVar(name))) {

            hConVar.GetString(value, sizeof(value));

            buf_idx += strcopy(buffer[buf_idx], maxlength - buf_idx, value);

        }

        else {

            buf_idx += FormatEx(buffer[buf_idx], maxlength - buf_idx, "{%s}", name);

        }



        i += name_len + 2;

    }



    buffer[buf_idx] = '\0';

}



void RestartTimer()

{

    delete mod_advertisements_g_hTimer;

    mod_advertisements_g_hTimer = CreateTimer(float(mod_advertisements_g_hInterval.IntValue), mod_advertisements_Timer_DisplayAd, _, TIMER_REPEAT);

}



// ---- adv-weapon_cleaner ----
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin mod_adv_weapon_cleaner_myinfo =
{
	name = "Adv Weapon Cleaner",
	author = "Unknown",
	description = "Removes dropped weapons to prevent weapon spam",
	version = "1.0",
	url = "https://forums.alliedmods.net/"
};

ConVar mod_adv_weapon_cleaner_cvRemoveDelay;
ConVar mod_adv_weapon_cleaner_cvRemoveDelay2;
ConVar mod_adv_weapon_cleaner_cvMuchWeapons;
ConVar mod_adv_weapon_cleaner_cvWeaponsPerPlayer;
ConVar mod_adv_weapon_cleaner_cvPunishment;
ConVar mod_adv_weapon_cleaner_cvKeepMapWeapons;

ArrayList mod_adv_weapon_cleaner_g_aWeapons;
ArrayList mod_adv_weapon_cleaner_g_aDropTimes;

int mod_adv_weapon_cleaner_g_iWeaponCount[MAXPLAYERS + 1];
int mod_adv_weapon_cleaner_g_iWeaponsOnGround;

public void mod_adv_weapon_cleaner_OnPluginStart()
{
	CreateConVar("adv_weapon_cleaner_version", "1.0", "Weapon Cleaner version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	mod_adv_weapon_cleaner_cvRemoveDelay = CreateConVar("adv_weapon_cleaner_remove_delay", "20.0", "Time to wait before weapon gets removed when a player drops it.", FCVAR_NOTIFY);
	mod_adv_weapon_cleaner_cvRemoveDelay2 = CreateConVar("adv_weapon_cleaner_remove_delay2", "0.1", "Reduced remove delay per weapon.", FCVAR_NOTIFY);
	mod_adv_weapon_cleaner_cvMuchWeapons = CreateConVar("adv_weapon_cleaner_much_weapons", "100", "How much weapons have to be spawned (including each players inventory) before intensifying remove delay.", FCVAR_NOTIFY);
	mod_adv_weapon_cleaner_cvWeaponsPerPlayer = CreateConVar("adv_weapon_cleaner_weapons_per_player", "10", "How much weapons a player can spawn before all his weapons get removed.", FCVAR_NOTIFY);
	mod_adv_weapon_cleaner_cvPunishment = CreateConVar("adv_weapon_cleaner_punishment", "0", "0: Disable 1: Warn player 2: Kick player", FCVAR_NOTIFY);
	mod_adv_weapon_cleaner_cvKeepMapWeapons = CreateConVar("adv_weapon_cleaner_keep_map_weapons", "1", "0: Disable 1: Keep", FCVAR_NOTIFY);

	HookEvent("map_start", mod_adv_weapon_cleaner_C_Event_MapStart);

	mod_adv_weapon_cleaner_g_aWeapons = new ArrayList();
	mod_adv_weapon_cleaner_g_aDropTimes = new ArrayList();

	CreateTimer(0.1, mod_adv_weapon_cleaner_Timer_Check, _, TIMER_REPEAT);
}

public void mod_adv_weapon_cleaner_OnMapStart()
{
	mod_adv_weapon_cleaner_C_Event_MapStart(null, "", false);
}

public Action mod_adv_weapon_cleaner_C_Event_MapStart(Event event, const char[] name, bool dontBroadcast)
{
	mod_adv_weapon_cleaner_g_aWeapons.Clear();
	mod_adv_weapon_cleaner_g_aDropTimes.Clear();
	mod_adv_weapon_cleaner_g_iWeaponsOnGround = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		mod_adv_weapon_cleaner_g_iWeaponCount[i] = 0;
	}

	return Plugin_Continue;
}

public void mod_adv_weapon_cleaner_OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= MaxClients)
	{
		return;
	}

	if (strncmp(classname, "weapon_", 7) != 0 && strncmp(classname, "item_", 5) != 0)
	{
		return;
	}

	if (mod_adv_weapon_cleaner_g_aWeapons.FindValue(entity) != -1)
	{
		return;
	}

	mod_adv_weapon_cleaner_g_aWeapons.Push(entity);
	mod_adv_weapon_cleaner_g_aDropTimes.Push(GetGameTime());
	mod_adv_weapon_cleaner_g_iWeaponsOnGround++;
}

public void mod_adv_weapon_cleaner_OnEntityDestroyed(int entity)
{
	int index = mod_adv_weapon_cleaner_g_aWeapons.FindValue(entity);

	if (index != -1)
	{
		mod_adv_weapon_cleaner_g_aWeapons.Erase(index);
		mod_adv_weapon_cleaner_g_aDropTimes.Erase(index);
		mod_adv_weapon_cleaner_g_iWeaponsOnGround--;
	}
}

public Action mod_adv_weapon_cleaner_Timer_Check(Handle timer)
{
	for (int i = mod_adv_weapon_cleaner_g_aWeapons.Length - 1; i >= 0; i--)
	{
		int weapon = mod_adv_weapon_cleaner_g_aWeapons.Get(i);

		if (!IsValidEdict(weapon))
		{
			mod_adv_weapon_cleaner_g_aWeapons.Erase(i);
			mod_adv_weapon_cleaner_g_aDropTimes.Erase(i);
			mod_adv_weapon_cleaner_g_iWeaponsOnGround--;
			continue;
		}

		int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");

		if (owner != -1)
		{
			if (owner >= 1 && owner <= MaxClients)
			{
				// Held by a player: reset drop timer.
				mod_adv_weapon_cleaner_g_aDropTimes.Set(i, GetGameTime());
			}

			continue;
		}

		// Weapon on the ground.
		int prevOwner = GetEntPropEnt(weapon, Prop_Send, "m_hPrevOwner");

		if (prevOwner >= 1 && prevOwner <= MaxClients)
		{
			mod_adv_weapon_cleaner_g_iWeaponCount[prevOwner]++;
			SetEntPropEnt(weapon, Prop_Send, "m_hPrevOwner", -1);

			if (mod_adv_weapon_cleaner_cvWeaponsPerPlayer.IntValue > 0 && mod_adv_weapon_cleaner_g_iWeaponCount[prevOwner] > mod_adv_weapon_cleaner_cvWeaponsPerPlayer.IntValue)
			{
				mod_adv_weapon_cleaner_g_iWeaponCount[prevOwner] = 0;
				PunishPlayer(prevOwner);
				continue;
			}
		}

		if (mod_adv_weapon_cleaner_cvKeepMapWeapons.BoolValue && prevOwner == -1)
		{
			// Map-placed weapon, keep it.
			continue;
		}

		float fRemoveDelay = mod_adv_weapon_cleaner_cvRemoveDelay.FloatValue;

		if (mod_adv_weapon_cleaner_g_iWeaponsOnGround > mod_adv_weapon_cleaner_cvMuchWeapons.IntValue)
		{
			fRemoveDelay = mod_adv_weapon_cleaner_cvRemoveDelay2.FloatValue;
		}

		if (GetGameTime() - mod_adv_weapon_cleaner_g_aDropTimes.Get(i) >= fRemoveDelay)
		{
			RemoveEdict(weapon);
			mod_adv_weapon_cleaner_g_aWeapons.Erase(i);
			mod_adv_weapon_cleaner_g_aDropTimes.Erase(i);
			mod_adv_weapon_cleaner_g_iWeaponsOnGround--;
		}
	}

	return Plugin_Continue;
}

void PunishPlayer(int client)
{
	for (int i = mod_adv_weapon_cleaner_g_aWeapons.Length - 1; i >= 0; i--)
	{
		int weapon = mod_adv_weapon_cleaner_g_aWeapons.Get(i);

		if (IsValidEdict(weapon) && GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") == client)
		{
			RemoveEdict(weapon);
			mod_adv_weapon_cleaner_g_aWeapons.Erase(i);
			mod_adv_weapon_cleaner_g_aDropTimes.Erase(i);
			mod_adv_weapon_cleaner_g_iWeaponsOnGround--;
		}
	}

	if (!IsClientInGame(client))
	{
		return;
	}

	switch (mod_adv_weapon_cleaner_cvPunishment.IntValue)
	{
		case 1:
		{
			PrintToChat(client, " \x02Removed all your weapons! Please don't spam weapons!");
		}
		case 2:
		{
			KickClient(client, "Weapon SPAM");
		}
	}
}


// ---- antiflood ----
/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Anti-Flood Plugin

 * Protects against chat flooding.

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



#pragma semicolon 1



#include <sourcemod>



#pragma newdecls required



public Plugin mod_antiflood_myinfo = 

{

	name = "Anti-Flood",

	author = "AlliedModders LLC",

	description = "Protects against chat flooding",

	version = SOURCEMOD_VERSION,

	url = "http://www.sourcemod.net/"

};



enum mod_antiflood_struct PlayerInfo {

	float lastTime; /* Last time player used say or say_team */

	int tokenCount; /* Number of flood tokens player has */

}



PlayerInfo mod_antiflood_playerinfo[MAXPLAYERS+1];



ConVar mod_antiflood_sm_flood_time;									/* Handle to sm_flood_time convar */

float mod_antiflood_max_chat;

public void mod_antiflood_OnPluginStart()

{

	mod_antiflood_sm_flood_time = CreateConVar("sm_flood_time", "0.75", "Amount of time allowed between chat messages");

}



public void mod_antiflood_OnClientPutInServer(int client)

{

	mod_antiflood_playerinfo[client].lastTime = 0.0;

	mod_antiflood_playerinfo[client].tokenCount = 0;

}





public bool mod_antiflood_OnClientFloodCheck(int client)

{

	mod_antiflood_max_chat = mod_antiflood_sm_flood_time.FloatValue;

	

	if (mod_antiflood_max_chat <= 0.0 

 		|| CheckCommandAccess(client, "sm_flood_access", ADMFLAG_ROOT, true))

	{

		return false;

	}

	

	if (mod_antiflood_playerinfo[client].lastTime >= GetGameTime())

	{

		/* If player has 3 or more flood tokens, block their message */

		if (mod_antiflood_playerinfo[client].tokenCount >= 3)

		{

			return true;

		}

	}

	

	return false;

}



public void mod_antiflood_OnClientFloodResult(int client, bool blocked)

{

	if (mod_antiflood_max_chat <= 0.0 

 		|| CheckCommandAccess(client, "sm_flood_access", ADMFLAG_ROOT, true))

	{

		return;

	}

	

	float curTime = GetGameTime();

	float newTime = curTime + mod_antiflood_max_chat;

	

	if (mod_antiflood_playerinfo[client].lastTime >= curTime)

	{

		/* If the last message was blocked, update their time limit */

		if (blocked)

		{

			newTime += 3.0;

		}

		/* Add one flood token when player goes over chat time limit */

		else if (mod_antiflood_playerinfo[client].tokenCount < 3)

		{

			mod_antiflood_playerinfo[client].tokenCount++;

		}

	}

	else if (mod_antiflood_playerinfo[client].tokenCount > 0)

	{

		/* Remove one flood token when player chats within time limit (slow decay) */

		mod_antiflood_playerinfo[client].tokenCount--;

	}

	

	mod_antiflood_playerinfo[client].lastTime = newTime;

}



// ---- basechat ----
/**

 * vim: set ts=4 :

 * =============================================================================

 * SourceMod Basic Chat Plugin

 * Implements basic communication commands.

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



#pragma semicolon 1



#include <sourcemod>



#pragma newdecls required



public Plugin mod_basechat_myinfo = 

{

	name = "Basic Chat",

	author = "AlliedModders LLC",

	description = "Basic Communication Commands",

	version = SOURCEMOD_VERSION,

	url = "http://www.sourcemod.net/"

};



#define mod_basechat_CHAT_SYMBOL '@'



char mod_basechat_g_ColorNames[13][10] = {"White", "Red", "Green", "Blue", "Yellow", "Purple", "Cyan", "Orange", "Pink", "Olive", "Lime", "Violet", "Lightblue"};

int mod_basechat_g_Colors[13][3] = {{255,255,255},{255,0,0},{0,255,0},{0,0,255},{255,255,0},{255,0,255},{0,255,255},{255,128,0},{255,0,128},{128,255,0},{0,255,128},{128,0,255},{0,128,255}};



ConVar mod_basechat_g_Cvar_Chatmode;



EngineVersion mod_basechat_g_GameEngine = Engine_Unknown;



public void mod_basechat_OnPluginStart()

{

	LoadTranslations("common.phrases");

	

	mod_basechat_g_GameEngine = GetEngineVersion();



	mod_basechat_g_Cvar_Chatmode = CreateConVar("sm_chat_mode", "1", "Allows player's to send messages to admin chat.", 0, true, 0.0, true, 1.0);



	RegAdminCmd("sm_say", mod_basechat_Command_SmSay, ADMFLAG_CHAT, "sm_say <message> - sends message to all players");

	RegAdminCmd("sm_csay", mod_basechat_Command_SmCsay, ADMFLAG_CHAT, "sm_csay <message> - sends centered message to all players");

	

	/* HintText does not work on Dark Messiah */

	if (mod_basechat_g_GameEngine != Engine_DarkMessiah)

	{

		RegAdminCmd("sm_hsay", mod_basechat_Command_SmHsay, ADMFLAG_CHAT, "sm_hsay <message> - sends hint message to all players");	

	}

	

	RegAdminCmd("sm_tsay", mod_basechat_Command_SmTsay, ADMFLAG_CHAT, "sm_tsay [color] <message> - sends top-left message to all players");

	RegAdminCmd("sm_chat", mod_basechat_Command_SmChat, ADMFLAG_CHAT, "sm_chat <message> - sends message to admins");

	RegAdminCmd("sm_psay", mod_basechat_Command_SmPsay, ADMFLAG_CHAT, "sm_psay <name or #userid> <message> - sends private message");

	RegAdminCmd("sm_msay", mod_basechat_Command_SmMsay, ADMFLAG_CHAT, "sm_msay <message> - sends message as a menu panel");

}



public Action mod_basechat_OnClientSayCommand(int client, const char[] command, const char[] sArgs)

{

	int startidx;

	if (sArgs[startidx] != mod_basechat_CHAT_SYMBOL)

		return Plugin_Continue;

	

	startidx++;

	

	if (strcmp(command, "say", false) == 0)

	{

		if (sArgs[startidx] != mod_basechat_CHAT_SYMBOL) // sm_say alias

		{

			if (!CheckCommandAccess(client, "sm_say", ADMFLAG_CHAT))

			{

				return Plugin_Continue;

			}

			

			SendChatToAll(client, sArgs[startidx]);

			LogAction(client, -1, "\"%L\" triggered sm_say (text %s)", client, sArgs[startidx]);

			

			return Plugin_Stop;

		}

		

		startidx++;



		if (sArgs[startidx] != mod_basechat_CHAT_SYMBOL) // sm_psay alias

		{

			if (!CheckCommandAccess(client, "sm_psay", ADMFLAG_CHAT))

			{

				return Plugin_Continue;

			}

			

			char arg[64];

			

			int len = BreakString(sArgs[startidx], arg, sizeof(arg));

			int target = FindTarget(client, arg, true, false);

			

			if (target == -1 || len == -1)

				return Plugin_Stop;

			

			SendPrivateChat(client, target, sArgs[startidx+len]);

			

			return Plugin_Stop;

		}

		

		startidx++;

		

		// sm_csay alias

		if (!CheckCommandAccess(client, "sm_csay", ADMFLAG_CHAT))

		{

			return Plugin_Continue;

		}

		

		DisplayCenterTextToAll(client, sArgs[startidx]);

		LogAction(client, -1, "\"%L\" triggered sm_csay (text %s)", client, sArgs[startidx]);

		

		return Plugin_Stop;

	}

	else if (strcmp(command, "say_team", false) == 0 || strcmp(command, "say_squad", false) == 0)

	{

		if (!CheckCommandAccess(client, "sm_chat", ADMFLAG_CHAT) && !mod_basechat_g_Cvar_Chatmode.BoolValue)

		{

			return Plugin_Continue;

		}

		

		SendChatToAdmins(client, sArgs[startidx]);

		LogAction(client, -1, "\"%L\" triggered sm_chat (text %s)", client, sArgs[startidx]);

		

		return Plugin_Stop;

	}

	

	return Plugin_Continue;

}



public Action mod_basechat_Command_SmSay(int client, int args)

{

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_say <message>");

		return Plugin_Handled;	

	}

	

	char text[192];

	GetCmdArgString(text, sizeof(text));



	SendChatToAll(client, text);

	LogAction(client, -1, "\"%L\" triggered sm_say (text %s)", client, text);

	

	return Plugin_Handled;		

}



public Action mod_basechat_Command_SmCsay(int client, int args)

{

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_csay <message>");

		return Plugin_Handled;	

	}

	

	char text[192];

	GetCmdArgString(text, sizeof(text));

	

	DisplayCenterTextToAll(client, text);

	

	LogAction(client, -1, "\"%L\" triggered sm_csay (text %s)", client, text);

	

	return Plugin_Handled;		

}



public Action mod_basechat_Command_SmHsay(int client, int args)

{

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_hsay <message>");

		return Plugin_Handled;  

	}

	

	char text[192];

	GetCmdArgString(text, sizeof(text));

 

	char nameBuf[MAX_NAME_LENGTH];

	

	for (int i = 1; i <= MaxClients; i++)

	{

		if (!IsClientInGame(i) || IsFakeClient(i))

		{

			continue;

		}

		FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));

		PrintHintText(i, "%s: %s", nameBuf, text);

	}

	

	LogAction(client, -1, "\"%L\" triggered sm_hsay (text %s)", client, text);

	

	return Plugin_Handled;	

}



public Action mod_basechat_Command_SmTsay(int client, int args)

{

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_tsay <message>");

		return Plugin_Handled;  

	}

	

	char text[192], colorStr[16];

	GetCmdArgString(text, sizeof(text));

	

	int len = BreakString(text, colorStr, 16);

		

	int color = FindColor(colorStr);

	char nameBuf[MAX_NAME_LENGTH];

	

	if (color == -1)

	{

		color = 0;

		len = 0;

	}

	

	for (int i = 1; i <= MaxClients; i++)

	{

		if (!IsClientInGame(i) || IsFakeClient(i))

		{

			continue;

		}

		FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));

		SendDialogToOne(i, color, "%s: %s", nameBuf, text[len]);

	}



	LogAction(client, -1, "\"%L\" triggered sm_tsay (text %s)", client, text);

	

	return Plugin_Handled;	

}



public Action mod_basechat_Command_SmChat(int client, int args)

{

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_chat <message>");

		return Plugin_Handled;	

	}	

	

	char text[192];

	GetCmdArgString(text, sizeof(text));



	SendChatToAdmins(client, text);

	LogAction(client, -1, "\"%L\" triggered sm_chat (text %s)", client, text);

	

	return Plugin_Handled;	

}



public Action mod_basechat_Command_SmPsay(int client, int args)

{

	if (args < 2)

	{

		ReplyToCommand(client, "[SM] Usage: sm_psay <name or #userid> <message>");

		return Plugin_Handled;	

	}	

	

	char text[192], arg[64];

	GetCmdArgString(text, sizeof(text));



	int len = BreakString(text, arg, sizeof(arg));

	

	int target = FindTarget(client, arg, true, false);

		

	if (target == -1)

		return Plugin_Handled;	

	

	SendPrivateChat(client, target, text[len]);

	

	return Plugin_Handled;	

}



public Action mod_basechat_Command_SmMsay(int client, int args)

{

	if (args < 1)

	{

		ReplyToCommand(client, "[SM] Usage: sm_msay <message>");

		return Plugin_Handled;	

	}

	

	char text[192];

	GetCmdArgString(text, sizeof(text));



	SendPanelToAll(client, text);



	LogAction(client, -1, "\"%L\" triggered sm_msay (text %s)", client, text);

	

	return Plugin_Handled;		

}



int FindColor(const char[] color)

{

	for (int i = 0; i < sizeof(mod_basechat_g_ColorNames); i++)

	{

		if (strcmp(color, mod_basechat_g_ColorNames[i], false) == 0)

			return i;

	}

	

	return -1;

}



void SendChatToAll(int client, const char[] message)

{

	char nameBuf[MAX_NAME_LENGTH];

	

	for (int i = 1; i <= MaxClients; i++)

	{

		if (!IsClientInGame(i) || IsFakeClient(i))

		{

			continue;

		}

		FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));

		

		if (mod_basechat_g_GameEngine == Engine_CSGO)

			PrintToChat(i, " \x01\x0B\x04%t: \x01%s", "Say all", nameBuf, message);

		else

			PrintToChat(i, "\x04%t: \x01%s", "Say all", nameBuf, message);

	}

}



void DisplayCenterTextToAll(int client, const char[] message)

{

	char nameBuf[MAX_NAME_LENGTH];

	

	for (int i = 1; i <= MaxClients; i++)

	{

		if (!IsClientInGame(i) || IsFakeClient(i))

		{

			continue;

		}

		FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));

		PrintCenterText(i, "%s: %s", nameBuf, message);

	}

}



void SendChatToAdmins(int from, const char[] message)

{

	int fromAdmin = CheckCommandAccess(from, "sm_chat", ADMFLAG_CHAT);

	for (int i = 1; i <= MaxClients; i++)

	{

		if (IsClientInGame(i) && (from == i || CheckCommandAccess(i, "sm_chat", ADMFLAG_CHAT)))

		{

			if (mod_basechat_g_GameEngine == Engine_CSGO)

				PrintToChat(i, " \x01\x0B\x04%t: \x01%s", fromAdmin ? "Chat admins" : "Chat to admins", from, message);

			else

				PrintToChat(i, "\x04%t: \x01%s", fromAdmin ? "Chat admins" : "Chat to admins", from, message);

		}	

	}

}



void SendDialogToOne(int client, int color, const char[] text, any ...)

{

	char message[100];

	VFormat(message, sizeof(message), text, 4);	

	

	KeyValues kv = new KeyValues("Stuff", "title", message);

	kv.SetColor("color", mod_basechat_g_Colors[color][0], mod_basechat_g_Colors[color][1], mod_basechat_g_Colors[color][2], 255);

	kv.SetNum("level", 1);

	kv.SetNum("time", 10);

	

	CreateDialog(client, kv, DialogType_Msg);



	delete kv;

}



void SendPrivateChat(int client, int target, const char[] message)

{

	if (!client)

	{

		PrintToServer("(Private to %N) %N: %s", target, client, message);

	}

	else if (target != client)

	{

		if (mod_basechat_g_GameEngine == Engine_CSGO)

			PrintToChat(client, " \x01\x0B\x04%t: \x01%s", "Private say to", target, client, message);

		else

			PrintToChat(client, "\x04%t: \x01%s", "Private say to", target, client, message);

	}

  

	if (mod_basechat_g_GameEngine == Engine_CSGO)

		PrintToChat(target, " \x01\x0B\x04%t: \x01%s", "Private say to", target, client, message);

	else

		PrintToChat(target, "\x04%t: \x01%s", "Private say to", target, client, message);

	LogAction(client, target, "\"%L\" triggered sm_psay to \"%L\" (text %s)", client, target, message);

}



void SendPanelToAll(int from, char[] message)

{

	char title[100];

	Format(title, 64, "%N:", from);

	

	ReplaceString(message, 192, "\\n", "\n");

	

	Panel mSayPanel = new Panel();

	mSayPanel.SetTitle(title);

	mSayPanel.DrawItem("", ITEMDRAW_SPACER);

	mSayPanel.DrawText(message);

	mSayPanel.DrawItem("", ITEMDRAW_SPACER);

	mSayPanel.CurrentKey = GetMaxPageItems(mSayPanel.Style);

	mSayPanel.DrawItem("Exit", ITEMDRAW_CONTROL);



	for(int i = 1; i <= MaxClients; i++)

	{

		if(IsClientInGame(i) && !IsFakeClient(i))

		{

			mSayPanel.Send(i, mod_basechat_Handler_DoNothing, 10);

		}

	}



	delete mSayPanel;

}



public int mod_basechat_Handler_DoNothing(Menu menu, MenuAction action, int param1, int param2)

{

	/* Do nothing */

}



// Bridges

public bool AskPluginLoad(Handle myself, bool late, char[] error, int err_max)
{
	if (!mod_sbpp_main_AskPluginLoad(myself, late, error, err_max))
	{
		return false;
	}
	return true;
}
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	mod_adminmenu_AskPluginLoad2(myself, late, error, err_max);
	mod_basecomm_AskPluginLoad2(myself, late, error, err_max);
	mod_mapchooser_AskPluginLoad2(myself, late, error, err_max);
	mod_sbpp_main_AskPluginLoad2(myself, late, error, err_max);
	return APLRes_Success;
}
public void BaseComm_OnClientGag(int client, bool gagState)
{
	mod_sbpp_comms_BaseComm_OnClientGag(client, gagState);
}
public void BaseComm_OnClientMute(int client, bool muteState)
{
	mod_sbpp_comms_BaseComm_OnClientMute(client, muteState);
}
public void OnAllPluginsLoaded()
{
	mod_adminmenu_OnAllPluginsLoaded();
	mod_sbpp_main_OnAllPluginsLoaded();
	mod_sbpp_sleuth_OnAllPluginsLoaded();
	mod_sm_noearbleed_OnAllPluginsLoaded();
}
public void OnClientAuthorized(int client, const char[] auth)
{
	mod_connectmessage_OnClientAuthorized(client, auth);
	mod_sbpp_checker_OnClientAuthorized(client, auth);
	mod_sbpp_main_OnClientAuthorized(client, auth);
}
public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if (!mod_basecomm_OnClientConnect(client, rejectmsg, maxlen))
	{
		return false;
	}
	if (!mod_sbpp_main_OnClientConnect(client, rejectmsg, maxlen))
	{
		return false;
	}
	return true;
}
public void OnClientConnected(int client)
{
	mod_rockthevote_OnClientConnected(client);
	mod_sbpp_comms_OnClientConnected(client);
}
public void OnClientCookiesCached(int client)
{
	mod_motd_fixer_OnClientCookiesCached(client);
}
public void OnClientDisconnect(int client)
{
	mod_connectmessage_OnClientDisconnect(client);
	mod_fast_spawn_OnClientDisconnect(client);
	mod_mapchooser_OnClientDisconnect(client);
	mod_missing_viewmodel_fix_OnClientDisconnect(client);
	mod_rockthevote_OnClientDisconnect(client);
	mod_sbpp_comms_OnClientDisconnect(client);
	mod_sbpp_main_OnClientDisconnect(client);
}
public void OnClientDisconnect_Post(int client)
{
	mod_reservedslots_OnClientDisconnect_Post(client);
}
public bool OnClientFloodCheck(int client)
{
	if (!mod_antiflood_OnClientFloodCheck(client))
	{
		return false;
	}
	return true;
}
public void OnClientFloodResult(int client, bool blocked)
{
	mod_antiflood_OnClientFloodResult(client, blocked);
}
public void OnClientPostAdminCheck(int client)
{
	mod_connectmessage_OnClientPostAdminCheck(client);
	mod_reservedslots_OnClientPostAdminCheck(client);
	mod_sbpp_comms_OnClientPostAdminCheck(client);
	mod_sbpp_sleuth_OnClientPostAdminCheck(client);
}
public Action OnClientPreAdminCheck(int client)
{
	Action _a_ = mod_sbpp_main_OnClientPreAdminCheck(client);
	if (_a_ != Plugin_Continue)
	{
		return _a_;
	}
	return Plugin_Continue;
}
public void OnClientPutInServer(int client)
{
	mod_antiflood_OnClientPutInServer(client);
	mod_fast_spawn_OnClientPutInServer(client);
	mod_motd_fixer_OnClientPutInServer(client);
	mod_showhealth_OnClientPutInServer(client);
	mod_sm_noearbleed_OnClientPutInServer(client);
	mod_SpecDetails_OnClientPutInServer(client);
}
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	Action _a_ = mod_basechat_OnClientSayCommand(client, command, sArgs);
	if (_a_ != Plugin_Continue)
	{
		return _a_;
	}
	Action _a_ = mod_basecomm_OnClientSayCommand(client, command, sArgs);
	if (_a_ != Plugin_Continue)
	{
		return _a_;
	}
	Action _a_ = mod_sbpp_report_OnClientSayCommand(client, command, sArgs);
	if (_a_ != Plugin_Continue)
	{
		return _a_;
	}
	return Plugin_Continue;
}
public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	mod_basetriggers_OnClientSayCommand_Post(client, command, sArgs);
	mod_nominations_OnClientSayCommand_Post(client, command, sArgs);
	mod_rockthevote_OnClientSayCommand_Post(client, command, sArgs);
}
public void OnConfigsExecuted()
{
	mod_adminmenu_OnConfigsExecuted();
	mod_advertisements_OnConfigsExecuted();
	mod_basecommands_OnConfigsExecuted();
	mod_basevotes_OnConfigsExecuted();
	mod_mapchooser_OnConfigsExecuted();
	mod_nominations_OnConfigsExecuted();
	mod_reservedslots_OnConfigsExecuted();
	mod_rockthevote_OnConfigsExecuted();
	mod_sbpp_main_OnConfigsExecuted();
}
public void OnEntityCreated(int entity, const char[] classname)
{
	mod_adv_weapon_cleaner_OnEntityCreated(entity, classname);
}
public void OnEntityDestroyed(int entity)
{
	mod_adv_weapon_cleaner_OnEntityDestroyed(entity);
}
public void OnLibraryAdded(const char[] name)
{
	mod_advertisements_OnLibraryAdded(name);
	mod_basetriggers_OnLibraryAdded(name);
	mod_sbpp_main_OnLibraryAdded(name);
	mod_sbpp_sleuth_OnLibraryAdded(name);
}
public void OnLibraryRemoved(const char[] name)
{
	mod_advertisements_OnLibraryRemoved(name);
	mod_basecommands_OnLibraryRemoved(name);
	mod_basetriggers_OnLibraryRemoved(name);
	mod_sbpp_comms_OnLibraryRemoved(name);
	mod_sbpp_sleuth_OnLibraryRemoved(name);
}
public void OnMapEnd()
{
	mod_funcommands_OnMapEnd();
	mod_mapchooser_OnMapEnd();
	mod_rockthevote_OnMapEnd();
	mod_sbpp_comms_OnMapEnd();
	mod_sbpp_main_OnMapEnd();
}
public void OnMapStart()
{
	mod_adminmenu_OnMapStart();
	mod_adv_weapon_cleaner_OnMapStart();
	mod_basecommands_OnMapStart();
	mod_basetriggers_OnMapStart();
	mod_funcommands_OnMapStart();
	mod_reservedslots_OnMapStart();
	mod_sbpp_checker_OnMapStart();
	mod_sbpp_comms_OnMapStart();
	mod_sbpp_main_OnMapStart();
	mod_showhealth_OnMapStart();
	mod_speclist_OnMapStart();
	mod_teamjoinblocker_OnMapStart();
}
public void OnMapTimeLeftChanged()
{
	mod_mapchooser_OnMapTimeLeftChanged();
}
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	Action _a_ = mod_fast_spawn_OnPlayerRunCmd(client, buttons, impulse, vel3, angles3, weapon, subtype, cmdnum, tickcount, seed, mouse2);
	if (_a_ != Plugin_Continue)
	{
		return _a_;
	}
	return Plugin_Continue;
}
public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	mod_SpecDetails_OnPlayerRunCmdPost(client, buttons, impulse, vel3, angles3, weapon, subtype, cmdnum, tickcount, seed, mouse2);
}
public void OnPluginEnd()
{
	mod_admincheats_OnPluginEnd();
	mod_reservedslots_OnPluginEnd();
}
public void OnPluginStart()
{
	mod_admincheats_OnPluginStart();
	mod_adminhelp_OnPluginStart();
	mod_adminmenu_OnPluginStart();
	mod_advertisements_OnPluginStart();
	mod_adv_weapon_cleaner_OnPluginStart();
	mod_antiflood_OnPluginStart();
	mod_basechat_OnPluginStart();
	mod_basecomm_OnPluginStart();
	mod_basecommands_OnPluginStart();
	mod_basetriggers_OnPluginStart();
	mod_basevotes_OnPluginStart();
	mod_clientprefs_OnPluginStart();
	mod_connectmessage_OnPluginStart();
	mod_fast_spawn_OnPluginStart();
	mod_funcommands_OnPluginStart();
	mod_funvotes_OnPluginStart();
	mod_mapchooser_OnPluginStart();
	mod_missing_viewmodel_fix_OnPluginStart();
	mod_motd_fixer_OnPluginStart();
	mod_nominations_OnPluginStart();
	mod_pause_OnPluginStart();
	mod_playercommands_OnPluginStart();
	mod_reservedslots_OnPluginStart();
	mod_rockthevote_OnPluginStart();
	mod_sbpp_checker_OnPluginStart();
	mod_sbpp_comms_OnPluginStart();
	mod_sbpp_main_OnPluginStart();
	mod_sbpp_report_OnPluginStart();
	mod_sbpp_sleuth_OnPluginStart();
	mod_showhealth_OnPluginStart();
	mod_sm_noearbleed_OnPluginStart();
	mod_sounds_OnPluginStart();
	mod_SpecDetails_OnPluginStart();
	mod_speclist_OnPluginStart();
	mod_sql_admin_manager_OnPluginStart();
	mod_teamjoinblocker_OnPluginStart();
}
public void OnRebuildAdminCache(AdminCachePart part)
{
	mod_admin_flatfile_OnRebuildAdminCache(part);
	mod_sbpp_admcfg_OnRebuildAdminCache(part);
	mod_sbpp_main_OnRebuildAdminCache(part);
}
public void SBPP_OnReportPlayer(int iReporter, int iTarget, const char[] sReason)
{
	mod_sbpp_report_SBPP_OnReportPlayer(iReporter, iTarget, sReason);
}