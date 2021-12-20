/************************* CREDITS *************************

- OciXCrom ( For VIP Hour stock )
- Yontu ( For map parsing in file code )

************************* CREDITS *************************/

#include < amxmodx >
#include < amxmisc >
#include < cstrike >
#include < engine >
#include < fakemeta >
#include < fun >
#include < hamsandwich >

#pragma semicolon 1

#define PLUGIN "VIP Clasic"
#define VERSION "1.9"
#define AUTHOR "Shadows Adi"

//Aici modifici 'ADMIN_LEVEL_H' in functie de flagul pe care il vrei. Default: 't'
#define is_user_vip(%1) (get_user_flags(%1) & ADMIN_LEVEL_H)

//Aici vei pune "//" in fata lui #define daca nu vrei sa ii apara tag in chat cand scrie.
//#define VIP_CHAT

enum _:CvarsSettings {
	VipHP,
	VipHsHP,
	VipAP,
	VipHsAP,
	VipMaxHP,
	VipMaxAP,
	VipPrefix,
	VipSpawnHP,
	VipSpawnAP,
#if defined VIP_CHAT
	VipChatPrefix,
#endif
	VipJumps,
	VipPrices,
	VipMenuRounds,
	VipFree,
	VipFreeStart,
	VipFreeEnd,
	VipMaxResets,
	VipModels
};

enum _:Teams
{
	CT = 0,
	TERO,
	BOTH
};

enum _:Weapons 
{
	WeapName[64],
	WeaponID[32],
	BpAmmo,
	Team[Teams],
	WeaponModels[64]
};

new const VipWeapons[][Weapons] = {
	{ "AK47 \d+ \wDeagle \d+ \wSet Grenade", "weapon_ak47", 90, TERO, "models/vip_models/ak47.mdl" },
	{ "Galil \d+ \wDeagle \d+ \wSet Grenade", "weapon_galil", 30, TERO, "models/vip_models/galil.mdl" },
	{ "AWP \d+ \wDeagle \d+ \wSet Grenade", "weapon_awp", 30, BOTH, "models/vip_models/awp.mdl" },
	{ "M4A1 \d+ \wDeagle \d+ \wSet Grenade", "weapon_m4a1", 90, CT, "models/vip_models/m4a1.mdl" },
	{ "Famas \d+ \wDeagle \d+ \wSet Grenade", "weapon_famas", 30, CT, "models/vip_models/famas.mdl" }
};

new const VipPistols[][Weapons] = {
	{ "\wDeagle \d+ \wGrenade Set", "weapon_deagle", 35, BOTH, "models/vip_models/deagle.mdl" },		
	{ "\wUSP \d+ \wGrenade Set","weapon_usp", 100, BOTH, "models/vip_models/usp.mdl" },	
	{ "\wGlock-18 \d+ \wGrenade Set", "weapon_glock18", 120, BOTH, "models/vip_models/glock18.mdl" }	
};

new pCvars[CvarsSettings];
new g_iRound;
new jumpnum[ 33 ] = 0;
new g_bMapBanned;
new Limit [ 33 ];
new Tag[ 32 ];

/********************** BOOLEANS **********************/
new bool:WeaponSelected[33];
new bool:dojump[ 33 ] = false;
/********************** END OF BOOLEANS **********************/

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90);
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE);

new const g_szWeaponEntName[][] =
{
	"weapon_p228",
	"weapon_scout",
	"weapon_hegrenade",
	"weapon_xm1014",
	"weapon_c4",
	"weapon_mac10",
	"weapon_aug",
	"weapon_smokegrenade",
	"weapon_elite",
	"weapon_fiveseven",
	"weapon_ump45",
	"weapon_sg550",
	"weapon_galil",
	"weapon_famas",
	"weapon_usp",
	"weapon_glock18",
	"weapon_awp",
	"weapon_mp5navy",
	"weapon_m249",
	"weapon_m3",
	"weapon_m4a1",
	"weapon_tmp",
	"weapon_g3sg1",
	"weapon_flashbang",
	"weapon_deagle",
	"weapon_sg552",
	"weapon_ak47",
	"weapon_knife",
	"weapon_p90"
};

