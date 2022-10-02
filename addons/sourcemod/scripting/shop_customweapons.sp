#pragma semicolon 1

#define MaxSize 9
#define NULL 	""	

#include <sourcemod>
#include <sdkhooks>

#include <smlib>
#include <fpvm_interface>
#include <colors>
#include <shop>
#include <PTaH>

#undef REQUIRE_PLUGIN
#include <weapons>
#include <knife_choice_core>
#define REQUIRE_PLUGIN


#pragma newdecls required

bool
	g_BlockAttack[MAXPLAYERS + 1],
	g_bWeapons,
	g_bPreviewEnable 	= true,
	g_bWeaponUpdate 	= true,
	g_bPreviewIsWeapon[MAXPLAYERS + 1],
	g_bPlayerSpawn[MAXPLAYERS + 1];

int
	m_hMyWeapons 		= -1,
	m_hActiveWeapon		= -1,
	//m_iPrimaryAmmoType 	= -1,
	//m_iAmmo				= -1,
	
	g_iAmmo[MAXPLAYERS + 1][2],
	g_iPreview 			= 5,
	g_iPreviewDelay 	= 5,
	g_iPreviewTimerDelay_Info[MAXPLAYERS + 1];

Handle
	// Forwards
	g_fOnWeaponsPre,
	g_fOnWeapons,
	
	// More...
	g_hKv,
	g_hPreviewTimer[MAXPLAYERS + 1],
	g_hPreviewTimerDelay[MAXPLAYERS + 1],
	g_hTimer_Usage[MAXPLAYERS + 1];

char
	global_sConfig[PLATFORM_MAX_PATH],
	Config[PLATFORM_MAX_PATH],
	DownloadList[PLATFORM_MAX_PATH],
	
	g_sWeaponSkin[MAXPLAYERS + 1][2][32];

ItemId
	g_IPreviewitem[MAXPLAYERS + 1] = {INVALID_ITEM, ...},
	g_ISelectedId[MAXPLAYERS + 1][MaxSize];

// ================================================



