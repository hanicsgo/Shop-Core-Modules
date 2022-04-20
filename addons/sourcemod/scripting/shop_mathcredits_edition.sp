#include <sourcemod>
#include <shop>
#include <sdktools_sound>
#include <sdktools_stringtables>
#pragma newdecls required

char Plugin_tag[]	=		" \x04[AEYB Quiz]";
#define PLUS				"+"
#define MINUS				"-"
#define DIVISOR				"/"
#define MULTIPL				"*"

char operators[][] = {PLUS, MINUS, DIVISOR, MULTIPL};

char Sound_download[]	=	"sound/shop/Applause.mp3";

char soundplay[sizeof(Sound_download) - 5] = "*";
int nbrmin;
int nbrmax;
int mincredits;
int maxcredits;
static int questionResult;
int credits;
float minquestion;
float maxquestion;
float timeanswer;

int fTrigger;
int MaxTime;
char hudtext[256];

Handle timerQuestionEnd;

public Plugin myinfo = 
{
	name = "Math Credits",
	author = "Arkarr / Psychologist21 & AlmazON, hani from anhemyenbai",
	description = "Shop Math Credits",
	version = "1.2.1",
	url = "http://www.sourcemod.net, http://hlmod.ru"
};

public void OnPluginStart()
{
	ConVar cvar = CreateConVar("sm_MathCredits_minimum_number",				"-100",	"Каким должно быть минимальное число в примере?");
	HookConVarChange(cvar,	CVAR_MinimumNumber);
	nbrmin = cvar.IntValue;
	HookConVarChange(cvar = CreateConVar("sm_MathCredits_maximum_number",	"100",	"Каким должно быть максимальное число в примере?"),	CVAR_MaximumNumber);
	nbrmax = cvar.IntValue;
	HookConVarChange(cvar = CreateConVar("sm_MathCredits_minimum_credits",	"15",	"Минимальное количество кредитов, заработанных за правильный ответ.", _, true, 1.0), CVAR_MinimumCredits);
	mincredits = cvar.IntValue;
	HookConVarChange(cvar = CreateConVar("sm_MathCredits_maximum_credits",	"100",	"Максимальное количество кредитов, заработанных за правильный ответ.", _, true, 1.0), CVAR_MaximumCredits);
	maxcredits = cvar.IntValue;
	HookConVarChange(cvar = CreateConVar("sm_MathCredits_time_answer_questions",	"15",	"Время в секундах для того, чтобы дать ответ на вопрос.", _, true, 5.0),	CVAR_TimeAnswer);
	timeanswer = cvar.FloatValue;
	HookConVarChange(cvar = CreateConVar("sm_MathCredits_time_minamid_questions",	"100",	"Минимальное время в секундах между каждым из вопросов.", _, true, 5.0),	CVAR_MinQuestion);
	minquestion = cvar.FloatValue;
	HookConVarChange(cvar = CreateConVar("sm_MathCredits_time_maxamid_questions",	"250",	"Максимальное время в секундах между каждым из вопросов.", _, true, 10.0),	CVAR_MaxQuestion);
	maxquestion = cvar.FloatValue;
	AutoExecConfig(true, "shop_math");

	strcopy(soundplay[GetEngineVersion() == Engine_CSGO], sizeof(soundplay), Sound_download[6]);
}

public void CVAR_MinimumNumber(ConVar convar, const char[] oldValue, const char[] newValue)
{
	nbrmin = convar.IntValue;
}
public void CVAR_MaximumNumber(ConVar convar, const char[] oldValue, const char[] newValue)
{
	nbrmax = convar.IntValue;
}
public void CVAR_MinimumCredits(ConVar convar, const char[] oldValue, const char[] newValue)
{
	mincredits = convar.IntValue;
}
public void CVAR_MaximumCredits(ConVar convar, const char[] oldValue, const char[] newValue)
{
	maxcredits = convar.IntValue;
}
public void CVAR_TimeAnswer(ConVar convar, const char[] oldValue, const char[] newValue)
{
	timeanswer = convar.FloatValue;
}
public void CVAR_MinQuestion(ConVar convar, const char[] oldValue, const char[] newValue)
{
	minquestion = convar.FloatValue;
}
public void CVAR_MaxQuestion(ConVar convar, const char[] oldValue, const char[] newValue)
{
	maxquestion = convar.FloatValue;
}

public void OnMapStart()
{
	PrecacheSound(soundplay, true);
	AddFileToDownloadsTable(Sound_download);
}