public plugin_precache()
{
	RegisterCvars();

	if(get_pcvar_num(pCvars[ VipModels ]))
	{
		for(new i; i < sizeof(VipWeapons); i++)
		{
			precache_model(VipWeapons[i][WeaponModels]);
		}

		for(new i; i < sizeof(VipPistols); i++)
		{
			precache_model(VipPistols[i][WeaponModels]);
		}
	}
}

public plugin_init( )
{
	register_plugin( PLUGIN, VERSION, AUTHOR);
	
	register_clcmd( "say /vm", "ShowVIPMenu" );
	register_clcmd( "say /vmenu", "ShowVIPMenu" );
	register_clcmd( "say /vip", "ShowVIPMotd" );
	register_clcmd( "say /vips", "ShowVIPs" );
	register_clcmd( "say /rsd", "check_vip" );
	register_clcmd( "say_team /vm", "ShowVIPMenu" );
	register_clcmd( "say_team /vmenu", "ShowVIPMenu" );
	register_clcmd( "say_team /vips", "ShowVIPs" );
	register_clcmd( "say_team /rsd", "check_vip" );
	
	#if defined VIP_CHAT
	register_clcmd( "say ", "hook_say" );
	//register_clcmd( "say_team ", "hook_sayteam" );
	pCvars [ VipChatPrefix ] = register_cvar( "vip_chat_prefix", "[VIP]" );
	#endif
	
	RegisterHam( Ham_Spawn, "player", "ham_PlayerSpawnPost", 1);
	RegisterHam( Ham_Killed, "player", "ham_PlayerKilledPost", 1);
	for(new i; i < sizeof(g_szWeaponEntName); i++)
	{
		RegisterHam( Ham_Item_Deploy, g_szWeaponEntName[i], "ham_ItemDeployPost", 1 );
	}
	register_event( "HLTV", "ev_NewRound", "a", "1=0", "2=0" ); 
	register_logevent( "logev_Restart", 2, "1&Restart_Round", "1&Game_Commencing" );
	register_message(get_user_msgid("ScoreAttrib"), "OnScoreAttrib");
	
	get_pcvar_string( pCvars[ VipPrefix ], Tag, charsmax( Tag ) );

	new path[ 64 ];
	get_localinfo( "amxx_configsdir", path, charsmax( path ) );
	formatex( path, charsmax( path ), "%s/VIP/vip_maps.ini", path);
	
	new file = fopen( path, "r+" );
	
	if( !file_exists( path ) )
	{
		write_file( path, "; VIP-UL ESTE DEZACTIVAT PE URMATOARELE HARTI: ");
		write_file( path, "; Exemplu de adaugare HARTA:^n; ^"harta^"^n^nfy_snow^nawp_bycastor" );
		write_file( path, "; NOTA:^n Pentru a ignora anumite harti, adaugati ^";^" in fata hartii" );
	}
	
	new mapname[ 32 ];
	get_mapname( mapname, charsmax( mapname ) );
	
	new text[ 121 ], maptext[ 32 ];
	while( !feof( file ) )
	{
		fgets( file, text, charsmax( text ) );
		trim( text );
		
		if( text[ 0 ] == ';' || !strlen( text ) ) 
		{
			continue; 
		}
		
		parse( text, maptext, charsmax( maptext ) );
		
		if( equal( maptext, mapname) )
		{
			//********* AICI STERGETI "//" DIN FATA PENTRU DEBUG. *********//
			//log_amx("Am dezactivat pluginul 'VIP' pe harta %s.", maptext ); 
			g_bMapBanned = 1;
			break;
		}
	}
	fclose( file );
}

