
/********************************************
* 
* DamageSound Version "1.6"
* 
* With this plugin a player hears a sound if he damaged another player.
* 
* WARNING: IF YOU UPDATE THIS PLUGIN DELETE THE CONFIG FILE FIRST.
* THE CONFIG FILE IS LOCATED IN cfg/sourcemod/damagesound.cfg
* 
* Install:
* 1. Put the damagesound.smx into your plugins folder.
*
* 2. Within cfg/sourcemod/ is the damagesound.cfg you can change
* the following:
* 
* Menu/Client Commands:
* 
*   sm_damagesound or sm_hitsound
*   -> opens the ingame client side menu.
* 
* Server Side Settings:
* 
* - sm_damagesound_enable default is: 1
*   -> Master Switch to enable or disable this plugin. (0=off/1=on)
* 
* - sm_damagesound_path default is: "buttons/button10.wav"
*   -> the path to the sound file.
* 
* - sm_damagesound_afterplaydelay default is: 0.1
*   -> How many secounds should the plugin wait to play the sound again.
*      (This is for fast weapons like in TF2 the Pyros Flamethrower)
* 
* Default Settings for Clients (still server side):
* 
* - sm_damagesound_client_enable default is: 1
*   -> Should the client have had DamageSound enabled by default? (1=yes/0=no)
* 
* - sm_damagesound_client_pitch default is: 0
*   -> Should the sound for the client pitch up with every hit by default? 
*     (1=yes/0=no) Like in Dystopia.
* 
* - sm_damagesound_client_pitch_time: default is: 2.0
*   -> After 2.0 seconds the pitch is at normal level again,
*      0.0 means it never resets until the victim dies
* 
* - sm_damagesound_client_volume: default is: 1.0
*   -> From 0.0 to 1.0 you can set the clients default volume of the sound.
* 
* 
* 
* Changelog:
*
* v1.6     - Add sm_damagesound_actonweapon to specify what weapons to play sound for - [foo] bar
*          - Hook fake clients (for bots) - [foo] bar
*            
* v1.5     - Changed Version number from 3 digits to 2
*          - Added support for bots
*          - Added support that spectators can hear sound when the observed player damage someone.
*          - Using now smlib functions
*          - Renamed the config file from damagesound.cfg into plugin.damagesound.cfg
* 
* v1.4.50  - Fixed some critical crash bugs.
* 
* v1.4.26  - Added /hitsound and /damagesound to give clients a menu
*            where they can change the settings of damagesound.
*          - Fixed console errors when the hitcouoter gets over 255
*          - Changed Cvar Names
* 
* v1.3.23  - Added cvar sm_damagesound_volume
*          - Added cvar sm_damagesound_pitch
*          - Added cvar sm_damagesound_pitch_time
* 
* v1.1.4   - Added Cvar for damage sound path (sm_damagesound_path)
* 
* v1.0.0   - First Public Release
* 
* 
* Thank you Berni, Manni, Mannis FUN House Community and SourceMod/AlliedModders-Team
* 
* 
* *************************************************/

/****************************************************************
P R E C O M P I L E R   D E F I N I T I O N S
*****************************************************************/

// enforce semicolons after each code statement
#pragma semicolon 1


/****************************************************************
I N C L U D E S
*****************************************************************/

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <clientprefs>

/****************************************************************
P L U G I N   C O N S T A N T S
*****************************************************************/

#define PLUGIN_VERSION	"1.6"
#define PLUGIN_NAME "Damage Sound"
#define MIN 0.0
#define MAX 1.0
#define MAXMENUENTRYS 10
#define MAXPITCH 255

const NUM_WEAPONS = 8;

//Cvars:
new Handle:damagesound_version 					= INVALID_HANDLE;
new Handle:cvar_soundmaster_enable 				= INVALID_HANDLE;
new Handle:cvar_soundpath 						= INVALID_HANDLE;
new Handle:cvar_soundafterplaydelay 			= INVALID_HANDLE;
new Handle:cvar_actonweapons = INVALID_HANDLE;
//Plugin stuff:
new String:soundpath[PLATFORM_MAX_PATH];
new hitCounter[MAXPLAYERS+1][MAXPLAYERS+1];
new Float:lastHit[MAXPLAYERS+1][MAXPLAYERS+1];