public void OnConfigsExecuted()
{
	timerQuestionEnd = null;
	CreateTimer(GetRandomFloat(minquestion, maxquestion), CreateQuestion, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action CreateQuestion(Handle timer)
{
	char op[sizeof(operators[])];
	strcopy(op, sizeof(op), operators[GetRandomInt(0,sizeof(operators)-1)]);

	int nbr1, nbr2 = GetRandomInt(nbrmin, nbrmax);

	if(strcmp(op, DIVISOR))
	{
		nbr1 = GetRandomInt(nbrmin, nbrmax);
		questionResult = strcmp(op, PLUS) ? strcmp(op, MINUS) ? nbr1 * nbr2:nbr1 - nbr2:nbr1 + nbr2;
	}
	else questionResult = (nbr1 = GetRandomInt(nbrmin/nbr2, nbrmax/nbr2) * nbr2) / nbr2;

	timerQuestionEnd = CreateTimer(timeanswer, EndQuestion, _, TIMER_FLAG_NO_MAPCHANGE);

	credits = GetRandomInt(mincredits, maxcredits);

	char sNbr1[32];
	if(nbr1 < 0)
	{
		Format(sNbr1, 32, "(%i)", nbr1);
	}
	else if(nbr1 >= 0)
	{
		Format(sNbr1, 32, "%i", nbr1);
	}

	char sNbr2[32];
	if(nbr2 < 0)
	{
		Format(sNbr2, 32, "(%i)", nbr2);
	}
	else if(nbr2 >= 0)
	{
		Format(sNbr2, 32, "%i", nbr2);
	}

	for(int i = 1; i <= MaxClients; ++i)
	{
		if(IsClientInGame(i)) PrintToChat(i, "\n%s \x03%s %s %s = ?\n \x01Trả lời đúng sẽ được nhận \x05%i\x01 credits.\n", Plugin_tag, sNbr1, op, sNbr2, credits);
	}

	MaxTime = GetTime() + RoundToNearest(timeanswer);
	CreateTimer(1.0, ShowHudQuiz, _, TIMER_REPEAT);
	Format(hudtext, 256, "<font color='#4BFF4E'>%s</font> \n<font color='#74FFF2'>%s %s %s = ?</font> Trả lời đúng sẽ được nhận <font color='#FF74FD'>%i</font> credits.", Plugin_tag, sNbr1, op, sNbr2, credits);

	return Plugin_Stop;
}

public Action ShowHudQuiz(Handle timer, any data)
{
	fTrigger = GetTime();
	int showtime = MaxTime - fTrigger;

	if(timerQuestionEnd != null)
	{
		if(showtime == 0)
		{
			return Plugin_Handled;
		}

		PrintHintTextToAll("%s \nThời gian còn lại <font color='#3638C6'>%i</font> giây", hudtext, showtime);
		return Plugin_Continue;
	}
	else
	{
		return Plugin_Handled;
	}
}

public Action EndQuestion(Handle timer)
{
	SendEndQuestion();
	return Plugin_Stop;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if(timerQuestionEnd && StringToInt(sArgs) == questionResult && (questionResult || strcmp(sArgs, "0") == 0))
	{
		int clients[1];
		
		CalculateCredits(clients[0] = client, credits);
		PrintHintText(clients[0], "<font color='#4BFF4E'>[AEYB Quiz]</font> Bạn đã nhận <font color='#FF74FD'>%i</font> credits!", credits);		//CS:GO
		SendEndQuestion(clients[0]);
		EmitSound(clients, 1, soundplay);
	}
}

void CalculateCredits(int client, int icredits)
{
	int clientcredits = Shop_GetClientCredits(client);
	Shop_SetClientCredits(client, clientcredits + icredits);
}

void SendEndQuestion(int client = 0)
{
	int i = MaxClients;
	if(client)
	{
		while(i)
		{
			if(IsClientInGame(i)) PrintToChat(i, "%s \x03%N \x01Đã nhận được \x05%i \x01credits vì chiến thắng bài toán giải đố", Plugin_tag, client, credits);
			--i;
		}
		delete timerQuestionEnd;
	}
	else
	{
		while(i)
		{
			if(IsClientInGame(i)) PrintToChat(i, "%s \x03Thời gian đã hết, Không ai dành chiến thắng.", Plugin_tag);
			--i;
		}
	}
	OnConfigsExecuted();
}