RegisterCvars()
{
	register_cvar( "lgcs_vip_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED );

	pCvars [ VipHP ] = register_cvar( "vip_kill_hp", "10" );
	pCvars [ VipAP ] = register_cvar( "vip_kill_ap", "10" );
	pCvars [ VipHsHP ] = register_cvar( "vip_killhs_hp", "15" );
	pCvars [ VipHsAP ] = register_cvar( "vip_killhs_ap", "15" );
	pCvars [ VipMaxHP ] = register_cvar( "vip_max_hp", "110" );
	pCvars [ VipMaxAP ] = register_cvar( "vip_max_ap", "110" );
	pCvars [ VipPrefix ] = register_cvar( "vip_msg_prefix", "[VIP]" );
	pCvars [ VipSpawnHP ] = register_cvar("vip_spawn_hp", "100");
	pCvars [ VipSpawnAP ] = register_cvar("vip_spawn_ap", "100");
	pCvars [ VipJumps ] = register_cvar( "vip_multi_jumps", "1" );
	pCvars [ VipPrices ] = register_cvar( "vip_prices_motd", "vip_info.html" );
	pCvars [ VipMenuRounds ] = register_cvar( "vip_rounds_showmenu", "3" );
	pCvars [ VipFree ] = register_cvar( "vip_free_on", "1" );
	pCvars [ VipFreeStart ] = register_cvar( "vip_free_start", "22" );
	pCvars [ VipFreeEnd ] = register_cvar( "vip_free_end", "10" );
	pCvars [ VipMaxResets ] = register_cvar( "vip_max_reset_deaths", "3" );
	pCvars [ VipModels ] = register_cvar( "vip_weapon_models", "0" );
}

public client_putinserver( id )
{
	if( is_user_vip( id ) )
	{
		new szName[32];
		get_user_name( id, szName, charsmax( szName ) );
		color_chat(0, "!g%s !yVIP-ul !g%s !ytocmai s-a conectat pe server!", Tag, szName);
	}
	jumpnum[ id ] = 0;
	dojump[ id ] = false;
}

#if AMXX_VERSION_NUM < 183
public client_disconnect( id )
#else
public client_disconnected( id )
#endif
{
	jumpnum[ id ] = 0;
	dojump[ id ] = false;
}

public ev_NewRound( )
{
	g_iRound++;

	if( IsVipHour( get_pcvar_num( pCvars [ VipFreeStart ] ), get_pcvar_num( pCvars [ VipFreeEnd ] ) ) )
		set_pcvar_string( pCvars [ VipFree ], "1" );
	else
		set_pcvar_string( pCvars [ VipFree ], "0" );
}

public logev_Restart( )
{
	g_iRound = 0;
}

public check_vip( id )
{
	if( is_user_vip( id ) )
	{
		vip_rs( id );
	}
	else
	{
		color_chat( id, "^3| ^4%s^3| ^1Aceasta comanda este doar pentru membrii ^4V.I.P. ^1!", Tag );
		return 1;
	}
	return 0;
}

public vip_rs(id)
{
	if(Limit [ id ] >= get_pcvar_num( pCvars[ VipMaxResets ] ) )
	{
		color_chat(id, "^3| ^4%s ^3| ^1Aceasta comanda poate fi folosita decat de ^4 3 ^1ori pe ^4harta ^1!", Tag );
		return 1;
	}
	else
	{
		cmd_rs(id);
		Limit[id]++;
	}
	return 0;
}

public cmd_rs(id)
{

	if(get_user_deaths(id) == 0)
	{
		color_chat(id, "^3| ^4%s ^3| ^1Death-urile tale sunt deja ^4 0^3!", Tag );
	}
	else 
	{
		cs_set_user_deaths(id,0);
		color_chat(id, "^3| ^4%s ^3| ^4Decesele tale ^1au fost ^4resetate^1!", Tag );
	}
	return PLUGIN_HANDLED;
}

public ShowVIPMenu( id )
{
	if(!is_user_connected(id) || !is_user_alive(id)) 
		return PLUGIN_HANDLED;
	
	if(is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		if(g_bMapBanned)
		{
			color_chat(id, "!g%s !yVIP-ul este dezactivat pe aceasta harta!g!", Tag);
			return PLUGIN_HANDLED;
		}
		else
		{
			if( g_iRound >= get_pcvar_num( pCvars[ VipMenuRounds ] ) )
			{
				if(!WeaponSelected [ id ] )
				{
					new g_iMenu = menu_create("\wVIP Menu", "handle_vip_menu_weapons" );
					new szItem[32], CsTeams:iTeam;

					iTeam = cs_get_user_team(id);
					
					for ( new i; i < sizeof VipWeapons; i++ )
					{
						switch(iTeam)
						{
							case CS_TEAM_T:
							{
								switch(VipWeapons[i][Team])
								{
									case TERO, BOTH:
									{
										num_to_str(i, szItem, charsmax(szItem));
										menu_additem( g_iMenu, VipWeapons[ i ][ WeapName ], szItem );
									}
								}
							}
							case CS_TEAM_CT:
							{
								switch(VipWeapons[i][Team])
								{
									case CT, BOTH:
									{
										num_to_str(i, szItem, charsmax(szItem));
										menu_additem( g_iMenu, VipWeapons[ i ][ WeapName ], szItem );
									}
								}
							}
						}
					}
					
					menu_setprop(g_iMenu, MPROP_EXIT, MEXIT_ALL);
					menu_display( id, g_iMenu );
				}
				else 
				{
					color_chat( id, "!g%s!y: Asteapta runda viitoare pentru a-ti alege iar armele!", Tag );
					return PLUGIN_HANDLED;
				}
			}
			else
			{
				if(!WeaponSelected [ id ] )
				{
					new g_iMenu = menu_create("\wVIP Menu", "handle_vip_menu_pistols" );
					new szItem[32], CsTeams:iTeam;

					iTeam = cs_get_user_team(id);
					
					for ( new i; i < sizeof VipPistols; i++ )
					{
						switch(iTeam)
						{
							case CS_TEAM_T:
							{
								switch(VipPistols[i][Team])
								{
									case TERO, BOTH:
									{
										num_to_str(i, szItem, charsmax(szItem));
										menu_additem( g_iMenu, VipPistols[ i ][ WeapName ], szItem );
									}
								}
							}
							case CS_TEAM_CT:
							{
								switch(VipPistols[i][Team])
								{
									case CT, BOTH:
									{
										num_to_str(i, szItem, charsmax(szItem));
										menu_additem( g_iMenu, VipPistols[ i ][ WeapName ], szItem );
									}
								}
							}
						}
					}
					
					menu_setprop(g_iMenu, MPROP_EXIT, MEXIT_ALL);
					menu_display( id, g_iMenu );
				}
				else 
				{
					color_chat( id, "!g%s!y: Asteapta runda viitoare pentru a-ti alege iar armele!", Tag );
					return PLUGIN_HANDLED;
				}
			}
		}
	}
	else 
	{
		color_chat( id, "!g%s!y: Acest meniu este doar pentru jucatorii !gVIP!y!", Tag );
		return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}

public handle_vip_menu_weapons( id, menu, item )
{
	if( item == MENU_EXIT || !is_user_alive( id ))
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}
	
	new itemdata[3];
	new data[6][32];
	new index[32];
	menu_item_getinfo(menu, item, itemdata[0], data[0], charsmax(data), data[1], charsmax(data), itemdata[1]);
	parse(data[0], index, 31);
	item = str_to_num(index);
	if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		drop_weapons( id, 1);
		drop_weapons( id, 2);
		give_item( id, "weapon_knife" );
		give_item( id, "weapon_hegrenade" );
		give_item( id, "weapon_flashbang" );
		cs_set_user_bpammo( id, CSW_FLASHBANG, 2 );
		WeaponSelected [ id ] = true;
		give_item( id, VipWeapons[ item ][ WeaponID ] );
		cs_set_user_bpammo( id, get_weaponid( VipWeapons[ item ][ WeaponID ] ), VipWeapons[ item ][ BpAmmo ] );
		give_item( id, "weapon_deagle" );
		cs_set_user_bpammo( id, CSW_DEAGLE, 35 );
	}
	return PLUGIN_HANDLED;
}