new String:actonWeapons[NUM_WEAPONS][32];

//cookie and settings:
new Handle:cvar_client_enable		= INVALID_HANDLE;
new Handle:cvar_client_volume		= INVALID_HANDLE;
new Handle:cvar_client_pitch		= INVALID_HANDLE;
new Handle:cvar_client_pitch_time	= INVALID_HANDLE;

new bool:client_enable[MAXPLAYERS+1];
new Float:client_volume[MAXPLAYERS+1];
new bool:client_pitch[MAXPLAYERS+1];
new Float:client_pitch_time[MAXPLAYERS+1];

new Handle:cookie_enable						= INVALID_HANDLE;
new Handle:cookie_volume						= INVALID_HANDLE;
new Handle:cookie_pitch							= INVALID_HANDLE;
new Handle:cookie_pitch_time					= INVALID_HANDLE;


public Plugin:myinfo = 
{
	name = PLUGIN_NAME,
	author = "Chanz",
	description = "This plugin plays a sound when players hit each other.",
	version = PLUGIN_VERSION,
	url = "www.mannisfunhouse.eu"
}

public OnPluginStart()
{
	//New Comamnds:
	RegConsoleCmd("sm_damagesound",Comamnd_DamageSoundMenu,"Shows the damagesound menu");
	RegConsoleCmd("sm_hitsound",Comamnd_DamageSoundMenu,"Shows the damagesound menu");
	
	damagesound_version = CreateConVar("sm_damagesound_version", PLUGIN_VERSION, "PLUGIN_NAME Version", FCVAR_PLUGIN|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	//cvars:
	cvar_soundmaster_enable = CreateConVar("sm_damagesound_enable", "1", "Master Switch to enable or disable this plugin. (0=off/1=on)", FCVAR_PLUGIN);
	cvar_soundpath = CreateConVar("sm_damagesound_path", "buttons/button10.wav", "Path to damage sound file", FCVAR_PLUGIN);
	cvar_soundafterplaydelay = CreateConVar("sm_damagesound_afterplaydelay", "0.1", "How many secounds should the plugin wait to play the sound again.(in seconds)", FCVAR_PLUGIN);
	
	//client defaults:
	cvar_client_enable = CreateConVar("sm_damagesound_client_enable", "1", "Should the client have had DamageSound enabled by default? (1=yes/0=no)", FCVAR_PLUGIN);
	cvar_client_volume = CreateConVar("sm_damagesound_client_volume", "0.7", "From 0.0 to 1.0 you can set the clients default volume of the sound.", FCVAR_PLUGIN);
	cvar_client_pitch = CreateConVar("sm_damagesound_client_pitch", "0", "Should the sound for the client pitch up with every hit by default? (1=on/0=off) (Dystopia Effect)", FCVAR_PLUGIN);
	cvar_client_pitch_time = CreateConVar("sm_damagesound_client_pitch_time", "2.0", "Sets the client default setting: If the attacker did not hit his victim, after X seconds the pitch resets to normal (0=it pitches up until the victim dies)", FCVAR_PLUGIN);
	cvar_actonweapons = CreateConVar("sm_damagesound_actonweapon","","Specifies which weapons damagesounds will play for.  Default is all");
	
	HookConVarChange(cvar_soundpath,CvarSoundPathHook);
	HookEvent("player_hurt", Event_Hurt);
	HookEvent("player_death", Event_Death);

	AutoExecConfig(true, "plugin.damagesound");
	
	cookie_enable = RegClientCookie("DmgSndConf-Enable","DamageSound Enable cookie",CookieAccess_Private);
	cookie_volume = RegClientCookie("DmgSndConf-Volume","DamageSound Volume cookie",CookieAccess_Private);
	cookie_pitch = RegClientCookie("DmgSndConf-Pitch","DamageSound PitchEnable cookie",CookieAccess_Private);
	cookie_pitch_time = RegClientCookie("DmgSndConf-PitchTime","DamageSound PitchTime cookie",CookieAccess_Private);
	
	RegConsoleCmd("sm_soundtest",Command_SoundTest,"damagesound test soound");
	
	decl String:temp[200];
	GetConVarString(cvar_actonweapons,temp,sizeof(temp));
	if(!StrEqual(temp,"")){
		ExplodeString(temp," ",actonWeapons,sizeof(actonWeapons),32);
	}

	PrintToServer("[%s] Plugin loaded... (v%s)",PLUGIN_NAME,PLUGIN_VERSION);
}

public OnConfigsExecuted(){
	
	SetConVarString(damagesound_version, PLUGIN_VERSION);
	
	decl String:tempsoundpath[PLATFORM_MAX_PATH];
	
	GetConVarString(cvar_soundpath,tempsoundpath,sizeof(tempsoundpath));
	
	if(IsSoundFileOk(tempsoundpath)){
	
		strcopy(soundpath,sizeof(soundpath),tempsoundpath);
	}
}

stock bool:IsSoundFileOk(const String:tempsoundpath[]){
	
	decl String:soundpathMainDir[PLATFORM_MAX_PATH];
	Format(soundpathMainDir,sizeof(soundpathMainDir),"sound/%s",tempsoundpath);
	
	new bool:foundfile = true;
	
	if(StrEqual(soundpathMainDir,"",false) || StrEqual(soundpathMainDir,"/",false)){
		
		PrintToChatAll("[%s] Sound File: '%s' is invalid.",PLUGIN_NAME,tempsoundpath);
		LogError("[%s] Sound File: '%s' is invalid.",PLUGIN_NAME,tempsoundpath);
		foundfile = false;
	}
	
	if(!FileExists(soundpathMainDir,true) && !FileExists(soundpathMainDir,false)){
		
		PrintToChatAll("[%s] Sound File: '%s' does not exist.",PLUGIN_NAME,tempsoundpath);
		LogError("[%s] Sound File: '%s' does not exist.",PLUGIN_NAME,tempsoundpath);
		foundfile = false;
	}	
	
	return foundfile;
}

bool:IsWeaponSoundable(String:weapon[])
{
	new i=0;
	if(StrEqual(actonWeapons[0],"")){
		return true;
	}
	for(i=0;i<sizeof(actonWeapons);i++){
//		PrintToServer("'%s' = '%s'", actonWeapons[i], weapon);
		if(StrEqual(actonWeapons[i],weapon)){
			return true;
		}
	}
	return false;
}

public CvarSoundPathHook(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	if(IsSoundFileOk(newVal)){
		
		PrintToChatAll("[%s] Found Sound File: '%s'",PLUGIN_NAME,newVal);
		
		strcopy(soundpath,sizeof(soundpath),newVal);
		
		
		decl String:soundpathMainDir[PLATFORM_MAX_PATH];
		Format(soundpathMainDir,sizeof(soundpathMainDir),"sound/%s",soundpath);
		
		PrintToChatAll("[%s] Found Sound File: '%s'",PLUGIN_NAME,soundpath);
		PrintToChatAll("[%s] Found Sound File: '%s'",PLUGIN_NAME,soundpathMainDir);
		
		File_AddToDownloadsTable(soundpathMainDir);
		
		PrecacheSound(soundpath);
	}
}

public OnMapStart(){
	
	GetConVarString(cvar_soundpath,soundpath,sizeof(soundpath));
	
	decl String:soundpathMainDir[PLATFORM_MAX_PATH];
	Format(soundpathMainDir,sizeof(soundpathMainDir),"sound/%s",soundpath);
	File_AddToDownloadsTable(soundpathMainDir);
	
	PrecacheSound(soundpath);
}

public OnClientConnected(client){
	
	new Float:thetime = GetGameTime();
	
	for (new attacker=1; attacker<=MaxClients; attacker++) {
		
		hitCounter[client][attacker] = 0;
		lastHit[client][attacker] = thetime;
	}
}

public OnClientPutInServer(client){
	
	if(IsClientConnected(client) && !IsClientSourceTV(client)){		//!IsFakeClient(client)){	
		
		if(AreClientCookiesCached(client)){
			
			loadClientCookiesFor(client);
		} 
		else{
			
			client_enable[client] 		= GetConVarBool(cvar_client_enable);
			client_volume[client] 		= GetConVarFloat(cvar_client_volume);
			client_pitch[client] 		= GetConVarBool(cvar_client_pitch);
			client_pitch_time[client] 	= GetConVarFloat(cvar_client_pitch_time);
		}
	}
}

public OnClientCookiesCached(client){
	
	if(IsClientInGame(client) && !IsClientSourceTV(client)){		//IsFakeClient(client)){
		
		loadClientCookiesFor(client);	
	}
}


loadClientCookiesFor(client){	
	
	client_enable[client] = loadCookieOrDefBool(client,cookie_enable,cvar_client_enable);
	client_volume[client] = loadCookieOrDefFloat(client,cookie_volume,cvar_client_volume);
	client_pitch[client] = loadCookieOrDefBool(client,cookie_pitch,cvar_client_pitch);
	client_pitch_time[client] = loadCookieOrDefFloat(client,cookie_pitch_time,cvar_client_pitch_time);
}

bool:loadCookieOrDefBool(client,Handle:cookie,Handle:defaultCvar){
	
	
	new String:buffer[64];
	
	GetClientCookie(client, cookie, buffer, sizeof(buffer));
	
	if(!StrEqual(buffer, "")){
		
		return bool:StringToInt(buffer);
	}
	else {
		
		return GetConVarBool(defaultCvar);
	}
}

Float:loadCookieOrDefFloat(client,Handle:cookie,Handle:defaultCvar){
	
	
	new String:buffer[64];
	
	GetClientCookie(client, cookie, buffer, sizeof(buffer));
	
	if(!StrEqual(buffer, "")){
		
		return StringToFloat(buffer);
	}
	else {
		
		return GetConVarFloat(defaultCvar);
	}
}

public Action:Event_Death(Handle:event, const String:name[], bool:dontBroadcast){
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	hitCounter[client][attacker] = 0;
}

public Action:Event_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{	
	decl String:weapon[32];	
	
	if(!GetConVarBool(cvar_soundmaster_enable)){
		return;
	}


	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!client_enable[client]){
		return;
	}

	GetClientWeapon(attacker,weapon,sizeof(weapon));
//	PrintToServer("damagesound: attacker=%d weapon=%s", attacker, weapon);	
	
	if(Client_IsValid(client) && Client_IsValid(attacker) && (client != attacker)){
		
		if(!IsWeaponSoundable(weapon)){
//			PrintToServer("damagesound: No make damage sound for %s",weapon);
			return;
		} else {
//			PrintToServer("damagesound: Make damage sound for %s",weapon);
		}

		new Float:thetime = GetGameTime();
		new Float:resettime = client_pitch_time[client];
		
		if(resettime > 0.0){
			
			if((thetime - resettime) >= lastHit[client][attacker]){
				
				hitCounter[client][attacker] = 0;
			}
		}
		
		new Float:afterplaydelay = GetConVarFloat(cvar_soundafterplaydelay);
		new bool:nosound = false;
		
		if(afterplaydelay > 0.0){
			
			if((thetime - afterplaydelay) <= lastHit[client][attacker]){
				
				nosound = true;
			}
		}
		
		lastHit[client][attacker] = thetime;
		
		if(!nosound){
			
			EmitSoundToClient(attacker, soundpath,SOUND_FROM_PLAYER,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,client_volume[client],(SNDPITCH_NORMAL+hitCounter[client][attacker]));
			EmitSoundToClient(attacker, soundpath,SOUND_FROM_PLAYER,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,client_volume[client],(SNDPITCH_NORMAL+hitCounter[client][attacker]));
		}
		
		if(client_pitch[client] && ((SNDPITCH_NORMAL+hitCounter[client][attacker]) < MAXPITCH)){
			hitCounter[client][attacker]++;
		}
	}
}

