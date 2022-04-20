#include <sourcemod>
#include <sdktools>

#include <shop>
#include <multicolors>

#pragma semicolon 1
//#pragma newdecls required

new Handle:kv;
new ItemId:selected_id[MAXPLAYERS+1] = {INVALID_ITEM, ...};

char g_sSound[SHOP_MAX_STRING_LENGTH][PLATFORM_MAX_PATH];
float g_fVolume[SHOP_MAX_STRING_LENGTH];
int g_iEquipt[MAXPLAYERS + 1] = -1;

char g_sChatPrefix[128];

int g_iCount = 0;

ItemId g_iID;
bool g_bUseMVP[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "Shop - MVP sound item module",
	author = "hani", 
	description = "MVP sound item",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	if (Shop_IsStarted()) Shop_Started();
	AutoExecConfig(true, "shop_mvpsound");

	HookEvent("round_mvp", Event_RoundMVP);
}

public void OnClientDisconnect(int iClient)
{
	selected_id[iClient] = INVALID_ITEM;
}

public OnMapStart()
{
	char sBuffer[256];

	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheSound(g_sSound[i], true);
		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[i]);
		AddFileToDownloadsTable(sBuffer);
	}
}

public void Shop_Started()
{
	new CategoryId:category_id = Shop_RegisterCategory("MVP", "");
	
	decl String:_buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(_buffer, sizeof(_buffer), "configs/shop/mvp.cfg");
	
	if (kv != INVALID_HANDLE) CloseHandle(kv);
	
	kv = CreateKeyValues("MVP");
	
	if (!FileToKeyValues(kv, _buffer))
	{
		ThrowError("\"%s\" not parsed", _buffer);
	}

	KvRewind(kv);
	decl String:item[64], String:item_name[64], String:desc[64];
	if (KvGotoFirstSubKey(kv))
	{
		{
			if (Shop_StartItem(category_id, item))
			{
				KvGetString(kv, "name", item_name, sizeof(item_name), item);
				KvGetString(kv, "description", desc, sizeof(desc));
				Shop_SetInfo(item_name, desc, KvGetNum(kv, "price", 5000), KvGetNum(kv, "sell_price", 2500), Item_Togglable, KvGetNum(kv, "duration", 86400));
				Shop_SetCallbacks(_, OnEquipItem);
				
				if (KvJumpToKey(kv, "Attributes", false))
				{
					Shop_KvCopySubKeysCustomInfo(kv);
					KvGoBack(kv);
				}
				
				Shop_EndItem();
			}
		}
		while (KvGotoNextKey(kv));
	}
	
	KvRewind(kv);
}

public ShopAction:OnEquipItem(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		selected_id[client] = INVALID_ITEM;
		
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	
	selected_id[client] = item_id;
	
	return Shop_UseOn;
}

stock File_AddToDownloadsTable(String:path[], bool:recursive=true, const String:ignoreExts[][]=_smlib_empty_twodimstring_array, size=0)
{
	if (path[0] == '\0') {
		return;
	}
	
	new len = strlen(path)-1;
	
	if (path[len] == '\\' || path[len] == '/')
	{
		path[len] = '\0';
	}

	if (FileExists(path)) {
		
		decl String:fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));
		
		if (StrEqual(fileExtension, "bz2", false) || StrEqual(fileExtension, "ztmp", false)) {
			return;
		}
		
		if (Array_FindString(ignoreExts, size, fileExtension) != -1) {
			return;
		}

		AddFileToDownloadsTable(path);
		
		if (StrEqual(fileExtension, "mdl", false))
		{
			PrecacheModel(path, true);
		}
	}
	
	else if (recursive && DirExists(path)) {

		decl String:dirEntry[PLATFORM_MAX_PATH];
		new Handle:__dir = OpenDirectory(path);

		while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry))) {

			if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) {
				continue;
			}
			
			Format(dirEntry, sizeof(dirEntry), "%s/%s", path, dirEntry);
			File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
		}
		
		CloseHandle(__dir);
	}
	else if (FindCharInString(path, '*', true)) {
		
		new String:fileExtension[4];
		File_GetExtension(path, fileExtension, sizeof(fileExtension));

		if (StrEqual(fileExtension, "*")) {

			decl
				String:dirName[PLATFORM_MAX_PATH],
				String:fileName[PLATFORM_MAX_PATH],
				String:dirEntry[PLATFORM_MAX_PATH];

			File_GetDirName(path, dirName, sizeof(dirName));
			File_GetFileName(path, fileName, sizeof(fileName));
			StrCat(fileName, sizeof(fileName), ".");

			new Handle:__dir = OpenDirectory(dirName);
			while (ReadDirEntry(__dir, dirEntry, sizeof(dirEntry))) {

				if (StrEqual(dirEntry, ".") || StrEqual(dirEntry, "..")) {
					continue;
				}

				if (strncmp(dirEntry, fileName, strlen(fileName)) == 0) {
					Format(dirEntry, sizeof(dirEntry), "%s/%s", dirName, dirEntry);
					File_AddToDownloadsTable(dirEntry, recursive, ignoreExts, size);
				}
			}

			CloseHandle(__dir);
		}
	}

	return;
}

