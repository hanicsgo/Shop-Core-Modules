#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <shop>
#include <fpvm_interface>
#include <colors>
#include <cstrike>
#include <smlib>

#define CATEGORY	"Custom Weapons"
#define DATA "1.0"

Handle kv;
Handle menu_cw;

new Handle:cvarcwmspawnmsg = INVALID_HANDLE;
new ItemId:selected_id[MAXPLAYERS+1] = {INVALID_ITEM, ...};

char client_w[MAXPLAYERS+1];

new Handle:hArrayWeapons;

public Plugin myinfo =
{
	name = "Shop - Custom Weapons Menu",
	author = "hani and chiizu from FPT University",
	description = "Shop dung cho retake 32",
	version = "DATA",
	url = "http://steamcommunity.com/id/hanicsgo",
}

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerSpawn);

	hArrayWeapons = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	if (Shop_IsStarted()) Shop_Started();
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
}

public OnMapStart()
{
	decl String:buffer[PLATFORM_MAX_PATH];
	for (new i = 0; i < GetArraySize(hArrayWeapons); i++)
	{
		GetArrayString(hArrayWeapons, i, buffer, sizeof(buffer));
		PrecacheModel(buffer, true);
	}
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "weapons_downloads.txt");
	
	if (!File_ReadDownloadList(buffer))
	{
		PrintToServer("File not exists %s", buffer);
	}
}

public OnClientDisconnect_Post(client)
{
	selected_id[client] = INVALID_ITEM;
}

public Shop_Started()
{
	new CategoryId:category_id = Shop_RegisterCategory(CATEGORY, "Custom Weapons", "");
	
	decl String:buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(buffer, sizeof(buffer), "weapons.cfg");
		
	if (kv != INVALID_HANDLE) CloseHandle(kv);
	
	kv = CreateKeyValues("CustomModels");
	
	if (!FileToKeyValues(kv, buffer))
	{
		ThrowError("\"%s\" not parsed", buffer);
	}
	
	ClearArray(hArrayWeapons);

	KvRewind(kv);

	decl String:item[64], String:item_name[64], String:desc[64];
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			if (!KvGetSectionName(kv, item, sizeof(item))) continue;
			
			KvGetString(kv, "ModelT", buffer, sizeof(buffer));
			new bool:result = false;
			if (buffer[0])
			{
				PrecacheModel(buffer);
				if (FindStringInArray(hArrayWeapons, buffer) == -1)
				{
					PushArrayString(hArrayWeapons, buffer);
				}
				result = true;
			}
			
			
			KvGetString(kv, "ModelCT", buffer, sizeof(buffer));
			if (buffer[0])
			{
				PrecacheModel(buffer, true);
				if (FindStringInArray(hArrayWeapons, buffer) == -1)
				{
					PushArrayString(hArrayWeapons, buffer);
				}
			}
			else if (!result) continue;
			
			if (Shop_StartItem(category_id, item))
			{
				KvGetString(kv, "name", item_name, sizeof(item_name), item);
				KvGetString(kv, "description", desc, sizeof(desc));
				Shop_SetInfo(item_name, desc, KvGetNum(kv, "price", 5000), KvGetNum(kv, "sell_price", 2500), Item_Togglable, KvGetNum(kv, "duration", 86400));
				Shop_SetCallbacks(_, OnEquipItem);
				
				if (KvJumpToKey(kv, "Attributes", false))
				{
					Shop_KvCopySubKeysCustomInfo(view_as<KeyValues>(kv));
					KvGoBack(kv);
				}
				
				Shop_EndItem();
			}
		}
		while (KvGotoNextKey(kv));
	}
	
	KvRewind(kv);
}

