#if defined _Shop_CustomWeapons_included_
  #endinput
#endif
#define _Shop_CustomWeapons_included_


// Natives

/**
 * Checks if the weapon is custom
 *
 * @iClient			Client
 * @WeaponName		Weapon name. Example: weapon_knife
 * @Buffer			Output unique name item
 * @iSize			Max length of the buffer
 * @unknown			Unknown
 *
 * @return true - Custom, false not Custom
 */
native bool CW_Exists(int iClient, char[] WeaponName, char[] Buffer = "", int iSize = 0, bool unknown = true);




// Forwards

/**
 * Called before the player turns on or off custom weapons.
 *
 * @iClient			Client
 * @WeaponName		Weapon name
 * @ItemName		Unique name item
 * @isOn			Switched on or off
 *
 * @noreturn
 */
forward void CW_OnWeaponPre(int iClient, char[] WeaponName, char[] ItemName, bool isOn);


/**
 * Called when a player turns on or off a non-standard weapon.
 *
 * @iClient			Client
 * @WeaponName		Weapon name
 * @ItemName		Unique name item
 * @isOn			Switched on or off
 *
 * @noreturn
 */
forward void CW_OnWeapon(int iClient, char[] WeaponName, char[] ItemName, bool isOn);