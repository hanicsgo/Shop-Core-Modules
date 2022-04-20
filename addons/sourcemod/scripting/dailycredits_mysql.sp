#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <shop>
#include <csgocolors>

#pragma newdecls required

Database db;
ConVar g_hDailyEnable;
ConVar g_hDailyCredits;
ConVar g_hDailyBonus;
ConVar g_hDailyMax;
ConVar g_hDailyReset;
ConVar g_hDailyInterval;
char CurrentDate[20];
int ConnectTime[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Daily Credits mysql to Shop core",
	author = "Simon & Nachtfrische, Snooze, hani from anhemyenbai",
	description = "Daily Credits",
	version = "1.0,
	url = "http://www.sourcemod.net, http://hlmod.ru"
};

public void OnPluginStart()
{
	LoadTranslations("dailycredits.phrases");
	CreateConVar("sm_daily_credits_version", PLUGIN_VERSION, "Daily Credits Version", FCVAR_DONTRECORD | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY);
	g_hDailyEnable = CreateConVar("sm_daily_credits_enable", "1", "Daily Credits enable? 0 = disable, 1 = enable", 0, true, 0.0, true, 1.0);
	g_hDailyCredits = CreateConVar("sm_daily_credits_amount", "1000", "Amount of Credits.", 0, true, 0.0);
	g_hDailyBonus = CreateConVar("sm_daily_credits_bonus", "2", "Increase in Daily Credits on consecutive days.", 0, true, 0.0);
	g_hDailyMax = CreateConVar("sm_daily_credits_max", "7000", "Max credits that you can get daily.", 0, true, 0.0);
	g_hDailyReset = CreateConVar("sm_daily_credits_resetperiod", "7", "Amount of days after which the streak should reset itself. Set to 0 to disable.", 0, true, 0.0);
	g_hDailyInterval = CreateConVar("sm_daily_credits_interval", "3", "Number of minutes required by the player to play on the server before getting daily credits. Set to 0 to immediately give credits upon using !daily.", 0, true, 0.0);
	
	AutoExecConfig(true, "dailycredits");
	RegConsoleCmd("sm_daily", Cmd_Daily);
	RegConsoleCmd("sm_dailies", Cmd_Daily);
	InitializeDB();
}

public void OnClientConnected(int client)
{
	ConnectTime[client] = GetTime();
}

public void OnClientDisconnect(int client)
{
	ConnectTime[client] = 0;
}

public void InitializeDB()
{
	char Error[255];
	db = SQL_Connect("dailycredits", true, Error, sizeof(Error));
	SQL_SetCharset(db, "utf8");
	if (db == INVALID_HANDLE)
	{
		SetFailState(Error);
	}
	SQL_TQuery(db, SQLErrorCheckCallback, "CREATE TABLE IF NOT EXISTS players (steam_id VARCHAR(20) UNIQUE, last_connect INT(12), bonus_amount INT(12));");
}