public Plugin myinfo = 
{
	name = "[Shop] Ultimate Custom Weapons",
	author = "MrQout, hani, chiizu from FPT University",
	description = "Custom Weapons for Shop",
	version = "1.0.4",
	url = "steamcommunity.com/id/haniicsgo"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Natives
	CreateNative("CW_Exists", Native_CW_Exists);
	
	
	// Forwards
	g_fOnWeaponsPre = CreateGlobalForward("CW_OnWeaponPre"	, ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
	g_fOnWeapons 	= CreateGlobalForward("CW_OnWeapon"		, ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
	
	RegPluginLibrary("Shop_CustomWeapons");
	
	MarkNativeAsOptional("Weapons_SetClientKnife");
	MarkNativeAsOptional("Weapons_GetClientKnife");
	
	return APLRes_Success;
}

// Natives
// ======================================

public int Native_CW_Exists(Handle hPlugin, int iArgc)
{
	char sBuffer[32];
	int iClient = GetNativeCell(1);
	GetNativeString(2, sBuffer, sizeof(sBuffer));
	bool unknown = GetNativeCell(5);
	ItemId Item = FindWeaponClass_ItemId(iClient, sBuffer, unknown);
	
	int iSize;
	if ((iSize = GetNativeCell(4)) > 0)
	{
		if (Item != INVALID_ITEM)
		{
			char ItemName[128];
			Shop_GetItemById(Item, ItemName, sizeof(ItemName));
			SetNativeString(3, ItemName, iSize);
		}
		else SetNativeString(3, "", 0);
	}
	
	return Item != INVALID_ITEM;
}

// ======================================





// Forwards
public void OnAllPluginsLoaded() 					{ g_bWeapons = LibraryExists("weapons"); 	}
public void OnLibraryRemoved(const char[] sName) 	{ g_bWeapons = !StrEqual(sName, "weapons"); }
public void OnLibraryAdded(const char[] sName) 		{ g_bWeapons = StrEqual(sName, "weapons"); 	}

// 													@Download files
public void OnMapStart() 							{ Downloads(); }

public void OnClientPutInServer(int iClient)
{
	// Clear User Info
	AllClear_ItemId(iClient);
	
	// Install hook on equip weapon
	if (g_bWeaponUpdate)SDKHook(iClient, SDKHook_WeaponEquip, OnWeaponUsage);
}

public void OnClientDisconnect (int iClient)	{ AllClear_ItemId(iClient); }
public void OnPluginEnd()						{ Shop_UnregisterMe(); }

// Block for update knife
public Action Weapons_OnClientKnifeSelectPre(int iClient, int iKnifeId, char[] sKnifeName)
{
	if (FindWeaponClass_ItemId(iClient, "weapon_knife", true) != INVALID_ITEM)
	{
		CPrintToChat(iClient, "%t%t", "prefix", "no_change_weapon");
		return Plugin_Handled;
	}
	else
		return Plugin_Continue;
}


// Start plugin
public void OnPluginStart()
{
	// Offsets
	m_hMyWeapons 		 = FindSendPropInfo	("CBasePlayer", "m_hMyWeapons");
	m_hActiveWeapon		 = FindSendPropInfo	("CCSPlayer", "m_hActiveWeapon");
	//m_iPrimaryAmmoType = FindSendPropInfo	("CWeaponCSBase", "m_iPrimaryAmmoType");
	//m_iAmmo 			 = FindSendPropInfo	("CCSPlayer", "m_iAmmo");
	
	// 
	g_bWeapons 			= LibraryExists		("weapons");
	
	
	// Generate Paths
	BuildPath(Path_SM, Config, sizeof(Config)				, "configs/shop/CustomWeapons.ini");
	BuildPath(Path_SM, DownloadList, sizeof(DownloadList)	, "configs/shop/CustomWeapons_downloads.txt");
	BuildPath(Path_SM, global_sConfig, sizeof(global_sConfig), "configs/CustomWeapons");
	if (!DirExists(global_sConfig))CreateDirectory(global_sConfig, 0x0265);
	
	// Checking load Shop Core
	if (Shop_IsStarted())Shop_Started();
}

// If Shop Core loaded...
public void Shop_Started()
{
	LoadTranslations("Shop_CustomWeapons.phrases");
	
	// Hooks
	HookEvent("player_spawn", OnPlayer);
	HookEvent("player_team" , OnPlayer);
	HookEvent("player_death", OnPlayer);
	
	// Reg console command for admins
	RegAdminCmd("sm_cw_reload"	, Reload_CallBack, ADMFLAG_ROOT, "Reload config custom weapons");
	
	// Load Config
	CfgReload();
}

// Hook Spawn And Death Player'a
public Action OnPlayer(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int iClient;
	if ((iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"))))
	{
		// Block SDKHook for Update Weapon Model
		Usage(iClient, false);
		
		if (IsPlayerAlive(iClient))
		{
			ProcessPlayer(iClient, INVALID_ITEM, true);
			Usage(iClient, true, true);
		}
	}
	
	return Plugin_Continue;
}

// Reload Config
public Action Reload_CallBack(int iClient, int iArgc)
{
	CfgReload();
	
	if (iClient > 0)
		PrintToConsole(iClient, "Configuration reloaded successfully!");
	
	return Plugin_Handled;
}

// Load And Reload Config
public void CfgReload()
{
	Shop_UnregisterMe();
	
	if (g_hKv != INVALID_HANDLE)delete g_hKv;
	
	g_hKv = CreateKeyValues("CustomWeapons");
	if (!FileToKeyValues(g_hKv, Config))ThrowError("\"%s\" not parsed", Config);
	else
	{
		char sDisplay[64], sDesc[64];
		
		SetGlobalTransTarget(LANG_SERVER);
		Format(sDisplay, sizeof(sDisplay), "%t", "display");
		
		SetGlobalTransTarget(LANG_SERVER);
		Format(sDesc, sizeof(sDesc), "%t", "desc");
		
		CategoryId _CategoryId = Shop_RegisterCategory("CustomWeapons", sDisplay, sDesc);
		
		KvRewind(g_hKv);
		

		g_bWeaponUpdate 	= view_as<bool>(KvGetNum(g_hKv, "weapon_update", 1));
		
		g_bPreviewEnable 	= view_as<bool>(KvGetNum(g_hKv, "preview_enable", 1));
		
		g_iPreview = KvGetNum(g_hKv, "preview_time", 5);
		if (g_iPreview < 3)g_iPreview = 3;
		else if (g_iPreview > 10)g_iPreview = 10;
		
		g_iPreviewDelay = KvGetNum(g_hKv, "preview_delay", 5);
		if (g_iPreviewDelay < 3)g_iPreviewDelay = 3;
		else if (g_iPreviewDelay > 30)g_iPreviewDelay = 30;
		
		if (KvGotoFirstSubKey(g_hKv))
		{
			do
			{
				char
					SectionName[16],
					
					Model[PLATFORM_MAX_PATH],
					WModel[PLATFORM_MAX_PATH],
					DModel[PLATFORM_MAX_PATH],
					
					item[64], desc[64],
					
					WeaponName[64];
			
			
				if (!KvGetSectionName(g_hKv, WeaponName, sizeof(WeaponName)))continue;
				else
				{
					KvGetString(g_hKv, "name", SectionName, sizeof(SectionName));
					
					if (KvGotoFirstSubKey(g_hKv))
					{
						do
						{
							if (!KvGetSectionName(g_hKv, item, sizeof(item)))continue;
							else
							{
								KvGetString(g_hKv, "model", Model, sizeof(Model));
								
								if (!Model[0])continue;
								else
								{
									KvGetString(g_hKv, "worldmodel"	, WModel, sizeof(WModel)	, "");
									KvGetString(g_hKv, "dropmodel"	, DModel, sizeof(DModel)	, "");
									
									if (Shop_StartItem(_CategoryId, item))
									{
										char sName[64];
										
										KvGetString(g_hKv, "name", sName, sizeof(sName), item);
										Format(sName, sizeof(sName), "[%s] %s", SectionName, sName);
										
										KvGetString(g_hKv, "description", desc, sizeof(desc));
										Shop_SetInfo(sName, desc, KvGetNum(g_hKv, "price", 5000), KvGetNum(g_hKv, "sell_price", 2500), Item_Togglable, KvGetNum(g_hKv, "duration", 86400));
										
										
										Shop_SetLuckChance(KvGetNum(g_hKv, "luckchance", 1));
										Shop_SetHide(view_as<bool>(KvGetNum(g_hKv, "hide", 0)));
										
										
										Shop_SetCustomInfoString("weapon_name"	, WeaponName);
										Shop_SetCustomInfoString("weapon_model"	, Model);
										Shop_SetCustomInfoString("weapon_wmodel", WModel);
										Shop_SetCustomInfoString("weapon_dmodel", DModel);
										
										
										Shop_SetCallbacks(_, OnEquipItem, _, _, _, ((g_bPreviewEnable && !IsSpecialItem(WeaponName)) ? OnPreviewItem : INVALID_FUNCTION));
										Shop_EndItem();
									}
								}
							}
						}
						while (KvGotoNextKey(g_hKv));

						KvGoBack(g_hKv);
					}
				}
			}
			while (KvGotoNextKey(g_hKv));
		}
		
		KvRewind(g_hKv);
	}
}

//public bool OnBuyItem(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ItemType type, int price, int sell_price, int value)

// Callback on Toggle Item
public ShopAction OnEquipItem(int iClient, CategoryId _CategoryId, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	// If Sell item
	if ((isOn || elapsed) && Find_ItemId(iClient, item_id) == -1)return Shop_UseOff;

	char WeaponName[32];
	Shop_GetItemCustomInfoString(item_id, "weapon_name", WeaponName, sizeof(WeaponName), "");
	
	Call_StartForward(g_fOnWeaponsPre);
	Call_PushCell(iClient);
	Call_PushString(WeaponName);
	Call_PushString(item);
	Call_PushCell(!(isOn || elapsed));
	Call_Finish();
	
	int iEnt;
	if (isOn || elapsed)
	{
		Remove_ItemId(iClient, item_id);
		
		if (g_bWeapons && g_sWeaponSkin[iClient][0][0] != '\0' && !strcmp(WeaponName, "weapon_knife"))
		{
			Weapons_SetClientKnife(iClient, g_sWeaponSkin[iClient][0], false);
			g_sWeaponSkin[iClient][0] = NULL;
		}
		
		if (WeaponName[0] != '\0')
		{
			if ((iEnt = GetClientWeaponOfEntity(iClient, WeaponName)) != INVALID_ENT_REFERENCE)
				GetWeaponAmmo(iClient, iEnt);
			
			Usage(iClient, false);
			
			FPVMI_SetClientModel(iClient, WeaponName);
			FixModel(iClient, WeaponName, _, true);
			Usage(iClient, true, true);
		}
		
		Call_StartForward(g_fOnWeapons);
		Call_PushCell(iClient);
		Call_PushString(WeaponName);
		Call_PushString(item);
		Call_PushCell(false);
		Call_Finish();
		
		return Shop_UseOff;
	}
	
	if (g_hPreviewTimer[iClient] != INVALID_HANDLE
		&& (g_IPreviewitem[iClient] == item_id || GetEntityOfSlot(iClient, WeaponName, true) == GetEntityOfSlot(iClient, g_sWeaponSkin[iClient][1], true)))
	{
		delete g_hPreviewTimer[iClient];
		
		g_IPreviewitem[iClient] = INVALID_ITEM;
		g_sWeaponSkin[iClient][1] = NULL;
		
		if (!g_bPreviewIsWeapon[iClient])
		{
			if ((iEnt = GetClientWeaponOfEntity(iClient, g_sWeaponSkin[iClient][1])) != INVALID_ENT_REFERENCE)
			{
				RemovePlayerItem(iClient, iEnt);
				AcceptEntityInput(iEnt, "Kill");
				
				g_BlockAttack[iClient] = false;
				
				iEnt = INVALID_ENT_REFERENCE;
			}
		}
	}
	
	ItemId _ItemId;
	if ((_ItemId = FindWeaponClass_ItemId(iClient, WeaponName)) && _ItemId != INVALID_ITEM)
	{
		Remove_ItemId(iClient, _ItemId);
		Shop_ToggleClientItem(iClient, _ItemId, Toggle_Off);
	}
	
	if (g_bWeapons && !strcmp(WeaponName, "weapon_knife"))
	{
		if (g_sWeaponSkin[iClient][0][0] == '\0')
			Weapons_GetClientKnife(iClient, g_sWeaponSkin[iClient][0], 32);
		
		Weapons_SetClientKnife(iClient, "weapon_knife", false);
	}
	
	
	Usage(iClient, false);
	
	Write_ItemId(iClient, item_id);
	ProcessPlayer(iClient, item_id, _, true);
	FixModel(iClient, WeaponName, _, true, true);
	
	Usage(iClient, true, true);
	
	Call_StartForward(g_fOnWeapons);
	Call_PushCell(iClient);
	Call_PushString(WeaponName);
	Call_PushString(item);
	Call_PushCell(true);
	Call_Finish();
	
	return Shop_UseOn;
}

// Callback on Preview
public void OnPreviewItem(int iClient, CategoryId _CategoryId, const char[] category, ItemId item_id, const char[] item)
{
	if (!g_bPreviewEnable)
	{
		CPrintToChat(iClient, "%t%t", "prefix", "preview_err3");
		return;
	}
	
	if (iClient > 0 && IsPlayerAlive(iClient))
	{
		if (g_hPreviewTimerDelay[iClient] != INVALID_HANDLE)
		{
			CPrintToChat(iClient, "%t%t", "prefix", "preview_err2", g_iPreviewTimerDelay_Info[iClient]);
			return;
		}
		
		char
			WeaponName[32],
			Model[PLATFORM_MAX_PATH];
		
		if (g_hPreviewTimer[iClient] != INVALID_HANDLE)
			delete g_hPreviewTimer[iClient];


		Shop_GetItemCustomInfoString(item_id, "weapon_name"	, WeaponName, sizeof(WeaponName), NULL);
		Shop_GetItemCustomInfoString(item_id, "weapon_model", Model		, sizeof(Model)		, NULL);
		
		if (g_bWeapons && !strcmp(WeaponName, "weapon_knife"))
		{
			if (g_sWeaponSkin[iClient][0][0] == '\0')
				Weapons_GetClientKnife(iClient, g_sWeaponSkin[iClient][0], 32);

			Weapons_SetClientKnife(iClient, "weapon_knife", false);
		}
		
		char Focus[32], OrigWeapon[32];
		GetClientWeapon(iClient, Focus, sizeof(Focus));
		
		int iEnt = GetClientWeaponOfEntity(iClient, WeaponName, true);
		if (iEnt == INVALID_ENT_REFERENCE)
		{
			if ((iEnt = GetEntityOfSlot(iClient, WeaponName)) != INVALID_ENT_REFERENCE)
			{
				GetWeaponAmmo(iClient, iEnt);
				GetEntityClassname(iEnt, OrigWeapon, sizeof(OrigWeapon));
				
				RemovePlayerItem(iClient, iEnt);
				AcceptEntityInput(iEnt, "Kill");
				
				iEnt = INVALID_ENT_REFERENCE;
			}
		}
		else GetWeaponAmmo(iClient, iEnt);



		FPVMI_SetClientModel(iClient, WeaponName, PrecacheModel(Model));
		
		// If Weapon Not Found for Preview
		if (iEnt == INVALID_ENT_REFERENCE
			&& (iEnt = GivePlayerItem(iClient, WeaponName))
			&& iEnt != -1)
		{
			g_BlockAttack[iClient] = true;
			RemoveStickers(iClient, iEnt);
			
			if (!IsSpecialItem(WeaponName))
			{
				SetEntProp(iEnt, Prop_Data, "m_iClip1", 0);
				SetEntProp(iEnt, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);
			}
		}
		else
		{
			g_bPreviewIsWeapon[iClient] = true;
			iEnt = FixModel(iClient, WeaponName, _, true, true);
		}

		CPrintToChat(iClient, "%t%t", "prefix", "preview", g_iPreview);
		
		DataPack Pack = new DataPack();
		
		WritePackCell(Pack, iClient);
		WritePackCell(Pack, iEnt == INVALID_ENT_REFERENCE ? -1 : iEnt);
		WritePackCell(Pack, (g_IPreviewitem[iClient] = FindWeaponClass_ItemId(iClient, WeaponName)));
		WritePackCell(Pack, item_id);
		WritePackString(Pack, Focus);
		WritePackString(Pack, OrigWeapon);
		
		g_sWeaponSkin[iClient][1] = WeaponName;

		if (g_hPreviewTimer[iClient] != INVALID_HANDLE)
			delete g_hPreviewTimer[iClient];
		
		if (g_hPreviewTimerDelay[iClient] != INVALID_HANDLE)
			delete g_hPreviewTimerDelay[iClient];
		
		g_hPreviewTimer[iClient] 			= CreateTimer(float(g_iPreview), Timer_Preview, Pack, TIMER_DATA_HNDL_CLOSE|TIMER_FLAG_NO_MAPCHANGE);
		g_iPreviewTimerDelay_Info[iClient] 	= g_iPreview + g_iPreviewDelay;
		
		g_hPreviewTimerDelay[iClient]		= CreateTimer(1.0, Timer_PreviewDelay, iClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	else CPrintToChat(iClient, "%t%t", "prefix", "preview_err1");
}

// For control'a SDKHook'a
void Usage(int iClient, bool bEnable, bool bTimer = false, float fInterval = 1.5)
{
	if (!g_bWeaponUpdate)return;
	
	if (g_hTimer_Usage[iClient] != INVALID_HANDLE)
	{
		delete g_hTimer_Usage[iClient];
		g_hTimer_Usage[iClient] = INVALID_HANDLE;
	}
	
	if (!bTimer)g_bPlayerSpawn[iClient] = bEnable;
	else
	{
		DataPack hPack = new DataPack();
		WritePackCell(hPack		, iClient);
		WritePackCell(hPack		, bEnable);
		
		g_hTimer_Usage[iClient] = CreateTimer(fInterval, Timer_Usage, hPack, TIMER_DATA_HNDL_CLOSE|TIMER_FLAG_NO_MAPCHANGE);
	}
}

// Update status'a for SDKHook'a
Action Timer_Usage(Handle hTimer, Handle hPack)
{
	ResetPack(hPack);
	
	int iClient 	= ReadPackCell(hPack);
	bool bEnable 	= ReadPackCell(hPack);
	
	g_hTimer_Usage[iClient] = INVALID_HANDLE;
	
	if (bEnable && IsClientConnected(iClient) && IsClientInGame(iClient) && IsPlayerAlive(iClient))
			g_bPlayerSpawn[iClient] = bEnable;
	else 	g_bPlayerSpawn[iClient] = bEnable;
	
	return Plugin_Handled;
}

// @SDKHook
// Hook for equip weapons
public Action OnWeaponUsage(int iClient, int iEnt)
{
	if (g_bWeaponUpdate && g_bPlayerSpawn[iClient])
	{
		char sClassName[64];
		GetWeaponName(iEnt, sClassName, sizeof(sClassName));

		ItemId _ItemId;
		if ((_ItemId = FindWeaponClass_ItemId(iClient, sClassName, true)) != INVALID_ITEM)
		{
			Shop_GetItemCustomInfoString(_ItemId, "weapon_name", sClassName, sizeof(sClassName), NULL);
			
			if (sClassName[0] != '\0')
			{
				DataPack hPack = new DataPack();
				
				WritePackCell(hPack		, iClient);
				WritePackCell(hPack		, _ItemId);
				WritePackString(hPack	, sClassName);
				
				RemoveStickers(iClient, iEnt);
				Usage(iClient, false);
				CreateTimer(0.5, Timer_UpdateUsage, hPack, TIMER_DATA_HNDL_CLOSE|TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	
	return Plugin_Continue;
}

// To install a model on a weapon with a delay
public Action Timer_UpdateUsage(Handle hTimer, Handle hPack)
{
	ResetPack(hPack);
	int iClient = ReadPackCell(hPack);
	
	if (g_hPreviewTimer[iClient] == INVALID_HANDLE)
	{
		if (IsPlayerAlive(iClient))
		{
			ItemId _ItemId 	= ReadPackCell(hPack);
			
			char sClassName[64];
			ReadPackString(hPack, sClassName, sizeof(sClassName));
			
			ProcessPlayer(iClient, _ItemId);
			FixModel(iClient, sClassName, _, _, true);
		}
	}
	
	Usage(iClient, true, true);
	
	return Plugin_Handled;
}

// Timer for preview delay
public Action Timer_PreviewDelay(Handle hTimer, any iClient)
{
	if (g_iPreviewTimerDelay_Info[iClient] > 0)
		g_iPreviewTimerDelay_Info[iClient]--;
	else
	{
		g_iPreviewTimerDelay_Info[iClient] = 0;
		g_hPreviewTimerDelay[iClient] = INVALID_HANDLE;
		
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

// Timer for preview
public Action Timer_Preview(Handle hTimer, Handle hPack)
{
	ResetPack(hPack);
	
	int
		iClient = ReadPackCell(hPack),
		iIndex 	= ReadPackCell(hPack);
	
	ItemId
		OrigWeapon 		= ReadPackCell(hPack),
		PreviewWeapon 	= ReadPackCell(hPack);
	
	char Focus[32], _OrigWeapon[32];
	ReadPackString(hPack, Focus, sizeof(Focus));
	ReadPackString(hPack, _OrigWeapon, sizeof(_OrigWeapon));
	
	
	g_hPreviewTimer[iClient] = INVALID_HANDLE;
	g_IPreviewitem[iClient]  = INVALID_ITEM;
	
	if (PreviewWeapon != INVALID_ITEM)
	{
		char WeaponName[32];
		Shop_GetItemCustomInfoString(PreviewWeapon, "weapon_name", WeaponName, sizeof(WeaponName), NULL);
		
		if (WeaponName[0] != '\0')
		{
			if (g_bPreviewIsWeapon[iClient])GetWeaponAmmo(iClient, iIndex);
			Usage(iClient, false);
				
			FPVMI_SetClientModel(iClient, WeaponName);
			
			if (OrigWeapon == INVALID_ITEM)
			{
				if (g_bWeapons && g_sWeaponSkin[iClient][0][0] != '\0' && !strcmp(WeaponName, "weapon_knife"))
				{
					Weapons_SetClientKnife(iClient, g_sWeaponSkin[iClient][0], false);
					g_sWeaponSkin[iClient][0] = NULL;
				}
			}
			
			if (!g_bPreviewIsWeapon[iClient])
			{
				RemovePlayerItem(iClient, iIndex);
				AcceptEntityInput(iIndex, "Kill");
				
				if ((iIndex = GetClientWeaponOfEntity(iClient, WeaponName, true)) && iIndex != INVALID_ENT_REFERENCE)
				{
					RemovePlayerItem(iClient, iIndex);
					AcceptEntityInput(iIndex, "Kill");
				}
				
				if (_OrigWeapon[0] != '\0' && (iIndex = GivePlayerItem(iClient, _OrigWeapon)) > 0
					&& IsValidEdict(iIndex))SetWeaponAmmo(iClient, iIndex);
				
				if (Focus[0] == '\0' || GetClientWeaponOfEntity(iClient, Focus, true) == INVALID_ENT_REFERENCE)
				{
					iIndex = GetClientWeaponOfEntity(iClient);
					if (iIndex != INVALID_ENT_REFERENCE)
						GetWeaponName(iIndex, Focus, sizeof(Focus));
				}
				
				if (Focus[0] != '\0')
				{
					if (StrContains(Focus, "knife_") != -1)Format(Focus, sizeof(Focus), "weapon_knife");
					FakeClientCommand(iClient, "use %s", Focus);
				}
			}
			else
			{
				if (OrigWeapon != INVALID_ITEM)ProcessPlayer(iClient, OrigWeapon);
				FixModel(iClient, WeaponName, _, true, true);
			}
			
			Usage(iClient, true, true);
		}
	}
	
	g_sWeaponSkin[iClient][1] = NULL;
	g_BlockAttack[iClient] = false;
	return Plugin_Handled;
}

// Install new model
void ProcessPlayer(int iClient, ItemId _ItemId = INVALID_ITEM, bool RemoveSticker = false, bool _GetAmmo = false)
{
	if (iClient > 0 && IsClientConnected(iClient)
		&& IsClientInGame(iClient) && !IsFakeClient(iClient)
		&& IsPlayerAlive(iClient))
	{
		bool Block = _ItemId != INVALID_ITEM;

		char
			WeaponName[64],
			
			Model[PLATFORM_MAX_PATH],
			WModel[PLATFORM_MAX_PATH],
			DModel[PLATFORM_MAX_PATH];
			
		for (int i = 0; i < MaxSize; i++)
		{
			if (!Block)
			{
				if (g_ISelectedId[iClient][i] == INVALID_ITEM)continue;
				
				_ItemId = g_ISelectedId[iClient][i];
			}
			
			Shop_GetItemCustomInfoString(_ItemId, "weapon_name", WeaponName, sizeof(WeaponName), NULL);
			
			if (WeaponName[0] != '\0')
			{
				KvRewind(g_hKv);
				
				Shop_GetItemCustomInfoString(_ItemId, "weapon_model" , Model , sizeof(Model) , NULL);
				Shop_GetItemCustomInfoString(_ItemId, "weapon_wmodel", WModel, sizeof(WModel), NULL);
				Shop_GetItemCustomInfoString(_ItemId, "weapon_dmodel", DModel, sizeof(DModel), NULL);
				
				int iEnt;
				if (_GetAmmo && (iEnt = GetClientWeaponOfEntity(iClient, WeaponName)) > 0)
					GetWeaponAmmo(iClient, iEnt);
				
				FPVMI_SetClientModel(
					iClient,
					WeaponName,
					(Model [0] == '\0' ? -1     : PrecacheModel(Model)),
					(WModel[0] == '\0' ? -1     : PrecacheModel(WModel)),
					(DModel[0] == '\0' ? "none" : DModel)
				);
				
				if (RemoveSticker && (iEnt = GetClientWeaponOfEntity(iClient, WeaponName)) != INVALID_ENT_REFERENCE)
					RemoveStickers(iClient, iEnt);
			}
			
			if (Block)break;
		}
	}
}

// For update new model
int FixModel(int iClient, char[] _WeaponName, int _index = -1, bool setAmmo = false, bool bRemoveStickers = false)
{
	bool IsTaser;
	
	char
		taser[] = "weapon_taser",
		
		WeaponName[32],
		Focus[32];
	
	int
		iEnt,
		index 	= _index,
		iRetEnt = -1;
	
	Format(WeaponName, sizeof(WeaponName), _WeaponName);
	
	if (WeaponName[0] == '\0'
		&& (index == -1
			|| !IsValidEntity(index)
			|| !GetEntityClassname(index, WeaponName, sizeof(WeaponName))))return iRetEnt;
	
	
	GetClientWeapon(iClient, Focus, sizeof(Focus));


	if (Focus[0] == '\0' || !((iEnt = GetClientWeaponOfEntity(iClient, Focus, true)) != INVALID_ENT_REFERENCE
		&& GetEntityClassname(iEnt, Focus, sizeof(Focus))))Focus = WeaponName;
	
	
	if (WeaponName[0] != '\0' && index == -1)
		index = GetClientWeaponOfEntity(iClient, WeaponName, true);
	
	int
		taserIndex;
	
	if (index == INVALID_ENT_REFERENCE || !IsValidEntity(index))return iRetEnt;

	// Remove a old model weapon
	RemovePlayerItem(iClient, index);
	AcceptEntityInput(index, "Kill");

	if ((taserIndex = GetClientWeaponOfEntity(iClient, taser)) == INVALID_ENT_REFERENCE || !IsValidEdict(taserIndex))
	{
		taserIndex = GivePlayerItem(iClient, taser);
		//taserIndex = GetClientWeaponOfEntity(iClient, taser);
	}
	else IsTaser = true;
	
	
	FakeClientCommand(iClient, "use %s", taser);
	
	// Entity Index new model
	if (GetClientWeaponOfEntity(iClient, WeaponName, true) == INVALID_ENT_REFERENCE)
		index = GivePlayerItem(iClient, WeaponName);
	
	
	if (index != -1 && IsValidEntity(index))
	{
		iRetEnt = index;
		
		// Set ammo for weapon with a new model
		if (setAmmo)SetWeaponAmmo(iClient, index);
	}
	
	if (taserIndex != INVALID_ENT_REFERENCE && IsValidEdict(taserIndex))
	{
		RemovePlayerItem(iClient, taserIndex);
		AcceptEntityInput(taserIndex, "Kill");
		
		if (IsTaser)GivePlayerItem(iClient, taser);
	}
	
	// Set to old weapon focus
	if (Focus[0] != '\0')
	{
		if (StrContains(Focus, "knife_") != -1)Format(Focus, sizeof(Focus), "weapon_knife");
		FakeClientCommand(iClient, "use %s", Focus);
	}
	
	if (bRemoveStickers)RemoveStickers(iClient, iRetEnt);
	
	return iRetEnt;
}





// Download files
void Downloads()
{
	Handle file;
	if((file = OpenFile(DownloadList, "r")) && file != INVALID_HANDLE)
	{
		char line[192];
		
		while (!IsEndOfFile(file))
		{
			if (!ReadFileLine(file, line, sizeof(line)))break;
			
			TrimString(line);
			if(strlen(line) > 0 && FileExists(line))
				AddFileToDownloadsTable(line);
		}

		CloseHandle(file);
	}
	else LogError("[SM] File downloads not found (%s)", DownloadList);
}




// Helper functions

int GetClientWeaponOfEntity(int iClient, char[] WeaponName = NULL, bool s = false)
{
	char sClassName[128];
	
	for (int i = 0, iIndex = -1; i < 188; i += 4)
	{
		if ((iIndex = GetEntDataEnt2(iClient, m_hMyWeapons + i)) > 0)
		{
			GetWeaponName(iIndex, sClassName, sizeof(sClassName));
			
			if ((WeaponName[0] == '\0' && sClassName[0] != '\0')
				|| (!strcmp(sClassName, WeaponName)
				|| (s && StrContains(WeaponName, sClassName) != -1)))return iIndex;
		}
	}
	
	return INVALID_ENT_REFERENCE;
}

ItemId FindWeaponClass_ItemId(int iClient, char[] WeaponName, bool s = false)
{
	char sBuffer[32];
	
	for (int i = 0; i < MaxSize; i++)
	{
		if (g_ISelectedId[iClient][i] == INVALID_ITEM)continue;
		
		Shop_GetItemCustomInfoString(g_ISelectedId[iClient][i], "weapon_name", sBuffer, sizeof(sBuffer), NULL);
		if (!strcmp(sBuffer, WeaponName) || (s && StrContains(sBuffer, WeaponName) != -1))return g_ISelectedId[iClient][i];
	}
	
	return INVALID_ITEM;
}

public int Find_ItemId(int iClient, ItemId _ItemId)
{
	for (int i = 0; i < MaxSize; i++)
		if (g_ISelectedId[iClient][i] == _ItemId)return i;
	
	return -1;
}

public int Write_ItemId(int iClient, ItemId _ItemId)
{
	for (int i = 0; i < MaxSize; i++)
	{
		if (g_ISelectedId[iClient][i] == INVALID_ITEM)
		{
			g_ISelectedId[iClient][i] = _ItemId;
			return i;
		}
	}
	
	return -1;
}

public int Remove_ItemId(int iClient, ItemId _ItemId)
{
	for (int i = 0; i < MaxSize; i++)
	{
		if (g_ISelectedId[iClient][i] == _ItemId)
		{
			g_ISelectedId[iClient][i] = INVALID_ITEM;
			return i;
		}
	}
	
	return -1;
}

public void AllClear_ItemId(int iClient)
{
	Usage(iClient, false);
	
	g_bPlayerSpawn[iClient] 	= false;
	g_BlockAttack[iClient] 		= false;
	g_iAmmo[iClient] 			= { 0, 0 };
	
	g_sWeaponSkin[iClient][0] 	= NULL;
	g_sWeaponSkin[iClient][1] 	= NULL;
	
	g_IPreviewitem[iClient] 	= INVALID_ITEM;
	
	if (g_hTimer_Usage[iClient] != INVALID_HANDLE)
		delete g_hTimer_Usage[iClient];
	
	if (g_hPreviewTimerDelay[iClient] != INVALID_HANDLE)
		delete g_hPreviewTimerDelay[iClient];
	
	g_iPreviewTimerDelay_Info[iClient] = 0;
	
	if (g_hPreviewTimer[iClient] != INVALID_HANDLE)
		delete g_hPreviewTimer[iClient];
	
	for (int i = 0; i < MaxSize; i++)
		g_ISelectedId[iClient][i] = INVALID_ITEM;
}

public bool IsSpecialItem(char[] WeaponName)
{
	char sArray[][] = {
		"weapon_smokegrenade",
		"weapon_molotov",
		"weapon_incgrenade",
		"weapon_hegrenade",
		"weapon_decoy",
		"weapon_flashbang",
		"weapon_tagrenade ",
		"weapon_healthshot",
		"weapon_fists",
		"weapon_c4"
	};
	
	for (int i = 0; i < sizeof(sArray); i++)
		if (StrEqual(WeaponName, sArray[i]))return true;
	
	
	return false;
}

bool GetWeaponName(int iEnt, char[] sBuffer, int iMaxLen)
{
	bool _ret = true;
	int index = GetEntProp(iEnt, Prop_Send, "m_iItemDefinitionIndex");
	
	if (index == 1)			Format(sBuffer, iMaxLen, "weapon_deagle");
	else if (index == 64)	Format(sBuffer, iMaxLen, "weapon_revolver");
	
	
	else
		_ret = GetEntityClassname(iEnt, sBuffer, iMaxLen);
	
	return _ret;
}

// Удаление наклеек с оружия
// Частичный копипаст :(
void RemoveStickers (int iClient, int iEnt)
{
	if (GetEntProp(iEnt, Prop_Send, "m_iItemIDHigh") < 16384)
	{
		int IDHigh = 16384;
		
		SetEntProp(iEnt, Prop_Send, "m_iItemIDLow", -1);
		SetEntProp(iEnt, Prop_Send, "m_iItemIDHigh", IDHigh++);
	}

	PTaH_GetEconItemViewFromEconEntity(iEnt)
		.NetworkedDynamicAttributesForDemos.DestroyAllAttributes();
	
	PTaH_ForceFullUpdate(iClient);
}

// Блокируем все атаки во время использования превью
// Можно в принципе убрать, но если не знаете что да как лучше не трогайте
public Action OnPlayerRunCmd(int iClient, int &buttons)  
{
	if (g_BlockAttack[iClient] && g_hPreviewTimer[iClient] != INVALID_HANDLE)
	{
		int iButton = buttons & (IN_ATTACK | IN_ATTACK2);
		
		if (iButton)
		{
			buttons &= ~iButton;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

// Блокируем дроп оружия во время превью
// Не убирать это, иначе могут быть баги связанные с превью ._.
public Action CS_OnCSWeaponDrop(int iClient, int iEnt)
{
     return (g_hPreviewTimer[iClient] != INVALID_HANDLE) 
     	? Plugin_Handled
     	: Plugin_Continue;
}

int[] GetWeaponAmmo(int iClient, int iEnt = -1)
{
	int i[2] = {-1, -1};
	
	if (iEnt > 0)
	{
		g_iAmmo[iClient][0] = GetAmmo(iClient, iEnt);
		g_iAmmo[iClient][1] = GetReserveAmmo(iClient, iEnt);
	}
	else
	{
		i = g_iAmmo[iClient];
		g_iAmmo[iClient] = {-1,-1};
	}
	
	return i;
}

void SetWeaponAmmo(int iClient, int iEnt = -1)
{
	int i[2] = {-1, -1};
	
	i = g_iAmmo[iClient];
	g_iAmmo[iClient] = {-1,-1};
	
	if (i[0] > -1)SetAmmo(iClient, iEnt, i[0]);
	if (i[1] > -1)SetReserveAmmo(iClient, iEnt, i[1]);
}

// Получение патронов которые обойме
int GetAmmo(int iClient, int iEnt = -1)
{
	//if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))return -1;
	
	if (iEnt == -1)
	{
		if (m_hActiveWeapon <= 0
			|| (iEnt = GetEntDataEnt2(iClient, m_hActiveWeapon)) <= 0
			|| !IsValidEntity(iEnt))return -1;
	}
	else if(!IsValidEntity(iEnt))return -1;
	
	int iAmmo;
	if ((iAmmo = GetEntProp(iEnt, Prop_Send, "m_iClip1")) < 0)iAmmo = 255;
	
	return iAmmo == 255 ? -1 : iAmmo;
}

// Получение патронов которые остались в запасе
int GetReserveAmmo(int iClient, int iEnt = -1)
{
	//if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))return -1;
	
	if (iEnt == -1)
	{
		if (m_hActiveWeapon <= 0
			|| (iEnt = GetEntDataEnt2(iClient, m_hActiveWeapon)) <= 0
			|| !IsValidEntity(iEnt))return -1;
	}
	else if(!IsValidEntity(iEnt))return -1;
	
	
	/*int iAmmo = -1, iEnt2 = GetPlayerWeaponSlot(iClient, 1);
	if (iEnt2 > 0 && IsValidEntity(iEnt2) && iEnt == iEnt2)
		iAmmo = GetEntProp(iEnt, Prop_Send, "m_iPrimaryReserveAmmoCount");
	else
	{
		int AmmoType;
		if (m_iPrimaryAmmoType > 0 && m_iAmmo > 0
			&& (AmmoType = GetEntData(iEnt, m_iPrimaryAmmoType)) > 0)
				iAmmo = GetEntData(iClient, (m_iAmmo + (AmmoType << 2)));
	}*/
	
	return GetEntProp(iEnt, Prop_Send, "m_iPrimaryReserveAmmoCount");
}

// Задаем паатроны которые в обойме
void SetAmmo(int iClient, int iEnt = -1, int value = 0)
{
	//if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))return -1;
	
	if (iEnt == -1)
	{
		if (m_hActiveWeapon <= 0
			|| (iEnt = GetEntDataEnt2(iClient, m_hActiveWeapon)) <= 0
			|| !IsValidEntity(iEnt))return;
	}
	else if(!IsValidEntity(iEnt))return;
	
	SetEntProp(iEnt, Prop_Send, "m_iClip1", value);
}

// Задаем патроны которые в запасе
void SetReserveAmmo(int iClient, int iEnt = -1, int value = 0)
{
	//if (iClient <= 0 || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))return -1;
	
	if (iEnt == -1)
	{
		if (m_hActiveWeapon <= 0
			|| (iEnt = GetEntDataEnt2(iClient, m_hActiveWeapon)) <= 0
			|| !IsValidEntity(iEnt))return;
	}
	else if(!IsValidEntity(iEnt))return;
	
	SetEntProp(iEnt, Prop_Send, "m_iPrimaryReserveAmmoCount", value);
	
	/*int iEnt2 = GetPlayerWeaponSlot(iClient, 1);
	if (iEnt2 > 0 && IsValidEntity(iEnt2) && iEnt == iEnt2)
		SetEntProp(iEnt, Prop_Send, "m_iPrimaryReserveAmmoCount", value);
	else
	{
		int AmmoType;
		if (m_iPrimaryAmmoType > 0 && m_iAmmo > 0
			&& (AmmoType = GetEntData(iEnt, m_iPrimaryAmmoType)) > 0)
				SetEntData(iClient, (m_iAmmo + (AmmoType << 2)), value);
	}*/
}

int GetEntityOfSlot(int iClient, char[] WeaponName, bool RetSlot = false)
{
	int iEnt = -1, iSlot = -1;
	char _WeaponName[32];

	Format(_WeaponName, sizeof(_WeaponName), WeaponName[7]);
	
	if (StrContains(_WeaponName, "knife") != -1)
	{
		iSlot = 2;
		if (!RetSlot)iEnt = GetPlayerWeaponSlot(iClient, 2);
	}
	else
	{
		char List[][] = {
			"ak47,aug,famas,galilar,m4a1_silencer,sg556,awp,g3sg1,ssg08,scar20,mac10,mp7,mp9,p90,ump45,bizon,negev,m249,xm1014,sawedoff,nova,mag7",
			"usp_silencer,glock,hkp2000,p250,tec9,elite,fiveseven,deagle,revolver,cz75a"
		};
		
		if (StrContains(List[0], _WeaponName) != -1)
		{
			iSlot = 0;
			if (!RetSlot)iEnt = GetPlayerWeaponSlot(iClient, 0);
		}
		else if (StrContains(List[1], _WeaponName) != -1)
		{
			iSlot = 1;
			if (!RetSlot)iEnt = GetPlayerWeaponSlot(iClient, 1);
		}
	}
	
	return RetSlot ? iSlot : ((iEnt <= 0 || !IsValidEdict(iEnt)) ? INVALID_ENT_REFERENCE : iEnt);
}

public Action KCC_OnReceivesKnifePre(int iClient, knifes &kKnife, bool bHasKnife, bool bKnifeClient, bool bSetKnife)
{
    if (FindWeaponClass_ItemId(iClient, "weapon_knife", true) != INVALID_ITEM)
    {
        kKnife = GetClientTeam(iClient) == 2 ? Default_T : Default_CT;
        return Plugin_Changed;
    }
    
    return Plugin_Continue;
}