public handle_vip_menu_pistols( id, menu, item )	
{	
	if( item == MENU_EXIT || !is_user_alive( id ) || !is_user_connected(id))
	{
		menu_destroy( menu );
		return PLUGIN_HANDLED;
	}
	
	new itemdata[3];
	new data[6][32];
	new index[32];
	menu_item_getinfo(menu, item, itemdata[0], data[0], charsmax(data), data[1], charsmax(data), itemdata[1]);
	parse(data[0], index, 31);
	item = str_to_num(index);
	
	if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )	
	{	
		drop_weapons( id, 2 );	
		give_item( id, "weapon_knife" );	
		give_item( id, "weapon_hegrenade" );	
		give_item( id, "weapon_flashbang" );	
		cs_set_user_bpammo( id, CSW_FLASHBANG, 2 );	
		WeaponSelected [ id ] = true;	
		give_item( id, VipPistols[ item ][ WeaponID ] );	
		cs_set_user_bpammo( id, get_weaponid( VipPistols[ item ][ WeaponID ] ), VipPistols[ item ][ BpAmmo ] );	
	}	
	return PLUGIN_HANDLED;	
}	


public ham_PlayerSpawnPost( id )
{
	if(!is_user_alive( id ) )
		return HAM_IGNORED;
	
	if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		WeaponSelected [ id ] = false;
		
		ShowVIPMenu( id );
		
		cs_set_user_armor( id, 100, CS_ARMOR_VESTHELM );
		
		if( get_user_team( id ) == 2 )
			give_item( id, "item_thighpack" );

		cs_set_user_armor(id, get_pcvar_num(pCvars [ VipSpawnAP ]), CS_ARMOR_VESTHELM);
		set_user_health(id, get_pcvar_num(pCvars [ VipSpawnHP ]));
	}
	return PLUGIN_HANDLED;
}

