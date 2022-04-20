#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <shop>

#define PLUGIN_VERSION "2.1.3"

#define CATEGORY	"skins"

new Handle:kv;
new ItemId:selected_id[MAXPLAYERS+1] = {INVALID_ITEM, ...};

new Handle:hArrayModels;

public Plugin:myinfo =
{
	name = "[Shop] Skins",
	author = "FrozDark",
	description = "Adds ability to buy skins",
	version = SHOP_VERSION,
	url = "www.hlmod.ru"
}

public OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerSpawn);
	
	hArrayModels = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	
	if (Shop_IsStarted()) Shop_Started();
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
}

public OnMapStart()
{
	decl String:buffer[PLATFORM_MAX_PATH];
	for (new i = 0; i < GetArraySize(hArrayModels); i++)
	{
		GetArrayString(hArrayModels, i, buffer, sizeof(buffer));
		PrecacheModel(buffer, true);
	}
	
	Shop_GetCfgFile(buffer, sizeof(buffer), "skins_downloads.txt");
	
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
	new CategoryId:category_id = Shop_RegisterCategory(CATEGORY, "Скины", "");
	
	decl String:_buffer[PLATFORM_MAX_PATH];
	Shop_GetCfgFile(_buffer, sizeof(_buffer), "skins.txt");
	
	if (kv != INVALID_HANDLE) CloseHandle(kv);
	
	kv = CreateKeyValues("Skins");
	
	if (!FileToKeyValues(kv, _buffer))
	{
		ThrowError("\"%s\" not parsed", _buffer);
	}
	
	ClearArray(hArrayModels);
	
	KvRewind(kv);
	decl String:item[64], String:item_name[64], String:desc[64];
	if (KvGotoFirstSubKey(kv))
	{
		do
		{
			if (!KvGetSectionName(kv, item, sizeof(item))) continue;
			
			KvGetString(kv, "ModelT", _buffer, sizeof(_buffer));
			new bool:result = false;
			if (_buffer[0])
			{
				PrecacheModel(_buffer);
				if (FindStringInArray(hArrayModels, _buffer) == -1)
				{
					PushArrayString(hArrayModels, _buffer);
				}
				result = true;
			}
			
			
			KvGetString(kv, "ModelCT", _buffer, sizeof(_buffer));
			if (_buffer[0])
			{
				PrecacheModel(_buffer, true);
				if (FindStringInArray(hArrayModels, _buffer) == -1)
				{
					PushArrayString(hArrayModels, _buffer);
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
		CS_UpdateClientModel(client);
		
		selected_id[client] = INVALID_ITEM;
		
		return Shop_UseOff;
	}
	
	Shop_ToggleClientCategoryOff(client, category_id);
	
	selected_id[client] = item_id;
	
	ProcessPlayer(client);
	
	return Shop_UseOn;
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
	
	CreateTimer(0.0, Timer_SetClientModel, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_SetClientModel(Handle:timer, any:client)
{
	decl String:buffer[PLATFORM_MAX_PATH];
	
	if(selected_id[client] != INVALID_ITEM)
	{
		Shop_GetItemById(selected_id[client], buffer, sizeof(buffer));
		
		KvRewind(kv);
		if (!KvJumpToKey(kv, buffer, false))
		{
			LogError("It seems that registered item \"%s\" not exists in the settings", buffer);
			return;
		}
		
		switch (GetClientTeam(client))
		{
			case 2 :
			{
				KvGetString(kv, "ModelT", buffer, sizeof(buffer));
			}
			case 3 :
			{
				KvGetString(kv, "ModelCT", buffer, sizeof(buffer));
			}
			default :
			{
				buffer[0] = '\0';
			}
		}
		if (buffer[0] && IsModelFile(buffer))
		{
			SetEntityModel(client, buffer);
			
			KvGetString(kv, "color", buffer, sizeof(buffer));
			if (strlen(buffer) > 7)
			{
				decl color[4];
				KvGetColor(kv, "color", color[0], color[1], color[2], color[3]);
				SetEntityRenderMode(client, RENDER_TRANSCOLOR);
				SetEntityRenderColor(client, color[0], color[1], color[2], color[3]);
			}
		}
		
		KvRewind(kv);
	}
}

bool:IsModelFile(const String:model[])
{
	decl String:buf[4];
	File_GetExtension(model, buf, sizeof(buf));
	
	return !strcmp(buf, "mdl", false);
}

new String:_smlib_empty_twodimstring_array[][] = { { '\0' } };
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

stock bool:File_GetFileName(const String:path[], String:buffer[], size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	File_GetBaseName(path, buffer, size);
	
	new pos_ext = FindCharInString(buffer, '.', true);

	if (pos_ext != -1) {
		buffer[pos_ext] = '\0';
	}
}

stock bool:File_GetDirName(const String:path[], String:buffer[], size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	new pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) {
		pos_start = FindCharInString(path, '\\', true);
		
		if (pos_start == -1) {
			buffer[0] = '\0';
			return;
		}
	}
	
	strcopy(buffer, size, path);
	buffer[pos_start] = '\0';
}

stock bool:File_GetBaseName(const String:path[], String:buffer[], size)
{	
	if (path[0] == '\0') {
		buffer[0] = '\0';
		return;
	}
	
	new pos_start = FindCharInString(path, '/', true);
	
	if (pos_start == -1) {
		pos_start = FindCharInString(path, '\\', true);
	}
	
	pos_start++;
	
	strcopy(buffer, size, path[pos_start]);
}