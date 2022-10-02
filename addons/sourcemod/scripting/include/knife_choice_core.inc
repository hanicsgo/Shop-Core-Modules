#if defined _knife_choice_core_included
  #endinput
#endif
#define _knife_choice_core_included

/*Типы ножей*/
enum knifes
{
	Default_CT = 1,
	Default_T,
	Gold,
	Flip,
	Gut,
	Bayonet,
	M9_bayonet,
	Karambit,
	Huntsman,
	Butterfly,
	Falchion,
	Shadow_Daggers,
	Bowie,
	Ursus,
	Gypsy_Jackknife, //Navaja
	Stiletto,
	Widowmaker, //Talon
	Ghost,
	Classic,
	Cord, //Paracord
	Canis, //Survival
	Outdoor, //Nomad
	Skeleton
}

/**
 **********************************************
 * ФУНКЦИИ
 **********************************************
**/

/**
 * Загружено ли ядро
 *
 * return:
 * false	        - ядро незагружено
 * true	            - ядро загружено
**/
native bool KCC_IsLoad();

/**
 * Получить имя ножа по его ид
 *
 * kKnife			- номер ножа
 * sBuffer			- строка куда вписано имя ножа
 * iSize			- размер sBuffer
 *
 * error			- ядро незагружено
**/
native void KCC_GetKnifeNameFromIndex(knifes kKnife, char[] sBuffer, int iSize);

/**
 * Выдать нож
 *
 * iClient			- игрок
 * kKnife		    - номер ножа
 *
 * return:
 * false	        - ошибка при выдаче ножа (чаще всего заблочен хуком)
 * true	            - нож выдан
 *
 * error			- невалидный клиент, ядро незагружено, игроку уже выдается нож
**/
native bool KCC_SetKnife(int iClient, knifes kKnife);

/**
 * Максимальный id ножа
 *
 * return: MaxId ножей
 *
 * error			- ядро незагружено
**/
native int KCC_GetKnifeMaxId();

/**
 * Получить id ножа из его типа
 *
 * return: Id ножа
 *
 * error			- ядро незагружено
**/
native int KCC_GetKnifeIdInType(knifes kKnife);

/**
 * Получить тип ножа из его id
 *
 * return: тип ножа
 *
 * error			- ядро незагружено, невалидный ид
**/
native knifes KCC_GetKnifeTypeInId(int id);

/**
 **********************************************
 * СОБЫТИЯ
 **********************************************
**/

/**
 * Knife choice CORE загрузился
**/
forward void KCC_OnLoaded();

/**
 * Вызывается перед выдачой ножа
 *
 * iClient			- индекс клиента
 * kKnife			- нож
 * bHasKnife		- имеет ли клиент нож (если нож выдается на прямую и у игрока уже есть нож то он просто упадет около него, а при выдаче через KCC_SetKnife старый нож будет удален)
 * bKnifeClient		- нож выдаеться клиенту напрямую (false - поднял с земли (если при false вернуть Plugin_Handled или Plugin_Stop тот нож будет убит))
 * bSetKnife		- нож выдаеться клиенту через KCC_SetKnife
 *	-
 * @return	Возврат Plugin_Stop или Plugin_Handled остановит выдачу ножа.
 * Возврат Plugin_Continue разрешит выдачу ножа без изменений.
 * Возврат Plugin_Changed разрешит выдачу ножа указаного в kKnife.
*/
forward Action KCC_OnReceivesKnifePre(int iClient, knifes &kKnife, bool bHasKnife, bool bKnifeClient, bool bSetKnife);

/**
 * Вызывается после выдачы ножа
 *
 * iClient			- индекс клиента
 * kKnife			- нож
 * iKnife			- id ножа
 * iKnifeEntity		- индекс ентити ножа
 * sKnifeName		- название ножа
 * bKnifeClient		- нож выдаеться клиенту напрямую (false - поднял с земли)
 *	-
 * @noreturn
*/
forward void KCC_OnReceivesKnife(int iClient, knifes kKnife, int iKnife, int iKnifeEntity, const char[] sKnifeName, bool bKnifeClient);


/**
Shared plugin information
**/
public SharedPlugin:__pl_knife_choice_core = 
{
	name = "knife_choice_core",
	file = "knife_choice_core.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_knife_choice_core_SetNTVOptional()
{
	MarkNativeAsOptional("KCC_IsLoad");
	MarkNativeAsOptional("KCC_GetKnifeNameFromIndex");
	MarkNativeAsOptional("KCC_GetKnifeNameFromIndexEx");
	MarkNativeAsOptional("KCC_SetKnife");
	MarkNativeAsOptional("KCC_GetKnifeMaxId");
	MarkNativeAsOptional("KCC_GetKnifeIdInType");
	MarkNativeAsOptional("KCC_GetKnifeTypeInId");
}
#endif