public ham_PlayerKilledPost( iVictim, iAttacker )
{
	if( !iVictim || !iAttacker || !is_user_alive( iAttacker ) )
		return HAM_IGNORED;
		
	if( is_user_vip( iAttacker ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		new g_iIsHeadshot = read_data( 3 );
		new g_iHealth = get_user_health( iAttacker );
		new g_iArmor = get_user_armor( iAttacker );
		new g_iHealthAdd = get_pcvar_num( pCvars[ VipHP ] );
		new g_iHealthHSAdd = get_pcvar_num( pCvars[ VipHsHP ] );
		new g_iArmorAdd = get_pcvar_num( pCvars[ VipAP ] );
		new g_iArmorHSAdd = get_pcvar_num( pCvars[ VipHsAP ] );
		new g_iMaxHP = get_pcvar_num( pCvars[ VipMaxHP ] );
		new g_iMaxAP = get_pcvar_num( pCvars[ VipMaxAP ] );
		
		if( g_iIsHeadshot )
		{
			if( g_iHealth >= g_iMaxHP || g_iArmor >= g_iMaxAP )
			{
				set_user_health( iAttacker, g_iMaxHP );
				set_user_armor( iAttacker, g_iMaxAP );
			}
			else
			{
				set_user_health( iAttacker, g_iHealth + g_iHealthHSAdd );
				set_user_armor( iAttacker, g_iHealth + g_iArmorHSAdd );
			}
		}
		else
		{
			if( g_iHealth >= g_iMaxHP || g_iArmor >= g_iMaxAP )
			{
				set_user_health( iAttacker, g_iMaxHP );
				set_user_armor( iAttacker, g_iMaxAP );
			}
			else
			{
				set_user_health( iAttacker, g_iHealth + g_iHealthAdd );
				set_user_armor( iAttacker, g_iHealth + g_iArmorAdd );
			}
		}
	}
	return PLUGIN_HANDLED;
}

public ham_ItemDeployPost(iEnt)
{
	if(pev_valid(iEnt) != 2 || !get_pcvar_num(pCvars[ VipModels ]))
		return;

	const OFFSET_WEAPONOWNER = 41;
	const OFFSET_WEAPON = 4;
	const OFFSET_ID = 43;
	const OFFSET_DIFF = 92389;
	
	new iPlayer = get_pdata_cbase(iEnt, OFFSET_WEAPONOWNER, OFFSET_WEAPON);

	if(!pev_valid(iPlayer))
		return;

	if(!is_user_vip(iPlayer))
		return;

	new szWeaponName[38], bool:bHasWeapon, iTemp = -1;
	get_weaponname(get_pdata_int(iEnt, OFFSET_ID, OFFSET_WEAPON), szWeaponName, charsmax(szWeaponName));

	for(new i; i < sizeof(VipWeapons); i++)
	{
		if(equali(szWeaponName, VipWeapons[i][WeaponID]))
		{
			bHasWeapon = true;
			iTemp = i + OFFSET_DIFF;
			break;
		}
	}

	for(new i; i < sizeof(VipPistols); i++)
	{
		if(equali(szWeaponName, VipPistols[i][WeaponID]))
		{
			bHasWeapon = true;
			iTemp = i;
			break;
		}
	}

	if(bHasWeapon)
	{
		new bool:bSomeBool;
		if(iTemp - OFFSET_DIFF > -1)
		{
			iTemp -= OFFSET_DIFF;
			bSomeBool = true;
		}

		if(bSomeBool)
		{
			set_pev(iPlayer, pev_viewmodel2, VipWeapons[iTemp][WeaponModels]);
		}
		else 
		{
			set_pev(iPlayer, pev_viewmodel2, VipPistols[iTemp][WeaponModels]);
		}
	}
}

public client_PreThink(id)
{
	if(!is_user_alive(id)) return PLUGIN_CONTINUE;
	
	new nbut = get_user_button(id);
	new obut = get_user_oldbutton(id);
	if((nbut & IN_JUMP) && !(get_entity_flags(id) & FL_ONGROUND) && !(obut & IN_JUMP))
	{
		if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
		{
			if(jumpnum[id] < get_pcvar_num( pCvars[ VipJumps ] ))
			{
				dojump[id] = true;
				jumpnum[id]++;
				return PLUGIN_CONTINUE;
			}
		}
	}
	if((nbut & IN_JUMP) && (get_entity_flags(id) & FL_ONGROUND))
	{
		jumpnum[id] = 0;
		return PLUGIN_CONTINUE;
	}
	return PLUGIN_CONTINUE;
}

public client_PostThink(id)
{
	if(!is_user_alive(id)) return PLUGIN_CONTINUE;
	if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		if(dojump[id] == true)
		{
			new Float:velocity[3]	;
			entity_get_vector(id,EV_VEC_velocity,velocity);
			velocity[2] = random_float(265.0,285.0);
			entity_set_vector(id,EV_VEC_velocity,velocity);
			dojump[id] = false;
			return PLUGIN_CONTINUE;
		}
	}
	return PLUGIN_CONTINUE;
}

