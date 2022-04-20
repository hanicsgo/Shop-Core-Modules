//------------------------------------------------------------------------------
// GPL LISENCE (short)
//------------------------------------------------------------------------------
/*
 * Copyright (c) 2016 R1KO

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
*/

#pragma semicolon 1
#include <sourcemod>
#include <shop>
#include <scp>
#include <clientprefs>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[Shop] Chat (CS:GO)",
	author = "R1KO",
	version = "1.0"
}

enum
{
	NAME_COLOR = 0,
	TEXT_COLOR,
	PREFIX_COLOR,
	PREFIX,

	SIZE
}

CategoryId g_iCategory_id[SIZE] = {INVALID_CATEGORY, ...};
bool g_bIgnoreTriggers;
Handle g_hCookie;

char g_sClientColors[MAXPLAYERS+1][3][16];
char g_sClientPrefix[MAXPLAYERS+1][64];
bool g_bClientPrefix[MAXPLAYERS+1];

public void OnPluginStart()
{
	g_hCookie = RegClientCookie("Shop_Chat_Prefix", "Shop_Chat_Prefix", CookieAccess_Private);
	
	RegConsoleCmd("sm_tag", SetChatTag_CMD);

	if (Shop_IsStarted()) Shop_Started();
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void Shop_Started()
{
	char sBuffer[PLATFORM_MAX_PATH];
	
	KeyValues hKeyValues = new KeyValues("Chat");
	
	Shop_GetCfgFile(sBuffer, sizeof(sBuffer), "chat.txt");
	
	if (!hKeyValues.ImportFromFile(sBuffer)) SetFailState("Failed to open file '%s'", sBuffer);

	bool category_enable[SIZE];
	char sName[64], sDescription[128];
	g_bIgnoreTriggers = view_as<bool>(hKeyValues.GetNum("ignore_chat_triggers"));
	category_enable[NAME_COLOR] = view_as<bool>(hKeyValues.GetNum("name_color_enable"));
	if(category_enable[NAME_COLOR])
	{
		hKeyValues.GetString("name_color_name", sName, sizeof(sName));
		hKeyValues.GetString("name_color_description", sDescription, sizeof(sDescription));
		g_iCategory_id[NAME_COLOR] = Shop_RegisterCategory("chat_name_color", sName, sDescription);
	}

	category_enable[TEXT_COLOR] = view_as<bool>(hKeyValues.GetNum("text_color_enable"));
	if(category_enable[TEXT_COLOR])
	{
		hKeyValues.GetString("text_color_name", sName, sizeof(sName));
		hKeyValues.GetString("text_color_description", sDescription, sizeof(sDescription));
		g_iCategory_id[TEXT_COLOR] = Shop_RegisterCategory("chat_text_color", sName, sDescription);
	}

	category_enable[PREFIX_COLOR] = view_as<bool>(hKeyValues.GetNum("prefix_color_enable"));
	if(category_enable[PREFIX_COLOR])
	{
		hKeyValues.GetString("prefix_color_name", sName, sizeof(sName));
		hKeyValues.GetString("prefix_color_description", sDescription, sizeof(sDescription));
		g_iCategory_id[PREFIX_COLOR] = Shop_RegisterCategory("chat_prefix_color", sName, sDescription);
	}

	category_enable[PREFIX] = view_as<bool>(hKeyValues.GetNum("prefix_enable"));

	if(category_enable[PREFIX])
	{
		hKeyValues.GetString("prefix_name", sName, sizeof(sName));
		hKeyValues.GetString("prefix_description", sDescription, sizeof(sDescription));
		g_iCategory_id[PREFIX] = Shop_RegisterCategory("chat_prefix", sName, sDescription);

		hKeyValues.Rewind();
		if(hKeyValues.JumpToKey("Prefixes") && hKeyValues.GotoFirstSubKey())
		{
			do
			{
				hKeyValues.GetSectionName(sBuffer, sizeof(sBuffer));
				if (Shop_StartItem(g_iCategory_id[PREFIX], sBuffer))
				{
					hKeyValues.GetString("tag", sDescription, sizeof(sDescription));
					hKeyValues.GetString("name", sName, sizeof(sName), sDescription);

					Shop_SetInfo(sName, "", hKeyValues.GetNum("price"), hKeyValues.GetNum("sellprice", -1), Item_Togglable, hKeyValues.GetNum("duration"));
					Shop_SetCallbacks(_, OnItemUsed);
					Shop_SetCustomInfoString("tag", sDescription);
					Shop_EndItem();
				}
			} while (hKeyValues.GotoNextKey());
		}
	}

	hKeyValues.Rewind();
	if(hKeyValues.JumpToKey("Colors") && hKeyValues.GotoFirstSubKey())
	{
		int i;
		do
		{
			hKeyValues.GetSectionName(sBuffer, sizeof(sBuffer));
			for(i = 0; i < 3; ++i)
			{
				if(category_enable[i])
				{
					if (Shop_StartItem(g_iCategory_id[i], sBuffer))
					{
						hKeyValues.GetString("color", sDescription, sizeof(sDescription));
						hKeyValues.GetString("name", sName, sizeof(sName), sDescription);

						Shop_SetInfo(sName, "", hKeyValues.GetNum("price"), hKeyValues.GetNum("sellprice", -1), Item_Togglable, hKeyValues.GetNum("duration"));
						Shop_SetCallbacks(_, OnItemUsed);
						Shop_SetCustomInfoString("color", sDescription);
						Shop_EndItem();
					}
				}
			}
		} while (hKeyValues.GotoNextKey());
	}
	
	delete hKeyValues;
}

public ShopAction OnItemUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	int index;
	
	if(category_id == g_iCategory_id[PREFIX])
	{
		index = PREFIX;
	}
	else if(category_id == g_iCategory_id[NAME_COLOR])
	{
		index = NAME_COLOR;
	}
	else if(category_id == g_iCategory_id[TEXT_COLOR])
	{
		index = TEXT_COLOR;
	}
	else if(category_id == g_iCategory_id[PREFIX_COLOR])
	{
		index = PREFIX_COLOR;
	}

	if (isOn || elapsed)
	{
		if(index == PREFIX)
		{
			Shop_GetItemCustomInfoString(item_id, "tag", g_sClientPrefix[iClient], sizeof(g_sClientPrefix[]));
			if(strcmp(g_sClientPrefix[iClient], "custom") == 0)
			{
				g_bClientPrefix[iClient] = false;
			}

			g_sClientPrefix[iClient][0] = 0;
		}
		else
		{
			g_sClientColors[iClient][index][0] = 0;
		}
		return Shop_UseOff;
	}

	Shop_ToggleClientCategoryOff(iClient, category_id);
	
	if(index == PREFIX)
	{
		Shop_GetItemCustomInfoString(item_id, "tag", g_sClientPrefix[iClient], sizeof(g_sClientPrefix[]));
		if(strcmp(g_sClientPrefix[iClient], "custom") == 0)
		{
			GetClientCookie(iClient, g_hCookie, g_sClientPrefix[iClient], sizeof(g_sClientPrefix[]));
			g_bClientPrefix[iClient] = true;
			PrintToChat(iClient, " \x04[SHOP] \x01To change/set the prefix, chat !tag \"Your prefix\"");
		}
	}
	else
	{
		Shop_GetItemCustomInfoString(item_id, "color", g_sClientColors[iClient][index], sizeof(g_sClientColors[][]));
		ReplaceStringColors(g_sClientColors[iClient][index], sizeof(g_sClientColors[][]));
	}

	return Shop_UseOn;
}