public Action Cmd_Daily(int client, int args)
{
	if (!GetConVarBool(g_hDailyEnable)) return Plugin_Handled;
	if (!IsValidClient(client)) return Plugin_Handled;
	if (GetConVarInt(g_hDailyInterval) > 0)
	{
		int TimeTillNow = 0;
		TimeTillNow = RoundToFloor(float((GetTime() - ConnectTime[client]) / 60));
		if (TimeTillNow < GetConVarInt(g_hDailyInterval))
		{
			CPrintToChat(client, "%t", "WaitForInterval", GetConVarInt(g_hDailyInterval) - TimeTillNow);
			return Plugin_Handled;
		}
	}
	FormatTime(CurrentDate, sizeof(CurrentDate), "%Y%m%d"); // Save current date in variable
	char steamId[32];
	if (GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
	{
		char buffer[200];
		Format(buffer, sizeof(buffer), "SELECT * FROM players WHERE steam_id = '%s'", steamId);
		SQL_LockDatabase(db);
		DBResultSet query = SQL_Query(db, buffer);
		SQL_UnlockDatabase(db);
		if (SQL_GetRowCount(query) == 0)
		{
			delete query;
			GiveCredits(client, true);
		}
		else
		{
			delete query;
			GiveCredits(client, false);
		}
	}
	else LogError("Failed to get Steam ID");
	
	return Plugin_Handled;
}

stock void GiveCredits(int client, bool FirstTime)
{
	char buffer[200];
	char steamId[32];
	if (GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId)))
	{
		if (FirstTime)
		{
			Shop_SetClientCredits(client, Shop_GetClientCredits(client) + GetConVarInt(g_hDailyCredits));
			CPrintToChat(client, "%t", "CreditsRecieved", GetConVarInt(g_hDailyCredits));
			Format(buffer, sizeof(buffer), "INSERT IGNORE INTO players (steam_id, last_connect, bonus_amount) VALUES ('%s', %d, 1)", steamId, StringToInt(CurrentDate));
			SQL_TQuery(db, SQLErrorCheckCallback, buffer);
		}
		else
		{
			Format(buffer, sizeof(buffer), "SELECT * FROM players WHERE steam_id = '%s'", steamId);
			SQL_LockDatabase(db);
			DBResultSet query = SQL_Query(db, buffer);
			SQL_UnlockDatabase(db);
			SQL_FetchRow(query);
			int date2 = SQL_FetchInt(query, 1);
			int bonus = SQL_FetchInt(query, 2);
			delete query;
			int date1 = StringToInt(CurrentDate);
			int resetDaysSetting = GetConVarInt(g_hDailyReset);
			
			if (resetDaysSetting > 0) {  //needed since after the reset, bonus starts at 0
				resetDaysSetting--;
			}
			
			//streak is currently continuing
			if ((date1 - date2) == 1)
			{
				int TotalCredits = GetConVarInt(g_hDailyCredits) + (bonus * GetConVarInt(g_hDailyBonus)); //bonus can't start at 1, since the first day would get the player a bonus as well
				if (TotalCredits > GetConVarInt(g_hDailyMax))TotalCredits = GetConVarInt(g_hDailyMax);
				Shop_SetClientCredits(client, Shop_GetClientCredits(client) + TotalCredits);
				
				if (resetDaysSetting != 0)
				{
					if (bonus >= resetDaysSetting)
					{
						CPrintToChat(client, "%t", "LastCreditsRecieved", TotalCredits);
						Format(buffer, sizeof(buffer), "UPDATE players SET last_connect = %i, bonus_amount = %i WHERE steam_id = '%s'", date1, 0, steamId);
						CPrintToChat(client, "%t", "ResetDays", resetDaysSetting + 1);
					}
					else
					{
						CPrintToChat(client, "%t", "CreditsRecieved", TotalCredits);
						Format(buffer, sizeof(buffer), "UPDATE players SET last_connect = %i, bonus_amount = %i WHERE steam_id = '%s'", date1, bonus + 1, steamId);
						CPrintToChat(client, "%t", "CurrentDay", bonus + 1);
					}
				}
				else
				{
					CPrintToChat(client, "%t", "CreditsRecieved", TotalCredits);
					Format(buffer, sizeof(buffer), "UPDATE players SET last_connect = %i, bonus_amount = %i WHERE steam_id = '%s'", date1, bonus + 1, steamId);
					CPrintToChat(client, "%t", "CurrentDay", bonus + 1);
				}
				SQL_TQuery(db, SQLErrorCheckCallback, buffer);
			}
			//already recieved credits today
			else if ((date1 - date2) == 0)
			{
				CPrintToChat(client, "%t", "BackTomorrow");
			}
			//streak ended
			else if ((date1 - date2) > 1)
			{
				CPrintToChat(client, "%t", "StreakEnded", bonus);
				Shop_SetClientCredits(client, Shop_GetClientCredits(client) + GetConVarInt(g_hDailyCredits));
				CPrintToChat(client, "%t", "CreditsRecieved", GetConVarInt(g_hDailyCredits));
				Format(buffer, sizeof(buffer), "UPDATE players SET last_connect = %i, bonus_amount = 1 WHERE steam_id = '%s'", date1, steamId);
				SQL_TQuery(db, SQLErrorCheckCallback, buffer);
			}
		}
	}
	else LogError("Failed to get Steam ID");
}

stock bool IsValidClient(int client)
{
	if (client <= 0)return false;
	if (client > MaxClients)return false;
	if (!IsClientConnected(client))return false;
	return IsClientInGame(client);
}

public void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (!StrEqual(error, ""))
		LogError(error);
} 