/************************* CREDITS *************************

- OciXCrom ( For VIP Hour stock )
- Yontu ( For map parsing in file code )

************************* CREDITS *************************/

#include < amxmodx >
#include < amxmisc >
#include < cstrike >
#include < engine >
#include < fun >
#include < hamsandwich >

#pragma semicolon 1

#define PLUGIN "VIP Clasic"
#define VERSION "1.5"
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
#if defined VIP_CHAT
	VipChatPrefix,
#endif
	VipJumps,
	VipPrices,
	VipMenuRounds,
	VipFree,
	g_type,
	g_recieved

};

enum _:Weapons {
	WeapName[64],
	WeaponID[32],
	BpAmmo
};

new const VipWeapons[][Weapons] = {
	{ "AK47 \d+ \wDeagle \d+ \wGrenade Set", "weapon_ak47", 90 },
	{ "M4A1 \d+ \wDeagle \d+ \wGrenade Set","weapon_m4a1", 90 },
	{ "AWP \d+ \wDeagle \d+ \wGrenade Set", "weapon_awp", 30 }
};

new const VipPistols[][Weapons] = {
	{ "\wDeagle \d+ \wGrenade Set", "weapon_deagle", 35 },
	{ "\wUSP \d+ \wGrenade Set","weapon_usp", 100 },
	{ "\wGlock-18 \d+ \wGrenade Set", "weapon_glock18", 120 }
};

new pCvars[CvarsSettings];
new g_iRound;
new jumpnum[ 33 ] = 0;
new g_bMapBanned;
new g_iHudMessages[2];

/********************** BOOLEANS **********************/
new bool:WeaponSelected[33];
new bool:dojump[ 33 ] = false;
/********************** END OF BOOLEANS **********************/

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90);
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE);