#if defined VIP_CHAT
public hook_say( id )
{
	if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		new szName[ 32 ], szMessage[ 192 ], szPrefix[ 32 ];
		get_user_name( id, szName, charsmax( szName ) );
		get_pcvar_string( pCvars[ VipChatPrefix ], szPrefix, charsmax( szPrefix ) );
		
		read_args( szMessage, charsmax( szMessage ) );
		remove_quotes( szMessage );
		
		if( is_user_alive( id ) )
			color_chat( 0, "!g%s!team %s!y: %s", szPrefix, szName, szMessage );
			
		else if(!is_user_alive( id ) )
			color_chat( 0, "!y*DEAD* !g%s!team %s!y: %s", szPrefix, szName, szMessage );
	}
	else 
	{
		new szName[ 32 ], szMessage[ 192 ];
		get_user_name( id, szName, charsmax( szName ) );

		read_args( szMessage, charsmax( szMessage ) );
		remove_quotes( szMessage );
		
		if( is_user_alive( id ) )
			color_chat( 0, "!team %s!y: %s", szName, szMessage );
			
		else if(!is_user_alive( id ) )
			color_chat( 0, "!y*DEAD* %s!team %s!y: %s", szName, szMessage );
	}
	return PLUGIN_HANDLED;
}

/*public hook_sayteam( id )
{
	if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		new szName[ 32 ], szMessage[ 192 ], szPrefix[ 32 ];
		get_user_name( id, szName, charsmax( szName ) );
		get_pcvar_string( pCvars[ VipChatPrefix ], szPrefix, charsmax( szPrefix ) );
		
		read_args( szMessage, charsmax( szMessage ) );
		remove_quotes( szMessage );

		if(get_user_team( id ) == 1 )
		{
			if( is_user_alive( id ) )
				color_chat( 0, "!y(Terrorist) !g%s!team %s!y: %s", szPrefix, szName, szMessage );
				
			else if( !is_user_alive( id ) )
				color_chat( 0, "!y*DEAD* (Terrorist) !g%s!team %s!y: %s", szPrefix, szName, szMessage );
		}
		if(get_user_team( id ) == 2 )
		{
			if( is_user_alive( id ) )
				color_chat( 0, "!y(Counter-Terrorist) !g%s!team %s!y: %s", szPrefix, szName, szMessage );
				
			else if( !is_user_alive( id ) )
				color_chat( 0, "!y*DEAD* (Counter-Terrorist) !g%s!team %s!y: %s", szPrefix, szName, szMessage );
		}
	}
	else
	{
		new szName[ 32 ], szMessage[ 192 ];
		get_user_name( id, szName, charsmax( szName ) );
		
		read_args( szMessage, charsmax( szMessage ) );
		remove_quotes( szMessage );
		if(get_user_team( id ) == 1 )
		{
			if( is_user_alive( id ) )
				color_chat( 0, "!y(Terrorist)!team %s!y: %s", szName, szMessage );
				
			else if( !is_user_alive( id ) )
				color_chat( 0, "!y*DEAD* (Terrorist)!team %s!y: %s", szName, szMessage );
		}
		if(get_user_team( id ) == 2 )
		{
			if( is_user_alive( id ) )
				color_chat( 0, "!y(Counter-Terrorist)!team %s!y: %s", szName, szMessage );
				
			else if( !is_user_alive( id ) )
				color_chat( 0, "!y*DEAD* (Counter-Terrorist)!team %s!y: %s", szName, szMessage );
		}
	}
	
	return PLUGIN_HANDLED;
}*/
#endif