void ReplaceStringColors(char[] sMessage, int iMaxLen)
{
	ReplaceString(sMessage, iMaxLen, "{DEFAULT}",		"\x01", false);
	ReplaceString(sMessage, iMaxLen, "{RED}",			"\x02", false);
	ReplaceString(sMessage, iMaxLen, "{TEAM}",			"\x03", false);
	ReplaceString(sMessage, iMaxLen, "{GREEN}",			"\x04", false);
	ReplaceString(sMessage, iMaxLen, "{LIME}",			"\x05", false);
	ReplaceString(sMessage, iMaxLen, "{LIGHTGREEN}",	"\x06", false);
	ReplaceString(sMessage, iMaxLen, "{LIGHTRED}",		"\x07", false);
	ReplaceString(sMessage, iMaxLen, "{GRAY}",			"\x08", false);
	ReplaceString(sMessage, iMaxLen, "{LIGHTOLIVE}",	"\x09", false);
	ReplaceString(sMessage, iMaxLen, "{OLIVE}",			"\x10", false);
	ReplaceString(sMessage, iMaxLen, "{PURPLE}",		"\x0E", false);
	ReplaceString(sMessage, iMaxLen, "{LIGHTBLUE}",		"\x0B", false);
	ReplaceString(sMessage, iMaxLen, "{BLUE}",			"\x0C", false);
}