public Action:Comamnd_DamageSoundMenu(client,args){
	
	ShowDamageSoundMenu(client);
}

BoolToString(String:str[],maxlen,bool:value){
	
	if(value){
		strcopy(str,maxlen,"On");
	}
	else {
		strcopy(str,maxlen,"Off");
	}
}

ShowDamageSoundMenu(client){
	
	new Handle:menu = CreateMenu(HandleDamageSoundMenu);
	
	SetMenuTitle(menu, "Damage Sound Menu\n\nThe Menu shows the\ncurrent settings");
	
	new String:value[14];
	new String:buffer[32];
	
	//Enable:
	BoolToString(value,sizeof(value),client_enable[client]);
	Format(buffer,sizeof(buffer),"DamageSound is %s",value);
	AddMenuItem(menu,"DS-Enable",buffer);
	
	//Volume:
	Format(buffer,sizeof(buffer),"Volume: %f",client_volume[client]);
	AddMenuItem(menu,"DS-Volume",buffer);
	
	//Pitch:
	BoolToString(value,sizeof(value),client_pitch[client]);
	Format(buffer,sizeof(buffer),"Pitch is %s",value);
	AddMenuItem(menu,"DS-Pitch",buffer);
	
	//PitchTime:
	Format(buffer,sizeof(buffer),"PitchResetTime: %f",client_pitch_time[client]);
	AddMenuItem(menu,"DS-PitchTime",buffer);
	
	DisplayMenu(menu, client, 90);	
}

