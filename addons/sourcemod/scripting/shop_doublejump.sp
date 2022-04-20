//------------------------------------------------------------------------------
// GPL LISENCE (short)
//------------------------------------------------------------------------------
/*
 * Copyright (c) 2014 R1KO

 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 * ChangeLog:
		1.0	- 	Релиз
*/
#pragma semicolon 1
#include <sourcemod>
#include <sdktools_functions>
#include <shop>

new bool:g_bHasDJ[MAXPLAYERS+1];
new Handle:g_hPrice,
	Handle:g_hSellPrice,
	Handle:g_hDuration,
	ItemId:id;

public Plugin:myinfo =
{
	name = "[Shop] Double Jump",
	author = "R1KO, hani from anhemyenbai",
	version = "1.1"
};

public OnPluginStart()
{
	g_hPrice = CreateConVar("sm_shop_doublejump_price", "10000", "Стоимость покупки двойного прыжка.");
	HookConVarChange(g_hPrice, OnConVarChange);
	
	g_hSellPrice = CreateConVar("sm_shop_doublejump_sellprice", "800", "Стоимость продажи двойного прыжка.");
	HookConVarChange(g_hPrice, OnConVarChange);
	
	g_hDuration = CreateConVar("sm_shop_doublejump_duration", "7200", "Длительность двойного прыжка в секундах.");
	HookConVarChange(g_hDuration, OnConVarChange);

	AutoExecConfig(true, "shop_doublejump", "shop");
	
	if (Shop_IsStarted()) Shop_Started();
}

public OnConVarChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	if(id != INVALID_ITEM)
	{
		if(hCvar == g_hPrice) Shop_SetItemPrice(id, GetConVarInt(hCvar));
		else if(hCvar == g_hSellPrice) Shop_SetItemSellPrice(id, GetConVarInt(hCvar));
		else if(hCvar == g_hDuration) Shop_SetItemValue(id, GetConVarInt(hCvar));
	}
}

public OnPluginEnd() Shop_UnregisterMe();

public Shop_Started()
{
	new CategoryId:category_id = Shop_RegisterCategory("Ability", "Ability", "");
	
	if (Shop_StartItem(category_id, "doublejump"))
	{
		Shop_SetInfo("Double Jump", "", GetConVarInt(g_hPrice), GetConVarInt(g_hSellPrice), Item_Togglable, GetConVarInt(g_hDuration));
		Shop_SetCallbacks(OnItemRegistered, OnItemUsed);
		Shop_EndItem();
	}
}
public OnItemRegistered(CategoryId:category_id, const String:category[], const String:item[], ItemId:item_id) id = item_id;

public Shop_OnClientAuthorized(iClient) g_bHasDJ[iClient] = (Shop_IsClientHasItem(iClient, id) && Shop_IsClientItemToggled(iClient, id)) ? true:false;

public ShopAction:OnItemUsed(iClient, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		g_bHasDJ[iClient] = false;
		return Shop_UseOff;
	}

	g_bHasDJ[iClient] = true;

	return Shop_UseOn;
}

public Action:OnPlayerRunCmd(iClient, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (g_bHasDJ[iClient] && IsPlayerAlive(iClient))
	{
		static g_fLastButtons[MAXPLAYERS+1], g_fLastFlags[MAXPLAYERS+1], g_iJumps[MAXPLAYERS+1], fCurFlags, fCurButtons;
		fCurFlags	 = GetEntityFlags(iClient);	
		fCurButtons = GetClientButtons(iClient);		
		if (g_fLastFlags[iClient] & FL_ONGROUND && !(fCurFlags & FL_ONGROUND) && !(g_fLastButtons[iClient] & IN_JUMP) && fCurButtons & IN_JUMP) g_iJumps[iClient]++;
		else if(fCurFlags & FL_ONGROUND) g_iJumps[iClient] = 0;
		else if(!(g_fLastButtons[iClient] & IN_JUMP) && fCurButtons & IN_JUMP && g_iJumps[iClient] == 1)
		{						
			g_iJumps[iClient]++;						
			decl Float:vVel[3];
			GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", vVel);
			vVel[2] = 250.0; // u can change this strafe more
			TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, vVel);
		}
		
		g_fLastFlags[iClient] = fCurFlags;		
		g_fLastButtons[iClient]	= fCurButtons;
	}
	return Plugin_Continue;
}