public ShowVIPMotd(id)
{
	if( !is_user_connected( id ) )
		return PLUGIN_HANDLED;

	new szString[ 64 ], Temp[ 64 ], Tag[32];
	get_pcvar_string( pCvars[ VipPrices ], szString, charsmax( szString ) );
	get_pcvar_string( pCvars[ VipPrefix ], Tag, charsmax( Tag ) );
	
	formatex( Temp, charsmax( Temp ), "addons/amxmodx/configs/%s", szString );
	
	show_motd( id, Temp, "Avantajele VIP-ului" );
	color_chat(0, "!g%s !yCiteste despre avantajele !gVIP!y-ului!y!");
	return PLUGIN_HANDLED;
}

public OnScoreAttrib( iMsgId, iMsgDest, iMsgEnt )
{
	new id = get_msg_arg_int(1);

	if(!is_user_connected(id))
		return;

	if( is_user_vip(id) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		set_msg_arg_int( 2, ARG_BYTE, is_user_alive(id) ? ( 1<<2 ) : ( 1 << 0) );
	}
}

public ShowVIPs( id )
{
	if(is_user_connected( id ) )
		return PLUGIN_HANDLED;
		
	new vip_name[33];
	new message[190];
	new contor, len;

	if( is_user_vip( id ) )
	{
		get_user_name( id, vip_name[ contor++ ], charsmax( vip_name ) );
	}

	len = format( message, charsmax( message ), "!g%s !yVIP's Online!team: ");
	if( contor > 0 ) 
	{
		for( new i = 0 ; i < contor ; i++)
		{
			len += format( message[ len ], charsmax( message ) - len, "!y%s%s ", vip_name[ i ], i < ( contor - 1 ) ? ", " : "");
			if(len > 96 )
			{
				color_chat( id, message );
				len = format( message, charsmax( message ), "%s ");
			}
		}
		color_chat( id, message);
	}
	else 
	{
		len += format( message[ len ], charsmax( message ) - len, "No VIP online.");
		color_chat( id, message );
	}
	return PLUGIN_CONTINUE;
}

bool:IsVipHour( iStart, iEnd ) //Credits OciXCrom
{
    new iHour; time( iHour );
    return bool:( iStart < iEnd ? ( iStart <= iHour < iEnd ) : ( iStart <= iHour || iHour < iEnd ) );
} 

stock drop_weapons(id, dropwhat)
{
    // Get user weapons
    new weapons[32], num_weapons, index, weaponid;
    get_user_weapons(id, weapons, num_weapons);
    
    // Loop through them and drop primaries or secondaries
    for (index = 0; index < num_weapons; index++)
    {
        // Prevent re-indexing the array
        weaponid = weapons[index];
        
        if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) 
        || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM))
        || (dropwhat == 3) && (((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM) || ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
        {
            // Get weapon entity
            new wname[32];
            get_weaponname(weaponid, wname, charsmax(wname));
            
            // Player drops the weapon
            engclient_cmd(id, "drop", wname);
        }
    }
} 

// Stock: ChatColor!
stock color_chat(const id, const input[], any:...)
{
	new count = 1, players[32];
	static msg[191];
	vformat(msg, 190, input, 3);
    
	replace_all(msg, 190, "!g", "^4"); // Green Color
	replace_all(msg, 190, "!y", "^1"); // Default Color
	replace_all(msg, 190, "!team", "^3"); // Team Color
	replace_all(msg, 190, "!team2", "^0"); // Team2 Color
        
	if (id) players[0] = id; else get_players(players, count, "ch");
	{
		for (new i = 0; i < count; i++)
		{
			if (is_user_connected(players[i]))
			{
				message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i]);
				write_byte(players[i]);
				write_string(msg);
				message_end();
			}
		}
	}
}