public HandleDamageSoundMenu(Handle:menu, MenuAction:action, client, param) {
	
	if (action == MenuAction_Select) {
		decl String:info[32];
		GetMenuItem(menu, param, info, sizeof(info));
		
		if(StrEqual(info,"DS-Enable",false)){
			
			client_enable[client] = !client_enable[client];
			ShowDamageSoundMenu(client);
		}
		else if(StrEqual(info,"DS-Volume",false)){
			
			ShowSettingFloatMenu(client,info,MIN,MAX,MAXMENUENTRYS);
		}
		else if(StrEqual(info,"DS-Pitch",false)){
			
			client_pitch[client] = !client_pitch[client];
			ShowDamageSoundMenu(client);
		}
		else if(StrEqual(info,"DS-PitchTime",false)){
			
			ShowSettingFloatMenu(client,info,MIN,MAX,MAXMENUENTRYS);
		}
	}
	else if (action == MenuAction_End) {
		
		CloseHandle(menu);
	}
}

ShowSettingFloatMenu(client,String:settingsName[],Float:rangeMin,Float:rangeMax,maxMenuEntrys){
	
	new Handle:menu = CreateMenu(HandleSettingFloatMenu);
	SetMenuTitle(menu, "Damage Sound Menu");
	
	new String:buffer[20];
	
	for(new i=0;i<=maxMenuEntrys;i++){
		
		FloatToString(rangeMin+(((rangeMax-rangeMin)/maxMenuEntrys)*i),buffer,sizeof(buffer));
		AddMenuItem(menu,settingsName,buffer);
	}
	
	DisplayMenu(menu, client, 90);
}