public plugin_init( )
{
	register_plugin( PLUGIN, VERSION, AUTHOR);
	
	register_clcmd( "say /vm", "ShowVIPMenu" );
	register_clcmd( "say /vmenu", "ShowVIPMenu" );
	register_clcmd( "say /vip", "ShowVIPMotd" );
	register_clcmd( "say /vips", "ShowVIPs" );
	register_clcmd( "say_team /vm", "ShowVIPMenu" );
	register_clcmd( "say_team /vmenu", "ShowVIPMenu" );
	register_clcmd( "say_team /vips", "ShowVIPs" );
	
	register_cvar( "lgcs_vip_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED );
	pCvars [ VipHP ] = register_cvar( "vip_kill_hp", "10" );
	pCvars [ VipAP ] = register_cvar( "vip_kill_ap", "10" );
	pCvars [ VipHsHP ] = register_cvar( "vip_killhs_hp", "15" );
	pCvars [ VipHsAP ] = register_cvar( "vip_killhs_ap", "15" );
	pCvars [ VipMaxHP ] = register_cvar( "vip_max_hp", "110" );
	pCvars [ VipMaxAP ] = register_cvar( "vip_max_ap", "110" );
	pCvars [ VipPrefix ] = register_cvar( "vip_msg_prefix", "[VIP]" );
	
	#if defined VIP_CHAT
	register_clcmd( "say ", "hook_say" );
	register_clcmd( "say_team ", "hook_sayteam" );
	pCvars [ VipChatPrefix ] = register_cvar( "vip_chat_prefix", "[VIP]" );
	#endif
	
	pCvars [ VipJumps ] = register_cvar( "vip_multi_jumps", "1" );
	pCvars [ VipPrices ] = register_cvar( "vip_prices_motd", "vip_info.html" );
	pCvars [ VipMenuRounds ] = register_cvar( "vip_rounds_showmenu", "3" );
	pCvars [ VipFree ] = register_cvar( "vip_free_on", "1" );
	pCvars [ g_type ] = register_cvar("amx_bulletdamage","1");
	pCvars [ g_recieved ] = register_cvar("amx_bulletdamage_recieved","1");    

	RegisterHam( Ham_Spawn, "player", "ham_PlayerSpawnPost", 1);
	RegisterHam( Ham_Killed, "player", "ham_PlayerKilled", 1);
	register_event( "HLTV", "ev_NewRound", "a", "1=0", "2=0" );
	register_event("Damage", "on_damage", "b", "2!0", "3=0", "4!0");   
	register_logevent( "logev_Restart", 2, "1&Restart_Round", "1&Game_Commencing" );
	register_message(get_user_msgid("ScoreAttrib"), "OnScoreAttrib");
	
	for(new i; i < sizeof( g_iHudMessages ); i++)
	{
		g_iHudMessages[i] = CreateHudSyncObj();
	}

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

public client_putinserver( id )
{
	new Tag[32], szName[32];
	get_pcvar_string( pCvars[ VipPrefix ], Tag, charsmax( Tag ) );
	get_user_name( id, szName, charsmax( szName ) );
	color_chat(0, "!g%s !yVIP-ul !g%s !ytocmai s-a conectat pe server!", Tag, szName);
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
}

public logev_Restart( )
{
	g_iRound = 0;
}

public ShowVIPMenu( id )
{
	if(!is_user_connected(id) || !is_user_alive(id)) 
		return PLUGIN_HANDLED;

	new Tag[32];
	get_pcvar_string( pCvars[ VipPrefix ], Tag, charsmax( Tag ) );
	
	if(is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		if(g_bMapBanned)
		{
			color_chat(id, "!g%s !yVIP-ul este dezactivat pe harti awp_!g!", Tag);
			return PLUGIN_HANDLED;
		}
		else
		{
			if( g_iRound >= get_pcvar_num( pCvars[ VipMenuRounds ] ) )
			{
				if(!WeaponSelected [ id ] )
				{
					new g_iMenu = menu_create("\wVIP Menu", "handle_vip_menu_weapons" );
					
					for ( new i; i < sizeof VipWeapons; i++ )
						menu_additem( g_iMenu, VipWeapons[ i ][ WeapName ] );
					
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
					
					for ( new i; i < sizeof VipPistols; i++ )
						menu_additem( g_iMenu, VipPistols[ i ][ WeapName ] );
						
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
	if( item == MENU_EXIT || !is_user_alive( id ) || !is_user_connected(id))
		menu_destroy( menu );
		
	if(!is_user_alive(id) || !is_user_connected(id))
		return PLUGIN_HANDLED;
		
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
		menu_destroy( menu );
		
	if(!is_user_alive(id) || !is_user_connected(id))
		return PLUGIN_HANDLED;
		
	if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		drop_weapons( id, 2);
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
		
		cs_set_user_armor( id, 100, CsArmorType:2 );
		
		if( get_user_team( id ) == 2 )
			give_item( id, "item_thighpack" );
	}
	return PLUGIN_HANDLED;
}

public ham_PlayerKilled( iVictim, iAttacker )
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

public on_damage( id ) 
{
	if( get_pcvar_num( g_type ) ) 
	{     
		static attacker; attacker = get_user_attacker( id );
		static damage; damage = read_data( 2 );                  
			set_hudmessage( 255, 0, 0, 0.45, 0.50, 2, 0.1, 4.0, 0.1, 0.1, -1 );
			ShowSyncHudMsg(id, g_iHudMessages[ 1 ], "%i^n", damage);         

		if( is_user_connected( attacker ) && is_user_vip( attacker ) == 1)
		{ 
			set_hudmessage( 0, 100, 200, -1.0, 0.55, 2, 0.1, 4.0, 0.02, 0.02, -1 ); 
			ShowSyncHudMsg( attacker, g_iHudMessages[ 0 ], "%i^n", damage );               
		} 
	} 
}

public client_PreThink( id )
{
	if( !is_user_alive( id ) ) return PLUGIN_CONTINUE;
	
	new nbut = get_user_button( id );
	new obut = get_user_oldbutton( id );
	if( ( nbut & IN_JUMP ) && !( get_entity_flags( id ) & FL_ONGROUND ) && !( obut & IN_JUMP ) )
	{
		if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
		{
			if(jumpnum[ id ] < get_pcvar_num( pCvars[ VipJumps ] ))
			{
				dojump[ id ] = true;
				jumpnum[ id ]++;
				return PLUGIN_CONTINUE;
			}
		}
	}
	if( ( nbut & IN_JUMP ) && ( get_entity_flags( id ) & FL_ONGROUND ) )
	{
		jumpnum[ id ] = 0;
		return PLUGIN_CONTINUE;
	}
	return PLUGIN_CONTINUE;
}

public client_PostThink( id )
{
	if( !is_user_alive( id ) ) return PLUGIN_CONTINUE;
	if( is_user_vip( id ) || get_pcvar_num( pCvars[ VipFree ] ) )
	{
		if(dojump[ id ] == true)
		{
			new Float:velocity[ 3 ]	;
			entity_get_vector( id, EV_VEC_velocity, velocity );
			velocity[ 2 ] = random_float( 265.0,285.0 );
			entity_set_vector( id, EV_VEC_velocity, velocity );
			dojump[ id ] = false;
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
		{
			color_chat( 0, "!g%s!team %s!y: %s", szPrefix, szName, szMessage );
		}
		
		else
		{	
			color_chat( 0, "!y*DEAD* !g%s!team %s!y: %s", szPrefix, szName, szMessage );
		}
	}
	else 
	{
		new szName[ 32 ], szMessage[ 192 ];
		get_user_name( id, szName, charsmax( szName ) );

		read_args( szMessage, charsmax( szMessage ) );
		remove_quotes( szMessage );
		
		if( is_user_alive( id ) )
		{
			color_chat( 0, "!team %s!y: %s", szName, szMessage );
		}
			
		else
		{
			color_chat( 0, "!y*DEAD* %s!team %s!y: %s", szName, szMessage );
		}
	}
	return PLUGIN_HANDLED;
}

public hook_sayteam( id )
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
			{
				color_chat( 0, "!y(Terrorist) !g%s!team %s!y: %s", szPrefix, szName, szMessage );
			}
				
			else 
			{
				color_chat( 0, "!y*DEAD* (Terrorist) !g%s!team %s!y: %s", szPrefix, szName, szMessage );
			}
		}
		if(get_user_team( id ) == 2 )
		{
			if( is_user_alive( id ) )
			{
				color_chat( 0, "!y(Counter-Terrorist) !g%s!team %s!y: %s", szPrefix, szName, szMessage );
			}
				
			else
			{
				color_chat( 0, "!y*DEAD* (Counter-Terrorist) !g%s!team %s!y: %s", szPrefix, szName, szMessage );
			}
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
			{
				color_chat( 0, "!y(Terrorist)!team %s!y: %s", szName, szMessage );
			}
				
			else 
			{
				color_chat( 0, "!y*DEAD* (Terrorist)!team %s!y: %s", szName, szMessage );
			}
		}
		if(get_user_team( id ) == 2 )
		{
			if( is_user_alive( id ) )
			{
				color_chat( 0, "!y(Counter-Terrorist)!team %s!y: %s", szName, szMessage );
			}
				
			else
			{
				color_chat( 0, "!y*DEAD* (Counter-Terrorist)!team %s!y: %s", szName, szMessage );
			}
		}
	}
	
	return PLUGIN_HANDLED;
}
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
	if( is_user_vip( get_msg_arg_int( 1 ) ) )
		set_msg_arg_int( 2, ARG_BYTE, ( 1<<2 ) );
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
		color_chat( id, message);
	}
	return PLUGIN_CONTINUE;
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