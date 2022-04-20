#pragma semicolon 1
#pragma newdecls required

#include <sdktools_hooks>
#include <shop>

public Plugin myinfo =
{
	name        = 	"[Shop] BHop",
	author      = 	"Someone, hani from anhemyenbai",
	version     = 	"1.2",
	url         = 	"http://hlmod.ru/"
};

ItemId g_iID;
bool g_bUseBhop[MAXPLAYERS+1];

public void OnPluginStart()
{
	if (Shop_IsStarted()) Shop_Started();
	AutoExecConfig(true, "shop_bhop");
}

public void OnClientDisconnect(int iClient)
{
	g_bUseBhop[iClient] = false;
}

public void Shop_Started()
{
	CategoryId category_id = Shop_RegisterCategory("Ability", "Ability", "");
	
	if (Shop_StartItem(category_id, "shop_bhop"))
	{
		ConVar CVARB, CVARS, CVART;
	
		(CVARB = CreateConVar("sm_shop_bhop_price", "10000", "Цена покупки.", _, true, 0.0)).AddChangeHook(ChangeCvar_Buy);
		(CVARS = CreateConVar("sm_shop_bhop_sell_price", "200", "Цена продажи.", _, true, 0.0)).AddChangeHook(ChangeCvar_Sell);
		(CVART = CreateConVar("sm_shop_bhop_time", "3000", "Время действия покупки в секундах.", _, true, 0.0)).AddChangeHook(ChangeCvar_Time);
		
		Shop_SetInfo("Bhop", "", CVARB.IntValue, CVARS.IntValue, Item_Togglable, CVART.IntValue);
		Shop_SetCallbacks(OnItemRegistered, OnEquipItem);
		Shop_EndItem();
	}
}

public void ChangeCvar_Buy(ConVar convar, const char[] oldValue, const char[] newValue)
{
	Shop_SetItemPrice(g_iID, convar.IntValue);
}

public void ChangeCvar_Sell(ConVar convar, const char[] oldValue, const char[] newValue)
{
	Shop_SetItemSellPrice(g_iID, convar.IntValue);
}

public void ChangeCvar_Time(ConVar convar, const char[] oldValue, const char[] newValue)
{
	Shop_SetItemValue(g_iID, convar.IntValue);
}

public void OnItemRegistered(CategoryId category_id, const char[] sCategory, const char[] sItem, ItemId item_id)
{
	g_iID = item_id;
}

public ShopAction OnEquipItem(int iClient, CategoryId category_id, const char[] sCategory, ItemId item_id, const char[] sItem, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bUseBhop[iClient] = false;
		return Shop_UseOff;
	}

	g_bUseBhop[iClient] = true;

	return Shop_UseOn;
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse) // float vel[3], float fAngles[3], int &iWeapon)
{
	if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && g_bUseBhop[iClient] && iButtons & IN_JUMP && !(GetEntityMoveType(iClient) & MOVETYPE_LADDER) && !(GetEntityFlags(iClient) & FL_ONGROUND))
	{
		iButtons &= ~IN_JUMP; 
	}
	return Plugin_Continue;
}