public Action OnChatMessage(int &iClient, Handle hRecipients, char[] sName, char[] sMessage)
{
	if(g_bIgnoreTriggers &&
		(sMessage[0] == '!' ||
		sMessage[0] == '/' ||
		sMessage[0] == '@'))
	{
		return Plugin_Continue;
	}
	
	if(g_sClientColors[iClient][NAME_COLOR][0]
	|| g_sClientColors[iClient][TEXT_COLOR][0]
	|| g_sClientColors[iClient][PREFIX_COLOR][0]
	|| g_sClientPrefix[iClient][0])
	{
		if(g_sClientColors[iClient][TEXT_COLOR][0])
		{
			Format(sMessage, MAXLENGTH_MESSAGE, "%s%s", g_sClientColors[iClient][TEXT_COLOR], sMessage);
		}
		
		if(g_sClientColors[iClient][NAME_COLOR][0])
		{
			Format(sName, MAXLENGTH_NAME, "%s%s", g_sClientColors[iClient][NAME_COLOR], sName);
		}
		else
		{
			Format(sName, MAXLENGTH_NAME, "\x03%s", sName);
		}
	
		if(g_sClientPrefix[iClient][0])
		{
			if(g_sClientColors[iClient][PREFIX_COLOR][0])
			{
				Format(sName, MAXLENGTH_NAME, " %s%s %s", g_sClientColors[iClient][PREFIX_COLOR], g_sClientPrefix[iClient], sName);
			}
			else
			{
				Format(sName, MAXLENGTH_NAME, " \x01%s %s", g_sClientPrefix[iClient], sName);
			}
		}
		else
		{
			Format(sName, MAXLENGTH_NAME, " %s", sName);
		}

		/*if(g_sClientColors[iClient][NAME_COLOR][0])
		{
			Format(sName, MAXLENGTH_NAME, " %s%s", g_sClientColors[iClient][NAME_COLOR], sName);
		}
		else
		{
			Format(sName, MAXLENGTH_NAME, "\x03%s", sName);
		}

		if(g_sClientPrefix[iClient][0])
		{
			Format(sName, MAXLENGTH_NAME, " %s %s", g_sClientPrefix[iClient], sName);

			if(g_sClientColors[iClient][PREFIX_COLOR][0])
			{
				Format(sName, MAXLENGTH_NAME, " %s%s", g_sClientColors[iClient][PREFIX_COLOR], sName);
			}
		}
		*/

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public void OnClientDisconnect(int iClient)
{
	g_sClientColors[iClient][0][0] =
	g_sClientColors[iClient][1][0] =
	g_sClientColors[iClient][2][0] =
	g_sClientPrefix[iClient][0] = 0;
	g_bClientPrefix[iClient] = false;
}

public Action SetChatTag_CMD(int iClient, int iArgs)
{
	if(iClient) 
	{
		if(g_bClientPrefix[iClient]) 
		{
			char sBuffer[128];
			GetCmdArgString(sBuffer, sizeof(sBuffer));
			TrimString(sBuffer);
			StripQuotes(sBuffer);
			if(sBuffer[0])
			{
				SetClientCookie(iClient, g_hCookie, sBuffer);
				strcopy(g_sClientPrefix[iClient], sizeof(g_sClientPrefix[]), sBuffer);
				PrintToChat(iClient, " \x04[SHOP] \x01You set yourself a prefix \"%s\".", sBuffer);
			}
		}
		else
		{
			PrintToChat(iClient, " \x04[SHOP] \x02To use the prefix, purchase it in the shop!");
		}
	}
	return Plugin_Handled;
}