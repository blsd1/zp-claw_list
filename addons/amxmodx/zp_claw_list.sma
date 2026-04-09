#include <amxmodx>
#include <hamsandwich>
#include <zombieplague>

enum
{
	SECTION_NONE = 0,
	SECTION_LIST_ZOMBIE,
	SECTION_LIST_NEMESIS
};

enum any: ZombieListStruct 
{
	KEY[32],
	WEAPLISTNAME[128]
};

new Array:gl_aZombieListData, Array:gl_aNemesisListData;

new const PLUGIN_NAME[] = "[ZP 4.3] Addon: Zombie WeaponList";
new const PLUGIN_VERSION[] = "2.0";
new const PLUGIN_AUTHOR[] = "ketamine";

public plugin_init() 
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
}

public plugin_precache() 
{
	gl_aZombieListData = ArrayCreate(ZombieListStruct);
	gl_aNemesisListData = ArrayCreate(128);
	ReadFile();

	new ZombieListData[ZombieListStruct];

	for(new iCase; iCase < ArraySize(gl_aZombieListData); iCase++) {
		ArrayGetArray(gl_aZombieListData, iCase, ZombieListData);

		register_clcmd(ZombieListData[WEAPLISTNAME], "ClientCommand_WeaponHook");
		
		UTIL_PrecacheSpritesFromTxt(ZombieListData[WEAPLISTNAME]);
	}
	
	for(new iCase; iCase < ArraySize(gl_aNemesisListData); iCase++) {
		new szNemesisListName[128];
		ArrayGetString(gl_aNemesisListData, iCase, szNemesisListName, charsmax(szNemesisListName));

		register_clcmd(szNemesisListName, "ClientCommand_WeaponHook");
		
		UTIL_PrecacheSpritesFromTxt(szNemesisListName);
	}

	RegisterHam(Ham_Item_AddToPlayer, "weapon_knife", "HamHook_Item_AddToPlayer_Post", true);
	RegisterHam(Ham_Spawn, "player", "HamHook_Spawn_Post", true);
}

public HamHook_Spawn_Post(UserId)
{
	RequestFrame("UpdateList", UserId);
}

public UpdateList(UserId) 
{
	if(zp_get_user_zombie(UserId))
	{
		new ZombieListData[ZombieListStruct];
		for(new iCase; iCase < ArraySize(gl_aZombieListData); iCase++)
		{
			ArrayGetArray(gl_aZombieListData, iCase, ZombieListData);
			new ClassId = zp_get_zombie_class_id(ZombieListData[KEY]);
			if(ClassId == -1) ClassId = str_to_num(ZombieListData[KEY]);

			if(zp_get_user_zombie_class(UserId) == ClassId)
			{
				UTIL_SetWeaponList(UserId, ZombieListData[WEAPLISTNAME]);
			}
		}
	}
	else if(!zp_get_user_nemesis(UserId))
	{	
		UTIL_SetWeaponList(UserId, "weapon_knife");
	}
}

public HamHook_Item_AddToPlayer_Post(iWeapon, UserId) {
	if(!is_user_alive(UserId)) 
	{
		return;
	}

	new ZombieListData[ZombieListStruct];
	
	if(zp_get_user_nemesis(UserId)) 
	{
		new szNemesisListName[128];
		new iArraySize = ArraySize(gl_aNemesisListData);
		
		ArrayGetString(gl_aNemesisListData, iArraySize > 0 ? random_num(0, iArraySize - 1) : 0, szNemesisListName, charsmax(szNemesisListName));
		
		UTIL_SetWeaponList(UserId, szNemesisListName);
	}
	else if(zp_get_user_zombie(UserId)) 
	{
		for(new iCase; iCase < ArraySize(gl_aZombieListData); iCase++) 
		{
			ArrayGetArray(gl_aZombieListData, iCase, ZombieListData);
			new ClassId = zp_get_zombie_class_id(ZombieListData[KEY]);
			if(ClassId == -1) ClassId = str_to_num(ZombieListData[KEY]);
			
			if(zp_get_user_zombie_class(UserId) == ClassId) 
			{
				UTIL_SetWeaponList(UserId, ZombieListData[WEAPLISTNAME]);
			}
		}
	}
	else 
	{
		UTIL_SetWeaponList(UserId, "weapon_knife");
	}	
}

public ClientCommand_WeaponHook(UserId) 
{
	engclient_cmd(UserId, "weapon_knife");
	return PLUGIN_HANDLED;
}

stock UTIL_SetWeaponList(UserId, const szWeaponName[], iPrimaryAmmoID = -1, 
	iPrimaryAmmoMaxAmount = -1, iSecondaryAmmoID = -1, iSecondaryAmmoMaxAmount = -1, iSlotID = 2, iNumberInSlot = 1, iWeaponID = 29, iFlags = 0)
{
	message_begin(MSG_ONE, 78, _, UserId);
	write_string(szWeaponName);
	write_byte(iPrimaryAmmoID);
	write_byte(iPrimaryAmmoMaxAmount);
	write_byte(iSecondaryAmmoID);
	write_byte(iSecondaryAmmoMaxAmount);
	write_byte(iSlotID);
	write_byte(iNumberInSlot);
	write_byte(iWeaponID);
	write_byte(iFlags);
	message_end();
}

public ReadFile() 
{
	new szData[256], f, ZombieListData[ZombieListStruct], szNemesisListName[128], iSection;
	formatex(szData, charsmax(szData), "addons/amxmodx/configs/plugins/clawlist.ini");

	f = fopen(szData, "r");

	while(!feof(f)) 
	{
		fgets(f, szData, charsmax(szData));
		trim(szData);

		if(szData[0] == EOS || szData[0] == ';' || szData[0] == '/' && szData[1] == '/')
		{
			continue;
		}
		
		if(szData[0] == '[') 
		{
			iSection++;
			continue;
		}
		
		switch(iSection) 
		{
			case SECTION_LIST_ZOMBIE: 
			{
				if(szData[0] == '"') 
				{
					parse(szData,
						ZombieListData[KEY], 31,
						ZombieListData[WEAPLISTNAME], 127
					);

					ArrayPushArray(gl_aZombieListData, ZombieListData);
				}
			}
			case SECTION_LIST_NEMESIS:
			{
				if(szData[0] == '"') 
				{				
					parse(szData,
						szNemesisListName, charsmax(szNemesisListName)
					);

					ArrayPushString(gl_aNemesisListData, szNemesisListName);
				}
			}
		}
	}
	
	fclose(f);
}

stock UTIL_PrecacheSpritesFromTxt(szWeaponList[])
{
	new szTxtDir[64], szSprDir[64]; 
	new szFileData[128], szSprName[48], temp[1];

	format(szTxtDir, charsmax(szTxtDir), "sprites/%s.txt", szWeaponList);
	precache_generic(szTxtDir);

	new iFile = fopen(szTxtDir, "rb");
	
	while(iFile && !feof(iFile)) 
	{
		fgets(iFile, szFileData, charsmax(szFileData));
		trim(szFileData);

		if(!strlen(szFileData)) 
			continue;

		new pos = containi(szFileData, "640");	
			
		if(pos == -1)
			continue;
			
		format(szFileData, charsmax(szFileData), "%s", szFileData[pos+3]);		
		trim(szFileData);

		strtok(szFileData, szSprName, charsmax(szSprName), temp, charsmax(temp), ' ', 1);
		trim(szSprName);
		
		format(szSprDir, charsmax(szSprDir), "sprites/%s.spr", szSprName);
		precache_generic(szSprDir);
	}

	if(iFile)
	{
		fclose(iFile);
	}
}