public ShopAction:OnEquipItem(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:sItem[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		CS_UpdateClientModel(client);
		
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	
	selected_id[client] = item_id;
	
	ProcessPlayer(client);
	
	return Shop_UseOn;
}

public Action:PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Get Client
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (GetClientTeam(client) == 1 && !IsPlayerAlive(client))
	{
	return;
	}
	
	// Check Convar & Spawnmsg
	if (GetConVarInt(cvarcwmspawnmsg) == 1)
	{	
		CPrintToChat(client," \x04[Shop]\x01 %T","spawnmsg", client);
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ProcessPlayer(client);
}

ProcessPlayer(client)
{
	if (!client || selected_id[client] == INVALID_ITEM || IsFakeClient(client) || !IsPlayerAlive(client))
	{
		return;
	}
}
public Action Command_cw(int client, int args)
{	
	SetMenuTitle(menu_cw, "Custom Weapons Menu v%s\n%T", DATA,"Select a weapon", client);
	DisplayMenu(menu_cw, client, 0);
	return Plugin_Handled;
}

public int Menu_Handler(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{

			char item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			Format(client_w[client], 64, "weapon_%s", item);
			
			KvJumpToKey(kv, client_w[client]);
			
			char temp[64];
			Menu menu_weapons = new Menu(Menu_Handler2);
			SetMenuTitle(menu_weapons, "%T", "Select a custom view model", client);
			AddMenuItem(menu_weapons, "default", "Default model");
			if(KvGotoFirstSubKey(kv))
			{
				do
				{
					KvGetSectionName(kv, temp, 64);
					AddMenuItem(menu_weapons, temp, temp);
			
				} while (KvGotoNextKey(kv));
			}
			KvRewind(kv);
			SetMenuExitBackButton(menu_weapons, true);
			DisplayMenu(menu_weapons, client, 0);
		}

	}
}

public int Menu_Handler2(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{

			char item[64];
			GetMenuItem(menu, param2, item, sizeof(item));
			if(StrEqual(item, "default"))
			{
				FPVMI_SetClientModel(client, client_w[client], -1, -1);
				return;
			}
			KvJumpToKey(kv, client_w[client]);
			KvJumpToKey(kv, item);
			
			char cwmodel[PLATFORM_MAX_PATH], cwmodel2[PLATFORM_MAX_PATH], cwmodel3[PLATFORM_MAX_PATH];
			KvGetString(kv, "model", cwmodel, PLATFORM_MAX_PATH, "none");
			KvGetString(kv, "worldmodel", cwmodel2, PLATFORM_MAX_PATH, "none");
			KvGetString(kv, "dropmodel", cwmodel3, PLATFORM_MAX_PATH, "none");
			if(StrEqual(cwmodel, "none") && StrEqual(cwmodel2, "none") && StrEqual(cwmodel3, "none"))
			{
				CPrintToChat(client, "Invalid configuration for this model", client);
			}
			else
			{
				char flag[8];
				KvGetString(kv, "flag", flag, 8, "");
				if(HasPermission(client, flag))
				{
					FPVMI_SetClientModel(client, client_w[client], !StrEqual(cwmodel, "none")?PrecacheModel(cwmodel):-1, !StrEqual(cwmodel2, "none")?PrecacheModel(cwmodel2):-1, cwmodel3);
					CPrintToChat(client, "Now you have a custom weapon model in",client, client_w[client]);
				}
				else
				{
					CPrintToChat(client, "You dont have access to use this weapon model", client);
				}
				Command_cw(client, 0);
			}
			KvRewind(kv);
		}
		case MenuAction_Cancel:
		{
			if(param2==MenuCancel_ExitBack)
			{
				Command_cw(client, 0);
			}
		}
		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);

		}

	}
}

stock bool HasPermission(int iClient, char[] flagString) 
{
	if (StrEqual(flagString, "")) 
	{
		return true;
	}
	
	AdminId admin = GetUserAdmin(iClient);
	
	if (admin != INVALID_ADMIN_ID)
	{
		int count, found, flags = ReadFlagString(flagString);
		for (int i = 0; i <= 20; i++) 
		{
			if (flags & (1<<i)) 
			{
				count++;
				
				if (GetAdminFlag(admin, view_as<AdminFlag>(i))) 
				{
					found++;
				}
			}
		}

		if (count == found) {
			return true;
		}
	}

	return false;
} 

