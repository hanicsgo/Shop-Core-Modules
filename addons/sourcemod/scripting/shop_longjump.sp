#pragma semicolon 1
#include <sourcemod>
#include <shop>

#define CATEGORY	"ability"
#define ITEM	"longjump"

bool g_bHasLJ[MAXPLAYERS+1];
float g_fLastJump[MAXPLAYERS+1];

int g_iPrice,
	g_iSellPrice,
	g_iDuration;

ItemId g_eItemID;

float g_fInterval,
	  g_fDistance;

int VelocityOffset_0 = -1,
	VelocityOffset_1 = -1,
	BaseVelocityOffset = -1; 

public Plugin myinfo =
{
	name = "[Shop] Long Jump",
	author = "R1KO, Faya, hani from anhemyenbai™",
	version = "1.5"
};

public void OnPluginStart()
{
	Handle hCvar;

	HookConVarChange((hCvar = CreateConVar("sm_shop_longjump_price", "10000", "Стоимость покупки длинных прыжков.")), OnPriceChange);
	g_iPrice = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_longjump_sellprice", "1000", "Стоимость продажи длинных прыжков.")), OnSellPriceChange);
	g_iSellPrice = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_longjump_duration", "7200", "Длительность длинных прыжков в секундах.")), OnDurationChange);
	g_iDuration = GetConVarInt(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_longjump_interval", "2.0", "Время между прыжками")), OnIntervalChange);
	g_fInterval = GetConVarFloat(hCvar);
	
	HookConVarChange((hCvar = CreateConVar("sm_shop_longjump_distance", "1.2", "Усиление прыжка")), OnDistanceChange); // if you want higher, change more 
	g_fDistance = GetConVarFloat(hCvar);
	
	AutoExecConfig(true, "shop_longjump", "shop");

	VelocityOffset_0 = GetSendPropOffset("CBasePlayer", "m_vecVelocity[0]");
	VelocityOffset_1 = GetSendPropOffset("CBasePlayer", "m_vecVelocity[1]");
	BaseVelocityOffset = GetSendPropOffset("CBasePlayer", "m_vecBaseVelocity");

	HookEvent("player_jump", Event_PlayerJump);

	if (Shop_IsStarted())
	{
		Shop_Started();
	}
}

public void OnClientDisconnect(int iClient)
{
	g_bHasLJ[iClient] = false;
}

public void OnClientPutInServer(int iClient)
{
	g_fLastJump[iClient] = GetGameTime();
}

int GetSendPropOffset(const char[] sNetClass, const char[] sPropertyName)
{
	int iOffset = FindSendPropInfo(sNetClass, sPropertyName);
	if (iOffset == -1)
	{
		SetFailState("Fatal Error: Unable to find offset: \"%s::%s\"", sNetClass, sPropertyName);
	}

	return iOffset;
}

public void OnPriceChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	if (g_eItemID != INVALID_ITEM)
	{
		g_iPrice = GetConVarInt(hCvar);
		Shop_SetItemPrice(g_eItemID, g_iPrice);
	}
}

public void OnSellPriceChange(Handle hCvar, const char[] oldValue, const char[] newValue) 
{
	if (g_eItemID != INVALID_ITEM)
	{
		g_iSellPrice = GetConVarInt(hCvar);
		Shop_SetItemSellPrice(g_eItemID, g_iSellPrice);
	}
}

public void OnDurationChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	if (g_eItemID != INVALID_ITEM)
	{
		g_iDuration = GetConVarInt(hCvar);
		Shop_SetItemValue(g_eItemID, g_iDuration);
	}
}

public void OnIntervalChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	g_fInterval = GetConVarFloat(hCvar);
}

public void OnDistanceChange(Handle hCvar, const char[] oldValue, const char[] newValue)
{
	g_fDistance = GetConVarFloat(hCvar);
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void Shop_Started()
{
	CategoryId category_id = Shop_RegisterCategory("Ability", "Ability", "");
	
	if (Shop_StartItem(category_id, ITEM))
	{
		Shop_SetInfo("Long Jump", "", g_iPrice, g_iSellPrice, Item_Togglable, g_iDuration);
		Shop_SetCallbacks(OnItemRegistered, OnLJUsed);
		Shop_EndItem();
	}
}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	g_eItemID = item_id;
}

public ShopAction OnLJUsed(int iClient, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		g_bHasLJ[iClient] = false;
		return Shop_UseOff;
	}

	g_bHasLJ[iClient] = true;

	return Shop_UseOn;
}

public Action Event_PlayerJump(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (g_bHasLJ[iClient])
	{
		float fGameTime = GetGameTime();
		if((fGameTime - g_fLastJump[iClient]) > g_fInterval)
		{
			g_fLastJump[iClient] = fGameTime;
			float finalvec[3];
			finalvec[0] = GetEntDataFloat(iClient, VelocityOffset_0) * g_fDistance / 2.0;
			finalvec[1] = GetEntDataFloat(iClient, VelocityOffset_1) * g_fDistance / 2.0;
			finalvec[2] = 0.0;
			SetEntDataVector(iClient, BaseVelocityOffset, finalvec, true);
		}
	}
}