public HandleSettingFloatMenu(Handle:menu, MenuAction:action, client, param) {
	
	if (action == MenuAction_Select) {
		
		decl String:info[11], String:display[20];
		new style;
		
		GetMenuItem(menu, param, info, sizeof(info), style, display, sizeof(display));
		
		if(StrEqual(info,"DS-Volume",false)){
			
			client_volume[client] = StringToFloat(display);
			SetClientCookie(client,cookie_volume,display);
		}
		else if(StrEqual(info,"DS-PitchTime",false)){
			
			client_pitch_time[client] = StringToFloat(display);
			SetClientCookie(client,cookie_pitch_time,display);
		}
		
		ShowDamageSoundMenu(client);
	}
	else if (action == MenuAction_End) {
		
		CloseHandle(menu);
	}
}

public Action:Command_SoundTest(client,args){
	
	new Float:volume = client_volume[client];
	new attacker = client;
	
	EmitSoundToClient(attacker, soundpath,SOUND_FROM_PLAYER,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,volume,(SNDPITCH_NORMAL+hitCounter[client][attacker]));
	EmitSoundToClient(attacker, soundpath,SOUND_FROM_PLAYER,SNDCHAN_AUTO,SNDLEVEL_NORMAL,SND_NOFLAGS,volume,(SNDPITCH_NORMAL+hitCounter[client][attacker]));
	
	return Plugin_Handled;
}