stock bool:File_ReadDownloadList(const String:path[])
{
	new Handle:file = OpenFile(path, "r");
	
	if (file  == INVALID_HANDLE) {
		return false;
	}

	new String:buffer[PLATFORM_MAX_PATH];
	while (!IsEndOfFile(file)) {
		ReadFileLine(file, buffer, sizeof(buffer));
		
		new pos;
		pos = StrContains(buffer, "//");
		if (pos != -1) {
			buffer[pos] = '\0';
		}
		
		pos = StrContains(buffer, "#");
		if (pos != -1) {
			buffer[pos] = '\0';
		}

		pos = StrContains(buffer, ";");
		if (pos != -1) {
			buffer[pos] = '\0';
		}
		
		TrimString(buffer);
		
		if (buffer[0] == '\0') {
			continue;
		}

		File_AddToDownloadsTable(buffer);
	}

	CloseHandle(file);
	
	return true;
}

stock File_GetExtension(const String:path[], String:buffer[], size)
{
	new extpos = FindCharInString(path, '.', true);
	
	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

stock Math_GetRandomInt(min, max)
{
	new random = GetURandomInt();
	
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

stock Array_FindString(const String:array[][], size, const String:str[], bool:caseSensitive=true, start=0)
{
	if (start < 0) {
		start = 0;
	}

	for (new i=start; i < size; i++) {

		if (StrEqual(array[i], str, caseSensitive)) {
			return i;
		}
	}
	
	return -1;
}

public void Shop_Reset()
{
	g_iCount = 0;
}

public bool Shop_Config(KeyValues &kv, int itemid)
{
	Shop_GetItemId(itemid, g_iCount);

	kv.GetString("sound", g_sSound[g_iCount], PLATFORM_MAX_PATH);

	char sBuffer[256];
	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[g_iCount]);

	g_fVolume[g_iCount] = kv.GetFloat("volume", 0.5);

	if (g_fVolume[g_iCount] > 1.0)
	{
		g_fVolume[g_iCount] = 1.0;
	}

	if (g_fVolume[g_iCount] <= 0.0)
	{
		g_fVolume[g_iCount] = 0.05;
	}

	g_iCount++;

	return true;
}

public ShopAction_OnEquipItem(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	g_iEquipt[client] = Shop_GetItemId(itemid);

	return 0;
}

public void Event_RoundMVP(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	if (g_iEquipt[client] == -1)
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		//if (g_bHide[client])
		//	continue;

		ClientCommand(i, "playgamesound Music.StopAllMusic");

		EmitSoundToClient(i, g_sSound[g_iEquipt[client]], SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NONE, _, g_fVolume[g_iEquipt[client]]);
	}
}
public void Shop_OnPreviewItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item)
{
	if (!StrEqual(type, "mvp_sound"))
		return;

	EmitSoundToClient(client, g_sSound[index], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[index] / 2);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Play Preview", client);
}
